#!/bin/sh
. ../lib.sh

# send valid message type with 0 length message body
# we expect the other end to hang up
echo "00010F00" | xxd -r -p | nc 127.0.0.1 5437
if [ $? -ne 0 ]; then
	fail "nc exited $?"
fi
