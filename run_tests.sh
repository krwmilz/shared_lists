#!/bin/sh

# try not to connect to a real production instance with this script!
export PORT=4729
temp_db=`mktemp`

# start server with temp db, non standard port, and in the background
perl sl -p $PORT -d $temp_db > server.log &
server_pid=$!

sleep 0.1

# clean up on ctrl-c
trap sigint_handler int

sigint_handler() {
	# remove temp db, and kill this process group
	rm $temp_db
	rm server.log
	kill 0
}

if which tput > /dev/null; then
	red=`tput setaf 1 0 0`
	green=`tput setaf 2 0 0`
	reset=`tput sgr0`
fi

cleanup() {
	> server.log

	# clean up the database between runs
	sqlite3 ${1} "delete from devices; delete from lists;
		delete from list_members; delete from list_data;
		delete from friends_map; delete from mutual_friends;"
}

passed=0
failed=0
count=0
for t in `ls tests/*/Makefile`; do
	count=$((count + 1))
	test_dir=`dirname ${t}`
	make -s -C $test_dir clean

	# run test, complain if failed
	if ! make -s -C $test_dir "test"; then
		printf "%3s %s: %s%s%s\n" $count $test_dir $red "test failed" $reset
		failed=$((failed + 1))
		cleanup $temp_db
		continue
	fi

	# make sure the server is still running
	if ! kill -0 $server_pid; then
		printf "%3s %s: %s%s%s\n" $count $test_dir $red "test killed server" $reset
		+cat server.log
		rm $temp_db
		exit 1
	fi

	# process server log and remove header, base64 strings and phone numbers
	sed -e "s/.*: //" -e "s/'[0-9]*'/<phone_num>/g" \
		-e "s/'[a-zA-Z0-9/+]*'/<base64>/g" \
		< server.log > $test_dir/server.log
	# truncate server log, don't delete it as it won't be recreated
	> server.log

	if ! make -s -C $test_dir diff; then
		printf "%3s %s: %s%s%s\n" $count $test_dir $red "diff failed" $reset

		failed=$((failed + 1))
		cleanup $temp_db
		continue
	fi

	printf "%3s %s: %s%s%s\n" $count $test_dir $green "ok" $reset
	passed=$((passed + 1))
	cleanup $temp_db
	make -s -C $test_dir clean
done
printf "\n"
if [ $passed -ne 0 ]; then
	printf "%i %sok%s " $passed $green $reset
fi
if [ $failed -ne 0 ]; then
	printf "%i %sfailed%s " $failed $red $reset
fi
# magic shell variable $SECONDS contains number of seconds since script start
printf "(took %i min %i sec)\n" $((SECONDS/60)) $((SECONDS%60))

kill $server_pid
rm $temp_db
rm server.log

exit $failed;
