# Python 3 server example
from http.server import BaseHTTPRequestHandler, HTTPServer
import sys
import os.path
import socket
import base64

hostName = socket.gethostbyname(socket.gethostname())
serverPort = 8080

reply = b"\x12\01Hi there - from the Python server!\x12\x00\x80"


def recover(a):
    # hexdump via https://github.com/walchko/pyhexdump/blob/master/pyhexdump/pyhexdump.py
    b = []
    for c in a:
        if 0x7e >= c >= 0x20:  # only print ascii chars
            b.append(chr(c))
        else:  # all others just replace with '.'
            b.append('.')
    ret = ''.join(b)
    return ret


def hexdump(data):
    size = 16
    buff = []
    line = [0]*size
    print_string = '{:09X} | ' + \
        '{:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} {:02X} ' + \
        '|{}|'
    for i, char in enumerate(data):
        if i % size == 0 and i != 0:
            buff.append(line)
            line = [0]*size
            line[0] = char
        else:
            line[i % size] = char

            if i == len(data) - 1:
                buff.append(line)

    for i, line in enumerate(buff):
        print(print_string.format(i,
                                  line[0],
                                  line[1],
                                  line[2],
                                  line[3],
                                  line[4],
                                  line[5],
                                  line[6],
                                  line[7],
                                  line[8],
                                  line[9],
                                  line[10],
                                  line[11],
                                  line[12],
                                  line[13],
                                  line[14],
                                  line[15],
                                  recover(line)
                                  )
              )


class MyServer(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        if self.path == "/7":
            self.wfile.write(base64.b64encode(reply))
        else:
            self.wfile.write(reply)

    def do_POST(self):
        self.send_response(200)
        self.end_headers()
        content_length = int(self.headers['Content-Length'])
        body = self.rfile.read(content_length)
        hexdump(bytearray(body))
        self.wfile.write(b"thank you")


if __name__ == "__main__":
    webServer = HTTPServer((hostName, serverPort), MyServer)
    print("Server started http://%s:%s" % (hostName, serverPort))

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
