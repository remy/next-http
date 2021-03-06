	MODULE Headers
Post
		ld hl, Strings.post
		jr method

Get
		ld hl, Strings.get
method
		ld bc, 5
		ldir
		ret

MethodTrailer
		ld hl, Strings.reqTail
		ld bc, Strings.reqTailLen
		ldir
		ret

; HL = copy from buffer terminated with null
; DE = copy to
; DE <- end of buffer
; Modifies: AF
Host
		push hl
		ld hl, Strings.host
		ld bc, 5
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
		jr z, .done
		ld (de), a
		inc hl
		inc de
		jr copyHLtoDE
.done
		ret

PostLengthAndTrailer
		push de
		push hl

		ex de, hl
		call StringLength
		jr c, .lengthError
		ld b, h
		ld c, l					; BC = HL (BC = string length of "length" value)
		pop hl					; HL = input buffer
		pop de					; DE = output
		ldir
		jr Trailer

.lengthError:
		ld hl, Err.lengthError
		;; jumping to error and exit here shouldn't matter as SP is
		;; restored so our corrupted/unpushed state will be ignored
		jp Error
Trailer
		ld hl, Strings.newLine
		ld bc, 3
		ldir
		ret


	ENDMODULE
