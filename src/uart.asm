; Author: Alexander Sharikhin nihirash
; License: https://github.com/nihirash/internet-nextplorer/blob/89baa64d974e2d916862280a9ec2f52247923172/LICENSE
; By them a coffee :-)

    MODULE Uart
UART_RxD  EQU $143B       ; Used to set the baudrate
UART_TxD  EQU $133B       ; Reads status
UART_Sel  EQU $153B       ; Selects between ESP and Pi, and sets upper 3 bits of baud
UART_SetBaud EQU UART_RxD ; Sets baudrate
UART_GetStatus EQU UART_TxD

UART_TX_BUSY       EQU %00000010
UART_RX_DATA_READY EQU %00000001
UART_FIFO_FULL     EQU %00000100

; Enable UART - Cleaning all flags by reading UART regs
;
; Modifies AF and BC
init
SMC_skip_baud_init
		nop
		ld hl, .baudTable
		ld bc, $243B			;Now adjust for the set Video timing.
		ld a, 17
		out (c), a
		ld bc, 9531
		in a, (c)			;get timing adjustment
		ld e,a
		rlc e				;*2 guaranteed as <127
		ld d, 0
		add hl, de

		ld e, (hl)
		inc hl
		ld d, (hl)
		ex de, hl

		ld bc, UART_Sel
		ld a, %00100000
		out (c), a 			; select uart

		ld bc, UART_SetBaud
		ld a, l
		AND %01111111			; Res BIT 7 to req. write to lower 7 bits
		out (c), a
		ld a, h
		rl l				; Bit 7 in Carry
		rla				; Now in Bit 0
		or %10000000			; Set MSB to req. write to upper 7 bits
		out (c), a
		ret

.baudTable:
		DEFW 243,248,256,260,269,278,286,234	; 115K


; A <- result
; Modifies: BC
read:
		call InitESPTimeout
		ld bc, UART_GetStatus
.wait:
		in a, (c)
		rrca
		jr nc, .checkTimeout
		ld bc, UART_RxD
		in a, (c)
	IFDEF TESTING
		call debug
	ENDIF
		call Border
		ret
.checkTimeout
		call CheckESPTimeout
		jr .wait

	IFDEF TESTING
debug:
		;; write to the debug bank - $A000 and no further
		push hl
		push af
		ld hl, (Bank.debug)
		ld a, h
		bit 7,h
		jr nz, .outOfDebugMemory
		pop af
		ld (hl), a
		inc hl
		ld (Bank.debug), hl
		pop hl
		ret
.outOfDebugMemory
		pop af
		pop hl
		ret
	ENDIF

; A = byte to write
; Modifies: BC, DE
;
; Write single byte to UART
write:
		call Border
		call InitESPTimeout
		ld d, a
	IFDEF TESTING
		call debug
	ENDIF

		ld bc, UART_GetStatus
.wait
		in a, (c)
		and UART_TX_BUSY
		jr nz, .checkTimeout
		out (c), d
		call Border
		ret

.checkTimeout
		call CheckESPTimeout
		jr .wait

    ENDMODULE
