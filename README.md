# httpbank (WIP)

Intended usage:

```
.httpbank -b 22 -o 0 -l 1024 -s 127.0.0.1 -p 8080
```

Options:

- `-b` bank number in 16K blocks
- `-o` address offset
- `-l` length of bytes to send
- `-s` host address
- `-p` port number
- `-h` shows help

## Process

1. Checks commands and allocates defaults or exits with errors
2. Connects to network address and port
3. Loads bank into slot
4. Reads address to offset sending bytes to network
5. Closes wifi connection
6. Restores slot

Thoughts on missing tasks:

- Run at full speed
- Sync uart or adjust it
- Restore speeds, etc

## Development

- Uses sjasmplus from VS Code task
- Follows this [code convention](https://github.com/remy/z80-code-conventions)
