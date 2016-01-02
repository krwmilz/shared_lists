#!/bin/sh

if [ "$PORT" == "" ]; then
	echo "PORT environment variable must be set!"
	exit 1
fi

fail() {
	echo -n "$1"
	exit 1
}
