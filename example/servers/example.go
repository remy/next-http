package main

import (
    "fmt"
    "log"
    "net/http"
    "net"
    "io/ioutil"
    "encoding/hex"
    "os"
    "encoding/base64"
)

func handler(w http.ResponseWriter, r *http.Request) {
    log.Printf("request: %s %s", r.Method, r.URL)

    switch r.Method {
      case "GET":
        // simple GET handler that adds FLASH on and FLASH off
        reply := "\x12\x01Hi there - from the Go server!\x12\x00\x80"
        if r.URL.Path == "/7" {
          fmt.Fprintf(w, base64.StdEncoding.EncodeToString([]byte(reply)))
        } else {
          fmt.Fprintf(w, reply)
        }
      case "POST":
        // accept the POST request and dump it out in hex format
        body, err := ioutil.ReadAll(r.Body)
        if err != nil {
            panic(err)
        }
        stdoutDumper := hex.Dumper(os.Stdout)
        defer stdoutDumper.Close()
        stdoutDumper.Write(body)
        fmt.Fprintf(w, "thank you")
      }

}

// GetLocalIP returns the non loopback local IP of the host
func GetLocalIP() string {
  addrs, err := net.InterfaceAddrs()
  if err != nil {
      return ""
  }
  for _, address := range addrs {
      // check the address type and if it is not a loopback the display it
      if ipnet, ok := address.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
          if ipnet.IP.To4() != nil {
              return ipnet.IP.String()
          }
      }
  }
  return ""
}

func main() {
    http.HandleFunc("/", handler)
    log.Printf("Go server listening on http://%s:8080", GetLocalIP())
    log.Fatal(http.ListenAndServe(":8080", nil))
}
