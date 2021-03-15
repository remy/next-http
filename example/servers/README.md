# Server examples

I've tried to include a few languages of how you might write a server to respond to requests from `httpbank`.

An important constraint with these servers that `httpbank` can connect to is that they must run over HTTP and _not_ HTTPS (which many hosting platforms provide and enforce for free).

To use the server, select the language you're familiar with or want to play with and start the server (details below).

You'll need to know your server machine's IP address (which will be printed when you start the server), and from NextBASIC you can test using the following code.

The example assumes your server is running on IP address 192.168.0.1 and on the port 8080:

```
10 LAYER 0
20 BANK 20 CLEAR :; we'll use bank 20 for this example
30 ../httpbank -b 20 -h 192.168.0.1 -p 8080
40 s$ = BANK 20 PEEK$(0, ~128) :; the response is terminated with the $80 byte
50 PRINT s$
```

If you're using Cspect, you will need to request the `http://192.168.0.1:8080/7` URL and use the `-7` flag as this encodes the bytes to 7-bit (a constraint on Cpsect) as the servers are sending byte values greater than `$3F`. This means line `30` will read:

```
30 ../httpbank -b 20 -h 192.168.0.1 -p 8080 -u /7 -7
```

If running from Next hardware, you do not need this.

## Running the servers

Note that PHP and Python typically come pre-installed on most operating systems, but these servers are intended as illustrative only.

- JavaScript: requires [nodejs](https://nodejs.org/en/), then use `node example.js`
- Go: requires [golang](https://golang.org/dl/), then use `go run example.go`
- PHP: requires [PHP](https://www.php.net/downloads), then use `php -S 192.168.0.1:8000 example.php` (remember to use your own IP)
- Python: requires [python](https://www.python.org/downloads/), then use `python3 example.py`

Note that all the servers include code to dump out the POST'ed body using a hexdump routine - this is only to give you a better insight into the contents sent from the Next machine to the server.

## Without a server

I have built an am running a simple hosted service for data which runs over HTTP. Accounts are free, but are on a request basis.

The service accepts GET and POST requests and you can manage what the reply is from the GET requests. It also has the functionality to process POST requests to modify the GET reply dynamically and is [documented](http://data.remysharp.com/docs).

The service can be found at http://data.remysharp.com

## Missing server languages

If there's a language you think should be included, please send a [pull request](https://github.com/remy/next-httpbank/pulls) with a server that supports the same functionality as that demonstrated by the existing servers.
