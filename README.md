# httpbank - for the Spectrum Next (public beta)

A utility for application developers to talk to web servers to exchange small blocks of data, such as high scores, game progress, etc.

This works best on small blocks of data. Requesting a 7K `.scr` does work, but has been seen as intermittent. Requesting 1K will work pretty much every time.

Usage:

```
.httpbank post -b 22 -l 1024 -h 192.168.1.100 -p 8080 -u /send
.httpbank get -b 26 -h next.remysharp.com -u /bytes
```

Options:

- `-b` bank number in 16K blocks
- `-l` length of bytes to send
- `-o` address offset (defaults to 0)
- `-h` host address
- `-p` port number (defaults to 80)
- `-u` url (defaults to `/`)
- `-7` enabled base64 decoding (useful for supporting [Cspect](http://cspect.org/) and 7-bit binary exchange*)

Note that by default a GET request will empty out the bank selected. If you want to preserve the data in the bank, use a negative value for the offset, i.e. `-b 5 -o -0` will load the http request into bank 5, preserving the RAM and inserting at memory position 0 (in fact, `$4000` in RAM).

Run with no arguments to see the help.

*Cpsect's emulated ESP support used 7-bit, which means if you want to send binary data, you will need to base64 encode your payload. Using the `-7` flag with `httpbank` will support decoding and support Cpsect. This is not required if you only plan to exchange 7-bit data (like readable text) or support hardware. See the example folder for a server returning binary using base64 encoding.

**What this is not:** a web browser or a tool for downloading large files over the web (>16K - yes, that's "large"). Feel free to build on this source code if that's what you're looking for.

## Using from NextBASIC

If the dot command isn't shipped as part of the distro and you want to ship `httpbank` as part of your project, you will need to call the dot command from a relative path. You might also need to set variables, such as a bank number through NextBASIC and pass this to `httpbank`. At time of writing (Feb 2021) the `.$` command doesn't support relative paths, so NextBASIC variable reading is support as part of `httpbank`.

The only variables that `httpbank` supports are single letter string variables.

Assuming `httpbank` is in the same directory as your NextBASIC file, the following prefix is required: `../` (dot dots and a slash). See the code below for the full example:

```
10 BANK NEW b
20 b$ = STR$ b : REM store as a string
30 c$ = "256" : REM we'll send 256 bytes from bank $b
30 ../httpbank post -b b$ -h example.com -l c$
40 PRINT "done"
```

Note that `httpbank` will expect a BASIC variable to represent a single argument value and you cannot combine multiple arguments into a single variable (i.e. `h$="-h example -p 8080` won't work).

## Installation

You can save the `httpbank` to your own `/dot` directory, or you can run it from your working directory using a relative path `../httpbank`.

## Limits

- When using a domain name, I've found that `CNAME` records can result in `DNS Error` so make sure to use `A` records ideally - you'll see error `2`.
- There's no SSL/TLS support - ensure your host is on *plain* http.
- Large binary `get` on Cpsect intermittently to fail (or my ESP is returning the data oddly)
- CSpect's ESP "emulation" doesn't have an 8-bit mode, so if you're sending or receiving bytes that are in the 8-bit range, i.e. above `$7F` the emulation won't work. If you want want to support cspect, then you can use the `-7` flag and your server will need to use base64 encoding. If your data is 7-bit (i.e. you have no byte values larger than `$7F`) then Cspect should work without extra options.
- Zesarux requires ESP bridging - I've not been able to test this, if you have feedback, please let me know.
- I've noticed when using Cspect's emulation, if the host can't be reached, Cspect will hang entirely.
- When using the `offset` you are constrained to 16K, so if the offset is 8,192, then the max length is also 8,192 (there's no error checking on this currently)

## Todo

- [ ] Add server example code
- [ ] Test > 16K to see effects
- [x] Potentially reset esp if failing to respond (AT+RST)
- [x] Test query string / quoting an argument, i.e. `-u /?a=z`
- [x] base64 version should stream to a buffer
- [x] Add support to leave bank untouched on GET
- [x] Thorough check of argument processing
- [x] Support offset
- [x] Number and document errors
- [x] Explore cspect (without additional hardware)
- [x] Surface DNS error
- [x] Timeout on esp comms
- [x] Support NextBASIC variables in the args, i.e. `-b a$`
- [x] Test calling from NextBASIC (with trailing comment)
- [x] Check POST or GET for > 512 bytes

## Not supported / future

- Chunked encoding
- Support length on GET

## Debugging and problems

This repo also includes a debug build of `httpbank`. The difference is that it will add all the ESP read and write to the second half of the bank you use. This way you can debug from the real hardware and capture exactly what's going on.

**Important** the debug dot command uses the second half of the bank you use, so ideally test with less than 8K to help debugging.

If you need to file an issue, this information is extremely valuable for debugging - and if you're not comfortable including the file in [an issue](https://github.com/remy/next-httpbank/issues/new) as an attachment, you can email me directly at remy@remysharp.com. To capture this, run:

```
10 ../httpbank-debug.dot -h example.com -u / -b 20
20 SAVE "httpbank-debug.bin" BANK 20
```

Then include the `httpbank-debug.bin` that was saved on  your Next to help debug the issue.

## Error codes

- `1` WiFi/server timeout - no ESP available or can't start communication
- `2` Failed to connect to host - possible DNS error (see limits above)
- `3` Cannot open TCP connection - failed to complete TCP handshake
- `4` Unknown command option
- `5` NextBASIC string variable not found - when passing `x$` variable to arguments
- `6` WiFi chip init failed - initialisation error
- `7` HTTP send fail - POST connect error
- `8` HTTP send fail - POST response fail
- `9` HTTP send fail - GET connect error
- `A` HTTP send fail - GET response fail
- `B` HTTP read timeout
- `C` Bank arg error - bank is required and must be a number
- `D` Length arg error - must be a number
- `E` Offset arg error - must be a number
- `F` Port error - must be a number

## Development

- Uses [sjasmplus](https://z00m128.github.io/sjasmplus/documentation.html) from VS Code task
- Follows this [code convention](https://github.com/remy/z80-code-conventions)
- Entry point is main.asm

## With special thanks to

- [Alexander Sharikhin](https://github.com/nihirash) - via internet-nextplorer (which uart.asm and much of wifi.asm is based)
- [Robin Verhagen-Guest](https://github.com/Threetwosevensixseven/NXtel) - via nxtp and nxtel source code
- [Peter Ped Helcmanovsky](https://github.com/ped7g/) - via dot commands and answering endless questions on discord

## License

It's in the license link, but all the same:

> THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND

This software simplifies access to the web from a machine that is typically disconnected. Please use this software for good, but I provide no warranty, or help for that matter, if this software is used for bad. It is what it is.

- [Full MIT license](https://rem.mit-license.org/)
