package main

import (
	"bytes"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	//"io"
	"log"
	"net/http"
	"net"

	"golang.org/x/net/http2"
)

func echo_server(c net.Conn, h http.Client) {
	buf := make([]byte, 4096)
	nr, err := c.Read(buf);
	if err != nil {
		return
	}

	var f interface{}

	data := buf[0:nr]
	fmt.Printf("Received: %v", string(data))
	err = json.Unmarshal(data, &f)

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
	resp, err := h.Do(req)
	fmt.Println("response was:", resp)

	c.Close()
}

func main() {
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
		fmt.Println(x509.MarshalPKIXPublicKey(v.PublicKey))
		fmt.Println(v.Subject)
	}
	log.Println("client: handshake: ", state.HandshakeComplete)
	log.Println("client: mutual: ", state.NegotiatedProtocolIsMutual)

	client := http.Client {
		Transport: &http2.Transport{TLSClientConfig: &config},
	}

	l, err := net.Listen("unix", "../apnd.socket")
	if err != nil {
		log.Fatal("listen error:", err)
	}

	for {
		fd, err := l.Accept()
		if err != nil {
			log.Fatal("accept error:", err)
		}

		go echo_server(fd, client)
	}
}
