; Author: Alexander Sharikhin nihirash
; License: https://github.com/nihirash/internet-nextplorer/blob/89baa64d974e2d916862280a9ec2f52247923172/LICENSE
; By them a coffee :-)
;
; Includes modifications specific to the httpbank dot command by Remy Sharp

    MODULE Wifi
bytesAvail DW 0
bufferPointer DW 0
closed DB 1
skipReply DB 0
firstRead DB 1
byteCounter DB 0
restarted DB 0

	DISPLAY "Wifi error @ ",/H,$
error DW 0
fail DW 0
timeout DW Err.ESPTimeout

; Initialize Wifi chip to work
init:
	call Uart.init
	EspCmdOkErr "ATE0"
	jr c, .initError
	EspCmdOkErr "AT+CIPCLOSE" ; Close if there some connection was. Don't care about result
	EspCmdOkErr "AT+CIPMUX=0" ; Single connection mode
	jr c, .initError

	or a
	ret
.initError
	call RetartESP
	jr c, .failed
	jr Wifi.init
.failed
	ld hl, Err.wifiInit
	scf
	ret

RetartESP:
	ld a, (restarted)
	and a
	jr nz, .alreadyTried
	ld a, 1
	ld (restarted), a

	EspCmd "AT+RST"
	jr .checkWifiConnect
.alreadyTried
	scf
	ret
.checkWifiConnect:
	call Uart.read
	cp 'F' : jr z, .connectedStart ; WIFI CONNECTED
	jr .checkWifiConnect
.connectedStart
	call Uart.read : cp 'I' : jr nz, .checkWifiConnect
	call Uart.read : cp ' '  : jr nz, .checkWifiConnect
	call Uart.read : cp 'G'  : jr nz, .checkWifiConnect  ; searching for "WIFI CONNECTED"
	call flushToLF
	or a
	ret


; HL - host pointer
; DE - port pointer
openTCP:
	push de
	push hl

	;; setup the custom error types
	ld hl, Err.hostConnect
	ld (error), hl
	ld hl, Err.errorConnect
	ld (fail), hl

	EspCmdOkErr "AT+CIPCLOSE" ; Don't care about result. Just close if it didn't happens before
	EspSend 'AT+CIPSTART="TCP","'
	pop hl
	call espSendT
	EspSend '",'
	pop hl
	call espSendT
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write
	xor a : ld (closed), a
	jp checkOkErr

checkOkErr:
	call Uart.read
	cp 'O' : jr z, .okStart ; OK
	cp 'E' : jr z, .errStart ; ERROR
	cp 'F' : jr z, .failStart ; FAIL
	jr checkOkErr
.okStart
	call Uart.read : cp 'K' : jr nz, checkOkErr
	call Uart.read : cp 13  : jr nz, checkOkErr
	call flushToLF
	or a
	ret
.errStart
	call Uart.read : cp 'R' : jr nz, checkOkErr
	call Uart.read : cp 'R' : jr nz, checkOkErr
	call Uart.read : cp 'O' : jr nz, checkOkErr
	call Uart.read : cp 'R' : jr nz, checkOkErr
	call flushToLF
	ld hl, (error)
	scf
	ret
.failStart
	call Uart.read : cp 'A' : jr nz, checkOkErr
	call Uart.read : cp 'I' : jr nz, checkOkErr
	call Uart.read : cp 'L' : jr nz, checkOkErr
	call flushToLF
	ld hl, (fail)
	scf
	ret
flushToLF
	call Uart.read
	cp 10 : jr nz, flushToLF
	ret

; Send buffer to UART
; HL - buff
; E - count
espSend:
	ld a, (hl) : call Uart.write
	inc hl
	dec e
	jr nz, espSend
	ret

; HL - string that ends with one of the terminator(CR/LF/TAB/NULL)
espSendT:
	ld a, (hl)

	and a : ret z
	cp 9 : ret z
	cp 13 : ret z
	cp 10 : ret z

	call Uart.write
	inc hl
	jr espSendT

; HL = header string
; BC = length of data to send
; Modifies: AF, BC, DE, HL
;
; Then sends pointer at DE plus the contents of Bank.buffer
tcpSendBuffer:
	push bc						; BC will be popped when in .sendBody
	push hl						; strLen will overwrite HL

	;; setup the custom error types
	push hl
	ld hl, Err.tcpSend1
	ld (error), hl
	ld hl, Err.tcpSend2
	ld (fail), hl
	pop hl

	ld d, h
	ld e, l
	call StringLength
	inc hl : inc hl ; +CRLF

	;; now add the length of data being sent
	add hl, bc

	push hl						; HL = length of sending body

	EspSend "AT+CIPSEND="

	pop hl
	call hlToNumEsp
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write
.wait
	call Uart.read : cp '>' : jr nz, .wait
	pop hl
.headerLoop
	ld a, (hl) : and a : jr z, .sendBody
	call Uart.write
	inc hl
	jp .headerLoop

.sendBody
	ld hl, (bufferPointer)					; now send the memory buffer
	pop bc


	;; IXH is used for tracking where we're up in the 3 byte buffer tracker
	;; then we load Base64.input into DE and when E mod 4 === 3 then we
	;; flush the buffer with individual calls to Uart.write
	ld de, Base64.input

.bodyLoop

	;; TODO if base64, then create a buffer of 3 bytes, then once full
	;; flush to base64 encoded and send all at once
	ld a, (hl)

.check7bitSupport
	jr .no7bitSupport

	; CSP_BREAK
	;; here be 7-bit / base64 encoding support
	ld (de), a
	inc de
	ld a, e
	and 3
	jr nz, .bufferNotFull

	; CSP_BREAK

	push hl
	push bc

	;; test value of bc here
	or a					; clear carry

	ld a, b
	and a					; if B != 0 then skip
	jp nz, .notAtEnd

	ld a, c
	cp 4
	jp nz, .notAtEnd

	ld a, (State.padding)
	and a
	jr z, .padNone

	cp 2
	jr nz, .padOne
	xor a
	ld (Base64.input+2), a
.padOne
	xor a
	ld (Base64.input+1), a

.padNone
	scf					; set carry as a flag for encode process

.notAtEnd
	ld hl, Base64.input
	call Base64.Encode

	ex de, hl				; swap DE because HL isn't modifid in Uart.write
	ld a, (hl)
	call Uart.write
	inc hl
	ld a, (hl)
	call Uart.write
	inc hl
	ld a, (hl)
	call Uart.write
	inc hl
	ld a, (hl)
	call Uart.write

	pop bc

	dec bc					; adjust for the 4 bytes we just
	dec bc					; sent, and the fourth DEC BC call
	dec bc					; happens before we jump bodyLoop

	pop hl

	ld de, Base64.input
	jr .nextByte

.bufferNotFull
	inc bc					; reverse BC dec whilst we haven't flushed
	jr .nextByte

.no7bitSupport
	push bc
	call Uart.write
	pop bc

.nextByte
	inc hl

	dec bc
	ld a, b
	or c
	jr nz, .bodyLoop

.exit
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write
	jp checkOkErr


; HL = string to send
; Modifies: AF, BC, DE
; Sends the contents of HL to ESP (auto adding the CR+LF to the message)
tcpSendString:
	push hl

	;; setup the custom error types
	ld hl, Err.tcpSend3
	ld (error), hl
	ld hl, Err.tcpSend4
	ld (fail), hl

	EspSend "AT+CIPSEND="
	pop de : push de
	call StringLength
	inc hl : inc hl ; +CRLF
	call hlToNumEsp
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write
.wait
	call Uart.read : cp '>' : jr nz, .wait
	pop hl
.loop
	ld a, (hl) : and a : jr z, .exit
	call Uart.write
	inc hl
	jp .loop
.exit
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write
	jp checkOkErr



; Puts the contents of an http request in buffer
; modifies: AF, BC, DE, HL
getPacket:
	ld hl, Err.readTimeout
	ld (timeout), hl
	call Uart.read
	cp '+' : jr z, .ipdBegun    ; "+IPD," packet
	cp 'O' : jr z, .closedBegun ; It enough to check "OSED\n" :-)
	jr getPacket
.closedBegun
	call Uart.read
	cp 'K' : jr z, .cspectHack
	cp 'S' : jr nz, getPacket
	call Uart.read : cp 'E' : jr nz, getPacket
	call Uart.read : cp 'D' : jr nz, getPacket
	call Uart.read : cp 13 : jr nz, getPacket
	ld a, 1
	ld (closed), a
	ret
.cspectHack
	;; I don't know why, but cspect gives us OK\n\r after the http request
	call Uart.read : cp 13 : jr nz, getPacket
	call Uart.read : cp 10 : jr nz, getPacket
	ld a, 1
	ld (closed), a
	ret
.ipdBegun
	call Uart.read : cp 'I' : jr nz, getPacket
	call Uart.read : cp 'P' : jr nz, getPacket
	call Uart.read : cp 'D' : jr nz, getPacket
	call Uart.read ; Comma
	call .count_ipd_length : ld (bytesAvail), hl

	ld a, (skipReply)
	cp 1
	jp z, .slurp

	;; put the byte count (from the AT response) in DE (to later to be put in BC)
	ex de, hl

	;; now point HL to the buffer
	ld hl, (bufferPointer)
	push hl

	ld a, (firstRead)
	and a : jr z, .headerProcessed

.searchForBlankLine
	;; since we're reading HTTP responses, the header isn't interesting to
	;; us so we'll look for \n\r\n\r in a row
	call Uart.read : dec de : cp CR : jr nz, .searchForBlankLine
	call Uart.read : dec de ; LR
	call Uart.read : dec de : cp CR : jr nz, .searchForBlankLine
	call Uart.read : dec de ; LR

	ld a, 0
	ld (firstRead), a
.headerProcessed
	pop hl

	ld b, d					; load DE (back) into BC
	ld c, e

	;; NOTE: IXH is used for tracking the buffer offset, in case we exit
	;; this routine and come back in half way through a base64 decoding
	;; process.
	;; IXL is used for tracking padding in the base64 message - this is
	;; right at the end and can be 0-2
	ld de, Base64.buffer
	ld a, ixh
	add de, a

	IFDEF TESTING
		and a
		call nz, .captureIXState
		jr .readp
.captureIXState
		ld iyh, d
		ld iyl, e
		exx
		ld a, ixh
		ld (hl), a
		dec hl

		ld d, iyh
		ld e, iyl

		ld (hl), e
		dec hl
		ld (hl), d
		dec hl
		exx
		ret
	ENDIF
.readp
	ld a, h
	cp HIGH Bank.buffer
	jr c, .skipbuff

	;; read UART into A
	push bc
	call Uart.read
	pop bc

.check7bitSupport				; this opcode (JR nn) gets replaced if we're 7bit
	jr .no7bitSupport

	;; here be 7-bit / base64 decode support

	ld (de), a
	cp '='
	jr nz, .skipPadding
	inc ixl
.skipPadding

	ld a, e  				; is the buffer length 4 bytes yet? DE is on a 4 byte edge
	and 3
	jr nz, .bufferNotFull

	push bc

	call Base64.Decode			; modifies BC and AF only
						; result is stored in Base64.output

	ld a, 3
	sub ixl					; calculate how many bytes we need to transfer

	ld hl, Base64.output
	ld de, (bufferPointer)
	ld b, 0
	ld c, a
	ldir

	ex de, hl				; update the tip of our result buffer
	ld (bufferPointer), hl			; save
	ld de, Base64.buffer-1			; reset DE to the start of the buffer (-1 because it'll immediately increment)

	pop bc
	ld ixh, 0				; reset the buffer offset counter
	jr .continue

.bufferNotFull
	inc ixh
	jr .continue
	;; ^--- 7-bit / base64 decode support ends here ---

.no7bitSupport
	ld (hl), a
	inc hl

.continue
	inc de

	dec bc
	ld a, b
	or c
	jr nz, .readp
	ld (bufferPointer), hl
	ret
.skipbuff
	push bc
	call Uart.read
	pop bc
	dec bc
	ld a, b
	or c
	jr nz, .skipbuff
	ret

.slurp
	;; HL contains the length of bytes from ESP
	ld b, h
	ld c, l
	jr .skipbuff


.count_ipd_length
	ld hl, 0			; count length
.cil1
        call Uart.read
	cp ':'
	ret z
	sub 0x30
	ld c,l
	ld b,h
	add hl,hl
	add hl,hl
	add hl,bc
	add hl,hl
	ld c,a
	ld b,0
	add hl,bc
	jr .cil1

; Based on: https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispHL
; HL - number
; It will be written to UART
hlToNumEsp:
	ld	bc,-10000
	call	.n1
	ld	bc,-1000
	call	.n1
	ld	bc,-100
	call	.n1
	ld	c,-10
	call	.n1
	ld	c,-1
.n1	ld	a,'0'-1
.n2	inc	a
	add	hl,bc
	jr	c, .n2
	sbc	hl,bc
	push bc
	call Uart.write
	pop bc
	ret

    ENDMODULE
