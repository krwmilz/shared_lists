#!/bin/sh

. ../test.sh

echo -n "baddbedd" | xxd -r -p | nc 127.0.0.1 ${PORT}
