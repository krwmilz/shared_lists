#!/bin/sh
. ../lib.sh

OUT=$(mktemp)
# -N disconnects after input EOF
nc -N 127.0.0.1 5437 < net.bin | tail -c +5 > $OUT
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

if [ $BYTES -ne 43 ]; then
	fail "expected 43 bytes, got $BYTES"
fi
