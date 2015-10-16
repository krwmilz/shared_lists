#!/bin/sh
. ../lib.sh

# send valid message type with 0 length message body
echo "00010000" | xxd -r -p | nc 127.0.0.1 5437
if [ $? -ne 0 ]; then
	fail "nc exited $?"
fi
