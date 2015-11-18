#!/bin/sh

PROTOCOL_VERSION=0
MSG_TYPES="new_device
	new_list
	add_friend
	list_request
	join_list
	leave_list
	list_items
	new_list_item
	ok"

OBJC_PATH="ios/shlist/MsgTypes.h"
PERL_PATH="msgs.pm"
JAVA_PATH="android/shlist/app/src/main/java/drsocto/shlist/MsgTypes.java"
SHELL_PATH="tests/msgs.sh"

GENERATED_AT="generated @ `date`"

gen_objc() {
	# Objective C message type header for ios
	cat << EOF > $OBJC_PATH
/* ${GENERATED_AT} */"

int protocol_version = $PROTOCOL_VERSION;
enum MSG_TYPES {
EOF
	i=0
	for msg in $MSG_TYPES; do
		echo -e "\t$msg = $i," >> $OBJC_PATH
		i=$((i + 1))
	done
	echo "};" >> $OBJC_PATH
}

gen_java() {
	# Java message enumerations for android
	cat << EOF > $JAVA_PATH
/* ${GENERATED_AT} */

int protocol_version = $PROTOCOL_VERSION;
public enum MsgTypes {
EOF
	i=0
	for msg in $MSG_TYPES; do
		echo -e "\t$msg\t(${i})," >> $JAVA_PATH
		i=$((i + 1))
	done
	echo "};" >> $JAVA_PATH
}

gen_perl() {
	# Perl source file constants for the server and test suite
	cat << EOF > $PERL_PATH
# ${GENERATED_AT}
package msgs;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(%msgs \$protocol_version);

our \$protocol_version = $PROTOCOL_VERSION;
our %msgs = (
EOF
	i=0
	for msg in $MSG_TYPES; do
		echo "\t$msg => $i," >> $PERL_PATH
		echo "\t$i => \"$msg\"," >> $PERL_PATH
		i=$((i + 1))
	done
	echo ");" >> $PERL_PATH

	# echo "my @msg_handlers = (" >> $PERL_PATH
	# i=0
	# for msg in $MSG_TYPES; do
	# 	echo "\t\&msg_$msg," >> $PERL_PATH

	# 	i=$((i + 1))
	# done
	# echo ");" >> $PERL_PATH
}

gen_shell() {
	# shell constants for test suite use
	cat << EOF > $SHELL_PATH
#!/bin/sh
# $GENERATED_AT

PROTOCOL_VERSION=$PROTOCOL_VERSION
EOF
	i=0
	for msg in $MSG_TYPES; do
		echo "export $msg=00$(printf "%02x" $i)" >> $SHELL_PATH
		i=$((i + 1))
	done
}

gen_objc
gen_java
gen_perl
gen_shell
