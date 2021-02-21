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

		;; TODO if GET then clear the banks
		call Bank.erase

		call Wifi.init
		jr c, .error

		ld hl, TestData.host
		ld de, TestData.port
		call Wifi.openTCP
		jr c, .error

		ld hl, TestData.get
		call Wifi.tcpSendZ

		ld hl, buffer				; store the buffer in the user bank
		ld (Wifi.buffer_pointer), hl
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
		call Bank.restore
		ld sp, (State.oldStack)
		ei
		ret

	MODULE TestData
host		DB "192.168.1.118", 0
port		DB "8080", 0
get		DB "GET /", CR, LF, 0
bank		DB 20					; 16K Bank 20
	ENDMODULE

	INCLUDE "vars.asm"
	INCLUDE "messages.asm"
	INCLUDE "uart.asm"
	INCLUDE "wifi.asm"
	INCLUDE "utils.asm"
	INCLUDE "bank.asm"

buffer		EQU $C000
last

diagBinSz   EQU     last-start
diagBinPcHi EQU     (100*diagBinSz)/8192
diagBinPcLo EQU     ((100*diagBinSz)%8192)*10/8192

    	DISPLAY "Binary size: ",/D,diagBinSz," (",/D,diagBinPcHi,".",/D,diagBinPcLo,"% of dot command 8kiB)"

	IFNDEF TESTING
		SAVEBIN "httpbank.dot",start,last-start
		DISPLAY "prod build"
	ELSE
		DISPLAY "test build"

testStart:
		; ld      a,$C3				; jp **
		; ld      (ORG_ADDRESS-3),a		; into $8000
		; ld      hl,testStart			; load $8000 with "jp testStart"
		; ld      (ORG_ADDRESS-2),hl
		; ; move the code into 0x2000..3FFF area, faking dot command environment
		; nextreg MMU1_2000_NR_51, TEST_CODE_PAGE
		; ; copy the machine code into the area
		; ld      hl,__bin_b
		; ld      de,$2000
		; ld      bc,last-start
		; ldir
		; ; setup fake argument and launch loader
		; ld      hl,testFakeArgumentsLine
		; CSP_BREAK
		; call    $2000       ; call to test the quit function
		; CSP_BREAK
		; ret
testFakeArgumentsLine
		DZ  "Nothing yet ..."

		DEFINE LAUNCH_EMULATOR
		SAVESNA "httpbank-post.sna",testStart

		IFDEF LAUNCH_EMULATOR : IF 0 == __ERRORS__ && 0 == __WARNINGS__
			;SHELLEXEC "( sleep 0.1s ; runCSpect -brk testing.sna )"
        	ENDIF : ENDIF

	ENDIF
