NOT_WRITING_TO_FILE	EQU 0
WRITE_TO_FILE		EQU 1
FILE_AND_ENCODING 	EQU 2

ULA_PORT                EQU $FE                         ; out (254), a
CR                      EQU 13
LF                      EQU 10

SMC			EQU 0				; Self Modifying Code - replaced inline ruing runtime

MMU0_0000_NR_50                 equ $50     ;Set a Spectrum RAM page at position 0x0000 to 0x1FFF
MMU1_2000_NR_51                 equ $51     ;Set a Spectrum RAM page at position 0x2000 to 0x3FFF
MMU2_4000_NR_52                 equ $52     ;Set a Spectrum RAM page at position 0x4000 to 0x5FFF
MMU3_6000_NR_53                 equ $53     ;Set a Spectrum RAM page at position 0x6000 to 0x7FFF
MMU4_8000_NR_54                 equ $54     ;Set a Spectrum RAM page at position 0x8000 to 0x9FFF
MMU5_A000_NR_55                 equ $55     ;Set a Spectrum RAM page at position 0xA000 to 0xBFFF
MMU6_C000_NR_56                 equ $56     ;Set a Spectrum RAM page at position 0xC000 to 0xDFFF
MMU7_E000_NR_57                 equ $57     ;Set a Spectrum RAM page at position 0xE000 to 0xFFFF

CPUSpeed              		equ $07

VARS                    	EQU $5c4b		; addr of variables area
NEXT_ONE_r3             	EQU $19b8           	; find next variable

ESPTimeout              	EQU 65535*4;65535 	; Use 10000 for 3.5MHz, but 28NHz needs to be 65535

BORDCR				EQU 23624


;;----------------------------------------------------------------------------------------------------------------------
;; NextZXOS APIs

REG_MMU0                equ     $50
REG_MMU1                equ     $51
REG_MMU2                equ     $52
REG_MMU3                equ     $53
REG_MMU4                equ     $54
REG_MMU5                equ     $55
REG_MMU6                equ     $56
REG_MMU7                equ     $57


IDE_BANK        equ     $01bd           		; NextZXOS function to manage memory
M_P3DOS         equ     $94  				; +3 DOS function call
M_DRVAPI        equ     $92
M_GETERR        equ     $93
M_ERRH          equ     $95

F_OPEN          equ     $9a     ; Entry: A=drive, HL=filespec, B=Access mode, Exit: CF=0: A=handle, CF=1: A=error code
F_CLOSE         equ     $9b
F_SYNC          equ     $9c
F_READ          equ     $9d     ; Entry: A=handle, HL=address, BC=bytes, Exit: BC=bytes read, CF=0: HL=after bytes, CF=1: A=error code
F_WRITE         equ     $9e
F_SEEK          equ     $9f
F_GETPOS        equ     $a0
F_FSTAT         equ     $a1
M_GETSETDRV     equ     $89


F_GETCWD        equ     $a8
FA_READ                 equ     $01
FA_WRITE                equ     $02
FA_RWP3HDR              equ     $40     ; Include +3 dos header.
FA_OPEN_EXISTING        equ     $00     ; Open an existing file, but error if not existing.
FA_OPEN                 equ     $08     ; Open an existing file or create a new one.
FA_CREATE               equ     $04     ; Create a new file or error if it already exists.
FA_CREATE_NEW           equ     $0c     ; Create a new file, deleting it if it already exists.
