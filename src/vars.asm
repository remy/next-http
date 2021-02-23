	MODULE State
POST		EQU 1
GET 		EQU 0
type		DB $ff

bank		DS 4				; 16K Bank <999
length		DS 6				; < 16384 (in reality < 2000 until I batch ESP sends)
offset		DEFB "0",0			; < 16384
		DS 4
host		DS 254				; max length for domain: 253
url		DB "/",0
		DS 254				; in reality this can/should be 2000 bytes… but we don't have the room!
port		DB "80",0			; < 999999 port
		DS 4
; cmd		DEFB "get -h scores.marbles2.com -b 22", 0

	ENDMODULE
