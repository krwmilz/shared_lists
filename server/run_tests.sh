#!/bin/sh

# try not to connect to a production instance with this script!
export PORT=4729

if which tput > /dev/null; then
	red=`tput setaf 1 0 0`
	green=`tput setaf 2 0 0`
	reset=`tput sgr0`
fi

if [ `uname` = "OpenBSD" ]; then
	alias make=gmake
fi

fail() {
	printf "%3s %s: $red%s$reset\n" $count "$1" "$2"
	failed=`expr $failed + 1`
}

ok() {
	printf "%3s %s: $green%s$reset\n" $count "$1" "ok"
	passed=`expr $passed + 1`
}

perl -T sl -p $PORT -t > server.log &
server_pid=$!

passed=0
failed=0
count=0
for t in `ls tests/*/Makefile`; do
	count=`expr $count + 1`
	test_dir=`dirname ${t}`
	make -s -C $test_dir clean

	# run test, complain if it failed
	if ! make -s -C $test_dir test; then
		fail $test_dir "test failed"
		continue
	fi

	# copy server log aside for diff'ing
	cp server.log $test_dir/server.log
	> server.log

	# diff the server's output log
	if ! make -s -C $test_dir diff; then
		fail $test_dir "diff failed"
		continue
	fi

	make -s -C $test_dir clean
	ok $test_dir
done

kill $server_pid
wait 2>/dev/null
rm server.log

printf "\n%i %sok%s %i %sfailed%s " $passed $green $reset $failed $red $reset
printf "(%i min %i sec)\n" $((SECONDS / 60)) $((SECONDS % 60))

exit $failed;
