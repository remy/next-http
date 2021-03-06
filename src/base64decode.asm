	MODULE Base64



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

; Modifies: AF, BC
; Expects Base64.buffer to contain only 4 bytes
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
		nop				; push this forward 1 byte
	DISPLAY "Base64 decode buffer @ ",/H,$
buffer
		DS 4
output
		DS 3

		DB "Z"
	ENDMODULE
