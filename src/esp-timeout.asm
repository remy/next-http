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
		ld (Value2), hl
		ld hl, ESPTimeout mod 65536
		ld (Value), hl
		jr Success
	ENDMODULE
