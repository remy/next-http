; HL = number to ASCII
; HL <- string buffer
; Modifies: AF
;
; Number in hl to decimal ASCII
; Thanks to z80 Bits
; example: hl=300 outputs '00300'
HLtoNumber:
		ld a, l
		or h
		jr z, .zero
		push hl
		exx
		pop hl

		ld de, .buffer
		call .hltoNumber

		exx
		ld hl, .buffer
.trim						; trim leading '0'
		ld a, (hl)
		cp '0'
		ret nz
		inc hl
		jr .trim

.zero
		ld a, '0'
		ld (hl), a
		ret

.hltoNumber
		ld	bc, -10000
		call	.num1
		ld	bc, -1000
		call	.num1
		ld	bc, -100
		call	.num1
		ld	c, -10
		call	.num1
		ld	c, -1
.num1:
		ld	a, '0'-1
.num2:
		inc	a
		add	hl, bc
		jr	c, .num2
		sbc	hl, bc
		ld (de), a
		inc de

		ret
.buffer
	DEFB "00000",0

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
		and a
		jr z, .return
		rst 16
		jr .loop
.return:
	        di
		ret

; DE = points to the base 10 number null terminated string.
; HL <- 16 bit value of DE
; Fc <- carry set on error
; Modifies: A, BC
;
;     HL is the 16-bit value of the number
;     DE points to the byte after the number
;     z flag reset (nz)
StringToNumber16:
		ld hl, 0				; init HL to zero
.convLoop:
		ld a, (de)
		and a
		ret z					; null character exit

		sub $30					; take DE and subtract $30 (48 starting point for numbers in ascii)
		ret c					; if we have a carry, then we're

		scf					; set the carry flag to test-
		cp 10					; if A >= 10 then we also have an error
		jr nc, .error

		inc de

		ld b, h					; copy HL to BC
		ld c, l

		add hl, hl				; (HL * 4 + HL) * 2 = HL * 10
		add hl, hl
		add hl, bc
		add hl, hl

		add a, l
		ld l, a
		jr nc, .convLoop
		inc h
		jr .convLoop

.error
		scf
		ret


; Return the address of the end of string
;
; HL = string
; HL <- end of string
strEnd:
                push    af
                xor     a
                dec     hl
.l1:            inc     hl
                cp      (hl)
                jp      nz,.l1
                pop     af
                ret


; via https://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Division#32.2F16_division
; ACIX = dividend
; DE = divisor
; ACIX <- quotient
; DE <- divisor
; HL <- remainder
; B <- 0
Div32By16:
		ld	hl,0
		ld	b,32
.loop:
		add	ix,ix
		rl	c
		rla
		adc	hl,hl
		jr	c,.overflow
		sbc	hl,de
		jr	nc,.setbit
		add	hl,de
		djnz	.loop
		ret
.overflow:
		or	a
		sbc	hl,de
.setbit:
		inc ixl
		djnz	.loop
		ret


; DE = base 10 number buffer
; HLIX <- 32bit value
; Modifies: BC, DE, AF
atoui32:
;===============================================================
;Input:
;     DE points to the base 10 number string in RAM.
;Outputs:
;     HLIX is the 32-bit value of the number
;     DE points to the byte after the number
;     BC points to the start of the number
;     z flag means it ended on a decimal point.
;Destroys:
;     A (actually, add 30h and you get the ending token)
;     BC
;===============================================================
		ld hl,0
		ld ix,0
		push de   ;save the pointer
		jr .start
.loop:
		inc de
		ld b,ixh
		ld c,ixl
		push hl
		add ix,ix
		adc hl,hl
		add ix,ix
		adc hl,hl
		inc ix
		dec ix
		add ix,bc
		pop bc
		adc hl,bc
		add ix,ix
		adc hl,hl
		add a,ixl
		ld ixl,a
		jr nc,.start
		inc ixh
		jr nz,.start
		inc hl
.start:
		ld a,(de)
		sub 30h
		cp 10
		jr c,.loop
		pop bc
		ret
