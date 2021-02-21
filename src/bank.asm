	MODULE Bank

prevBankA	DEFB 0
prevBankB	DEFB 0
userBank	DEFB 0



; A <- 16K bank number to use as active bank
; Modifies: A, BC (via macro)
init:
		;; double the value as we'll get 16K bank
		add a, a
		ld (userBank), a

		;; backup the banks that are sitting over $C000 and $E000
		;; note that with a dot file, the stack originally is sitting at $FF42
		;; so do use this area, I need to set my own stackTop (see vars.asm)
		NextRegRead MMU6_C000_NR_56
		ld (prevBankA), a
		NextRegRead MMU7_E000_NR_57
		ld (prevBankB), a

		;; now page in our user banks
		ld a, (userBank)
		nextreg	MMU6_C000_NR_56, a ; set bank to A
		inc a
		nextreg	MMU7_E000_NR_57, a ; set bank to A
		ret

erase:
		ld bc, $4000				; 16k
		ld hl, buffer
		ld de, buffer + 1
		ld (hl), 0
		ldir
		ret

restore:
		ld a, (prevBankA)
		nextreg	MMU6_C000_NR_56, a
		ld a, (prevBankB)
		nextreg	MMU7_E000_NR_57, a
		ret

	ENDMODULE


; Not used directly - called from the NextRegRead macro
;
; A = register value
; A <- value of register
; Modifies: B
NextRegReadProc:
		out (c), a
		inc b
		in a, (c)
		ret
