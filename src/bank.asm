	MODULE Bank

prevBankA	DEFB 0
prevBankB	DEFB 0
userBank	DEFB 0

pageA		EQU MMU4_8000_NR_54
pageB		EQU MMU5_A000_NR_55

					; NOTE: MMU3/5 are safe from being
					;       paged out when making NextZXOS
					;       calls (unlike MMU0/1/6/7)

buffer		EQU $8000
	IFDEF TESTING
debug		DW $A000
	ENDIF

; A <- 16K bank number to use as active bank
; Modifies: A, BC (via macro)
init:
		;; double the value as we'll get 16K bank
		add a, a
		ld (userBank), a

		;; backup the banks that are sitting over $8000 and $A000
		;; note that with a dot file, the stack originally is sitting at $FF42
		;; so if I do use this area, I need to set my own stackTop
		NextRegRead pageA		; loads A with pageA bank number
		ld (prevBankA), a
		NextRegRead pageB
		ld (prevBankB), a

		;; now page in our user banks
		ld a, (userBank)
		nextreg	pageA, a ; set bank to A
		inc a
		nextreg	pageB, a ; set bank to A
		ret

erase:
		ld bc, $4000				; 16k
		ld hl, buffer
		ld de, buffer + 1
		ld (hl), 0
		ldir
		ret

restore:
		push af
		ld a, (prevBankA)
		nextreg	pageA, a
		ld a, (prevBankB)
		nextreg	pageB, a
		pop af
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
