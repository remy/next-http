	MODULE Http

get
		;; if GET then clear the banks and make sure not to skip the content
		ld a, 0
		ld (Wifi.skipReply), a
		call Bank.erase
		ld hl, TestData.get
		call Wifi.tcpSendZ

		ld hl, Bank.buffer			; store the buffer in the user bank
		ld (Wifi.buffer_pointer), hl
.loadPackets
		call Wifi.getPacket
		ld a, (Wifi.closed)
		and a
		jr nz, .cleanUpAndExit
		jr .loadPackets

post

	ENDMODULE
