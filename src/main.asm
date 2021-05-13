	DEVICE ZXSPECTRUM48
	SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
	OPT reset --zxnext --syntax=abfw

	; DEFINE TESTING
	; DEFINE THROTTLE					; throttle storage writing

	INCLUDE "version.inc.asm"
	INCLUDE "macros.inc.asm"
	INCLUDE "constants.inc.asm"

	;; Dot commands always start at $2000, with HL=address of command tail
	ORG $2000

	IFDEF TESTING
		OPT --zxnext=cspect
		CSPECTMAP "http.map"
		DISPLAY "Adding jump to ",/H,testStart
testStart:
		; ld hl, testFakeArgumentsLine
		call start
		ret
testFakeArgumentsLine
		;; bank based tests
		; DZ "post -b 21 -h data.remysharp.com -u /1 -f 3 -l 2048"
		; DZ "post -b 21 -h data.remysharp.com -u /1 -f 3 -l 5000"
		; DZ "post -b 21 -h data.remysharp.com -u /1 -f 4 -l 5000 -7"
		; DZ "post -b 21 -h data.remysharp.com -u /1 -f 3 -l 16384 -7"

		; DZ "get -b 5 -h data.remysharp.com -u /2 -7 -o -0 -f 3" ; screen$
		; DZ "get -b 5 -o -0 -h data.remysharp.com -u /5 -v 2" ; screen$
		; DZ "get -b 20 -h data.remysharp.com -u /8 -v 2" ; 8K
		DZ "get -h data.remysharp.com -u /6 -b 20 -7 -v 2" ; marbles demo

		;; file based tests
		; DZ "get -f 8k.bin -h data.remysharp.com -u /8 -v 2" ; 8K
		; DZ "get -h data.remysharp.com -u /11 -f 48k.bin"
		; DZ "get -f demo.scr -h data.remysharp.com -u /5 -v 2" ; screen$
		; DZ "get -f http-demo.tap -h zxdb.remysharp.com -u /get/18840 -v 2"
		; DZ "get -f 4k.bin -h data.remysharp.com -u /10 -v 3"
		; DZ "get -f tmp.bin -h data.remysharp.com -u /13 -7 -v 3 -r"
		; DZ "get -f 3mb.bin -h data.remysharp.com -u /15 -r -v 3"
		; DZ "get -h zxdb.remysharp.com -u /get/25485 -f targetr.tap -v 3"

	ENDIF

start:
	DISPLAY "Start @ ",/H,$
		jr init

		;; leaving this in makes it easier to debug versions
		DB NAME, "@", VERSION, 0
bankError:
		ld hl, Err.bankError
		jp Error

init:
		di
		push ix					; protect this register and I'll mess with it later
		push iy					; protect this register and I'll mess with it later
		ld ixl, 0				; IXL is being used to track the padding length
		ld ixh, 0

		ld (Exit.SMC_stack), sp			; set my own stack so this dot command can be called

		ld a, (BORDCR)				; save SYSB the border for restore later
		ld (Exit.SMC_border), a
		call Border.Init

		;; set cpu speed to 28mhz
		NextRegRead CPUSpeed			; Read CPU speed
		and %11					; Mask out everything but the current desired speed
		ld (Exit.SMC_cpu), a			; Save current speed so it can be restored on exit
		nextreg CPUSpeed, %11			; Set current desired speed to 28MHz

		;; parse the command line arguments
		call Parse.start

		;; only now do I set my own SP. This needs to happen _after_
		;; Parse.start because the argument parsing routine can possibly
		;; call RST $10 (for "show help") or RST $18 (for args as
		;; NextBASIC variables) - and both these restart routines expect
		;; the stack to be sitting _outside_ the dot command (see NextOS
		;; and esxDOS APIs PDF, pg 26).
		ld sp, stackTop

		;; set up the border flashing
		ld de, State.border
		ld a, (de)
		cp $ff
		jr z, .noBorder

		call StringToNumber16
		jp c, borderError
		ld a, l
		scf					; set carry as we're looking for > 7
		cp 8
		jr nc, borderError
		ld (Border.newColour), a
		jr .setupBank

.noBorder
		ld a, $c9				; $C9 = ret
		ld (Border.SMC_disableBorder), a

.setupBank
		;; page in our bank
		ld de, State.bank
		;; if bank is still zero either there's an error or the user is
		;; working with a file
		ld a, (de)
		and a
		jr z, .useFiles

		;; disable bank rolling because we're not using files
		xor a
		ld (Bank.rollingActive), a

		call StringToNumber16
		jr c, bankError
		ld c, l					; expecting HL to be < 144 (total number of banks in 2mb)
		call Bank.init
		jr .setupBankContinue
.useFiles
		ld a, (State.encoded)
		inc a
		ld (State.fileMode), a			; 1 = saving to file, 2 = decoding and saving

		ld de, State.filename
		ld a, (de)
		and a
		jr z, noFileOrBankError

		call Bank.init
		;; open the file in create mode
		ld hl, State.filename
		call esxDOS.fOpen			; NOTE this makes the file even if there's an error
		jr c, fileOpenError

.setupBankContinue

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
		ld a, (hl)
		and a
		jr z, hostError
		ld de, State.port
		call Wifi.openTCP
		jp c, Error

		;; if type = 0 => get, = 1 => post, else ¯\_(ツ)_/¯
		ld a, (State.type)
		ld (Wifi.skipReply), a			; if GET then clear the banks and make sure not to skip the content
		and a
		jp z, Get
		jr Post

hostError:
		ld hl, Err.hostError
		jp Error

borderError:
		ld hl, Err.borderError
		jp Error
noFileOrBankError:
		ld hl, Err.noFileOrBank
		jp Error
notEnoughMemory:
		call Wifi.closeTCP
		ld hl, Err.notEnoughMemory
		jp Error
fileOpenError:
		ld hl, Err.fileOpen
		jp Error

offsetError:
		ld hl, Err.offsetError
		jp Error
portError:
		ld hl, Err.portError
		jp Error
lengthError:
		ld hl, Err.lengthError
		jp Error
Post
		ld de, requestBuffer			; DE is our working buffer

		call Headers.Post
		ld hl, State.url
		call Headers.Url
		call Headers.PostTrailer

		ld hl, State.length
.SMC_check7bitSupport1
		jr .skipBase64EncodeLength1

		push de
		ld de, State.length
		call StringToNumber16			; convert to numeric
		call Base64.EncodedLength		; adjust length
		call HLtoNumber
		pop de
.skipBase64EncodeLength1
		call Headers.copyHLtoDE

		call Headers.NewLine
		ld hl, State.host
		call Headers.Host
		call Headers.EndPost

		;; send headers then start on body which may be in chunks
		ld de, requestBuffer
		call StringLength
		ld b, h
		ld c, l
		ld hl, requestBuffer

		call Wifi.tcpSendBufferFrame

		;; now send the bank over UART broken down in to chunks of
		;; 2048 for 8bit and 1536 for 7bit (to allow for encoding)
		ld de, State.offset			; load and prepare the offset
		call StringToNumber16			; HL = offset
		jr c, offsetError
		ld bc, Bank.buffer			; BC is our starting point
		add hl, bc				; then add the offset
		ld (Wifi.bufferPointer), hl		; and now data will be stored here.

		ld de, State.length
		call StringToNumber16
		jr c, lengthError

.SMC_check7bitSupport2
		jr .skipBase64EncodeLength2
		call Base64.EncodedLength

.skipBase64EncodeLength2
		ld b, h : ld c, l			; load BC with out POST length
		ld hl, (Wifi.bufferPointer)

.bufferFrameLoop
		push bc
		ld a, b
		cp 8
		jr c, .assignPaddingValue		; < 2048
		ld bc, $800
		jr .startSend
.assignPaddingValue
		ld a, (State.paddingReal)
		ld (State.padding), a
.startSend
.SMC_sendPostMethod EQU $+1
		call Wifi.tcpSendBufferFrame		; swapped for Wifi.tcpSendEncodedBufferFrame in 7bit

		call Base64.Encode.reset		; reset the padding logic

		pop bc

		ld a, b					; if first send < 2K then we're done
		cp 8
		jr c, .finishSend

		;; subtract 2K, increment HL and loop
		ld a, b
		sub 8
		ld b, a

		;; check if the original message was exactly on the 2K edge
		or c

		jr nz, .bufferFrameLoop

.finishSend
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

		;; reduce the content length left to read
		ld de, (Wifi.bufferLength)
		call Headers.contentLengthSub
		ld hl, (Headers.contentLength)
		jr nz, .continue
		jr c, .contentLenghtError

		;; there's no more content to slurp, close connection
		call Wifi.closeTCP
		ld hl, Wifi.closed
		ld (hl), 1
.continue
		;; now write to file if required
		ld a, (State.fileMode)
		cp NOT_WRITING_TO_FILE
		jr z, .skipFileWrite

		ld a, (Bank.rollingActive)
		and a
		jr nz, .skipFileWrite

		ld hl, Bank.buffer			; HL = starting point
		ld (Wifi.bufferPointer), hl		; reset the wifi buffer at the same time
		ld bc, (Wifi.bufferLength)
		call esxDOS.fWrite

		;; this tests throttled writing to the sd card
	IFDEF THROTTLE
		push bc
		ld c, $ff

.throttleLoopOuter
		ld b, $ff
.throttleLoopInner
	DUP 20
		nop
	EDUP
		djnz .throttleLoopInner
		dec c
		ld a, c
		and a
		jr nz, .throttleLoopOuter

		pop bc
	ENDIF

.skipFileWrite
		ld a, (Wifi.closed)
		and a
		jr nz, PreExitCheck

		jr LoadPackets

.contentLenghtError:
		ld hl, Err.contentLength
		jp Error

PreExitCheck
		ld a, (State.fileMode)
		cp NOT_WRITING_TO_FILE
		jr z, .cleanExit

		;; Now work through banks and write to file
		;; we can do it forward from the start of the stack
		ld a, (Bank.rollingActive)
		and a
		call nz, Bank.flushBanksToDisk
.cleanExit
		and a					; clear carry for exit
		jr Exit

; HL = pointer to error string
Error
		xor a					; set A = 0 - TODO is this actually needed?
		scf					; Exit Fc=1

Exit
		;; for a clean exit, the carry flag needs to be clear (and a)
		push af
		push hl
		call Bank.restore
		call esxDOS.fClose
		pop hl
		pop af
.nop
		ld b, a					; put a somewhere
.SMC_border EQU $+1
		ld a, SMC				; restore the user's border
		ld (BORDCR), a
		call Border.Restore
		ld a, b
.SMC_stack EQU $+1
		ld sp, SMC				; the original stack pointer is set here upon load
		pop iy
		pop ix
.SMC_cpu EQU $+3:
		nextreg CPUSpeed, SMC       		; Restore original CPU speed
		ei
		ret

	INCLUDE "state.asm"
	INCLUDE "messages.asm"
	INCLUDE "border.asm"
	INCLUDE "esp-timeout.asm"
	INCLUDE "uart.asm"
	INCLUDE "wifi.asm"
	INCLUDE "utils.asm"
	INCLUDE "bank.asm"
	INCLUDE "file.asm"
	INCLUDE "parse.asm"
	INCLUDE "base64.asm"
	INCLUDE "headers.asm"

stack
	DS  $80, $AA    ; $AA is just debug filler of stack area
stackTop EQU $
	DISPLAY "Stack @ ",/H,$

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
		SAVEBIN "http",start,last-start
		DISPLAY "prod build"
	ELSE
		SAVEBIN "http-debug.dot",testStart,last-testStart

		DEFINE LAUNCH_CSPECT

		IFDEF LAUNCH_CSPECT : IF ((_ERRORS = 0) && (_WARNINGS = 0))
			;; delete any autoexec.bas
			SHELLEXEC "(hdfmonkey rm /Applications/cspect/app/cspect-next-2gb.img /nextzxos/autoexec.bas > /dev/null) || exit 0"
			SHELLEXEC "hdfmonkey put /Applications/cspect/app/cspect-next-2gb.img http-debug.dot /devel/http-debug.dot"
			SHELLEXEC "mono /Applications/cspect/app/cspect.exe -r -w5 -basickeys -zxnext -nextrom -exit -brk -tv -mmc=/Applications/cspect/app/cspect-next-2gb.img -map=./http.map -sd2=/Applications/cspect/app/empty-32mb.img" ;  -com='/dev/tty.wchusbserial1430:11520'
		ENDIF : ENDIF
		DISPLAY "TEST BUILD"
	ENDIF
