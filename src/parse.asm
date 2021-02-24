	MODULE Parse
showHelp:
		ld hl, Msg.help
		call PrintRst16
		pop af					; discard the return address (from call Parse.start)
		and a					; Exit Fc=0
		jp Exit.nop


doGet:
		ld a, State.GET
		ld (State.type), a
		PrintText "Do GET"
		jr startToken

doPost:
		ld a, State.POST
		ld (State.type), a
		PrintText "Do POST"
		jr Parse.startToken

parseError:
		PrintText "Bad option"
		pop af
		ld hl, Err.badOption
		xor a					; set A = 0
		scf					; Exit Fc=1
		jp Exit.nop


; HL = start of arguments
; Modifies: A, HL
start:
		ld a, h : or l				; check if HL is zero
		jr z, Parse.showHelp			; if no args, show help

startToken
		ld a, (hl)
		inc hl

		;; terminated by $00, $0d or ':'
		call checkForEnd
		ret z

		cp 'g' : jr z, doGet
		cp 'p' : jr z, doPost
		cp '-' : jr z, parseOption

		jr startToken

parseOption
		ld a, (hl)
		inc hl
		call checkForEnd
		jr z, parseError

		push af
.eatSpaces:
		ld a, (hl)
		inc hl
		cp ' ' : jr z, .eatSpaces
		call checkForEnd
		jr z, parseError

		ld b, a
		pop af

		cp 'b' : jr z, parseBank
		cp 'h' : jr z, parseHost
		cp 'p' : jr z, parsePort
		cp 'u' : jr z, parseUrl
		cp 'l' : jr z, parseLength
		cp 'o' : jr z, parseOffset
		jr parseError

continueOption:
		ld a, b
.loop
		ld (de), a
		inc de
		ld a, (hl)
		inc hl
		cp ' ' : jr z, .optionDone
		call checkForEnd
		jr z, .optionDone
		jr .loop
.optionDone:
		xor a
		ld (de), a				; add null terminator to the option
		jp startToken


parseBank:	ld de, State.bank : jr continueOption
parseHost:	ld de, State.host : jr continueOption
parsePort:	ld de, State.port : jr continueOption
parseUrl:	ld de, State.url : jr continueOption
parseLength:	ld de, State.length : jr continueOption
parseOffset:	ld de, State.offset : jr continueOption


; A = character to test
; Fz <- if at end
checkForEnd:
		and a  : ret z				; A is null
		cp ':' : ret z
		cp $0d : ret z
		ret

	ENDMODULE
