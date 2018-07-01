#!/bin/bash

#set -exuo pipefail

DEFAULTCOINUSER="zen"
COINHOME=$DEFAULTCOINUSER
DEFAULTCOINPORT=9033
DEFAULTRPCPORT=18231
DEFAULTORGANAME="zen"

COINTITLE="Zen"
COINDAEMON="zend"
COINCLI="zen-cli"
CONFIG_FILE="zen.conf"
COIN_REPO="https://github.com/ArcticCore/arcticcoin.git"
COINDAEMON_VERSION="0.12.2"
COINDAEMON_ZIPFILE="${DEFAULTORGANAME}-${COINDAEMON_VERSION}-linux64.tar.gz"
COINDAEMON_ZIPURL="https://github.com/ArcticCore/arcticcoin/releases/download/v0.12.1.2/${COINDAEMON_ZIPFILE}"
FQDN=zen1.crypto-pool.net

TMP_FOLDER=$(mktemp -d)
BIN_TARGET="/usr/local/bin"
BINARY_FILE="${BIN_TARGET}/${COINDAEMON}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $COINDAEMON)" ]; then
  echo -e "${GREEN}\c"
  read -e -p "$COINDAEMON is already running. Do you want to add another MN? [Y/N]" NEW_COIN
  echo -e "{NC}"
  clear
else
  NEW_COIN="new"
fi
}

function prepare_system() {

echo -e "Prepare the system to install $COINTITLE master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1

echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make  \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl monit libdb4.8-dev bsdmainutils \
libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw automake libevent-dev libzmq3-dev \
apt-transport-https lsb-release dirmngr ssl-cert jq npm 


if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make  \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl monit libdb4.8-dev bsdmainutils \
libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw automake libevent-dev libzmq3-dev \
apt-transport-https lsb-release dirmngr ssl-cert jq npm"
 exit 1
fi


echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(swapon -s)
if [[ "$PHYMEM" -lt "6" && -z "$SWAP" ]];
  then
    echo -e "${GREEN}Server is running with less than 6G of RAM, creating 6G swap file.${NC}"
    dd if=/dev/zero of=/swapfile bs=1024 count=6M
    chmod 600 /swapfile
    mkswap /swapfile
    swapon -a /swapfile
else
  echo -e "${GREEN}The server running with at least 6G of RAM, or SWAP exists.${NC}"
fi
}

function deploy_binaries() {
echo -e "${GREEN}Adding zencash PPA repository"
echo 'deb https://zencashofficial.github.io/repo/ '$(lsb_release -cs)' main' | sudo tee --append /etc/apt/sources.list.d/zen.list
gpg --keyserver ha.pool.sks-keyservers.net --recv 219F55740BBF7A1CE368BA45FB7053CE4991B669
gpg --keyserver keyserver.ubuntu.com  --recv 219F55740BBF7A1CE368BA45FB7053CE4991B669

echo -e "${GREEN}Adding certbot PPA repository"
add-apt-repository ppa:certbot/certbot -y
apt install -y zen certbot
sudo -H -u $COINUSER bash -c 'zen-fetch-params' 
sudo -H -u $COINUSER bash -c 'zend' 
}

function ask_permission() {
 echo -e "${RED}I trust you and want to use binaries compiled on your server.${NC}."
 echo -e "Please type ${RED}YES${NC} if you want to use precompiled binaries, or type anything else to compile them on your server"
 read -e ALREADYCOMPILED
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow incomning access on port ${GREEN}$COINPORT${NC}"
  ufw allow $COINPORT/tcp comment "$COINTITLE MN port" >/dev/null
  ufw allow ssh >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  ufw default deny incoming >/dev/null 2>&1
  ufw allow http/tcp >/dev/null 2>&1
  ufw allow https/tcp >/dev/null 2>&1
  ufw logging on >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

function systemd_install() {
  cat << EOF > /etc/systemd/system/$COINUSER.service
[Unit]
Description=$COINTITLE service
After=network.target

[Service]

Type=forking
User=$COINUSER
Group=$COINUSER
WorkingDirectory=$COINHOME
ExecStart=$BIN_TARGET/$COINDAEMON -daemon
ExecStop=$BIN_TARGET/$COINCLI stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
  
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COINUSER.service
  systemctl enable $COINUSER.service >/dev/null 2>&1

  if [[ -z $(pidof $COINDAEMON) ]]; then
    echo -e "${RED}Arcticcoind is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo "systemctl start $COINUSER.service"
    echo "systemctl status $COINUSER.service"
    echo "less /var/log/syslog"
    exit 1
  fi
}

function ask_port() {
read -p "$COINTITLE Port: " -i $DEFAULTCOINPORT -e COINPORT
: ${COINPORT:=$DEFAULTCOINPORT}
}

function ask_user() {
  read -p "$COINTITLE user: " -i $DEFAULTCOINUSER -e COINUSER
  : ${COINUSER:=$DEFAULTCOINUSER}

  if [ -z "$(getent passwd $COINUSER)" ]; then
    useradd -m $COINUSER
    usermode -aG adm,systemd-journal,sudo $COINUSER
    COINHOME=$(sudo -H -u $COINUSER bash -c 'echo $HOME')
    DEFAULTCOINFOLDER="${COINHOME}/.${DEFAULTORGANAME}"
    read -p "Configuration folder: " -i $DEFAULTCOINFOLDER -e COINFOLDER
    : ${COINFOLDER:=$DEFAULTCOINFOLDER}
    mkdir -p $COINFOLDER
    chown -R $COINUSER: $COINFOLDER >/dev/null
    echo "export FQDN=$FQDN" >> $COINHOME/.bashrc
    USERPASS=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w12 | head -n1)
    echo "$COINUSER:$USERPASS" | chpasswd
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $COINPORT ]] || [[ ${PORTS[@]} =~ $[COINPORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $COINFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$DEFAULTRPCPORT
rpcworkqueue=512
server=1
daemon=1
listen=1
txindex=1
logtimestamps=1
### testnet config
#testnet=1
EOF
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "$COINTITLE Masternode is up and running as user ${GREEN}$COINUSER${NC} and it is listening on port ${GREEN}$COINPORT${NC}."
 echo -e "${GREEN}$COINUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$COINFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $COINUSER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $COINUSER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$COINPORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$COINKEY${NC}"
 echo -e "================================================================================================================================"
}

function fail2ban() {
sudo apt install -y fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl restart fail2ban.service
}

function monit() {
 echo -e "Please type email for notifications"
 read -e EMAIL
  cat << EOF >> /etc/monit/monitrc
set alert ${EMAIL}
set httpd port 2812
  use address localhost
  allow localhost
EOF

  cat << EOF > /etc/monit/monitrc.d/fail2ban
check process fail2ban with pidfile /var/run/fail2ban/fail2ban.pid
    group services
    start program = "/etc/init.d/fail2ban force-start"
    stop  program = "/etc/init.d/fail2ban stop || :"
    if failed unixsocket /var/run/fail2ban/fail2ban.sock then restart
    if 5 restarts within 5 cycles then timeout

check file fail2ban_log with path /var/log/fail2ban.log
    if match "ERROR|WARNING" then alert
EOF

ln -s /etc/monit/monitrc.d/fail2ban /etc/monit/conf-enabled/fail2ban
ln -s /etc/monit/conf-available/cron /etc/monit/conf-enabled/cron
ln -s /etc/monit/conf-available/openssh-server /etc/monit/conf-enabled/openssh-server


monit reload
monit -t
monit start all
}

function motd() {
  cat << EOF > /etc/update-motd.d/99-${DEFAULTCOINUSER}
#!/bin/bash
printf "\n${COINCLI} goldminenode status\n"
sudo -u $COINUSER $BIN_TARGET/$COINCLI -conf=$COINFOLDER/$CONFIG_FILE -datadir=$COINFOLDER goldminenode status
printf "\n"
EOF
chmod +x /etc/update-motd.d/99-${DEFAULTCOINUSER}
}

function challange_test() {
  ${COINCLI} zcbenchmark createjoinsplit 1
}

function secure_sshd(){
sed -i  "s/.*PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config &&\
sed -i  "s/.*PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config &&\
sed -i  "s/.*ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/g" /etc/ssh/sshd_config
systemctl restart sshd
}

function request_cert(){
  certbot certonly -n --agree-tos --register-unsafely-without-email --standalone -d $FQDN
  cp /etc/letsencrypt/live/$FQDN/chain.pem /usr/local/share/ca-certificates/chain.crt
  update-ca-certificates
  echo "tlscertpath=/etc/letsencrypt/live/$FQDN/cert.pem" >> ~/.zen/zen.conf
  echo "tlskeypath=/etc/letsencrypt/live/$FQDN/privkey.pem" >> ~/.zen/zen.conf
  usermode -aG ssl-cert $COINUSER
  chown -R root:ssl-cert /etc/letsencrypt/
  chmod -R 750 /etc/letsencrypt/
  systemctl stop $COINUSER.service
  sleep 3
  systemctl start $COINUSER.service
  $COINCLI getnetworkinfo
}

function setup_node() {
  ask_user
  check_port
  create_config
  enable_firewall
  secure_sshd
  systemd_install
  request_cert
  important_information
  fail2ban
  monit
  motd
  challange_test
}


##### Main #####
clear

checks
if [[ ("$NEW_COIN" == "y" || "$NEW_COIN" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_COIN" == "new" ]]; then
  prepare_system
  ask_permission
  if [[ "$ALREADYCOMPILED" == "YES" ]]; then
    deploy_binaries
  else
    compile_arcticcoin
  fi
  setup_node
else
  echo -e "${GREEN}$COINDAEMON already running.${NC}"
  exit 0
fi
