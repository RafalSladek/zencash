#!/bin/bash


DEFAULTCOINUSER="zen"
COINHOME=/home/$DEFAULTCOINUSER
COINUSER=$DEFAULTCOINUSER
COINTITLE="Zen"
COINDAEMON="zend"
COINCLI="zen-cli"

cat <<EOF > /etc/systemd/system/zentracker.service
[Unit]
Description=$COINTITLE node daemon installed on $COINHOME/zencash/secnodetracker/
Requires=$COINUSER.service
After=$COINUSER.service
 
[Service]
User=$COINUSER
Group=$COINUSER
Type=simple
WorkingDirectory=$COINHOME/zencash/secnodetracker/
ExecStart=/usr/local/bin/node $COINHOME/zencash/secnodetracker/app.js
Restart=always
RestartSec=10
 
[Install]
WantedBy=multi-user.target
EOF