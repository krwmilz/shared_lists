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

// Object that comes from the main server
type NotifyRequest struct {
	Devices [][]string `json:"devices"`
	MsgType string `json:"msg_type"`
	Payload interface{} `json:"payload"`
}

// Object that matches the format for badge changes
type Badge struct {
	Count int `json:"badge"`
}

// Object that we serialize and send as the POST payload to APN servers
type APNRequest struct {
	Aps interface{} `json:"aps"`
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

	// Parse JSON
	var notify_request NotifyRequest
	err = json.Unmarshal(data, &notify_request)
	if err != nil {
		log.Printf("error parsing json:", err)
		return
	}

	total_devices := len(notify_request.Devices)
	log.Printf("sending message type '%s' to %d device(s)", notify_request.MsgType, total_devices)

	if total_devices == 0 {
		return
	}

	var badge Badge
	badge.Count = 17

	var apn_request APNRequest
	apn_request.Aps = badge
	apn_request.Payload = notify_request.Payload
	apn_request.MsgType = notify_request.MsgType

	// Create the POST request body, only needs to be done once because we
	// send the same message to all devices
	request_body, err := json.Marshal(apn_request)
	if err != nil {
		log.Printf("error re-marshaling payload:", err)
		return
	}

	// APN documentation says this is where we request stuff from
	base_url := "https://api.development.push.apple.com/3/device/"

	// Loop over all devices, check if they are ios and send a message
	for i, d := range notify_request.Devices {

		// Order defined by SQL statement in main server
		os, hex_token := d[0], d[1]
		log_header := fmt.Sprintf("%3d %s", i + 1, hex_token)

		// Filter out any non iOS devices
		if os != "ios" {
			log.Printf("%s: not an ios device", log_header)
			continue
		}

		// Construct entire post URL by adding hexadecimal device token
		// to base URL
		post_url := base_url + hex_token

		// Make new POST request
		req, err := http.NewRequest("POST", post_url, bytes.NewBuffer(request_body))
		if err != nil {
			log.Printf("%s: new request error: %s", log_header, err)
			continue
		}

		// This delivers messages to our iOS application only
		req.Header.Set("apns-topic", "com.octopus.shlist")

		// Make request over existing transport
		resp, err := h.Do(req)
		if err != nil {
			log.Printf("%s: %s", log_header, err)
			continue
		}
		log.Printf("%s: %s", log_header, resp.Status)
	}
}

func main() {
	// These keys are provided by Apple through their Developer program
	cert, err := tls.LoadX509KeyPair("certs/aps.pem", "certs/aps.key")
	if err != nil {
		log.Fatalf("loadkeys: %s", err)
	}
	config := tls.Config{Certificates: []tls.Certificate{cert}, InsecureSkipVerify: true}

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
		log.Printf("caught signal %s: shutting down", sig)

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
