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

ifeq ($(DIFF_MOD), none)
diff:
	rm -f server.log
else ifeq ($(DIFF_MOD), sort)
diff: process-server-log
	LC_ALL=C sort -o server.log < server.log
	diff -u server.log.good server.log
else
diff: process-server-log
	diff -u server.log.good server.log
endif

clean:
	rm -f server.log
