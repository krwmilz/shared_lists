#!/bin/sh

. ../lib.sh

DEV_ID=$(nc -N 127.0.0.1 5437 < register.bin | tail -c +5)
if [ $? -ne 0 ]; then
	fail "nc -N exited $?"
fi

# echo -n "device id is $DEV_ID"
dev_id_hex=$(echo -n $DEV_ID | xxd -p)
list_name_hex=$(echo -n "some new list that's" | xxd -p)
hex_str="${msg_new_list}0040${dev_id_hex}00${list_name_hex}"

OUT=$(mktemp)
echo -n $hex_str | xxd -r -p | nc -N 127.0.0.1 5437 > $OUT
if [ $? -ne 0 ]; then
	rm $OUT
	fail "nc -N exited $?"
fi

#  6 six_byte_file | del white | get the '6'
BYTES=$(wc -c $OUT | tr -s ' ' | cut -d ' ' -f 2)
if [ $? -ne 0 ]; then
	rm $OUT
	fail "wc -c exited $?"
fi
rm $OUT

if [ $BYTES -eq 0 ]; then
	fail "bytes was zero"
fi
