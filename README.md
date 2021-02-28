# httpbank - for the Spectrum Next (public beta)

Usage:

```
.httpbank post -b 22 -l 1024 -h 127.0.0.1 -p 8080 -u /send
.httpbank get -b 26 -h example.com -u /receive
```

Options:

- `-b` bank number in 16K blocks
- `-l` length of bytes to send
- `-o` address offset (defaults to 0)
- `-h` host address
- `-p` port number (defaults to 80)
- `-u` url (defaults to `/`)

Note that by default a GET request will empty out the bank selected. If you want to preserve the data in the bank, use a negative value for the offset, i.e. `-b 5 -o -0` will load the http request into bank 5, preserving the RAM and inserting at memory position 0 (in fact, `$4000` in RAM).

Run with no arguments to see the help.

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

## Installation

You can save the `httpbank` to your own `/dot` directory, or you can run it from your working directory using a relative path `../httpbank`.

## Limits

- When using a domain name, I've found that `CNAME` records result is `DNS Error` so make sure to use `A` records ideally - you'll see error 2.
- There's no SSL/TLS support - ensure your host is on *plain* http.
- Large binary get on cpsect seems to fail (or my ESP is returning the data oddly)
- CSpect's ESP "emulation" doesn't have an 8-bit mode, so if you're sending or receiving bytes that are in the 8-bit range, i.e. above `$7F` the emulation won't work. You can of course attach a real ESP 01 device and
- Zesarux requires ESP bridging - I've not been able to test this, if you have feedback, please let me know.

## Todo

- [ ] Potentially reset esp if failing to respond (AT+RST)
- [ ] Support length on GET
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

## Debugging and problems

This repo also includes a debug build of httpbank. The difference is that it will add all the ESP read and write to the second half of the bank you use. This way you can debug from the real hardware and capture exactly what's going on.

If you need to file an issue, this information is extremely valuable for debugging - and if you're not comfortable including the file in [an issue](https://github.com/remy/next-httpbank/issues/new) as an attachment, you can email me directly at remy@remysharp.com. To capture this, run:

```
10 ../httpbank-debug.dot -h example.com -u / -b 20
20 SAVE "esp-debug.bin" BANK 20, 8192, 8192
```

Then include the `esp-debug.bin` that was saved on  your Next to help debug the issue.

## Errors

- 1 WiFi/server timeout
- 2 Failed to connect to host - possible DNS error (see limits above)
- 3 Cannot open TCP connection - failed to complete TCP handshake
- 4 Unknown command option
- 5 NextBASIC string variable not found - when passing `x$` variable to arguments
- 6 WiFi chip init failed - initialisation error
- 7 HTTP send fail - POST connect error
- 8 HTTP send fail - POST response fail
- 9 HTTP send fail - GET connect error
- A HTTP send fail - GET response fail
- B HTTP read timeout

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
