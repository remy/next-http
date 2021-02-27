	DEVICE ZXSPECTRUM48
	SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
	OPT reset --zxnext --syntax=abfw --zxnext=cspect

	INCLUDE "version.inc.asm"
	INCLUDE "macros.inc.asm"
	INCLUDE "constants.inc.asm"

	; DEFINE TESTING

	DEFINE DISP_ADDRESS     $2000

	IFNDEF TESTING
		DEFINE ORG_ADDRESS      $2000
	ELSE
		OPT --zxnext=cspect
		DEFINE ORG_ADDRESS      $8003
		DEFINE TEST_CODE_PAGE   223         ; using the last page of 2MiB RAM (in emulator)
	ENDIF

		;; Dot commands always start at $2000, with HL=address of command tail
	ORG 	ORG_ADDRESS
start:
		jr .init
		DB NAME, " v", VERSION 			; meh, just because I can :)

.init:
		di
		ld (Exit.stack), sp			; set my own stack so I can use $e000-$ffff
		;ld sp, State.stackTop

		;; set cpu speed to 28mhz
		NextRegRead CPUSpeed			; Read CPU speed
		and %11					; Mask out everything but the current desired speed
		ld (Exit.cpu), a			; Save current speed so it can be restored on exit
		nextreg CPUSpeed, %11			; Set current desired speed to 28MHz

		;; parse the command line arguments
		; ld hl, .testFakeArgumentsLine
		call Parse.start

		;; page in our bank
		ld de, State.bank
		call StringToNumber16
		ld a, l					; expecting HL to be < 144 (total number of banks in 2mb)
		call Bank.init

		;; FIXME remove
		; jr Exit

		;; TODO add timeout for wifi connect (try with ESP removed)
		call Wifi.init
		jp c, Error

		ld hl, State.host
		ld de, State.port
		call Wifi.openTCP
		jp c, Error

		;; if type = 0 => get, = 1 => post, else ¯\_(ツ)_/¯
		ld a, (State.type)
		ld (Wifi.skipReply), a			; if GET then clear the banks and make sure not to skip the content
		and a : jr z, Get
		cp 1 : jr z, Post
		call Parse.showHelp

Post
		ld de, requestBuffer
		ld hl, Strings.post
		ld bc, 5				; "POST "
		ldir

		ld hl, State.url			; copies user URL
		call CopyDEtoHL

		ld hl, Strings.postTail			; adds the content type, etc
		ld bc, Strings.postLen
		ldir

		push de
		ld de, State.length
		call StringLength
		ld b, h : ld c, l			; BC = HL (BC = string length of "length" value)
		pop de					; DE = responseBuffer (again)
		ld hl, State.length
		ldir					; POST / ... Content-Length: 64

		ld hl, Strings.emptyLine
		ld bc, 5
		ldir					; POST header ready

		ld de, State.length
		call StringToNumber16
		ld b, h : ld c, l			; BC = HL
		ld hl, requestBuffer
		call Wifi.tcpSendBuffer

		jr LoadPackets				; ensure we drain the ESP

Get
		call Bank.erase
		ld de, requestBuffer
		ld hl, Strings.get
		ld bc, 4
		ldir					; "GET "

		ld hl, State.url
		call CopyDEtoHL

		ld hl, Strings.newLine
		ld bc, 3
		ldir
		ld hl, requestBuffer

		call Wifi.tcpSendZ

		ld hl, Bank.buffer			; store the buffer in the user bank
		ld (Wifi.bufferPointer), hl
LoadPackets
		call Wifi.getPacket
		ld a, (Wifi.closed)
		and a
		jr nz, Exit
		jr LoadPackets

; HL = pointer to error string
Error
		xor a					; set A = 0
		scf					; Exit Fc=1

Exit
		;; for a clean exit, the carry flag needs to be clear (and a)
		call Bank.restore
.nop
.stack equ $+1
		ld sp, SMC				; the original stack pointer is set here upon load
.cpu equ $+3:
		nextreg CPUSpeed, SMC       		; Restore original CPU speed
		ei
		ret

	INCLUDE "vars.asm"
	INCLUDE "messages.asm"
	INCLUDE "esp-timeout.asm"
	INCLUDE "uart.asm"
	INCLUDE "wifi.asm"
	INCLUDE "utils.asm"
	INCLUDE "bank.asm"
	INCLUDE "parse.asm"
	INCLUDE "strings.asm"

requestBuffer	BLOCK 256				; Reqest buffer is only used for the POST headers, not the body
last

diagBinSz   	EQU last-start
diagBinPcHi 	EQU (100*diagBinSz)/8192
diagBinPcLo 	EQU ((100*diagBinSz)%8192)*10/8192

    	DISPLAY "Binary size: ",/D,diagBinSz," (",/D,diagBinPcHi,".",/D,diagBinPcLo,"% of dot command 8kiB)"

	IFNDEF TESTING
		SAVEBIN "httpbank",start,last-start
		DISPLAY "prod build"
	ELSE
		DISPLAY "test build"

testStart:
		; setup fake argument and launch loader
		ld      hl,testFakeArgumentsLine
		call 	start
		ret
testFakeArgumentsLine   DZ  "post -h httpbank.remysharp.com -u /picture.scr -b 31"

		SAVESNA "httpbank.sna",testStart
	ENDIF
