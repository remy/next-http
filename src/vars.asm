	MODULE State

oldStack	DW 0
stack
	        DS  $80, $AA    ; $AA is just debug filler of stack area
stackTop:
        	DW  $AAAA
	ENDMODULE

