#!/bin/sh

# *never* connect to a real production instance with this script!
port=4729
temp_db=$(mktemp)

# start server with temp db, non standard port, and in the background
perl sl -p $port -d $temp_db > server.log &
server_pid=$!
echo -n "[$server_pid] server started"

# clean up on ctrl-c
trap sigint_handler int

sigint_handler() {
	# remove temp db, and kill this process group
	rm $temp_db
	rm server.log
	kill 0
}

if [ $# -eq 3 ]; then
	echo "(implement running single test)"
fi

# if tput is available we can do colors!
if which tput > /dev/null; then
	# make sure we run on XTERM={screen,xterm} which have 8 colors
	if [ $(tput colors) -ne -1 ]
	then
		red=$(tput setaf 1 0 0)
		green=$(tput setaf 2 0 0)
		yellow=$(tput setaf 3 0 0)
	fi
	reset=$(tput sgr0)
fi

# don't start the test suite until we can connect to the server
while ! nc -z 127.0.0.1 $port 2> /dev/null; do
	if ! ps -p $server_pid > /dev/null
	then
		echo " server died! log file was:"
		cat server.log
		exit 1
	fi
	echo -n "."
	sleep 0.1
done

# wait for the output triggered from the above `nc` command to be flushed
if grep "disconnected!" server.log > /dev/null; then
	sleep 0.1
	echo -n "."
fi
cat server.log
> server.log
echo " ready"

cleanup() {
	> server.log

	# clean up the database between runs
	sqlite3 ${1} "delete from devices;
			delete from lists;
			delete from list_members;
			delete from list_data;
			delete from friends_map;
			delete from mutual_friends;"
}

passed=0
failed=0
count=0
for t in `ls tests/*/test.*`; do
	count=$((count + 1))
	printf "%3s %s: %s" $count $(dirname $t) $yellow

	# run test
	if ! ./${t} $port; then
		echo "$red test failed$reset"
		failed=$((failed + 1))
		cleanup $temp_db
		continue
	fi
	echo -n "${reset}"

	# validate the server is still running
	if ! kill -0 $server_pid; then
		echo "$red test killed server!$reset"
		+cat server.log
		rm $temp_db
		exit 1
	fi

	# wait for server output to be flushed
	if grep "disconnected!" server.log > /dev/null; then
		sleep 0.001
	fi

	# validate server output against known good
	processed_log=`mktemp`
	sed 's/.*: //' < server.log | sed 's/[0-9]*:[a-zA-Z0-9/+]*/<ph num>:<dev id>/g' > $processed_log
	# truncate server log, don't delete it as it won't be recreated
	> server.log

	if ! diff -u $(dirname $t)/expected_out $processed_log > /dev/null
	then
		echo "${red}server log output diff failed$reset"
		diff -u `dirname $t`/expected_out $processed_log
		failed=$((failed + 1))
		rm $processed_log
		cleanup $temp_db
		continue
	fi
	rm $processed_log

	echo "${green}ok${reset}"
	passed=$((passed + 1))
	cleanup $temp_db
done
printf "\n%i %sok%s %i %sfail%s " $passed $green $reset $failed $red $reset
# magic shell variable $SECONDS contains number of seconds since script start
printf "(took %i min %i sec)\n" $((SECONDS/60)) $((SECONDS%60))

kill $server_pid
rm $temp_db
rm server.log

if [ $failed -ne 0 ]; then
	exit 1
fi
