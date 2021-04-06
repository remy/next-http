	MODULE Bank

prevPageA	DEFB 0
prevPageB	DEFB 0
userBank	DEFB 0,0

pageA		EQU MMU4_8000_NR_54
pageB		EQU MMU5_A000_NR_55

		;; NOTE: MMU3/5 are safe from being paged out when making
		;; NextZXOS calls (unlike MMU0/1/6/7)

buffer		EQU $8000
	IFDEF TESTING
debug		DW $A000
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

		pop bc

		;; check the bank init method, `loadToBank` = 1 if we're loading
		;; data in and out of banks, and set to 1 if we're working with
		;; files
		ld a, (State.fileMode)
		and a
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
		call allocPage
		ld (userBank), a
		nextreg	pageA, a ; set bank to A

		call allocPage
		ld (userBank+1), a
		nextreg	pageB, a ; set bank to A

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
		ld e, a
		call freePage

		ld a, (userBank+1)
		ld e, a
		call freePage

.done
		pop af
		ret


;; via Matt Davies — 30/03/2021
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
