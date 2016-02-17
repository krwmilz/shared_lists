#!/bin/sh

json_str='{"msg_type":"updated_list","payload":{},"devices":[["not_ios","hex"],["android","some_token"]]}'

echo "$json_str" | nc -U ../apnd.socket -
