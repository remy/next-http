; DE = buffer to write to
; HL = pointer to string to copy
; DE <- byte after new string inserted
; Modifies: AF, HL, DE
;
; Copies until it reaches a null byte in HL (when length is unknown)
CopyDEtoHL:
.loop
		ld a, (hl)
		and a : jr z, .done
		ld (de), a
		inc hl
		inc de
		jr .loop
.done
		ret

; DE = pointer to string that's null terminated
; HL <- string length
; Modifies: DE
StringLength:
		ld hl, 0
.loop
		ld a, (de) : and a : ret z
		inc de
		inc hl
		jr .loop

; Uses RST 16 to loop through and print a sequence of characters
; HL = string pointer, null terminated
; Modifies: A
PrintRst16:
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

; DE = points to the base 10 number string in RAM.
; HL <- 16 bit value of DE
; Modifies: A, BC
;
;     HL is the 16-bit value of the number
;     DE points to the byte after the number
;     BC is HL/10
;     z flag reset (nz)
;     c flag reset (nc)
; Size:  23 bytes
; Speed: 104n+42+11c
;       n is the number of digits
;       c is at most n-2
;       at most 595 cycles for any 16-bit decimal value
StringToNumber16:
	ld hl, 0				; init HL to zero
ConvLoop:
	ld a, (de)
	sub $30					; take DE and subtract $30 (48 starting point for numbers in ascii)
	cp 10					; is A < 10
	ret nc
	inc de

	ld b, h					; copy HL to BC
	ld c, l

	add hl, hl				; (HL * 4 + HL) * 2 = HL * 10
	add hl, hl
	add hl, bc
	add hl, hl

	add a, l
	ld l, a
	jr nc, ConvLoop
	inc h
	jr ConvLoop
