InitESPTimeout:
	MODULE InitESPTimeout
		push hl
		ld hl, ESPTimeout mod 65536 	; Timeout is a 32-bit value, so save the two LSBs first,
		ld (CheckESPTimeout.Value), hl
		ld hl, ESPTimeout / 65536	; then the two MSBs.
		ld (CheckESPTimeout.Value2), hl
		pop hl
		ret
	ENDMODULE

; Modifies: nothing
CheckESPTimeout:
	MODULE CheckESPTimeout
		push hl
		push af
Value 	EQU $+1
		ld hl, SMC
		dec hl
		ld (Value), hl
		call WaitRaster
		ld a, h
		or l
		jr z, Rollover
Success:	pop af
		pop hl
		ret
Failure:	ld hl, (Wifi.timeout)
HandleError:
		call Error 			; Ignore current stack depth, and just jump

Rollover:
Value2 	EQU $+1
		ld hl, SMC			; Check the two upper values
		ld a, h
		or l
		jr z, Failure			; If we hit here, 32 bit value is $00000000
		dec hl
		call WaitRaster
		ld (Value2), hl
		ld hl, ESPTimeout mod 65536
		ld (Value), hl
		jr Success

// https://github.com/remy/next-http/issues/7
WaitRaster:
		push bc
		push af
.waitloop:
		ld bc, $243b
		ld a, $1f     			; only really care about lsb
		out (c), a
		inc b
		in a, (c)
		cp 192
		jr nz, .waitloop
		pop af
		pop bc
		ret

	ENDMODULE
