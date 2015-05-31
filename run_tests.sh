#!/bin/sh

echo running tests
for f in `ls tests/*`; do
	nc 127.0.0.1 5437 < $f
done
