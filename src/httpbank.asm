	DEVICE ZXSPECTRUMNEXT
	SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
	OPT reset --zxnext --syntax=abfw
	OPT --zxnext=cspect

	INCLUDE "version.inc.asm"
	INCLUDE "macros.inc.asm"
	INCLUDE "constants.inc.asm"

	DEFINE ORG_ADDRESS      $2000

	ORG ORG_ADDRESS

		;; Dot commands always start at $2000, with HL=address of command tail
		;; (terminated by $00, $0d or ':').

start:
		jr .init
		DB NAME, " v", VERSION 			; meh, just because I can :)
.init:
		di
		CSP_BREAK
		ld (Exit.stack), sp			; set my own stack so I can use $e000-$ffff
		;ld sp, State.stackTop

		;; set cpu speed to 28mhz
		NextRegRead CPUSpeed       		; Read CPU speed
		and %11                         	; Mask out everything but the current desired speed
		ld (Exit.cpu), a	             	; Save current speed so it can be restored on exit
		nextreg CPUSpeed, %11       		; Set current desired speed to 28MHz

		;; TODO parse the command line arguments
		;; TODO [ ] test from command line
		;; TODO [ ] test from NextBASIC
		;; TODO [ ] test from NextBASIC using .$ call
		; ld hl, TestData.cmd
		call Parse.start

		;; page in our bank
		ld de, TestData.bank
		call StringToNumber16
		ld a, l					; expecting HL to be < 144 (total number of banks in 2mb)
		call Bank.init

		;; FIXME remove
		jr Exit

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
		call StringLength
		ld b, h : ld c, l			; BC = HL (BC = string length of "length" value)
		pop de					; DE = responseBuffer (again)
		ld hl, TestData.length
		ldir					; POST / ... Content-Length: 64

		ld hl, Strings.emptyLine
		ld bc, 5
		ldir					; POST header ready

		ld de, TestData.length
		call StringToNumber16
		ld b, h : ld c, l			; BC = HL
		ld hl, requestBuffer
		call Wifi.tcpSendBuffer

		jr .loadPackets				; ensure we drain the ESP

.get
		;; if GET then clear the banks and make sure not to skip the content
		ld a, 0
		ld (Wifi.skipReply), a
		call Bank.erase
		ld hl, TestData.get
		call Wifi.tcpSendZ

		ld hl, Bank.buffer			; store the buffer in the user bank
		ld (Wifi.bufferPointer), hl
.loadPackets
		call Wifi.getPacket
		ld a, (Wifi.closed)
		and a
		jr nz, Exit
		jr .loadPackets

.error
		ld (Err.generic), hl
		PrintMsg Err.generic

Exit
		call Bank.restore
.nop
.stack equ $+1
		ld sp, SMC
.cpu equ $+3:
		nextreg CPUSpeed, SMC       		; Restore original CPU speed
		and a					; Fc=0, successful
		ei
		ret

	MODULE TestData
host		DEFB "192.168.1.118", 0
port		DEFB "8080", 0
get		DEFB "GET /", CR, LF, 0
post		DEFB "POST / HTTP/1.1", CR, LF, "Connection: close", CR, LF, "Content-Length:"
postLen		EQU $-post
length		DEFB "64",0
bank		DEFB "20"				; 16K Bank 20
cmd		DEFB "get -h 192.168.1.118 -p 8080 -u / -b 22", 0
	ENDMODULE

	INCLUDE "vars.asm"
	INCLUDE "messages.asm"
	INCLUDE "uart.asm"
	INCLUDE "wifi.asm"
	INCLUDE "utils.asm"
	INCLUDE "bank.asm"
	INCLUDE "parse.asm"

requestBuffer	BLOCK 256
last

diagBinSz   	EQU last-start
diagBinPcHi 	EQU (100*diagBinSz)/8192
diagBinPcLo 	EQU ((100*diagBinSz)%8192)*10/8192

    	DISPLAY "Binary size: ",/D,diagBinSz," (",/D,diagBinPcHi,".",/D,diagBinPcLo,"% of dot command 8kiB)"

	SAVEBIN "httpbank.dot",start,last-start
