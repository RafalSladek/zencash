#!/bin/bash

echo "Generate t_address..."
COINUSER=zen
sudo -u $COINUSER -H sh -c "zen-cli getnewaddress > /dev/null && zen-cli listaddresses | jq -r '.[1]'"