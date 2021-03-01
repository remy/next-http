	; DEFINE TEST_BASE64
	IFDEF TEST_BASE64
		OPT reset --zxnext --syntax=abfw
		DEVICE ZXSPECTRUM48

		ORG $8000
start:
		di
		ld hl, Base64.sample7
		ld de, result
		call Base64.Decode			; result in DE
		jr $

result:
		DS 256
	ENDIF


	MODULE Base64

; HL = input buffer
; DE = output buffer location
Decode:
		push de
		push de
		ld de, buffer
		ld ixl, 0

.loop
		ld a, (hl)
		inc hl
		and a
		jr z, .end

		cp '='
		jr z, .padding

		call ToIndex
		ret c				; bail on error
		rla				; shift left 2
		rla
.continue
		ld (de), a			; then save
		inc de
		inc ixl
		ld a, ixl
		cp 4
		jr z, .capture			; if we have 4 bytes, then convert

		jr .loop

.padding					; put a null byte to ignore padding
		xor a
		jr .continue

.capture
		;; DE holds the current 4 byte buffer

		;; byte 1 - is (%00111111 << 2) | (%00110000 >> 4)
		ld a, (buffer+1)
		ld c, a
		rlca				; rotate left twice through carry
		rlca				; because our byte was already left shift 2
		ld b, %00000011
		and b				; add last 2 bytes to A
		ld b, a
		ld a, (buffer)
		add b
		ld (output), a

		;; byte 2 - is %00001111 << 4 | %00110000 >> 4
		ld a, c
		rla
		rla				; A should mask to %11110000
		and %11110000
		ld c, a				; C contains buffer + 1 with shift and mask

		;; only if we have 3 chars (though the above was potentially a waste)
		ld a, (buffer + 2)
		and a
		jr z, .capturePad2
		;; plus (byte 3 >> 4) & %00001111
		; swapnib
		rra
		rra
		rra
		rra
		and %00001111
		or c
		ld (output+1), a

		;; byte 3 - is %00000011 << 6 | %00111111
		ld a, (buffer + 3)
		and a
		jr z, .capturePad1
		rra
		rra				; (undo shift left) shift right 2
		ld c, a

		ld a, (buffer + 2)
		rla
		rla
		rla
		rla
		and %11000000

		or c
		ld (output+2), a

		jr .captureDone

.capturePad2
		xor a
		ld (output+1), a
.capturePad1
		xor a
		ld (output+2), a
.captureDone:
		;; TODO check whether == on a long string is going to corrupt the
		;; end of DE
		pop de				; copy output to the end of DE
		push hl
		ld bc, 3
		ld hl, output
		ldir

		pop hl


		push de				; setup for the next 4 byte loop
		ld de, buffer
		ld ixl, 0			; reset the counter
		jr .loop

.end:
		pop de
		xor a
		ld (de), a
		pop de				; restore DE to start position
		ret
.error
		scf
		ret

;; -----------------------------------------------------------------------------

; A = 7-bit byte value
; A <- index
; Fc <- carry flag indicates error
ToIndex
		cp '+'
		jr z, .plus
		cp '/'
		jr z, .slash

		cp ':'				; if A < ':' then it's a numeric
		jr c, .numeric
		cp '['				; if A < '[' then it's uppercase
		jr c, .uppercase

		;; else it's lowercase
		cp 'a'				; if A < 'a' then we're out of bounds
		ret c
		sub 'a'
		add a, 26
		ret

.uppercase
		cp 'A'				; if A < 'A' then we're out of bounds
		ret c
		sub 'A'
		ret

.numeric
		cp '0'				; if A < '0' then we're out of bounds
		ret c
		sub '0'
		add a, 52
		ret

.plus
		ld a, 62
		ret

.slash
		ld a, 63
		ret

buffer
		DS 4
output
		DS 3

	IFDEF TEST_BASE64

sample1:	DEFB "SQ==",0 ; I
sample6:	DEFB "QW0=",0 ; Am
sample5:	DEFB "UmVt",0 ; Rem
sample4:	DEFB "SGVsbG8sIHdvcmxkIQ==",0 ; Hello, World
sample2:	DEFB "UmVteQ==",0 ; Remy
sample3:	DEFB "SGVsbG8=",0 ; Hello
sample7:	DEFB "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0"
		DEFB "+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3"
		DEFB "x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5u"
		DEFB "ru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4"
		DEFB "+fr7/P3+/w==",0 ; 0-255
	ENDIF

	ENDMODULE
	IFDEF TEST_BASE64
		SAVESNA "base64decode.sna", start
	ENDIF
