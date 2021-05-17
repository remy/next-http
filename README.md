# http - for the Spectrum Next

A utility for application developers to talk to web servers to exchange blocks of data, such as high scores, game progress. The `.http` dot command can also download and save to files over the web.

## Usage

```
; Send 1024 bytes from bank 22 to http://192.168.1.100:8080/send
.http post -b 22 -l 1024 -h 192.168.1.100 -p 8080 -u /send

; Download and save Manic Miner http://zxdb.remysharp.com/get/18840
.http -h zxdb.remysharp.com -u /18840 -f manic.tap

; Load http://data.remysharp.com/1 directly into bank 26 and flash border red (2)
.http get -b 26 -h data.remysharp.com -u /1 -v 2
```

Options:

- `-b` bank number in 16K blocks
- `-f` filename (only available in `get` and cannot be used with `-b`)
- `-h` host address
- `-p` port number (defaults to 80)
- `-u` url (defaults to `/`)
- `-l` length of bytes to POST
- `-o` address offset (defaults to 0)
- `-v` flash the border to n 0-7 (defaults to no flashing) and restores original border on exit
- `-7` enabled base64 decoding (useful for supporting [Cspect](http://cspect.org/) and 7-bit binary exchange*)
- `-r` disable rolling banks (see [rolling banks](#rolling-banks))
- `-x` disable uart init - only use this if you know what you're doing!

Note that by default a GET request will empty out the bank selected. If you want to preserve the data in the bank, use a negative value for the offset, i.e. `-b 5 -o -0` will load the http request into bank 5, preserving the RAM and inserting at memory position 0 (in fact, `$4000` in RAM).

Run with no arguments to see the help.

*Cpsect's emulated ESP support used 7-bit, which means if you want to send binary data, you will need to base64 encode your payload. Using the `-7` flag with `http` will support decoding and support Cpsect. This is not required if you only plan to exchange 7-bit data (like readable text) or support hardware. See the example folder for a server returning binary using base64 encoding.

## Using from NextBASIC

If the dot command isn't (currently) shipped as part of the distro and you want to ship `http` as part of your project, you will need to call the dot command from a relative path. You might also need to set variables, such as a bank number through NextBASIC and pass this to `http`. At time of writing (Feb 2021) the `.$` command doesn't support relative paths, so NextBASIC variable reading is support as part of `http`.

The only variables that `http` supports are single letter string variables.

Assuming `http` is in the same directory as your NextBASIC file, the following prefix is required: `../` (dot dots and a slash). See the code below for the full example:

```
10 BANK NEW b
20 b$ = STR$ b : REM store as a string
30 c$ = "256" : REM we'll send 256 bytes from bank $b
30 ../http post -b b$ -h example.com -l c$
40 PRINT "done"
```

Note that `http` will expect a BASIC variable to represent a single argument value and you cannot combine multiple arguments into a single variable (i.e. `h$="-h example -p 8080` won't work).

## Rolling banks

For file saving, rolling banks are used by default. What this means is that the http request is buffered into memory for as many memory banks are available (16K banks - two 8K pages). Before the file is fully downloaded a size check is run against the `content-length` and your available memory, and if there's not enough, `.http` will exit with error `M Not enough memory`.

Rolling banks is used to provide as much support across different SD card speeds. If you need to download more than your memory limits _and_ you have a fast SD card (class 10 is a good default), then you can disable rolling banks using the `-r` switch as an argument.

## Installation

You can save the `http` to your own `/dot` directory, or you can run it from your working directory using a relative path `../http`.

**Download the latest [release here](https://github.com/remy/next-http/releases)**

## Example servers

I've written a number of [example servers](https://github.com/remy/next-http/tree/main/example/servers) in different languages for you to try out.

## Limits

- When using a domain name, I've found that `CNAME` records can result in `DNS Error` so make sure to use `A` records ideally - you'll see error `2`.
- There's no SSL/TLS support - ensure your host is on *plain* http.
- CSpect's ESP "emulation" doesn't have an 8-bit mode, so if you're sending or receiving bytes that are in the 8-bit range, i.e. above `$7F` the emulation won't work. If you want want to support cspect, then you can use the `-7` flag and your server will need to use base64 encoding. If your data is 7-bit (i.e. you have no byte values larger than `$7F`) then Cspect should work without extra options.
- Zesarux requires ESP bridging - I've not been able to test this, if you have feedback, please let me know.
- I've noticed when using Cspect's emulation, if the host can't be reached, Cspect will hang indefinitely.
- When using the `offset` you are constrained to 16K, so if the offset is 8,192, then the max length is also 8,192 (there's no error checking on this currently)

## Not supported / potential future

- 7bit / cspect emulated ESP support for file saving isn't supported (yet)
- http chunked encoding (just make sure your server isn't sending chunked encoding)
- Support length on GET
- File POST and offsets in file saving

## Error codes

- `1` WiFi/server timeout - no ESP available or can't start communication
- `2` Failed to connect to host - possible DNS error (see limits above)
- `3` Cannot open TCP connection - failed to complete TCP handshake
- `4` Unknown command option
- `5` NextBASIC string variable not found - when passing `x$` variable to arguments
- `6` WiFi chip init failed - initialisation error
- `7` HTTP send fail - POST connect error
- `8` HTTP send fail - POST response fail
- `9` HTTP get fail - GET connect error
- `A` HTTP send tcp frame fail - POST read error
- `B` HTTP read timeout
- `C` Bank arg error - bank is required and must be a number
- `D` Length arg error - must be a number
- `E` Offset arg error - must be a number
- `F` Port error - must be a number
- `G` Border option error - must be a number between 0 and 7
- `H` Hostname is required
- `I` Filename or bank must be specified (command is missing the `-b` or `-f` argument)
- `J` Could not open file for writing
- `K` Could not read the http content length header correctly
- `L` Out of memory to buffer file download: try with `-r` to disable rolling banks
- `M` Not enough memory to download: try with `-r` to disable rolling banks

## Testing

Assuming that `http` is in your `/dot/` directory, there are two verification programs in the [example](https://github.com/remy/next-http/tree/main/example) folder. Download [verify.bas](https://github.com/remy/next-http/blob/main/example/verify.bas) and run it and if it succeeds you'll see the following screen:

![](https://user-images.githubusercontent.com/13700/114017829-68f57380-9864-11eb-9590-71cad0e4c4a1.png)

If any of the sections fail however, there is a debug script available in [capture-esp.bas](https://github.com/remy/next-http/blob/main/example/capture-esp.bas) which uses [`http-debug.dot`](https://github.com/remy/next-http/blob/main/http-debug.dot) in the **same** directory as capture-esp.bas.

The `capture-esp.bas` will test a simple 4K file and generate `4k-esp-bank.bin` in the same working directory which contains full debug exchange between your machine and the ESP chip uses to send data. If you share that file with me either [via issues](https://github.com/remy/next-http/issues/new) or via [email](mailto:remy@remysharp.com) I can use it to debug.


## Debugging and problems

This repo also includes a debug build of `http`. The difference is that it will add all the ESP read and write to the second half of the bank you use. This way you can debug from the real hardware and capture exactly what's going on.

**Important** the debug dot command uses the second half of the bank you use, so ideally test with less than 8K to help debugging.

If you need to file an issue, this information is extremely valuable for debugging - and if you're not comfortable including the file in [an issue](https://github.com/remy/next-http/issues/new) as an attachment, you can email me directly at remy@remysharp.com. To capture this, run:

```
10 ../http-debug.dot -h example.com -u / -b 20
20 SAVE "http-debug.bin" BANK 20
```

Then include the `http-debug.bin` that was saved on  your Next to help debug the issue.

### Notes on http-debug.dot

1. Does not erase the bank
2. The contents of the `State` structure (in `state.asm`) are written to the 2nd half of the bank, i.e. the second 8K page
3. After the `State` object, around 519 bytes later, the ESP exchange are stored, including the AT commands and ESP raw response.
4. `Wifi.getPacket` writes to the end of the bank with the `IX` register state as a stack like array - this is to debug the final parsing of the base64 encoded packet


## With special thanks to

- [Alexander Sharikhin](https://github.com/nihirash) - via internet-nextplorer (which uart.asm and much of wifi.asm is based)
- [Robin Verhagen-Guest](https://github.com/Threetwosevensixseven/NXtel) - via nxtp and nxtel source code
- [Peter Ped Helcmanovsky](https://github.com/ped7g/) - via dot commands and answering endless questions on discord
- [David Saphier](https://github.com/em00k/) - for starting and inspiring full "save to file" support

## Development

- Uses [sjasmplus](https://z00m128.github.io/sjasmplus/documentation.html) from VS Code task
- Follows this [code convention](https://github.com/remy/z80-code-conventions)
- Entry point is main.asm
- Optional `Makefile` has been included

## License for .HTTP

It's in the license link, but all the same:

> THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND

This software simplifies access to the web from a machine that is typically disconnected. Please use this software for good, but I provide no warranty, or help for that matter, if this software is used for bad. It is what it is.

- [Full MIT license](https://rem.mit-license.org/)
