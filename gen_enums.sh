#!/bin/sh

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
PERL_PATH="MsgTypes.pm"
JAVA_PATH="android/shlist/app/src/main/java/drsocto/shlist/MsgTypes.java"
SHELL_PATH="tests/net_enums.sh"

WARN_HEADER="GENERaTED @ $(date) BY ${0}"

# Objective C message type header for ios
cat << EOF > $OBJC_PATH
/* ${WARN_HEADER} */"

enum MSG_TYPES {
EOF

# Java message enumerations for android
cat << EOF > $JAVA_PATH
/* ${WARN_HEADER} */

public enum MsgTypes {
EOF

# Perl source file constants for the server and test suite
cat << EOF > $PERL_PATH
package MsgTypes;
# ${WARN_HEADER}
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(%msgs);

our %msgs = (
EOF

# shell constants for test suite use
cat << EOF > $SHELL_PATH
#!/bin/sh
# $WARN_HEADER

EOF

i=0
for msg in $MSG_TYPES; do
	echo -e "\t$msg = $i," >> $OBJC_PATH
	echo -e "\t$msg\t(${i})," >> $JAVA_PATH
	echo "\t$msg => $i," >> $PERL_PATH
	echo "\t$i => \"$msg\"," >> $PERL_PATH
	echo "export $msg=00$(printf "%02x" $i)" >> $SHELL_PATH

	i=$((i + 1))
done

echo "};" >> $OBJC_PATH
echo "};" >> $JAVA_PATH
echo ");" >> $PERL_PATH

echo "my @msg_handlers = (" >> $PERL_PATH
i=0
for msg in $MSG_TYPES; do
	echo "\t\&msg_$msg," >> $PERL_PATH

	i=$((i + 1))
done
echo ");" >> $PERL_PATH
