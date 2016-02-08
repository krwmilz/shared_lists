package main

import (
	"bytes"
	"crypto/tls"
	//"crypto/x509"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net"
	"os"
	"os/signal"
	"syscall"

	"golang.org/x/net/http2"
)

// Fields here defined in specification
type NotifyRequest struct {
	// Order of inner array defined by SQL statement in main server
	Devices [][]string `json:"devices"`
	MsgType string `json:"msg_type"`
	Payload interface{} `json:"payload"`
}

func process_client(c net.Conn, h http.Client) {

	// Read data from connection
	buf := make([]byte, 4096)
	nr, err := c.Read(buf);
	if err != nil {
		return
	}
	c.Close()

	data := buf[0:nr]
	fmt.Printf("Received: %v", string(data))

	// Parse JSON
	var notify_request NotifyRequest
	err = json.Unmarshal(data, &notify_request)
	if err != nil {
		log.Printf("error parsing json:", err)
		return
	}

	log.Print("msg type:", notify_request.MsgType)

	// Re-marshal the payload
	// Can also add "aps":{"badge":33} to set badge icon too
	request_body, err := json.Marshal(notify_request.Payload)
	if err != nil {
		log.Printf("error marshaling payload:", err)
		return
	}

	// APN documentation says this is where we request stuff from
	base_url := "https://api.development.push.apple.com/3/device/"

	// Loop over all devices
	for i, d := range notify_request.Devices {
		if d[0] != "ios" {
			// We don't send messages for non-iOS devices
			log.Print(i, " skipping device with os ", d[0])
			continue
		}

		// Construct entire post URL by adding hexadecimal device token
		// to base URL
		post_url := base_url + d[1]

		// Make new POST request
		req, err := http.NewRequest("POST", post_url, bytes.NewBuffer(request_body))
		if err != nil {
			log.Printf("error making new request:", err)
			continue
		}

		// This must be set otherwise nothing gets delivered
		req.Header.Set("apns-topic", "com.octopus.shlist")

		// Make request over existing transport
		resp, err := h.Do(req)
		if err != nil {
			log.Printf("error making request:", err)
			continue
		}
		fmt.Println("response was:", resp)
	}
}

func main() {
	// Read client SSL key pair
	cert, err := tls.LoadX509KeyPair("ssl/aps.pem", "ssl/aps.key")
	if err != nil {
		log.Fatalf("server: loadkeys: %s", err)
	}

	config := tls.Config{Certificates: []tls.Certificate{cert}, InsecureSkipVerify: true}
	conn, err := tls.Dial("tcp", "api.development.push.apple.com:443", &config)
	if err != nil {
		log.Fatalf("client: dial: %s", err)
	}
	defer conn.Close()
	log.Println("client: connected to: ", conn.RemoteAddr())

	state := conn.ConnectionState()
	for _, v := range state.PeerCertificates {
		// fmt.Println(x509.MarshalPKIXPublicKey(v.PublicKey))
		fmt.Println(v.Subject)
	}
	log.Println("client: handshake: ", state.HandshakeComplete)
	log.Println("client: mutual: ", state.NegotiatedProtocolIsMutual)

	// Create new http client with http2 TLS transport underneath
	client := http.Client {
		Transport: &http2.Transport{TLSClientConfig: &config},
	}

	// Create socket that listens for connections from the main server
	l, err := net.Listen("unix", "../apnd.socket")
	if err != nil {
		log.Fatal("listen error:", err)
	}

	// Close (and unlink) listener socket on shutdown signals
	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc, os.Interrupt, os.Kill, syscall.SIGTERM)
	go func(c chan os.Signal) {
		// Wait for signal
		sig := <-c
		log.Printf("Caught signal %s: shutting down", sig)

		l.Close()
		os.Exit(0)
	}(sigc)

	// Main loop, service new main server connections
	for {
		fd, err := l.Accept()
		if err != nil {
			log.Fatal("accept error:", err)
			continue
		}

		go process_client(fd, client)
	}
}
