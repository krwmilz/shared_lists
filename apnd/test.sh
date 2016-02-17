#!/bin/sh

hex_token="DE2D368BB6C80E1D8BCB86D20CB6C2161BD5CEC5BA35A1E1AA0DB382849ED9B2"
json_str="{\"msg_type\":\"updated_list\",\"payload\":{},\"devices\":[[\"ios\",\"$hex_token\"]]}"

echo "$json_str" | nc -U ../apnd.socket -
