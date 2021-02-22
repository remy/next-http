	MODULE Parse
; HL = start of arguments
; Modifies: A
start:
		ld a, h : or l				; check if HL is zero
		jr z, showHelp				; if no args, show help
		ret

showHelp:
		ld hl, Msg.help
		call PrintRst16
		pop af					; discard the return address (from call Parse.start)
		jp Exit.nop

	ENDMODULE
