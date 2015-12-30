test:
	perl test.pl

process-server-log:
	# remove header, phone numbers, base64 and strings from server.log
	sed -i  -e "s/.*> //" \
		-e "s/'[0-9]*'/<digits>/g" \
		-e "s/'[a-zA-Z0-9/+]*'/<base64>/g" \
		-e "s/'[a-zA-Z0-9 ]*'/<string>/g" \
		-e 's/[0-9]\.[0-9]\.[0-9]\.[0-9]:[0-9]*/<ip>:<port>/' \
		server.log

ifndef DIFF_MOD
diff: process-server-log
	diff -u server.log.good server.log
else
diff: process-server-log
	sort -o server.log < server.log
	diff -u server.log.good server.log
endif

clean:
	rm -f server.log
