	MODULE Bank

prevPageA	DEFB 0
prevPageB	DEFB 0
userBank	DEFB 0,0
pagesRequired	DEFB 0
lastPageSize	DEFW 0
pageA		EQU MMU4_8000_NR_54
pageB		EQU MMU5_A000_NR_55
		;; NOTE: MMU3/5 are safe from being paged out when making
		;; NextZXOS calls (unlike MMU0/1/6/7)

		;; Note that although I'm blocking out 224 (potential) pages
		;; the reality is that, even with a 2mb machine, that a good
		;; number of these will already be reserved by the system.

poolSize	EQU 224
		;; TODO: add some protection for when in some future, there's a
		;; 4mb spectrum next...
		ALIGN 256
pool		BLOCK poolSize,0
rolling		DW pool				; use bank rolling by default for file saving
rollingActive	DB 1

buffer		EQU $8000
	IFDEF TESTING
prevDebugPage	DEFB 0
debugPage	EQU MMU6_C000_NR_56
debug		DW $C000
	ENDIF

; C <- 16K bank number to use as active bank
; Modifies: A, BC (via macro)
init:
		push bc

		;; backup the banks that are sitting over $8000 and $A000
		;; note that with a dot file, the stack originally is sitting at $FF42
		;; so if I do use this area, I need to set my own stackTop
		NextRegRead pageA		; loads A with pageA bank number
		ld (prevPageA), a
		NextRegRead pageB
		ld (prevPageB), a


	IFDEF TESTING
		NextRegRead debugPage
		ld (prevDebugPage), a
		ld a, $28			; debug is stored in first page of bank 20
		nextreg	debugPage, a

		push bc
		push de
		push hl

		;; erase 8K of the data in bank 20
		ld bc, $2000
		ld hl, debug
		ld de, debug + 1
		ld (hl), 0
		ldir

		pop hl
		pop de
		pop bc

	ENDIF

		pop bc

		;; check the bank init method, `fileMode` = 0 if we're loading
		;; data in and out of banks, and set to 1 if we're working with
		;; files
		ld a, (State.fileMode)
		cp NOT_WRITING_TO_FILE
		jr nz, .initNewBank

		;; double the value as we'll get 16K bank
		ld a, c
		add a, a
		ld (userBank), a

		;; now page in our user banks
		nextreg	pageA, a ; set bank to A
		inc a
		nextreg	pageB, a ; set bank to A
		ret

.initNewBank
		call allocateRollingBank
		ret

erase:
		ld bc, $4000				; 16k
		ld hl, buffer
		ld de, buffer + 1
		ld (hl), 0
		ldir
		ret

restore:
		push af					; protect the F flags

		;; only release the 2nd page if we're not testing - if we're
		;; testing then this preserves 2nd part of bank 20
	IFDEF TESTING
		NextRegRead debugPage
		call freePage
		ld a, (prevDebugPage)
		nextreg	debugPage, a
	ENDIF

		ld a, (prevPageA)
		nextreg	pageA, a
		ld a, (prevPageB)
		nextreg	pageB, a

		;; if fileMode = 0 we're done, otherwise release the pages
		ld a, (State.fileMode)
		and a
		jr z, .done

		;; if writing to a file, we need to release the 2 pages we allocated
		ld a, (userBank)
		call freePage

.done
		pop af
		ret


;; via Matt Davies — 30/03/2021
; A <- 8k bank number
; Fc <- if out of memory
allocPage:
                push    ix
                push    bc
                push    de
                push    hl

                ; Allocate a page by using the OS function IDE_BANK.
                ld      hl,$0001        ; Select allocate function and allocate from normal memory.
                call    .callP3dos
                ccf
                ld      a,e
                pop     hl
                pop     de
                pop     bc
                pop     ix
                ret     nc
                xor     a               ; Out of memory, page # is 0 (i.e. error), CF = 1
                scf
                ret

.callP3dos:
                exx                     ; Function parameters are switched to alternative registers.
                ld      de,IDE_BANK     ; Choose the function.
                ld      c,7             ; We want RAM 7 swapped in when we run this function (so that the OS can run).
                rst     8
                db      M_P3DOS         ; Call the function, new page # is in E
                ret

; E <- total pages available
; Modifies: HL
availablePages:
		ld hl, $0004                		; ZX banks, available
	        call  allocPage.callP3dos
		ret

freePage:
                push    af
                push    ix
                push    bc
                push    de
                push    hl

                ld      e,a             ; E = page #
                ld      hl,$0003        ; Deallocate function from normal memory
                call    allocPage.callP3dos

                pop     hl
                pop     de
                pop     bc
                pop     ix
                pop     af
                ret

; Writes all the banks used in the rolling bank method to SD card all in one go
;
; Modifies: HL, BC, AF, DE, IX
flushBanksToDisk:
		ld hl, pool
		ld a, (pagesRequired)
		ld d, a

		;; this is a bit weird, but it ensures that we capture all the
		;; pages to the sd card - in some cases we'll do a final write
		;; of zero bytes to the storage (a waste of cpu cycles) but
		;; this also simplifies logic and protects us from lossing the
		;; last page of data.
		inc d
.exactPageSize
		ld a, d				; Now copy into A and other
		ld b, a				; registers for loop prep
		ld c, a

		;; we allocate pages in pairs, so we need to make sure
		;; we're releasing an even number of pages - so if A is odd
		;; add 1 to the loop counter
		bit 0, a
		jr z, .loop
		inc b
.loop
		ld a, (hl)
		nextreg	pageA, a		; load page into $8000
		ld (.SMC_pageNumber), a

		push af
		push bc
		push hl

		ld hl, buffer			; HL = starting point
		;; if C = 0, then don't write
		ld a, c
		and a
		jr z, .dealloc

		;; if C == 1 then BC = Bank.lastPageSize
		cp 1
		jr z, .lastPage
		ld bc, $2000
		jr .write
.lastPage
		ld bc, (Bank.lastPageSize)

.write
		call Border
		call esxDOS.fWrite

.dealloc
		;; release the page - light version of freePage
.SMC_pageNumber EQU $+1
                ld e, SMC             		; E = page #
                ld hl, $0003        		; Deallocate function from normal memory
                call allocPage.callP3dos

		pop hl
		pop bc
		pop af

		inc l
		dec c
		djnz .loop
		ret

deallocateAllRollingBanks:
		ld hl, pool			; array of allocated pages
		ld b, $ff
.loop
		ld a, (hl)
		and a
		ret z				; if page is zero, we're done

		push hl
		push bc

		ld e, a
                ld hl, $0003        		; Deallocate function from normal memory
                call allocPage.callP3dos

		pop bc
		pop hl
		inc l				; point to next page in the array
		djnz .loop
		ret

; Allocates two 8K pages at a time then puts them in our MMU 4 & 5
;
; Modifies: HL, AF
allocateRollingBank:
		ld hl, (rolling)			; HL = points to base of the pool

		call allocPage
		jr c, outOfMemory
		ld (userBank), a
		nextreg	pageA, a
		ld (hl), a
		inc l

		call allocPage
		jr c, outOfMemory
		ld (userBank), a
		nextreg	pageB, a ; set bank to A
		ld (hl), a
		inc l

		ld (rolling), hl
		ret

outOfMemory
		call deallocateAllRollingBanks
		ld hl, Err.outOfMemory
		jp Error


	ENDMODULE


; Not used directly - called from the NextRegRead macro
;
; A = register value
; A <- value of register
; Modifies: B
NextRegReadProc:
		out (c), a
		inc b
		in a, (c)
		ret
