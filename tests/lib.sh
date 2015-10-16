#!/bin/sh


send_msg() {
	echo "$1" | xxd -r -p | nc -N 127.0.0.1 5437 > $OUT
}

fail() {
	echo -n "$1"
	exit 1
}
