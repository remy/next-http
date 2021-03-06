	DEVICE ZXSPECTRUM48
	SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
	OPT reset --zxnext --syntax=abfw

	; DEFINE TESTING

	INCLUDE "version.inc.asm"
	INCLUDE "macros.inc.asm"
	INCLUDE "constants.inc.asm"

	;; Dot commands always start at $2000, with HL=address of command tail
	ORG $2000

	IFDEF TESTING
		OPT --zxnext=cspect
		CSPECTMAP "httpbank.map"
		DISPLAY "Adding jump to ",/H,testStart
testStart:
		exx
		ld hl, $9FFF
		exx
		; ld hl, testFakeArgumentsLine
		call start
		ret
testFakeArgumentsLine
		;; test:
		; DZ "post -b 20 -h 192.168.1.118 -p 8080 -l 20"
		; DZ "get -h rbmtest.atwebpages.com -u /test.txt -b 20"
		; DZ  "get -h 192.168.1.118 -p 8080 -u /7test -b 5 -o -0 -7"
		; DZ  "get -h 192.168.1.118 -p 8080 -u /test-query?foo=bar -b 10"
		; DZ  "get -h next.remysharp.com -u /k6912 -b 5 -o -0"
		; DZ  "get -h remy-testing.000webhostapp.com -b 20"
		; DZ  "get -b 5 -h remy-testing.000webhostapp.com -o -0 -7"

	ENDIF

start:
	DISPLAY "Start @ ",/H,$
		jr init

bankError:
		ld hl, Err.bankError
		jp Error

init:
		di
		push ix					; protect this register and I'll mess with it later
		push iy					; protect this register and I'll mess with it later
		ld ixl, 0				; IXL is being used to track the padding length
		ld ixh, 0

		ld (Exit.stack), sp			; set my own stack so I can use $e000-$ffff
		;ld sp, State.stackTop

		;; set cpu speed to 28mhz
		NextRegRead CPUSpeed			; Read CPU speed
		and %11					; Mask out everything but the current desired speed
		ld (Exit.cpu), a			; Save current speed so it can be restored on exit
		nextreg CPUSpeed, %11			; Set current desired speed to 28MHz

		;; parse the command line arguments
		call Parse.start

		;; page in our bank
		ld de, State.bank
		call StringToNumber16
		jr c, bankError
		ld a, l					; expecting HL to be < 144 (total number of banks in 2mb)
		call Bank.init

	IFDEF TESTING
		;; must happen after Bank.init
		;; copy the variables to memory for debugging
		ld de, (Bank.debug)
		ld hl, State.Start
		ld bc, State.StateLen
		ldir
		ld (Bank.debug), de
	ENDIF

		call Wifi.init
		jp c, Error

		ld de, State.port
		call StringToNumber16
		jr c, portError

		ld hl, State.host
		ld de, State.port
		call Wifi.openTCP
		jp c, Error

		;; if type = 0 => get, = 1 => post, else ¯\_(ツ)_/¯
		ld a, (State.type)
		ld (Wifi.skipReply), a			; if GET then clear the banks and make sure not to skip the content
		and a : jr z, Get
		jr Post

offsetError:
		ld hl, Err.offsetError
		jp Error
portError:
		ld hl, Err.portError
		jp Error
Post
		ld de, requestBuffer			; DE is our working buffer

		call Headers.Post
		ld hl, State.url
		call Headers.Url
		call Headers.PostTrailer
		ld hl, State.length
		call Headers.copyHLtoDE
		call Headers.NewLine
		ld hl, State.host
		call Headers.Host
		call Headers.EndPost

		ld hl, requestBuffer
		CSP_BREAK

		ld de, State.offset			; load and prepare the offset
		call StringToNumber16			; HL = offset
		jr c, offsetError
		ld bc, Bank.buffer			; BC is our starting point
		add hl, bc				; then add the offset
		ld (Wifi.bufferPointer), hl		; and now data will be stored here.

		ld de, State.length
		call StringToNumber16
		ld b, h : ld c, l			; load BC with out POST length

		ld hl, requestBuffer
		call Wifi.tcpSendBuffer

		jr LoadPackets				; ensure we drain the ESP

Get
		ld de, State.offset			; load and prepare the offset
		ld a, (de)
		;; if the offset is negative we won't erase
		cp '-'
		jr z, .skipErase

		push de
	IFNDEF TESTING
		call Bank.erase
	ENDIF
		pop de
		jr .offsetApplied
.skipErase
		inc de					; since the offset was negative, move to the next char
.offsetApplied
		call StringToNumber16			; HL = offset
		jp c, offsetError

		ld bc, Bank.buffer			; BC is our starting point
		add hl, bc				; then add the offset
		ld (Wifi.bufferPointer), hl		; and now http response will be stored here.

		;; prepare the http request headers
		ld de, requestBuffer			; DE is our working buffer

		call Headers.Get
		ld hl, State.url
		call Headers.Url
		call Headers.GetTrailer
		ld hl, State.host
		call Headers.Host
		call Headers.EndGet

		ld hl, requestBuffer

		call Wifi.tcpSendString
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
		; CSP_BREAK
		;; for a clean exit, the carry flag needs to be clear (and a)
		call Bank.restore
.nop
.stack equ $+1
		ld sp, SMC				; the original stack pointer is set here upon load
		pop iy
		pop ix
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
	INCLUDE "base64decode.asm"
	INCLUDE "headers.asm"

		;; NOTE even though the request buffer is 256, it sits at the end
		;; of our program in memory, and this currently is well under the
		;; 8K limit of a dot file.
requestBuffer	BLOCK 256				; Request buffer is only used for the POST headers, not the body
last

diagBinSz   	EQU last-start
diagBinPcHi 	EQU (100*diagBinSz)/8192
diagBinPcLo 	EQU ((100*diagBinSz)%8192)*10/8192

    	DISPLAY "Binary size: ",/D,diagBinSz," (",/D,diagBinPcHi,".",/D,diagBinPcLo,"% of dot command 8kiB)"

	IFNDEF TESTING
		SAVEBIN "httpbank",start,last-start
		DISPLAY "prod build"
	ELSE
		SAVEBIN "httpbank-debug.dot",testStart,last-testStart

		DEFINE LAUNCH_CSPECT

		IFDEF LAUNCH_CSPECT : IF ((_ERRORS = 0) && (_WARNINGS = 0))
			;; delete any autoexec ba
			SHELLEXEC "(hdfmonkey rm /Applications/cspect/app/cspect-next-2gb.img /nextzxos/autoexec.bas > /dev/null) || exit 0"
			SHELLEXEC "hdfmonkey put /Applications/cspect/app/cspect-next-2gb.img httpbank-debug.dot /devel/httpbank.dot"
			SHELLEXEC "mono /Applications/cspect/app/cspect.exe -r -w5 -basickeys -zxnext -nextrom -exit -brk -tv -mmc=/Applications/cspect/app/cspect-next-2gb.img -map=./httpbank.map"
		ENDIF : ENDIF
		DISPLAY "TEST BUILD"
	ENDIF
