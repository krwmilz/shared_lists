#!/bin/sh

protocol_version=0
msg_types="
	new_device
	add_friend
	new_list
	join_list
	leave_list
	list_get
	list_get_other
	list_items
	new_list_item
	ok
"

objc_path="ios/shlist/MsgTypes.h"
perl_path="msgs.pl"
java_path="android/shlist/app/src/main/java/drsocto/shlist/MsgTypes.java"

generated_at="generated `date`"

# enumerate messages and make a table
print_table() {
	# print header
	echo "${2}" >> ${1}

	i=0
	for msg in $msg_types; do
		eval "echo \"\t$3\"" >> ${1}
		i=$((i + 1))
	done

	# print footer
	echo "${4}" >> ${1}
}

gen_objc() {
	cat << EOF > $objc_path
/* ${generated_at} */"

int protocol_version = $protocol_version;
EOF

	print_table $objc_path "enum msg_types {" "\$msg = \$i," "};"
}

gen_java() {
	cat << EOF > $java_path
/* ${generated_at} */

int protocol_version = $protocol_version;
EOF

	print_table $java_path "public enum MsgTypes {" "\$msg\t(\$i)," "};"
}

gen_perl() {
	cat << EOF > $perl_path
#!/usr/bin/perl
# ${generated_at}
use strict;
use warnings;

our \$protocol_ver = $protocol_version;
EOF
	print_table $perl_path "our %msg_num = (" "\$msg => \$i," ");"
	print_table $perl_path "our @msg_str = (" "'\$msg'," ");"
	print_table $perl_path "our @msg_func = (" "\\&msg_\$msg," ");"
}

gen_objc
gen_java
gen_perl
