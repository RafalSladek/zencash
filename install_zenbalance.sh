cat << EOF >> /usr/local/bin/zenbalance
#!/bin/bash
COINUSER=zen
sudo -u '$COINUSER' -H sh -c "zen-cli z_gettotalbalance"
EOF

chmod +x /usr/local/bin/zenbalance

zenbalance
