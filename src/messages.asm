	MODULE Err
openTCP		DC "TCP open failed"
badOption	DC "Unknown option"
varNotFound	DC "NextBASIC string variable not found"

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
		DB "-u str*   url (default /)",CR, CR
		DB "-l num*   length of data",CR
		DB "          (required with POST)",CR
		DB "-o num*   offset in bank",CR
		DB "          (default 0)",CR, CR
		DB "* denotes optional with defaults",CR
		DB "-> FAQ @ tinyurl.com/httpbank",CR,0

	ENDMODULE
