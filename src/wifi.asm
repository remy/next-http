; This code started out as the wifi.asm from internet-nextplorer - but has now
; been long transformed into something (uglier!) different. However, right at
; start, the origial source author is Alexander Sharikhin nihirash
; License: https://github.com/nihirash/internet-nextplorer/blob/89baa64d974e2d916862280a9ec2f52247923172/LICENSE
; By them a coffee :-)
;
; Includes A LOT of modifications specific to the http dot command by Remy Sharp

    MODULE Wifi
bytesAvail DW 0
bufferPointer DW 0
closed DB 1
skipReply DB 0
firstRead DB 1
bufferLength DW 0
restarted DB 0
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

	and a
	ret
.initError
	call RetartESP
	jr c, .failed
	jp Wifi.init
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
	and a
	ret


closeTCP
	EspCmdOkErr "AT+CIPCLOSE"
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
	and a
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

; HL = buff
; E = count
;
; Send buffer to UART
espSend:
	ld a, (hl) : call Uart.write
	inc hl
	dec e
	jr nz, espSend
	ret

; HL = string that ends with one of the terminator(CR/LF/TAB/NULL)
; Modifies: AF, BC, DE
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
tcpSendEncodedBufferFrame:
	push hl
	push bc
	;; setup the custom error types
	ld hl, Err.tcpSend2
	ld (timeout), hl
	ld hl, Err.tcpSend4
	ld (error), hl

	EspSend "AT+CIPSEND="
	pop hl
	push hl
	call hlToNumEsp
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write

.wait
	call Uart.read : cp '>' : jr nz, .wait

	pop bc
	pop hl

	ld de, Base64.input

.bodyLoop

	;; For base64 encode create a buffer of 3 bytes, then once full
	;; flush to base64 encoded and send all at once
	ld a, (hl)

	;; here be 7-bit / base64 encoding support
	ld (de), a
	inc de
	ld a, e
	and 3
	jr nz, .nextByte

	push hl
	push bc

	;; test value of bc here
	and a					; clear carry

	ld a, b
	and a					; if B != 0 then skip
	jp nz, .sendEncodedBuffer

	ld a, c
	cp 4
	jp nz, .sendEncodedBuffer		; only apply padding *right* at the end

	;; work out how much padding is required now we're at the end
	ld a, (State.padding)
	and a					; if padding == 0 then don't add any null bytes
	jr z, .padNone

	cp 2					; if padding == 2 null out Base64.input + 1 & + 2 (end)
	jr nz, .padOne
	xor a
	ld (Base64.input+1), a
.padOne
	xor a
	ld (Base64.input+2), a

.padNone
	scf					; set carry as a flag for encode process

.sendEncodedBuffer
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

	dec bc					; adjust for the 4 bytes we just sent
	dec bc
	dec bc
	dec bc

	pop hl

	ld de, Base64.input			; reset the position of the encode buffer

.nextByte
	inc hl
	ld a, b
	or c
	jr nz, .bodyLoop
	jp checkOkErr


; HL = string to send
; BC = length
; Modifies: AF, BC, DE
; Sends the contents of HL to ESP - to close out the connection, the sequence CR LF, CR, LF is required
tcpSendBufferFrame:
	push hl
	push bc
	;; setup the custom error types
	ld hl, Err.tcpSend2
	ld (timeout), hl
	ld hl, Err.tcpSend4
	ld (error), hl

	EspSend "AT+CIPSEND="
	pop hl
	push hl
	call hlToNumEsp
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write

.wait
	call Uart.read : cp '>' : jr nz, .wait
	pop bc
	pop hl
.writeLoop
	ld a, (hl)
	push bc
	call Uart.write
	pop bc
	inc hl

	dec bc
	ld a, b
	or c
	jr nz, .writeLoop
	jp checkOkErr


; HL = string to send
; Modifies: AF, BC, DE
; Sends the contents of HL up to null terminator to ESP,
; auto adding the CR+LF to the message
tcpSendString:
	push hl

	;; setup the custom error types
	ld hl, Err.tcpSend3
	ld (timeout), hl

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
	ld a, (hl)
	and a
	jr z, .exit
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

	ld a, (skipReply)			; the body isn't needed if we're doing a POST
	and a
	jp nz, .slurp

	;; put the byte count (from the AT response) in DE (to later to be put in BC)
	ex de, hl

	;; now point HL to the buffer
	ld hl, (bufferPointer)
	push hl

	ld a, (firstRead)
	and a
	jr z, .headerProcessed

.processHeader
	;; we're searching for "content-length:"
	call Headers.findContentLength

	ld a, 0
	ld (firstRead), a
.headerProcessed
	pop hl

	ld b, d					; load DE (back) into BC
	ld c, e
	ld (bufferLength), bc			; save the length for saving to file

	;; check if the header was all we got in the IPD request
	ld a, b
	or c
	jr nz, .headerProcessedContinue
	ld (bufferPointer), hl
	ret

.headerProcessedContinue
	;; NOTE: IXH is used for tracking the buffer offset, in case we exit
	;; this routine and come back in half way through a base64 decoding
	;; process.
	;; IXL is used for tracking padding in the base64 message - this is
	;; right at the end and can be 0-2
	ld de, Base64.buffer
	ld a, ixh
	add de, a

.readp
	ld a, h
	bit 6, h

	;; we'e gotten up to $c000
	jr nz, .outOfMemory

	;; read UART into A
	push bc
	call Uart.read
	pop bc

.SMC_check7bitSupport				; this opcode (JR nn) gets replaced if we're 7bit
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

	; CSP_BREAK
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

.outOfMemory
	ld a, (Bank.rollingActive)
	and a
	jr z, .skipSavingBuffer

	;; since we're rolling, we allocate a new bank, and reset the
	;; bufferpointer value
	call Bank.allocateRollingBank
	ld hl, Bank.buffer
	ld (bufferPointer), hl
	jr .readp

.skipSavingBuffer
	push bc
	call Uart.read
	pop bc
	dec bc
	ld a, b
	or c
	jr nz, .skipSavingBuffer
	ret

.slurp
	;; HL contains the length of bytes from ESP
	ld b, h
	ld c, l
	jr .skipSavingBuffer


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

; HL = number
; Modifies: AF, BC
; Based on: https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispHL
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
