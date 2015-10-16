#!/bin/sh

# check if server is running
if [ `pgrep -f perl\ sl` ]; then
	echo "server already running, great."
else
	echo "server not running, you need to start it!"
	exit 1
fi

# if tput is available, we can do colors!
if [ `which tput` ]; then
	RED=$(tput setaf 9 0 0)
	GREEN=$(tput setaf 10 0 0)
	RESET=$(tput sgr0)
fi

# bring in the automatically generated message type environment variables
. tests/net_enums.sh

export TESTS=asdf

PORT=5437

passed=0
failed=0
for t in `ls tests/*/test.sh`; do
	CWD=$(pwd)
	echo -n "$(dirname $t): "

	# XXX: put PORT in the environment
	cd $(dirname $t) && sh $(basename $t) $PORT
	if [ $? -ne 0 ]; then
		echo "\t$RED fail$RESET"
		failed=$(($failed + 1))
	else
		echo "\t$GREEN ok$RESET"
		passed=$(($passed + 1))
	fi
	cd $CWD

	sqlite3 db "delete from devices"
done
echo "\n$passed$GREEN ok$RESET $failed$RED fail$RESET"
