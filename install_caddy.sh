#!/bin/bash

echo -e "Please type full qualified domain name for this server"
read -e FQDN

echo -e "Please type host"
read -e hostname

echo -e "Please type username"
read -e username

echo -e "Please type password"
read -e password

echo -e "Please type email"
read -e email

curl https://getcaddy.com | bash -s personal hook.service,http.cache,http.datadog,http.geoip,http.login,http.minify,http.nobots,http.ratelimit

chown www-data:www-data /usr/local/bin/caddy

# config
mkdir /etc/caddy
chown -R root:www-data /etc/caddy

rm -rf /var/www/html/*

cat << EOF > /etc/caddy/Caddyfile
${FQDN}/monit {
	gzip
	log /var/log/caddy/access.log
	proxy / localhost:2812
	tls ${email}
	basicauth / ${username} ${password}
	datadog {
    		statsd 127.0.0.1:8125
			tags loc:${hostname} usecase:masternode role:monit
  	}
}
${FQDN} {
	gzip
	log /var/log/caddy/access.log
	root /var/www/html
	tls ${email}
	basicauth / ${username} ${password}
	datadog {
    		statsd 127.0.0.1:8125
			tags loc:${hostname} usecase:masternode role:monit
  	}      
}
EOF

# ssl
mkdir /etc/ssl/caddy
chown -R www-data /etc/ssl/caddy
chmod 0770 /etc/ssl/caddy

# log
mkdir /var/log/caddy
chown -R www-data /var/log/caddy
chmod 0770 /var/log/caddy

# firewall
ufw allow http
ufw allow https

# service unit file
curl -s https://raw.githubusercontent.com/mholt/caddy/master/dist/init/linux-systemd/caddy.service -o /etc/systemd/system/caddy.service

systemctl daemon-reload
systemctl enable caddy
systemctl start caddy
systemctl status caddy