
	MODULE Strings
emptyLine	DEFB CR, LF, CR, LF, 0
get		DEFB "GET /", CR, LF, 0
post		DEFB "POST / HTTP/1.1", CR, LF, "Connection: close", CR, LF, "Content-Length:"
postLen		EQU $-post

	ENDMODULE
