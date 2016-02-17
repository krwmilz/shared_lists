#!/bin/sh

# Try not to connect to a production instance with this script!
export PORT=5899

if [ `uname` = "OpenBSD" ]; then
	alias make=gmake
fi

# Start server with Devel::Cover module loaded
perl -MDevel::Cover sl -p $PORT -t &
server_pid=$!

perl testd &
testd_pid=$!

passed=0
failed=0
count=0
for t in `ls tests/*/Makefile`; do
	count=`expr $count + 1`
	test_dir=`dirname ${t}`

	if ! make -s -C $test_dir test; then
		printf ">>> %3s %s: test failed\n" $count $test_dir
		failed=`expr $failed + 1`
		continue
	fi

	printf ">>> %3s %s: ok\n" $count $test_dir
	passed=`expr $passed + 1`
done

# Kill the server to flush all coverage data
kill $testd_pid
kill $server_pid
wait

sleep 1

printf ">>> %i ok %i failed " $passed $failed
printf "(%i min %i sec)\n" $((SECONDS / 60)) $((SECONDS % 60))

# Run Devel::Cover tool to post process coverage data
cover
