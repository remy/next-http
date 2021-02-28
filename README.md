# httpbank (WIP)

Intended usage:

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

## Limits

- _todo_ / to discover
- When using a domain name, I've found that `CNAME` records result is `DNS Error` so make sure to use `A` records ideally.
- There's no SSL/TLS support - ensure your host is on *plain* http.
- Large binary get on cpsect seems to fail (or my ESP is returning the data oddly)

## Todo

- [ ] Support cspect (without additional hardware)
- [ ] Support offset
- [ ] Reduce memory used for host and URL (currently max RFC length)
- [ ] Thorough check of argument processing
- [ ] Potentially reset esp if failing to respond (AT+RST)
- [ ] Number and document errors
- [x] Surface DNS error
- [x] Timeout on esp comms
- [x] Support NextBASIC variables in the args, i.e. `-b a$`
- [x] Test calling from NextBASIC (with trailing comment)
- [x] Check POST or GET for > 512 bytes

## How it works

1. Checks commands and allocates defaults or exits with errors
2. Connects to network address and port
3. Loads bank into slot
4. Reads address to offset sending bytes to network
5. Closes wifi connection
6. Restores slot

Thoughts on missing tasks:

- ~~Run at full speed~~
- ~~Sync uart or adjust it~~
- ~~Restore speeds, etc~~

## Development

- Uses sjasmplus from VS Code task
- Follows this [code convention](https://github.com/remy/z80-code-conventions)

## License

- [MIT](https://rem.mit-license.org/)
