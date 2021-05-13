	; DEFINE TEST_BASE64
	IFDEF TEST_BASE64
		OPT reset --zxnext --syntax=abfw
		INCLUDE "constants.inc.asm"
		DEVICE ZXSPECTRUM48
		SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

		ORG $8000
		INCLUDE "utils.asm"
		INCLUDE "state.asm"
start:
		di

		;; decode test
		ld hl, s12
		ld a, 96
		;; now a / 4
		rra
		rra

		ld b, a
.loopDecode
		ld de, Base64.buffer
		push bc
	DUP 4
		ld a, (hl)
		ld (de), a
		inc hl
		inc de
	EDUP
		push hl
		call Base64.Decode
		pop hl
		pop bc
		djnz .loopDecode
		jr $

		;; encode
		ld hl, 32
		call Base64.EncodedLength
		; jr $

		ld b, 11
		ld hl, i0
		ld a, 1
		ld (State.padding), a
		ld de, result
.loop
		push hl
		push de
		call Base64.Encode			; result in DE
		pop de

		ld hl, Base64.buffer
	DUP 4
		ld a, (hl)
		ld (de), a
		inc de : inc hl
	EDUP

		pop hl
	DUP 3
		inc hl
	EDUP
		djnz .loop
		jr $

		ALIGN 256
result:
		DS 256
	ENDIF


	MODULE Base64

; HL = length of pre-encoded text
; HL <- result (HL / 3 * 4 rounded)
; A <- padding
; Modifies: BC
;
; Returns the length required to encode a string of HL length
EncodedLength
		push de					; protect DE
		push hl
		ld c, 3					; start by dividing HL by 3
		xor a
		ld b, 16
.loop:
		add hl, hl
		rla
		jr c, $+5
		cp c
		jr c, $+4

		sub c
		inc l

		djnz .loop

		;; capture remainder in C to restore later
		; ld c, a
		and a
		jr z, $+3
		inc hl

		;; then multiply by 4 via two rotate shifts left
		rl l
		rl h					; make sure to carry to H

		and a					; now clear the carry
		rl l					; and repeat
		rl h

		;; now we need to work out what the padding is
		;; and store this for when we deliver the a stream
		pop bc					; BC is original value, HL is multiplied value
		push hl

		rr h					; HL / 4
		rr l
		rr h
		rr l

		ld d, h					; copy HL to DE
		ld e, l

		add hl, hl				; HL * 2
		add hl, de				; HL + DE = (HL / 4) * 3

		;; HL now contains estimated source length, now we substract
		;; the original length stored in BC to work out how many
		;; padding bytes we need
		and a					; first clear the  carry
		sbc hl, bc				; HL - BC (and the carry, but that's cleared)
		ld a, l					; will be 0, 1 or 2
		ld (State.paddingReal), a		; squirrel away for later

		pop hl					; HL is our base64 encoded length
		pop de					; restore original DE

		ret


encode64

 		DB "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

; HL = pointer to 3 character buffer
; DE <- buffer with 4 bytes base64 encoded
Encode
		;; if carry, then the support padding
		jp nc, .notAtEnd

		;; if there IS carry, then we want to add padding, but let's
		;; first check the state padding, because sometimes I'm coming
		;; into this call with a carry, and we're not actually at the
		;; very end of the stream. I suspect a bug in the logic somewhere
		;; but this extra check should get me out of jail and prevent
		;; the logic.
		ld a, (State.padding);
		and a
		jr z, .notAtEnd				; not stritly true, but might also mean no padding required

		;; modify out routine - don't worry, it won't be called again
		push hl
		ld hl, .SMC_withPaddingJump

		ld (hl), .withPadding
		pop hl

.notAtEnd
		ld a, (hl)				; chr 1
		and %11111100
		rra
		rra

		;; encode A to base64 table
		ld de, encode64
		add de, a
		ld a, (de)
		ld (buffer), a				; save first value

		ld a, (hl)
		and %00000011
		rla
		rla
		rla
		rla					; shift left 4

		ld d, a					; save char 1 for or op later
		inc hl
		ld a, (hl)				; chr 2
		and %11110000				; take the upper nibble
		rra
		rra
		rra
		rra					; shift right 4 (aka swap nibble)
		or d					; then or original A value

		ld de, encode64
		add de, a
		ld a, (de)
		ld (buffer+1), a			; save second value

.SMC_withPaddingJump EQU $+1
		jr $+1

		ld a, (hl)				; chr 3
		and %00001111				; take the lower nibble
		rla
		rla					; A = %00111100
		ld d, a					; save for later
		inc hl
		ld a, (hl)
		rlca
		rlca					; rotate *through* carry twice
		and %00000011				; then mask
		or d

		ld de, encode64
		add de, a
		ld a, (de)
		ld (buffer+2), a			; save third value

		ld a, (hl)				; chr 4

		and %00111111
		ld de, encode64
		add de, a
		ld a, (de)
		ld (buffer+3), a			; save fouth value

		jr .done

.twoBytes:
		ld hl, buffer+2
		ld a, '='
		ld (hl), a
		inc hl
		ld (hl), a
		jr .done

.threeBytes:
		ld hl, buffer+3
		ld a, '='
		ld (hl), a
.done
		ld de, buffer
		ret

; Modifies: A
.reset
		ld a, $ff
		ld (.SMC_withPaddingJump), a
		ret

.withPadding EQU $-.SMC_withPaddingJump-1

		ld a, (hl)				; chr 3
		and a
		jr z, .twoBytes

		and %00001111				; take the lower nibble
		rla
		rla					; A = %00111100
		ld d, a					; save for later
		inc hl
		ld a, (hl)
		rlca
		rlca					; rotate *through* carry twice
		and %00000011				; then mask
		or d

		ld de, encode64
		add de, a
		ld a, (de)
		ld (buffer+2), a			; save third value

		ld a, (hl)				; chr 4
		and a
		jr z, .threeBytes

		and %00111111
		ld de, encode64
		add de, a
		ld a, (de)
		ld (buffer+3), a			; save fouth value

		jr .done
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

; Expects Base64.buffer to contain only 4 bytes
;
; Modifies: AF, BC
Decode:

; Convert the 4 bytes in .buffer from 7-bit encoded to 8-bit decoded bytes,
; and store in .output. Once done, .output is 3 bytes long, copy it over
; the original input buffer.
.capture
		;; byte 1 - is (%00111111 << 2) | (%00110000 >> 4)
		ld a, (buffer+1)
		call ToIndex			; convert to base64 table and shift left x 2
		rla
		rla

		ld c, a
		rlca				; rotate left twice through carry
		rlca				; because our byte was already left shift 2
		ld b, %00000011
		and b				; add last 2 bytes to A
		ld b, a
		ld a, (buffer)
		call ToIndex			; convert to base64 table and shift left x 2
		rla
		rla

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
		call ToIndex			; convert to base64 table and shift left x 2
		rla
		rla

		;; plus (byte 3 >> 4) & %00001111
		rra
		rra
		rra
		rra
		and %00001111
		or c
		ld (output+1), a

		;; byte 3 - is %00000011 << 6 | %00111111
		ld a, (buffer + 3)
		call ToIndex			; convert to base64 table and no shift
		ld c, a

		ld a, (buffer + 2)
		call ToIndex			; convert to base64 table and no shift
		rrca
		rrca
		and %11000000

		or c
		ld (output+2), a
		ret

	ALIGN ;; align 4 by default
		DB $AA				; marker
input
output
		DS 3
		nop				; push this forward 1 byte
	DISPLAY "Base64 decode buffer @ ",/H,$
buffer
		DS 4
	ENDMODULE

	IFDEF TEST_BASE64
i0
		DEFB $16, $1f, $19, $00, $42, $42, $3b, $12, $1c, $30, $4f, $58, $57, $56, $55, $60
 		DEFB $60, $5f, $5e, $5d, $5f, $5d, $5d, $47, $51, $5b, $51, $51, $5b, $52, $45, $4d, 0
i1:		DEFB "123",0 ; MTIz
i2:		DEFB "I",0 ; SQ==
i3:		DEFB "Am",0 ; QW0=
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

s12:		DEFB "UkVNmZl4DVJFTVdGeAhKVUwiIUYIUkVNV0bUB0FCSVdGoAdSRQBw/ogHU1RTshNYB0RBRJmZVgdSRU2ZmRQHRVRTIiG4BA==",0

end:
		SAVESNA "base64.sna", start
	ENDIF
