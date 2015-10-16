#!/bin/sh
. ../lib.sh

hex_str="0000000a32333136373139383725"

OUT=$(mktemp)
# -N disconnects after input EOF
echo -n $hex_str | xxd -r -p | nc -N 127.0.0.1 5437 | tail -c +5 > $OUT
if [ $? -ne 0 ]; then
	rm $OUT
	fail "nc -N exited $?"
fi

# verify that we get exactly the right number of bytes back
BYTES=$(wc -c $OUT | tr -s ' ' | cut -d ' ' -f 2)
if [ $? -ne 0 ]; then
	rm $OUT
	fail "wc -c exited $?"
fi
rm $OUT

if [ $BYTES -ne 0 ]; then
	fail "expected 43 bytes, got $BYTES"
fi
