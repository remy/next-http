	MODULE Headers
Post
		ld hl, Strings.post
		ld bc, 5
		jr method

Get
		ld hl, Strings.get
		ld bc, 4
method
		ldir
		ret

GetTrailer
		ld hl, Strings.reqTail
		ld bc, Strings.reqTailLen
		ldir
		ret

PostTrailer
		ld hl, Strings.reqTail
		ld bc, Strings.postLen
		ldir
		ret

; HL = copy from buffer terminated with null
; DE = copy to
; DE <- end of buffer
; Modifies: AF
Host
		push hl
		ld hl, Strings.host
		ld bc, 6
		ldir
		pop hl
		;; intentionally fall through to copyHLtoDE

; HL = copy from buffer terminated with null
; DE = copy to
; DE <- end of buffer
; Modifies: AF
Url
copyHLtoDE
		ld a, (hl)
		and a
		ret z
		ld (de), a
		inc hl
		inc de
		jr copyHLtoDE

NewLine
		ld hl, Strings.newLine
		ld bc, 2
		ldir
		ret

EndPost
		ld hl, Strings.emptyLine
		ld bc, 5
		ldir
		ret

EndGet
		ld hl, Strings.newLine
		ld bc, 3
		ldir
		ret


	ENDMODULE
