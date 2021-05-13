	; DEFINE TEST_HEADERS
	IFDEF TEST_HEADERS
		OPT reset --zxnext --syntax=abfw
		INCLUDE "constants.inc.asm"
		DEVICE ZXSPECTRUM48
		SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

		ORG $8000
start:
		di
		exx
		ld hl, s2
		exx
		call Headers.findContentLength

		ld de, 1299
		call Headers.contentLengthSub

		; call Uart.read

		jr $

		INCLUDE "utils.asm"

	MODULE Uart
; Fake Uart.read
;
; A <- result
; Modifies: BC
read:
		exx
		ld a, (hl)
		inc hl
		exx
		ret
	ENDMODULE


result:
		DS 256
	ENDIF


	MODULE Headers
contentLength:						; 32bit result
	DISPLAY "Header.contentLength @ ",/H,$
		DWORD 0
tmpBuffer:
	DISPLAY "Header.buffer @ ",/H,$
		BLOCK 9, 0

; Subtracts DE from contentLength
;
; DE=integer
; Fz=all bytes consumed
; Fc=error
; Modifies: AF, HL, DE
contentLengthSub:
		or a					; reset carry for sbc
		ld hl, (contentLength)		; do the LSW first
		sbc hl, de
		ld (contentLength), hl
		ret nc

		or a
		ld hl, (contentLength+2)
		ld de, 1
		sbc hl, de
		ld (contentLength+2), hl
		jr z, .checkZero
		ret
.checkZero
		ld hl, (contentLength)
		ld a, h
		or l
		ret


; Takes DE and searches the text for the content length setting it in (HL)
; searching through the headers for `content-length: nnnn`. If successful
; carry is clear and the Header.contentLength is set to 32bits.
; This reduces DE as it works through the Uart.read
;
; DE=length of UART buffer
; Fc=failed to find header
; Modifies: AF, BC, DE, HL
findContentLength
		push ix
		ld hl, tmpBuffer

		;; process a single header
.processHeader
		call Uart.read				; load A with the next character
		dec de

		;; convert character to uppercase
		cp 'a'					; if A < 'a' then skip case shift
		jr c, .noCaseShiftC
		sub $20
.noCaseShiftC

		;; narrow down what we're looking for, ref:
		;; https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers
		cp 'C'
		jp nz, .TestForLineEndingHeader

		;; slurp to the `-` character
.findDash
		call Uart.read
		dec de
		cp CR					; always check if we have an EOL
		jr z, .processHeader

		cp '-'					; now check for the char we want
		jr nz, .findDash

		call Uart.read				; after `-` we're looking for L
		dec de

		;; shift case
		cp 'a'					; if A < 'a' then skip case shift
		jr c, .noCaseShiftL
		sub $20
.noCaseShiftL
		cp CR
		jr z, .processHeader			; is this EOL?

		cp 'L'					; L?
		jr nz, .slurpToEndOfHeader

		call Uart.read				; E?
		dec de
		cp CR					; EOL?
		jr z, .processHeader

		cp 'a'					; if A < 'a' then skip case shift
		jr c, .noCaseShiftE
		sub $20
.noCaseShiftE

		cp 'E'					; this now the content-length
		jr nz, .slurpToEndOfHeader

.findColon
		call Uart.read
		dec de
		cp CR					; always check if we have an EOL
		jr z, .processHeader

		cp ':'
		jr nz, .findColon

.eatSpaces
		call Uart.read
		dec de
		cp CR					; always check if we have an EOL
		jr z, .processHeader

		cp ' '
		jr z, .eatSpaces

		;; now we have our numbers - store this in a buffer for later conversion
		ld (hl), a
		inc hl
.captureNumeric
		call Uart.read
		dec de
		cp CR					; always check if we have an EOL
		jr z, .convertToUint32

		ld (hl), a
		inc hl
		jr .captureNumeric

.convertToUint32
		push de
		ld de, tmpBuffer
		call atoui32
		ld (contentLength), ix
		ld (contentLength+2), hl

		ld a, (Bank.rollingActive)
		and a
		jr z, .doneWithContentLengthChecks

		;; Now we have the content length both as text and as a numeric
		;; we also need to do some prep calculations for writing to disk
		;; so we do this now.
		ld a, h
		ld c, l					; ACIX=dividend
		ld de, $2000

		call Div32By16

		;; check memory limits and store values for bank rolling
		ld a, ixh
		and a

		jp nz, notEnoughMemory

		ld a, ixl
		ld (Bank.pagesRequired), a
		ld (Bank.lastPageSize), hl

		push af
		call Bank.availablePages
		pop af

		;; I'm reducing E because A (pages required) is rounded down
		dec e
		cp e

		;; we already know we don't have enough memory
		jp nc, notEnoughMemory

.doneWithContentLengthChecks
		pop de
		jp .slurpToEndOfAllHeaders

.TestForLineEndingHeader
		;; this could actually be a blank line in which case we need to return
		cp CR
		jr nz, .slurpToEndOfHeader
		;; this was a CR and we've not found the content length

		;; flush the next character: LF
		call Uart.read
		dec de
		scf
		jr .exit

.slurpToEndOfHeader
		call Uart.read : dec de : cp CR : jr nz, .slurpToEndOfHeader
		call Uart.read : dec de ; LR
		jp .processHeader

.slurpToEndOfAllHeaders
		call Uart.read : dec de : cp CR : jr nz, .slurpToEndOfAllHeaders
		call Uart.read : dec de ; LR
		call Uart.read : dec de : cp CR : jr nz, .slurpToEndOfAllHeaders
		call Uart.read : dec de ; LR
.exit
		pop ix
		ret
Parse


Post
		ld hl, HeaderStrings.post
		ld bc, 5
		jr method

Get
		ld hl, HeaderStrings.get
		ld bc, 4
method
		ldir
		ret

GetTrailer
		ld hl, HeaderStrings.reqTail
		ld bc, HeaderStrings.reqTailLen
		ldir
		ret

PostTrailer
		ld hl, HeaderStrings.reqTail
		ld bc, HeaderStrings.postLen
		ldir
		ret

; HL = copy from buffer terminated with null
; DE = copy to
; DE <- end of buffer
; Modifies: AF
Host
		push hl
		ld hl, HeaderStrings.host
		ld bc, 6
		ldir
		pop hl
		;; intentionally fall through to copyHLtoDE

; HL = copy from buffer terminated with null
; DE = copy to
; DE <- end of buffer
; Modifies: AF
Url
copyHLtoDE
		ld a, (hl)
		and a
		ret z
		ld (de), a
		inc hl
		inc de
		jr copyHLtoDE

NewLine
		ld hl, HeaderStrings.newLine
		ld bc, 2
		ldir
		ret

EndPost
		ld hl, HeaderStrings.emptyLine
		ld bc, 5
		ldir
		ret

EndGet
		ld hl, HeaderStrings.newLine
		ld bc, 3
		ldir
		ret


	ENDMODULE

	MODULE HeaderStrings
emptyLine	DEFB CR, LF
newLine		DEFB CR, LF, 0
get		DEFB "GET "
post		DEFB "POST "
host		DEFB "Host: "
reqTail		DEFB " HTTP/1.1", CR, LF, "Connection: keep-alive", CR, LF
reqTailLen	EQU $-reqTail
postLength	DEFB "Content-Type: application/x-www-form-urlencoded", CR, LF, "Content-Length: "
postLen		EQU $-reqTail

	ENDMODULE


	IFDEF TEST_HEADERS

s1:		DEFB "HTTP/1.1 200 OK",CR,LF
		DEFB "Server: nginx/1.14.2",CR,LF
		DEFB "Date: Fri, 23 Apr 2021 18:42:46 GMT",CR,LF
		DEFB "Content-Type: text/html",CR,LF
		DEFB "Content-Length: 6608",CR,LF
		DEFB "Last-Modified: Fri, 10 Jul 2020 15:43:55 GMT",CR,LF
		DEFB "Connection: keep-alive",CR,LF
		DEFB "Permissions-Policy: interest-cohort=()",CR,LF
		DEFB "Referrer-Policy: no-referrer",CR,LF
		DEFB "Accept-Ranges: bytes",CR,LF
		DEFB CR,LF
		DEFB "<!DOCTYPE html>",0

s2:
		DEFB "HTTP/1.1 200 OK",CR,LF
		DEFB "Content-Type: application/octet-stream",CR,LF
		DEFB "Content-Length: 65536",CR,LF
		DEFB "Date: Fri, 23 Apr 2021 22:22:26 GMT",CR,LF
		DEFB "Connection: keep-alive",CR,LF
		DEFB "Keep-Alive: timeout=5",CR,LF
		DEFB CR,LF
		DEFB "<!DOCTYPE html>",0
s3:
		DEFB "HTTP/1.1 200 OK",CR,LF
		DEFB "Content-Type: application/octet-stream",CR,LF
		DEFB "Date: Fri, 23 Apr 2021 22:22:26 GMT",CR,LF
		DEFB "Connection: keep-alive",CR,LF
		DEFB "Keep-Alive: timeout=5",CR,LF
		DEFB CR,LF
		DEFB "<!DOCTYPE html>",0


		SAVESNA "headers.sna", start
	ENDIF
