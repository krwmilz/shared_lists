#!/bin/sh

# try not to connect to a production instance with this script!
export PORT=4729

if which tput > /dev/null; then
	red=`tput setaf 1 0 0`
	green=`tput setaf 2 0 0`
	reset=`tput sgr0`
fi

fail() {
	printf "%3s %s: %s%s%s\n" $count $1 $red "$2" $reset
	failed=`expr $failed + 1`
}

passed=0
failed=0
count=0
tmp_file=`mktemp`
for t in `ls tests/*/Makefile`; do
	count=`expr $count + 1`
	test_dir=`dirname ${t}`
	export TEST_DIR="$test_dir"
	make -s -C $test_dir clean

	perl sl -p $PORT -d $tmp_file > $test_dir/server.log &
	server_pid=$!

	# run test, complain if failed
	if ! make -s -C $test_dir test; then
		fail $test_dir "test failed"
		kill $server_pid
		wait
		continue
	fi

	# make sure the server is still running
	if ! kill -0 $server_pid; then
		fail $test_dir "test killed server"
		continue
	fi

	# kill the server and wait for it to shut down
	kill $server_pid
	wait 2>/dev/null

	if ! make -s -C $test_dir diff; then
		fail $test_dir "diff failed"
		continue
	fi

	printf "%3s %s: %s%s%s\n" $count $test_dir $green "ok" $reset
	passed=`expr $passed + 1`
	make -s -C $test_dir clean
done
rm -f $tmp_file

printf "\n"
if [ $passed -ne 0 ]; then
	printf "%i %sok%s " $passed $green $reset
fi
if [ $failed -ne 0 ]; then
	printf "%i %sfailed%s " $failed $red $reset
fi
printf "(%i min %i sec)\n" $((SECONDS / 60)) $((SECONDS % 60))

exit $failed;
