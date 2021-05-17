SJASMPLUS = sjasmplus
SJASMPLUSFLAGS = --nologo
INCLUDE_FILES = $(wildcard src/*.asm)

# try to assemble the "runtime" file as standalone file (as if included elsewhere)
# then create the binary of the dot command
HTTP: src/main.asm $(INCLUDE_FILES) Makefile
	$(SJASMPLUS) --zxnext $(SJASMPLUSFLAGS) src/main.asm

.PHONY: all clean

all: HTTP

clean:
	$(RM) -f HTTP src/*.labels src/*.sld
