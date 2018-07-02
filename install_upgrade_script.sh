#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

cat <<EOF > ~/upgrade_script.sh
#!/bin/bash
sudo apt update
sudo apt -y dist-upgrade
sudo apt -y autoremove
sudo rkhunter --propupd
EOF

chmod u+x ~/upgrade_script.sh