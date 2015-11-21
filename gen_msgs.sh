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

GENERATED_AT="generated `date`"

# enumerate messages and make a table
print_table() {
	# print header
	echo "${2}" >> ${1}

	i=0
	for msg in $MSG_TYPES; do
		eval "echo \"$3\"" >> ${1}
		i=$((i + 1))
	done

	# print footer
	echo "${4}" >> ${1}
}

# ios
gen_objc() {
	cat << EOF > $OBJC_PATH
/* ${GENERATED_AT} */"

int protocol_version = $PROTOCOL_VERSION;
EOF

	print_table $OBJC_PATH "enum MSG_TYPES {" "\t\$msg = \$i," "};"
}

# android
gen_java() {
	cat << EOF > $JAVA_PATH
/* ${GENERATED_AT} */

int protocol_version = $PROTOCOL_VERSION;
EOF

	print_table $JAVA_PATH "public enum MsgTypes {" "\t\$msg\t(\$i)," "};"
}

# server and test suite
gen_perl() {
	cat << EOF > $PERL_PATH
# ${GENERATED_AT}
package msgs;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(%msg_num @msg_str @msg_func \$protocol_version);

our \$protocol_version = $PROTOCOL_VERSION;
EOF
	print_table $PERL_PATH "our %msg_num = (" "\t\$msg => \$i," ");"
	print_table $PERL_PATH "our @msg_str = (" "\t'\$msg'," ");"
	print_table $PERL_PATH "our @msg_func = (" "\t\\&msg_\$msg," ");"
}

gen_objc
gen_java
gen_perl
