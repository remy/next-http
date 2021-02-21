	MODULE State

oldStack	DW 0
stack
	        DS  $80, $AA    ; $AA is just debug filler of stack area
stackTop:
        	DW  $AAAA
	ENDMODULE

	MODULE Strings
emptyLine	DEFB CR, LF, CR, LF, 0
	ENDMODULE
