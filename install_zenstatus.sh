cat << EOF >> /usr/local/bin/zenstatus
#!/bin/bash
COINUSER=zen
PUBLIC_IP=$(curl -s ipecho.net/plain)
sudo -u $COINUSER -H sh -c "echo '{ \"timestamp\": \"`date`\", \"details\": ['; zen-cli goldminenode status; echo ','; zen-cli getinfo; echo ','; echo ']}'"
EOF

chmod +x /usr/local/bin/zenstatus

zenstatus