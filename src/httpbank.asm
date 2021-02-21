	DEVICE ZXSPECTRUMNEXT
	SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
	OPT reset --zxnext --syntax=abfw
	OPT --zxnext=cspect

	INCLUDE "macros.inc.asm"
	INCLUDE "constants.inc.asm"

	; DEFINE TESTING
	DEFINE DISP_ADDRESS     $2000

	IFNDEF TESTING
		DEFINE ORG_ADDRESS      $2000
	ELSE
		OPT --zxnext=cspect
		DEFINE ORG_ADDRESS      $8003
		DEFINE TEST_CODE_PAGE   95         ; using the last page of 1MiB RAM (in emulator)
	ENDIF

	ORG ORG_ADDRESS
__bin_b DISP    DISP_ADDRESS
start:
		jr .init
		DB " HTTPBANK by Remy Sharp "		; meh, just because I can :)
.init:
		di
		ld (State.oldStack), sp			; set my own stack so I can use $e000-$ffff
		ld sp, State.stackTop

		;; TODO parse the command line arguments

		;; page in our bank
		ld a, (TestData.bank)
		call Bank.init

		;; TODO add timeout for wifi connect (try with ESP removed)
		call Wifi.init
		jr c, .error

		ld hl, TestData.host
		ld de, TestData.port
		call Wifi.openTCP
		jr c, .error

.post							; FIXME hard limit on 2048 bytes due to CIPSEND
		ld a, 1
		ld (Wifi.skipReply), a
		ld de, requestBuffer
		ld hl, TestData.post
		ld bc, TestData.postLen
		ldir

		push de
		ld de, TestData.length
		call strLen
		ld b, h
		ld c, l					; BC now has string length
		pop de					; DE = responseBuffer (again)
		ld hl, TestData.length
		ldir					; POST / ... Content-Length: 64

		ld hl, Strings.emptyLine
		ld bc, 5
		ldir					; POST header ready

		ld hl, requestBuffer
		call Wifi.tcpSendBuffer
		jr .loadPackets

		; jr .cleanUpAndExit

.get
		;; if GET then clear the banks and make sure not to skip the content
		ld a, 0
		ld (Wifi.skipReply), a
		call Bank.erase
		ld hl, TestData.get
		call Wifi.tcpSendZ

		ld hl, buffer				; store the buffer in the user bank
		ld (Wifi.bufferPointer), hl
.loadPackets
		call Wifi.getPacket
		ld a, (Wifi.closed)
		and a
		jr nz, .cleanUpAndExit
		jr .loadPackets

.error
		ld (Err.generic), hl
		PrintMsg Err.generic

.cleanUpAndExit
		CSP_BREAK
		call Bank.restore
		ld sp, (State.oldStack)
		ei
		ret

	MODULE TestData
host		DEFB "192.168.1.118", 0
port		DEFB "8080", 0
get		DEFB "GET /", CR, LF, 0
post		DEFB "POST / HTTP/1.1", CR, LF, "Content-Length:"
postLen		EQU $-post
length		DEFB "64",0
bank		DEFB 20					; 16K Bank 20
	ENDMODULE

	INCLUDE "vars.asm"
	INCLUDE "messages.asm"
	INCLUDE "uart.asm"
	INCLUDE "wifi.asm"
	INCLUDE "utils.asm"
	INCLUDE "bank.asm"

requestBuffer	BLOCK 256
buffer		EQU $C000
last

diagBinSz   	EQU last-start
diagBinPcHi 	EQU (100*diagBinSz)/8192
diagBinPcLo 	EQU ((100*diagBinSz)%8192)*10/8192

    	DISPLAY "Binary size: ",/D,diagBinSz," (",/D,diagBinPcHi,".",/D,diagBinPcLo,"% of dot command 8kiB)"

	SAVEBIN "httpbank.dot",start,last-start
