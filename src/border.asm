; Toggles the border based on a predefined value swapped into
; Border.newColour and the value from Border.Init - which is
; the border when the program started
Border:
		;; we'll change this to `ret` if border is disabled
		;; otherwise it remains as nop
.SMC_disableBorder:
		nop
		ex af, af'
		jr nc, .addColour
.userColour EQU $+1
		ld a, SMC
		and a				; reset carry
		jr .apply
.addColour
.newColour EQU $+1
		ld a, SMC
		scf
.apply
		out (254), a
		ex af, af'
		ret

; A = raw value from BORDCR - actual border is in bits 3-5
.Init
		rrca 				; A >> 3
		rrca
		rrca
		and a, %00000111		; mask the rest
		ld (Border.userColour), a
		ret

.Restore
		ex af, af'
		ld a, (Border.userColour)
		out (254), a
		ex af, af'
		ret
