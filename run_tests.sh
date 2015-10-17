#!/bin/sh

if ! pgrep -f perl\ sl; then
	echo "server not running, you need to start it!"
	exit 1
fi

# if tput is available, we can do colors!
if which tput; then
	RED=$(tput setaf 1 0 0)
	GREEN=$(tput setaf 2 0 0)
	YELLOW=$(tput setaf 3 0 0)
	RESET=$(tput sgr0)
fi

export TESTS=asdf

PORT=5437

passed=0
failed=0
count=1
for t in `ls tests/*/test.*`; do
	CWD=$(pwd)
	printf "%3s " $count
	echo -n "$(dirname $t): $YELLOW"

	# XXX: put PORT in the environment
	cd $(dirname $t) && ./$(basename $t) $PORT
	if [ $? -ne 0 ]; then
		echo "$RED fail$RESET"
		failed=$((failed + 1))
	else
		echo "$GREEN ok$RESET"
		passed=$((passed + 1))
	fi
	cd $CWD

	# `ps -o pid= -p $SERVER_PID`
	# if [ $? -eq 0 ]; then
	# 	echo ">>> $RED server died!$RESET"
	# 	exit 1
	# fi

	# clean up the database between runs
	sqlite3 db "delete from devices"
	sqlite3 db "delete from lists"
	sqlite3 db "delete from list_members"

	count=$((count + 1))
done
echo "\n$passed$GREEN ok$RESET $failed$RED fail$RESET"

if [ $failed -ne 0 ]; then
	exit 1
fi
