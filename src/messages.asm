	MODULE Err
ESPTimeout	DC "1 WiFi/server timeout"
hostConnect	DC "2 Failed to connect to host"
errorConnect	DC "3 Cannot open TCP connection"
badOption	DC "4 Unknown command option"
varNotFound	DC "5 NextBASIC variable not found"
wifiInit	DC "6 WiFi chip init failed"
tcpSend1	DC "7 HTTP send post fail"
tcpSend2	DC "8 HTTP send fail"
tcpSend3	DC "9 HTTP get fail"
tcpSend4	DC "A HTTP send tcp frame fail"
readTimeout	DC "B HTTP read timeout"
bankError	DC "C Bank arg error"
lengthError	DC "D Length arg error"
offsetError	DC "E Offset arg error"
portError	DC "F Port error"
borderError	DC "G Border out of range 0-7"
hostError	DC "H Host required"
noFileOrBank	DC "I Filename or bank required"
fileOpen	DC "J Can't open file for writing"
contentLength	DC "K Content length error"
outOfMemory	DC "L Out of memory: try '-r'"
notEnoughMemory	DC "M Not enough memory: try '-r'"
	ENDMODULE

	MODULE Msg

help
		;;  12345678901234567890123456789012
		DB NAME, " v", VERSION, " by Remy Sharp", CR
		DB "-> GET and POST over HTTP", CR, CR
		DB "Synopsis:",CR
		DB " .",NAME," get ...args",CR
		DB " .",NAME," post ...args",CR, CR
		DB "Args:",CR
		DB "-b num*   bank to use",CR
		DB "-f str*   filename",CR
		DB "-r        disable rolling banks",CR
		DB "-h str    host address",CR
		DB "-p num*   port",CR
		DB "-u str*   url",CR
		DB "-l num*   length of data",CR
		DB "          (required with POST)",CR
		DB "-o num*   offset in bank",CR
		DB "-7        base64 decode",CR
		DB "-v num*   flash border colour",CR,CR
		DB "* denotes optional with defaults",CR
		DB "FAQ: github.com/remy/next-http",CR,0

	ENDMODULE
