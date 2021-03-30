	MODULE State
Start		EQU $
POST		EQU 1
GET 		EQU 0
type		DB 0				; default to GET requests

	DISPLAY "Bank @ ",/H,$
bank		DEFB "remy"			; 16K Bank <999 - if this is unchanged it'll correctly throw
length		DS 6				; < 16384
offset		DEFB "0",0			; < 16384 (and in theory length + limit must be less than 16K)
		DS 4
border		DB $ff,0			; $FF means no border flashing
		DS 4				; some safety padding though I should really have better validation
padding		DB 0
paddingReal	DB 0
	DISPLAY "Host @ ",/H,$
port		DB "80",0			; < 999999 port
		DS 4
host		DB 0
		DS 253				; max length for domain: 253
url		DB "/",0
		DS 254				; in reality this can/should be 2000 bytes… not sure I should blow the room though.
StateLen	EQU $-Start
	ENDMODULE
