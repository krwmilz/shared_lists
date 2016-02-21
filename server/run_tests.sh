#!/bin/sh

# Try not to connect to the production server with this script!
export PORT=4729

if which tput > /dev/null; then
	red=`tput setaf 1 0 0`
	green=`tput setaf 2 0 0`
	reset=`tput sgr0`
fi

if [ `uname` = "OpenBSD" ]; then
	alias make=gmake
fi

perl -T sl -p $PORT -t > server.log &
server_pid=$!

perl testd.pl > testd.log &
testd_pid=$!

ok=0
test_failed=0
diff_failed=0
count=0
for t in `LC_ALL=C ls t/*/Makefile`; do
	count=`expr $count + 1`
	test_dir=`dirname ${t}`
	> server.log
	> testd.log

	# run test, complain if it failed
	if ! make -s -C $test_dir test; then
		printf "%3s %s: $red%s$reset\n" $count $test_dir "test failed"
		test_failed=$((test_failed + 1))
		> server.log
		> testd.log
		continue
	fi

	# copy server log aside for diff'ing
	cp server.log $test_dir/server.log
	cp testd.log $test_dir/testd.log

	# diff the server's output log
	if ! make -s -C $test_dir diff; then
		printf "%3s %s: $red%s$reset\n" $count $test_dir "diff failed"
		diff_failed=$((diff_failed + 1))
		continue
	fi

	make -s -C $test_dir clean
	printf "%3s %s: $green%s$reset\n" $count $test_dir "ok"
	ok=$((ok + 1))
done

kill $testd_pid
kill $server_pid
wait 2>/dev/null
rm testd.log
rm server.log

printf "\n%i ok, %i test + %i diff fail " $ok $test_failed $diff_failed
printf "(%i min %i sec)\n" $((SECONDS / 60)) $((SECONDS % 60))

exit $failed;
