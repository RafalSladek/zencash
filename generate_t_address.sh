#!/bin/bash

echo "Generate t_address..."
zen-cli getnewaddress > /dev/null && zen-cli listaddresses | jq -r '.[1]'

zen-cli z_gettotalbalance