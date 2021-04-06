; Modified version of exdos.asm from Robin Verhagen-Guest, spliced with code
; from Matt Davies (in Odin) and my own tweaks

;  Copyright 2019-2020 Robin Verhagen-Guest
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

; NOTE: File paths use the slash character (/) as directory separator (UNIX style)

	MODULE esxDOS

CurrentDrive	DB '*'
Handle		DB 255

; Open file
;
; HL = pointer to file name (ASCIIZ) (IX for non-dot commands)
; Modifies: BC, AF
; A <- file handle
; Fc <- On error
;       A = 5   File not found
;       A = 7   Name error - not 8.3?
;       A = 11  Drive not found
fOpen:
		ld a, (CurrentDrive)            ; get drive we're on
		ld b, FA_WRITE | FA_CREATE_NEW ;  FA_READ                   ; b = open mode
		dos F_OPEN		; open read mode
		ld (Handle), a
		ret                             ; Returns a file handler in 'A' register.

; Function:             Read bytes from a file
; In:                   A  = file handle
;                       HL = address to load into (IX for non-dot commands)
;                       BC = number of bytes to read
; Out:                  Carry flag is set if read fails.
fRead:
		ld a, (Handle)           ; file handle
		dos F_READ               ; read file
		ret


; Write bytes to file
;
; HL = address of bytes
; BC = bytes to write
; BC <- bytes actually written
; Fc <- On error
fWrite:
		ld a, (Handle)
		dos F_WRITE
		ret


; Close file
;
; Modifies: AF
; Fc <- active if error when closing
fClose:
		ld a, (Handle)
		and a
		ret z
		dos F_CLOSE            ; close file
		ret

	ENDMODULE
