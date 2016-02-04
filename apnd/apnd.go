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
	var f interface{}
	err = json.Unmarshal(data, &f)
	if err != nil {
		log.Printf("error parsing json:", err)
		return
	}

	m := f.(map[string]interface{})

	for k, v := range m {
		switch vv := v.(type) {
		case string:
			fmt.Println(k, "is string", vv)
		case int:
			fmt.Println(k, "is int", vv)
		case []interface{}:
			fmt.Println(k, "is an array", vv)
			for i, u := range vv {
				fmt.Println(i, u)
			}
		default:
			fmt.Println(k, "is of a type I don't know how to handle")
		}
	}

	var jsonStr = []byte(`{"aps":{"badge":33},"other_key":"other_value"}`)

	req, err := http.NewRequest("POST", "https://api.development.push.apple.com/3/device/DE2D368BB6C80E1D8BCB86D20CB6C2161BD5CEC5BA35A1E1AA0DB382849ED9B2", bytes.NewBuffer(jsonStr))
	req.Header.Set("apns-topic", "com.octopus.shlist")

	// Make request over existing transport
	resp, err := h.Do(req)
	fmt.Println("response was:", resp)
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
		}

		go process_client(fd, client)
	}
}
