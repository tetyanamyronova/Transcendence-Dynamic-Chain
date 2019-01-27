#/bin/bash
cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
IP4COUNT=$(find /root/.transcendence_* -maxdepth 0 -type d | wc -l)
DELETED="$(cat /root/bin/deleted | wc -l)"
ALIASES="$(find /root/.transcendence_* -maxdepth 0 -type d | cut -c22-)"
face="$(lshw -C network | grep "logical name:" | sed -e 's/logical name:/logical name: /g' | awk '{print $3}' | head -n1)"
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
function configure_systemd() {
  cat << EOF > /etc/systemd/system/transcendenced$ALIAS.service
[Unit]
Description=transcendenced$ALIAS service
After=network.target
 [Service]
User=root
Group=root
Type=forking
#PIDFile=/root/.transcendence_$ALIAS/transcendenced.pid
ExecStart=/root/bin/transcendenced_$ALIAS.sh
ExecStop=/root/bin/transcendence-cli_$ALIAS.sh stop
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
  sleep 6
  crontab -l > cron$ALIAS
  echo "@reboot systemctl start transcendenced$ALIAS" >> cron$ALIAS
  crontab cron$ALIAS
  rm cron$ALIAS
  systemctl start transcendenced$ALIAS.service
}
IP4=$(curl -s4 api.ipify.org)
perl -i -ne 'print if ! $a{$_}++' /etc/network/interfaces
if [ ! -f "/usr/local/bin/transcendenced" ]; then
 DOSETUP="y"
else
 DOSETUP="n"
fi
clear
if [ -f "/usr/local/bin/transcendenced" ]
then
if [ ! -f "/root/bin/v1.1.0.0c" ]
then
echo -e "${GREEN}Please wait, updating wallet.${NC}"
sleep 2
rm /usr/local/bin/transcendence*
wget https://github.com/phoenixkonsole/transcendence/releases/download/v1.1.0.0c/Linux.zip -O /root/Linux.zip 
unzip Linux.zip -d /usr/local/bin 
chmod +x /usr/local/bin/transcendence*
rm Linux.zip
touch /root/bin/v1.1.0.0c
echo -e "${GREEN}Wallet updated. Please restart your nodes or reboot your VPS when possible.${NC}"
echo ""
fi
fi
echo -e "${RED}This script is not compatbile with older versions of it by default. Use it on a fresh VPS or disable bind manually to enable backwards compatibility.${NC}"
echo ""
echo "1 - Create new nodes"
echo "2 - Remove an existing node"
echo "3 - List aliases"
echo "4 - Check for node errors"
echo "What would you like to do?"
read DO
echo ""

if [ $DO = "4" ]
then
echo $ALIASES > temp1
cat temp1 | grep -o '[^ |]*' > temp2
CN="$(cat temp2 | wc -l)"
rm temp1
let LOOP=0
while [  $LOOP -lt $CN ]; do
LOOP=$((LOOP+1))
CURRENT="$(sed -n "${LOOP}p" temp2)"
echo -e "${GREEN}${CURRENT}${NC}:"
sh /root/bin/transcendence-cli_${CURRENT}.sh masternode status | grep "message"
OFFSET="$(sh /root/bin/transcendence-cli_${CURRENT}.sh getinfo | grep "timeoffset")"
OFF1=${OFFSET:(-2)}
OFF=${OFF1:0:1}
if [ $OFF = "1" ]
then
echo "$OFFSET" 
fi
done
rm temp2
fi
if [ $DO = "3" ]
then
echo -e "${GREEN}${ALIASES}${NC}"
echo ""
echo "1 - Create new nodes"
echo "2 - Remove an existing node"
echo "What would you like to do?"
read DO
echo ""
fi
if [ $DO = "2" ]
then
perl -i -ne 'print if ! $a{$_}++' /etc/monit/monitrc >/dev/null 2>&1
echo "Input the alias of the node that you want to delete"
read ALIASD
echo ""
echo -e "${GREEN}Deleting ${ALIASD}${NC}. Please wait."
## Removing service
systemctl stop transcendenced$ALIASD >/dev/null 2>&1
systemctl disable transcendenced$ALIASD >/dev/null 2>&1
rm /etc/systemd/system/transcendenced${ALIASD}.service >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
systemctl reset-failed >/dev/null 2>&1
## Removing monit and directory
rm /root/.transcendence_$ALIASD -r >/dev/null 2>&1
sed -i "/${ALIASD}/d" .bashrc
crontab -l -u root | grep -v transcendenced$ALIASD | crontab -u root - >/dev/null 2>&1
source .bashrc
echo "1" >> /root/bin/deleted
echo -e "${ALIASD} Successfully deleted."
fi
if [ $DO = "1" ]
then
echo "1 - Easy mode"
echo "2 - Expert mode"
echo "Please select a option:"
read EE
echo ""
if [ $EE = "1" ] 
then
MAXC="64"
fi
if [ $EE = "2" ] 
then
echo ""
echo "Enter max connections value"
read MAXC
fi
if [ $DOSETUP = "y" ]
then
  echo -e "Installing ${GREEN}Transcendence dependencies${NC}. Please wait."
  apt-get update 
  apt-get -y upgrade
  apt-get -y dist-upgrade
  apt-get update
  apt-get install -y zip unzip bc curl nano lshw gawk
  echo -e "${RED}Creating swap. This may take a while.${NC}"
  dd if=/dev/zero of=/var/swap.img bs=2048 count=1M
  chmod 600 /var/swap.img
  mkswap /var/swap.img 
  swapon /var/swap.img 
  free -m
  echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
  cd /root 
 if [ ! -f Linux.zip ]
  then
  wget https://github.com/phoenixkonsole/transcendence/releases/download/v1.1.0.0/Linux.zip -O /root/Linux.zip
  touch /root/bin/v1.1.0.0c
 fi
  unzip Linux.zip -d /usr/local/bin 
  chmod +x /usr/local/bin/transcendence*
  rm Linux.zip
  apt-get install -y ufw 
  ufw allow ssh/tcp 
  ufw limit ssh/tcp 
  ufw logging on
  echo "y" | ufw enable 
  ufw allow 22123
  mkdir -p ~/bin 
  echo 'export PATH=~/bin:$PATH' > ~/.bash_aliases
  source ~/.bashrc
  echo ""
  cd
  sysctl vm.swappiness=10
  sysctl vm.vfs_cache_pressure=200
  echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure=200' | tee -a /etc/sysctl.conf
fi
if [ ! -f Bootstrap.zip ]
then
wget https://aeros-os.org/Bootstrap1.zip -O /root/Bootstrap.zip
fi
gateway1=$(/sbin/route -A inet6 | grep -v ^fe80 | grep -v ^ff00 | grep -w "$face")
gateway2=${gateway1:0:26}
gateway3="$(echo -e "${gateway2}" | tr -d '[:space:]')"
if [[ $gateway3 = *"128"* ]]; then
  gateway=${gateway3::-5}
fi
if [[ $gateway3 = *"64"* ]]; then
  gateway=${gateway3::-3}
fi
MASK="/64"
echo -e "Telos nodes currently installed: ${GREEN}${IP4COUNT}${NC}, Telos nodes previously Deleted: ${GREEN}${DELETED}${NC}"
echo ""
if [ $IP4COUNT = "0" ] 
then
echo -e "${RED}First node must be ipv4.${NC}"
let COUNTER=0
PORT=22123
RPCPORTT=22130
RPCPORT=$(($RPCPORTT+$COUNTER))
  echo ""
  echo "Enter alias for first node"
  read ALIAS
  CONF_DIR=~/.transcendence_$ALIAS
  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY
  if [ $EE = "2" ] 
	then
	echo ""
	echo "Enter port for $ALIAS"
	read PORTD
  fi
  mkdir ~/.transcendence_$ALIAS
  unzip Bootstrap.zip -d ~/.transcendence_$ALIAS >/dev/null 2>&1
  echo '#!/bin/bash' > ~/bin/transcendenced_$ALIAS.sh
  echo "transcendenced -daemon -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> ~/bin/transcendenced_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/transcendence-cli_$ALIAS.sh
  echo "transcendence-cli -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> ~/bin/transcendence-cli_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/transcendence-tx_$ALIAS.sh
  echo "transcendence-tx -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> ~/bin/transcendence-tx_$ALIAS.sh
  chmod 755 ~/bin/transcendence*.sh
  mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> transcendence.conf_TEMP
  echo "rpcport=$RPCPORT" >> transcendence.conf_TEMP
  echo "listen=1" >> transcendence.conf_TEMP
  echo "server=1" >> transcendence.conf_TEMP
  echo "daemon=1" >> transcendence.conf_TEMP
  echo "logtimestamps=1" >> transcendence.conf_TEMP
  echo "maxconnections=$MAXC" >> transcendence.conf_TEMP
  echo "masternode=1" >> transcendence.conf_TEMP
  echo "dbcache=20" >> transcendence.conf_TEMP
  echo "maxorphantx=5" >> transcendence.conf_TEMP
  echo "maxmempool=100" >> transcendence.conf_TEMP
  echo "" >> transcendence.conf_TEMP
  echo "" >> transcendence.conf_TEMP
  echo "bind=$IP4:$PORT" >> transcendence.conf_TEMP
  echo "externalip=$IP4" >> transcendence.conf_TEMP
  echo "masternodeaddr=$IP4:$PORT" >> transcendence.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> transcendence.conf_TEMP
  

  mv transcendence.conf_TEMP $CONF_DIR/transcendence.conf
  echo ""
  echo -e "Your ip is ${GREEN}$IP4:$PORT${NC}"
	echo "alias ${ALIAS}_status=\"transcendence-cli -datadir=/root/.transcendence_${ALIAS} masternode status\"" >> .bashrc
	echo "alias ${ALIAS}_stop=\"systemctl stop transcendenced$ALIAS\"" >> .bashrc
	echo "alias ${ALIAS}_start=\"systemctl start transcendenced$ALIAS\""  >> .bashrc
	echo "alias ${ALIAS}_config=\"nano /root/.transcendence_${ALIAS}/transcendence.conf\""  >> .bashrc
	echo "alias ${ALIAS}_getinfo=\"transcendence-cli -datadir=/root/.transcendence_${ALIAS} getinfo\"" >> .bashrc
    	echo "alias ${ALIAS}_getpeerinfo=\"transcendence-cli -datadir=/root/.transcendence_${ALIAS} getpeerinfo\"" >> .bashrc
	echo "alias ${ALIAS}_resync=\"/root/bin/transcendenced_${ALIAS}.sh -resync\"" >> .bashrc
	echo "alias ${ALIAS}_reindex=\"/root/bin/transcendenced_${ALIAS}.sh -reindex\"" >> .bashrc
	echo "alias ${ALIAS}_restart=\"systemctl restart transcendenced$ALIAS\""  >> .bashrc
	## Config Systemctl
	configure_systemd
fi
if [ $IP4COUNT != "0" ] 
then
echo "How many ipv6 nodes do you want to install on this server?"
read MNCOUNT
let MNCOUNT=MNCOUNT+1
let MNCOUNT=MNCOUNT+IP4COUNT
let MNCOUNT=MNCOUNT+DELETED
let COUNTER=1
let COUNTER=COUNTER+IP4COUNT
let COUNTER=COUNTER+DELETED
while [  $COUNTER -lt $MNCOUNT ]; do
 PORT=22123
 RPCPORTT=22130
 RPCPORT=$(($RPCPORTT+$COUNTER))
  echo ""
  echo "Enter alias for new node"
  read ALIAS
  CONF_DIR=~/.transcendence_$ALIAS
  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY
  echo "up /sbin/ip -6 addr add ${gateway}$COUNTER$MASK dev $face # $ALIAS" >> /etc/network/interfaces
  /sbin/ip -6 addr add ${gateway}$COUNTER$MASK dev $face
  mkdir ~/.transcendence_$ALIAS
  unzip Bootstrap.zip -d ~/.transcendence_$ALIAS >/dev/null 2>&1
  echo '#!/bin/bash' > ~/bin/transcendenced_$ALIAS.sh
  echo "transcendenced -daemon -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> ~/bin/transcendenced_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/transcendence-cli_$ALIAS.sh
  echo "transcendence-cli -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> ~/bin/transcendence-cli_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/transcendence-tx_$ALIAS.sh
  echo "transcendence-tx -conf=$CONF_DIR/transcendence.conf -datadir=$CONF_DIR "'$*' >> ~/bin/transcendence-tx_$ALIAS.sh
  chmod 755 ~/bin/transcendence*.sh
  mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> transcendence.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> transcendence.conf_TEMP
  echo "rpcport=$RPCPORT" >> transcendence.conf_TEMP
  echo "listen=1" >> transcendence.conf_TEMP
  echo "server=1" >> transcendence.conf_TEMP
  echo "daemon=1" >> transcendence.conf_TEMP
  echo "logtimestamps=1" >> transcendence.conf_TEMP
  echo "maxconnections=$MAXC" >> transcendence.conf_TEMP
  echo "masternode=1" >> transcendence.conf_TEMP
  echo "dbcache=20" >> transcendence.conf_TEMP
  echo "maxorphantx=5" >> transcendence.conf_TEMP
  echo "maxmempool=100" >> transcendence.conf_TEMP
  echo "bind=[${gateway}$COUNTER]:$PORT" >> transcendence.conf_TEMP
  echo "externalip=[${gateway}$COUNTER]" >> transcendence.conf_TEMP
  echo "masternodeaddr=[${gateway}$COUNTER]:$PORT" >> transcendence.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> transcendence.conf_TEMP
  mv transcendence.conf_TEMP $CONF_DIR/transcendence.conf
  echo ""
  echo -e "Your ip is ${GREEN}[${gateway}$COUNTER]:$PORT${NC}"
	echo "alias ${ALIAS}_status=\"transcendence-cli -datadir=/root/.transcendence_${ALIAS} masternode status\"" >> .bashrc
	echo "alias ${ALIAS}_stop=\"systemctl stop transcendenced$ALIAS\"" >> .bashrc
	echo "alias ${ALIAS}_start=\"systemctl start transcendenced$ALIAS\""  >> .bashrc
	echo "alias ${ALIAS}_config=\"nano /root/.transcendence_${ALIAS}/transcendence.conf\""  >> .bashrc
	echo "alias ${ALIAS}_getinfo=\"transcendence-cli -datadir=/root/.transcendence_${ALIAS} getinfo\"" >> .bashrc
    	echo "alias ${ALIAS}_getpeerinfo=\"transcendence-cli -datadir=/root/.transcendence_${ALIAS} getpeerinfo\"" >> .bashrc
	echo "alias ${ALIAS}_resync=\"/root/bin/transcendenced_${ALIAS}.sh -resync\"" >> .bashrc
	echo "alias ${ALIAS}_reindex=\"/root/bin/transcendenced_${ALIAS}.sh -reindex\"" >> .bashrc
	echo "alias ${ALIAS}_restart=\"systemctl restart transcendenced$ALIAS\""  >> .bashrc
	## Config Systemctl
	configure_systemd
	COUNTER=$((COUNTER+1))
done
fi
echo ""
echo -e "${RED}Please do not set maxconnections lower than 48 or your node may not receive rewards as often.${NC}"
echo ""
echo "Commands:"
echo "${ALIAS}_start"
echo "${ALIAS}_restart"
echo "${ALIAS}_status"
echo "${ALIAS}_stop"
echo "${ALIAS}_config"
echo "${ALIAS}_getinfo"
echo "${ALIAS}_getpeerinfo"
echo "${ALIAS}_resync"
echo "${ALIAS}_reindex"
fi
echo ""
echo "Made by lobo & xispita with the help of all Transcendence team "
echo "lobo's Transcendence Address for donations: GWe4v6A6tLg9pHYEN5MoAsYLTadtefd9o6"
echo "xispita's Transcendence Address for donations: GRDqyK7m9oTsXjUsmiPDStoAfuX1H7eSfh" 
echo "Bitcoin Address for donations: 1NqYjVMA5DhuLytt33HYgP5qBajeHLYn4d"
exec bash
exit
