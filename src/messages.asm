	MODULE Err
ESPTimeout	DC "1 WiFi/server timeout"
hostConnect	DC "2 Failed to connect to host"
errorConnect	DC "3 Cannot open TCP connection"
badOption	DC "4 Unknown command option"
varNotFound	DC "5 NextBASIC string variable not found"
wifiInit	DC "6 WiFi chip init failed"
tcpSend1	DC "7 HTTP send fail"
tcpSend2	DC "8 HTTP send fail"
tcpSend3	DC "9 HTTP send fail"
tcpSend4	DC "A HTTP send fail"
readTimeout	DC "B HTTP read timeout"
	ENDMODULE

	MODULE Msg

help
		;;  12345678901234567890123456789012
		DB NAME, " v", VERSION, " by Remy Sharp", CR
		DB "-> GET and POST to a bank", CR, CR
		DB "Synopsis:",CR
		DB " .",NAME," get ...args",CR
		DB " .",NAME," post ...args",CR, CR
		DB "Args:",CR
		DB "-b num    bank to use",CR
		DB "-h str    host address",CR
		DB "-p num*   port (default 80)",CR
		DB "-u str*   url (default /)",CR
		DB "-l num*   length of data",CR
		DB "          (required with POST)",CR
		DB "-o num*   offset in bank",CR
		DB "          (default 0)",CR, CR
		DB "* denotes optional with defaults",CR
		DB "-> FAQ @ tinyurl.com/httpbank",CR,0

	ENDMODULE
