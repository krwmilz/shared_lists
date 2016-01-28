#!/bin/sh

protocol_version=0
msg_types="
	device_add
	device_update
	friend_add
	friend_delete
	list_add
	list_update
	list_join
	list_leave
	lists_get
	lists_get_other
	list_items_get
	list_item_add
"

objc_path="ios/shlist/MsgTypes.h"
java_path="android/shlist/app/src/main/java/drsocto/shlist/MsgTypes.java"
perl_path="server/msgs.pl"
test_path="server/tests/msgs.pl"

generated_at="generated `date`"

# Helper function to enumerate messages and make tables
# arg 1: path to output file
# arg 2: array/list/hash/whatever declaration
# arg 3: a string that's interpreted in the loop below, like "$msg => $i"
# arg 4: closing parenthesis/curly braces/whatever
print_table() {
	echo "${2}" >> ${1}

	i=0
	for msg in $msg_types; do
		eval "echo \"	$3\"" >> ${1}
		i=$((i + 1))
	done

	# print footer
	echo "${4}" >> ${1}
}

gen_objc() {
	cat << EOF > $objc_path
/* ${generated_at} */

int protocol_version = $protocol_version;
EOF

	print_table $objc_path "enum msg_types {" "\$msg = \$i," "};"
}

gen_java() {
	cat << EOF > $java_path
/* ${generated_at} */

package drsocto.shlist;

public final class MsgTypes {

	public final static int protocol_version = $protocol_version;
EOF

	print_table $java_path "" "public final static int \$msg = \$i;" "}"
}

gen_perl() {
	cat << EOF > $perl_path
#!/usr/bin/perl
# ${generated_at}
use strict;
use warnings;

our \$protocol_ver = $protocol_version;
EOF

	# We want message name to number map, number to name array, and function
	# pointer array
	print_table $perl_path "our %msg_num = ("  "\$msg => \$i," ");"
	print_table $perl_path "our @msg_str = ("  "'\$msg',"      ");"
	print_table $perl_path "our @msg_func = (" "\\&msg_\$msg," ");"

	cp $perl_path $test_path
}

gen_objc
gen_java
gen_perl
