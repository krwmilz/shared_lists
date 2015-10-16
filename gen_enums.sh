#!/bin/sh

MSG_TYPES="msg_new_device msg_new_list msg_update_friends msg_list_request"
MSG_TYPES="${MSG_TYPES} msg_join_list msg_leave_list msg_list_items"
MSG_TYPES="${MSG_TYPES} msg_new_list_item"

WARN_HEADER="GENERaTED @ $(date) BY ${0}"

OBJC_PATH="ios/shlist/MsgTypes.h"
PERL_PATH="msg_types.pl"
JAVA_PATH="android/shlist/app/src/main/java/drsocto/shlist/MsgTypes.java"
TEST_PATH="tests/net_enums.sh"

# Objective C message type header for ios
echo "/* ${WARN_HEADER} */" > $OBJC_PATH
echo "" >> $OBJC_PATH
echo "enum MSG_TYPES {" >> $OBJC_PATH
i=0
for msg in $MSG_TYPES; do
	echo -e "\t$msg = $i," >> $OBJC_PATH
	i=$((i + 1))
done
echo "};" >> $OBJC_PATH

# Perl source file constants for the server
echo "#!/usr/bin/env perl -w" > $PERL_PATH
echo "# ${WARN_HEADER}" >> $PERL_PATH
echo "" >> $PERL_PATH
echo "my @msg_handlers = (" >> $PERL_PATH
for msg in $MSG_TYPES; do
	echo "\t\\&$msg," >> $PERL_PATH
done
echo ");" >> $PERL_PATH

# Java message enumerations for android
echo "/* ${WARN_HEADER} */ " > $JAVA_PATH
echo "" >> $JAVA_PATH
echo "public enum MsgTypes {" >> $JAVA_PATH
i=0
for msg in $MSG_TYPES; do
	echo -e "\t$msg\t(${i})," >> $JAVA_PATH
	i=$((i + 1))
done
echo "};" >> $JAVA_PATH

# shell constants for test suite use
echo "#!/bin/sh" > $TEST_PATH
echo "# $WARN_HEADER" >> $TEST_PATH
echo "" >> $TEST_PATH

i=0
for msg in $MSG_TYPES; do
	hex_bytes=$(printf "%02x" $i)
	echo "export $msg=00$hex_bytes" >> $TEST_PATH
	i=$((i + 1))
done
