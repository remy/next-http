const http = require("http");
const { networkInterfaces } = require("os");

http
  .createServer((req, res) => {
    console.log(
      new Date().toJSON() + " - request: " + req.method + " " + req.url
    );

    if (req.method === "POST") {
      const data = [];
      req
        .on("data", (chunks) => {
          data.push(...chunks);
        })
        .on("end", () => {
          last = data.length;
          console.log(hexdump(data));
        });
      return res.end("thank you");
    }

    // note that I'm using this method (byte array from) because I want to add
    // some raw bytes that will make the text flash on the spectrum
    const reply = Buffer.from([
      0x12,
      0x01, // FLASH 1;
      ...new TextEncoder().encode("Hi there - from the JS server!"),
      0x12,
      0x00, // FLASH 0;
      0x80, // terminating byte for `s$ = BANK 20 PEEK$(0, ~128): PRINT s$`
    ]);
    if (req.url === "/7") {
      // then encode
      return res.end(reply.toString("base64"));
    }

    return res.end(reply);
  })
  .listen(8080, () => {
    console.log("JavaScript server listening on http://%s:8080", getLocalIP());
  });

function hexdump(buffer) {
  buffer = Uint8Array.from(buffer);

  let offset = 0;
  const length = buffer.length;

  let out = "";
  let row = "";
  for (var i = 0; i < length; i += 16) {
    row += offset.toString(16).padStart(8, "0") + "  ";
    var n = Math.min(16, length - offset);
    let string = "";
    for (var j = 0; j < 16; ++j) {
      if (j === 8) {
        // group bytes into 8 bytes
        row += " ";
      }
      if (j < n) {
        var value = buffer[offset];
        string += value >= 32 ? String.fromCharCode(value) : ".";
        row += value.toString(16).toLowerCase().padStart(2, "0") + " ";
        offset++;
      } else {
        row += "   ";
        string += " ";
      }
    }
    row += " |" + string + "|\n";
  }
  out += row;
  return out.trim();
}

function getLocalIP() {
  const nets = networkInterfaces();
  const results = Object.create(null); // or just '{}', an empty object

  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      // skip over non-ipv4 and internal (i.e. 127.0.0.1) addresses
      if (net.family === "IPv4" && !net.internal) {
        if (!results[name]) {
          results[name] = [];
        }

        results[name].push(net.address);
      }
    }
  }
  return results["en0"][0];
}
