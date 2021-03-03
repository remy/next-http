	; DEFINE TEST_BASE64
	IFDEF TEST_BASE64
		OPT reset --zxnext --syntax=abfw
		INCLUDE "constants.inc.asm"
		DEVICE ZXSPECTRUM48
		SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

		ORG $8000
start:
		di
		ld bc, $aa
		ld de, $dd
		ld hl, Base64.s11
		call Base64.Decode			; result in DE
		jr $

result:
		DS 256
	ENDIF


	MODULE Base64

; HL = input buffer in blocks of 4 bytes - null terminatd
; HL <- end of updated buffer (overwriting original HL) - null terminated (plus tailing junk from original HL buffer)
; Modifies: AF, IX
Decode:
		push bc				; protect DE and BC
		push de

		push hl				; we need to save the start position of the
						; user input buffer, so we can write to it
						; in .captureDone

		ld de, buffer			; DE points to the working temp buffer
		ld ixl, 0			; ixl used as a mod 4 counter
		ld ixh, 0			; ixh is used to track the padding

.loop
		ld a, (hl)			; set A to user buffer byte
		inc hl
		and a				; check for null byte (0)
		jr z, .end			; exit if we've hit the end of the buffer

		cp '='
		jr z, .padding			; '=' is used as padding in base64

		;; arguably this doesn't need to be a routine, and could be inline
		call ToIndex
		jr c, .error			; bail on error
		rla				; shift left 2
		rla
.continue
		ld (de), a			; save the base64 table value into
		inc de				; the working buffer
		inc ixl
		ld a, ixl
		cp 4
		jr z, .capture			; if we have 4 bytes, then convert

		jr .loop

.padding					; put a null byte to ignore padding
		xor a
		inc ixh
		jr .continue

; Convert the 4 bytes in .buffer from 7-bit encoded to 8-bit decoded bytes,
; and store in .output. Once done, .output is 3 bytes long, copy it over
; the original input buffer.
.capture
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

.captureDone:
		pop de				; pop input buffer to DE for LDIR copy
		push hl				; save working position
		ld bc, 3
		ld hl, output
		ldir

		pop hl				; restore working position

		push de				; save result pointer

		; ex de, hl			; point HL back to user input buffer

		ld de, buffer
		ld ixl, 0			; reset the counter

		jr .loop

.end:
		pop de				; DE now points to end of string
		xor a
		ld (de), a
		ld a, ixh
		and a
		jr z, .exit
		ld b, a
.endCleanLoop:
		;; FIXME this is wrong, it's incorrectly eating any zero bytes
		;; that was put there by the user
		dec de
		djnz .endCleanLoop
		jr .exit
.error:
		pop de
		scf
.exit:
		ex de, hl
		pop de
		pop bc
		ret


;; -----------------------------------------------------------------------------

; A = 7-bit byte value
; A <- index
; Fc <- carry flag indicates error
;
; This could be refactored to be a lookup table - it would take up more space
; as it would need to be byte aligned on 256 edge, but it would be a lot faster
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
sample2:	DEFB "QW0=",0 ; Am
sample3:	DEFB "UmVt",0 ; Rem
sample4:	DEFB "SGVsbG8sIHdvcmxkIQ==",0 ; Hello, World
sample5:	DEFB "UmVteQ==",0 ; Remy
sample6:	DEFB "SGVsbG8=",0 ; Hello
sample7:	DEFB "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0"
		DEFB "+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3"
		DEFB "x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5u"
		DEFB "ru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4"
		DEFB "+fr7/P3+/w==",0 ; 0-255
s8:		DEFB "//8A",0
s9:		DEFB "AAAA",0
s10:		DEFB "AAAA",0

s11:		DEFB "AAECAwQFBgcICQoLDA0ODxAREhMUFQ==",0
	ENDIF

	ENDMODULE
	IFDEF TEST_BASE64
		SAVESNA "base64decode.sna", start
	ENDIF
