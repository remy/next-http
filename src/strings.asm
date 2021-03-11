
	MODULE Strings
emptyLine	DEFB CR, LF
newLine		DEFB CR, LF, 0
get		DEFB "GET "
post		DEFB "POST "
host		DEFB "Host: "
reqTail		DEFB " HTTP/1.1", CR, LF, "Connection: close", CR, LF
reqTailLen	EQU $-reqTail
postLength	DEFB "Content-Type: application/x-www-form-urlencoded", CR, LF, "Content-Length: "
postLen		EQU $-reqTail

	ENDMODULE
