diff:
	# remove header, phone numbers and base64 strings from server.log
	sed -i -e "s/.*: //" -e "s/'[0-9]*'/<phone_num>/g" \
		-e "s/'[a-zA-Z0-9/+]*'/<base64>/g" \
		server.log
	diff -u server.log.good server.log

clean:
	rm -f server.log
