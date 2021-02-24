
	MODULE Strings
emptyLine	DEFB CR, LF
newLine		DEFB CR, LF, 0
get		DEFB "GET ",0
post		DEFB "POST ",0
postTail	DEFB " HTTP/1.1", CR, LF, "Connection: close", CR, LF, "Content-Length:"
postLen		EQU $-post

	ENDMODULE
