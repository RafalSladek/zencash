#!/bin/bash
echo "* * * * * /usr/local/bin/zenstatus > /var/www/html/zenstatus.json >/dev/null 2>&1" >> /var/spool/cron/crontabs/root

sudo crontab -l
sudo crontab -e