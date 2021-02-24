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

## Limits

-


## Todo

- [ ] Timeout on esp comms
- [ ] Check POST or GET for > 512 bytes
- [ ] Support offset
- [ ] Thorough check of argument processing
- [ ] Test calling from NextBASIC
- [ ] Potentially reset esp if failing to respond (AT+RST)
- [ ] Support NextBASIC variables in the args, i.e. `-b a$`

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
