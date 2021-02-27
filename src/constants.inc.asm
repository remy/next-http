ULA_PORT                EQU $FE                         ; out (254), a
CR                      EQU 13
LF                      EQU 10

SMC				EQU 0		; Self Modifying Code - replaced inline ruing runtime

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
