; DE = pointer to string that's null terminated
; HL <- string length
; Modifies: DE
strLen:
		ld hl, 0
.loop
		ld a, (de) : and a : ret z
		inc de
		inc hl
		jr .loop

PrintRst16:
        MODULE PrintRst16
		ei
.loop:
	        ld a, (hl)
		inc hl
		or a
		jr z, .return
		rst 16
		jr .loop
.return:
	        di
		ret
        ENDMODULE
