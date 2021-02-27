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
	ld hl, .errMsg
	scf
	ret
.errMsg
	DB "WiFi chip init failed!",0

; HL - host pointer
; DE - port pointer
openTCP:
	push de
	push hl
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
	call .flushToLF
	or a
	ret
.errStart
	call Uart.read : cp 'R' : jr nz, checkOkErr
	call Uart.read : cp 'R' : jr nz, checkOkErr
	call Uart.read : cp 'O' : jr nz, checkOkErr
	call Uart.read : cp 'R' : jr nz, checkOkErr
	call .flushToLF
	scf
	ret
.failStart
	call Uart.read : cp 'A' : jr nz, checkOkErr
	call Uart.read : cp 'I' : jr nz, checkOkErr
	call Uart.read : cp 'L' : jr nz, checkOkErr
	call .flushToLF
	scf
	ret
.flushToLF
	call Uart.read
	cp 10 : jr nz, .flushToLF
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
; Adds CR LF
; Then sends pointer at DE
tcpSendBuffer:
	push bc						; BC will be popped when in .sendBody

	push hl						; strLen will overwrite HL
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
	ld hl, Bank.buffer					; now send the memory buffer
	pop bc
.bodyLoop
	ld a, (hl)

	push bc
	call Uart.write
	pop bc

	inc hl

	dec bc : ld a, b : or c : jr nz, .bodyLoop

.exit
	ld a, 13 : call Uart.write
	ld a, 10 : call Uart.write
	jp checkOkErr


; HL - stringZ to send
; Adds CR LF
tcpSendZ:
	push hl
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
	call Uart.read
	cp '+' : jr z, .ipdBegun    ; "+IPD," packet
	cp 'O' : jr z, .closedBegun ; It enough to check "OSED\n" :-)
	jr getPacket
.closedBegun
	call Uart.read : cp 'S' : jr nz, getPacket
	call Uart.read : cp 'E' : jr nz, getPacket
	call Uart.read : cp 'D' : jr nz, getPacket
	call Uart.read : cp 13 : jr nz, getPacket
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
	jr z, .slurp

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
	push de
	pop bc
.readp
	ld a, h
	cp HIGH Bank.buffer
	jr c, .skipbuff

	;; read UART into A
	push bc
	push hl
	call Uart.read
	pop hl
	pop bc

	ld (hl), a
	inc hl

	dec bc : ld a, b : or c : jr nz, .readp
	ld (bufferPointer), hl
	ret
.skipbuff
	push bc
	call Uart.read
	pop bc
	dec bc : ld a, b : or c : jr nz, .skipbuff
	ret

.slurp
	;; HL contains the length of bytes from ESP
	ld b, h
	ld c, l
	jr .skipbuff


.count_ipd_length
	ld hl,0			; count length
.cil1
	push  hl
        call Uart.read
        pop hl
	cp ':' : ret z
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
