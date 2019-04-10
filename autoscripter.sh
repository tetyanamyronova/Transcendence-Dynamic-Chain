#!/bin/bash
cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

## Error checks

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

perl -i -ne 'print if ! $a{$_}++' /etc/network/interfaces

if [ ! -d "/root/bin" ]; then
mkdir /root/bin
fi

## Setup

if [ ! -f "/root/bin/cname" ]; then
 DOSETUP="y"
else
 cname=`cat /root/bin/cname` 
 PORT=`cat /root/bin/cport`
 DOSETUP="n"
fi

if [ $DOSETUP = "y" ]
then
  
  echo "Please enter the github coin link" 
  read github
  
  if [[ ! $github == *".git"* ]]; then
  github="${github}.git"
  fi
  
  foldername1=${github::-4}
  foldername=${foldername1##*/}

  git clone $github
  cd $foldername
  
  cliname1=`grep 'BITCOIN_CLI_NAME' configure.ac | head -n 1`
  cliname=${cliname1##*=}
  cname=${cliname::-4}
  
  
  PORT=`grep 'nDefaultPort' src/chainparams.cpp | head -n 1 | tr -d -c 0-9`
  

  ## Installing pre-requisites
 
  echo -e "Installing ${GREEN}${cname} dependencies${NC}. Please wait."
  apt-get update 
  apt-get -y upgrade
  apt install software-properties-common -y
  add-apt-repository universe -y
  apt update
  apt install -y zip unzip bc curl nano lshw ufw gawk libdb++-dev git zip automake software-properties-common unzip build-essential libtool autotools-dev autoconf pkg-config libssl-dev libcrypto++-dev libevent-dev libminiupnpc-dev libgmp-dev libboost-all-dev devscripts libsodium-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libcrypto++-dev libminiupnpc-dev qt5-default gcc-5 g++-5 --auto-remove
  thr="$(nproc)"
  
  ## Creating swap

  echo -e "${RED}Creating swap. This may take a while.${NC}"
  dd if=/dev/zero of=/var/swap.img bs=2048 count=1M
  chmod 600 /var/swap.img
  mkswap /var/swap.img 
  swapon /var/swap.img 
  free -m
  echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
  
  ## Compatibility issues
  
  export LC_CTYPE=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  apt update
  apt install libssl1.0-dev -y
  apt install libzmq3-dev -y --auto-remove
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 100
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 100
  
  ## Preparing and building
  
  chmod +x */*/*
  ./autogen.sh
  ./configure --with-incompatible-bdb --disable-tests
  make -j $thr
  make install
  
  ## Final configs
  
  echo $cname > /root/bin/cname
  echo $PORT > /root/bin/cport   
  ufw allow ssh/tcp 
  ufw limit ssh/tcp 
  ufw logging on
  echo "y" | ufw enable 
  ufw allow $PORT
  echo 'export PATH=~/bin:$PATH' > ~/.bash_aliases
  source ~/.bashrc
  echo ""
  cd
  sysctl vm.swappiness=10
  sysctl vm.vfs_cache_pressure=200
  echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure=200' | tee -a /etc/sysctl.conf
fi

## Constants

IP4COUNT=$(find /root/.${cname}_* -maxdepth 0 -type d | wc -l)
DELETED="$(cat /root/bin/deleted${cname} | wc -l)"
ALIASES="$(find /root/.${cname}_* -maxdepth 0 -type d | cut -c22-)"
face="$(lshw -C network | grep "logical name:" | sed -e 's/logical name:/logical name: /g' | awk '{print $3}' | head -n1)"
IP4=$(curl -s4 api.ipify.org)

RPCPORTT=$((PORT*10))
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


## Systemd Function

function configure_systemd() {
  cat << EOF > /etc/systemd/system/${cname}d$ALIAS.service
[Unit]
Description=${cname}d$ALIAS service
After=network.target
 [Service]
User=root
Group=root
Type=forking
#PIDFile=/root/.${cname}_$ALIAS/${cname}d.pid
ExecStart=/root/bin/${cname}d_$ALIAS.sh
ExecStop=/root/bin/${cname}-cli_$ALIAS.sh stop
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
  echo "@reboot systemctl start ${cname}d$ALIAS" >> cron$ALIAS
  crontab cron$ALIAS
  rm cron$ALIAS
  systemctl start ${cname}d$ALIAS.service
}

## Start of Guided Script

clear
echo "1 - Create new nodes"
echo "2 - Remove an existing node"
echo "3 - List aliases"
echo "4 - Check for node errors"
echo "5 - Reset script for using another coin"
echo "What would you like to do?"
read DO
echo ""

## Reseting

if [ $DO = "5" ]
then
rm /root/bin/cname
rm /root/bin/cport
exit
fi

## Checking for node errors

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
sh /root/bin/${cname}-cli_${CURRENT}.sh masternode status | grep "message"
OFFSET="$(sh /root/bin/${cname}-cli_${CURRENT}.sh getinfo | grep "timeoffset")"
OFF1=${OFFSET:(-2)}
OFF=${OFF1:0:1}
if [ $OFF = "1" ]
then
echo "$OFFSET" 
fi
done
rm temp2
fi

## Listing aliases

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

## Properly deleting nodes

if [ $DO = "2" ]
then
echo "Input the alias of the node that you want to delete"
read ALIASD
echo ""
echo -e "${GREEN}Deleting ${ALIASD}${NC}. Please wait."
## Removing service
systemctl stop ${cname}d$ALIASD >/dev/null 2>&1
systemctl disable ${cname}d$ALIASD >/dev/null 2>&1
rm /etc/systemd/system/${cname}d${ALIASD}.service >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
systemctl reset-failed >/dev/null 2>&1
rm /root/.${cname}_$ALIASD -r >/dev/null 2>&1
sed -i "/${ALIASD}/d" .bashrc
crontab -l -u root | grep -v ${cname}d$ALIASD | crontab -u root - >/dev/null 2>&1
source .bashrc
echo "1" >> /root/bin/deleted${cname}
echo -e "${ALIASD} Successfully deleted."
fi

## Easy or expert mode

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



echo -e "${cname} nodes currently installed: ${GREEN}${IP4COUNT}${NC}, ${cname} nodes previously Deleted: ${GREEN}${DELETED}${NC}"
echo ""
if [ $IP4COUNT = "0" ] 
then
echo -e "${RED}First node must be ipv4.${NC}"
let COUNTER=0
RPCPORT=$(($RPCPORTT+$COUNTER))
  echo ""
  echo "Enter alias for first node"
  read ALIAS
  CONF_DIR=~/.${cname}_$ALIAS
  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY
  if [ $EE = "2" ] 
	then
	echo ""
	echo "Enter port for $ALIAS"
	read PORTD
  fi
  mkdir ~/.${cname}_$ALIAS
  echo '#!/bin/bash' > ~/bin/${cname}d_$ALIAS.sh
  echo "${cname}d -daemon -conf=$CONF_DIR/${cname}.conf -datadir=$CONF_DIR "'$*' >> ~/bin/${cname}d_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/${cname}-cli_$ALIAS.sh
  echo "${cname}-cli -conf=$CONF_DIR/${cname}.conf -datadir=$CONF_DIR "'$*' >> ~/bin/${cname}-cli_$ALIAS.sh
  chmod 755 ~/bin/${cname}*.sh
  mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> ${cname}.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> ${cname}.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> ${cname}.conf_TEMP
  echo "rpcport=$RPCPORT" >> ${cname}.conf_TEMP
  echo "listen=1" >> ${cname}.conf_TEMP
  echo "server=1" >> ${cname}.conf_TEMP
  echo "daemon=1" >> ${cname}.conf_TEMP
  echo "logtimestamps=1" >> ${cname}.conf_TEMP
  echo "maxconnections=$MAXC" >> ${cname}.conf_TEMP
  echo "masternode=1" >> ${cname}.conf_TEMP
  echo "dbcache=20" >> ${cname}.conf_TEMP
  echo "maxorphantx=5" >> ${cname}.conf_TEMP
  echo "maxmempool=100" >> ${cname}.conf_TEMP
  echo "" >> ${cname}.conf_TEMP
  echo "" >> ${cname}.conf_TEMP
  echo "bind=$IP4:$PORT" >> ${cname}.conf_TEMP
  echo "externalip=$IP4" >> ${cname}.conf_TEMP
  echo "masternodeaddr=$IP4:$PORT" >> ${cname}.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> ${cname}.conf_TEMP
  

  mv ${cname}.conf_TEMP $CONF_DIR/${cname}.conf
  echo ""
  echo -e "Your ip is ${GREEN}$IP4:$PORT${NC}"
	echo "alias ${ALIAS}_status=\"${cname}-cli -datadir=/root/.${cname}_${ALIAS} masternode status\"" >> .bashrc
	echo "alias ${ALIAS}_stop=\"systemctl stop ${cname}d$ALIAS\"" >> .bashrc
	echo "alias ${ALIAS}_start=\"systemctl start ${cname}d$ALIAS\""  >> .bashrc
	echo "alias ${ALIAS}_config=\"nano /root/.${cname}_${ALIAS}/${cname}.conf\""  >> .bashrc
	echo "alias ${ALIAS}_getinfo=\"${cname}-cli -datadir=/root/.${cname}_${ALIAS} getinfo\"" >> .bashrc
    echo "alias ${ALIAS}_getpeerinfo=\"${cname}-cli -datadir=/root/.${cname}_${ALIAS} getpeerinfo\"" >> .bashrc
	echo "alias ${ALIAS}_resync=\"/root/bin/${cname}d_${ALIAS}.sh -resync\"" >> .bashrc
	echo "alias ${ALIAS}_reindex=\"/root/bin/${cname}d_${ALIAS}.sh -reindex\"" >> .bashrc
	echo "alias ${ALIAS}_restart=\"systemctl restart ${cname}d$ALIAS\""  >> .bashrc
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

 RPCPORT=$(($RPCPORTT+$COUNTER))
  echo ""
  echo "Enter alias for new node"
  read ALIAS
  CONF_DIR=~/.${cname}_$ALIAS
  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY
  echo "up /sbin/ip -6 addr add ${gateway}$COUNTER$MASK dev $face # $ALIAS" >> /etc/network/interfaces
  /sbin/ip -6 addr add ${gateway}$COUNTER$MASK dev $face
  mkdir ~/.${cname}_$ALIAS
  unzip Bootstrap.zip -d ~/.${cname}_$ALIAS >/dev/null 2>&1
  echo '#!/bin/bash' > ~/bin/${cname}d_$ALIAS.sh
  echo "${cname}d -daemon -conf=$CONF_DIR/${cname}.conf -datadir=$CONF_DIR "'$*' >> ~/bin/${cname}d_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/${cname}-cli_$ALIAS.sh
  echo "${cname}-cli -conf=$CONF_DIR/${cname}.conf -datadir=$CONF_DIR "'$*' >> ~/bin/${cname}-cli_$ALIAS.sh
  chmod 755 ~/bin/${cname}*.sh
  mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> ${cname}.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> ${cname}.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> ${cname}.conf_TEMP
  echo "rpcport=$RPCPORT" >> ${cname}.conf_TEMP
  echo "listen=1" >> ${cname}.conf_TEMP
  echo "server=1" >> ${cname}.conf_TEMP
  echo "daemon=1" >> ${cname}.conf_TEMP
  echo "logtimestamps=1" >> ${cname}.conf_TEMP
  echo "maxconnections=$MAXC" >> ${cname}.conf_TEMP
  echo "masternode=1" >> ${cname}.conf_TEMP
  echo "dbcache=20" >> ${cname}.conf_TEMP
  echo "maxorphantx=5" >> ${cname}.conf_TEMP
  echo "maxmempool=100" >> ${cname}.conf_TEMP
  echo "bind=[${gateway}$COUNTER]:$PORT" >> ${cname}.conf_TEMP
  echo "externalip=[${gateway}$COUNTER]" >> ${cname}.conf_TEMP
  echo "masternodeaddr=[${gateway}$COUNTER]:$PORT" >> ${cname}.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> ${cname}.conf_TEMP
  mv ${cname}.conf_TEMP $CONF_DIR/${cname}.conf
  echo ""
  echo -e "Your ip is ${GREEN}[${gateway}$COUNTER]:$PORT${NC}"
	echo "alias ${ALIAS}_status=\"${cname}-cli -datadir=/root/.${cname}_${ALIAS} masternode status\"" >> .bashrc
	echo "alias ${ALIAS}_stop=\"systemctl stop ${cname}d$ALIAS\"" >> .bashrc
	echo "alias ${ALIAS}_start=\"systemctl start ${cname}d$ALIAS\""  >> .bashrc
	echo "alias ${ALIAS}_config=\"nano /root/.${cname}_${ALIAS}/${cname}.conf\""  >> .bashrc
	echo "alias ${ALIAS}_getinfo=\"${cname}-cli -datadir=/root/.${cname}_${ALIAS} getinfo\"" >> .bashrc
    echo "alias ${ALIAS}_getpeerinfo=\"${cname}-cli -datadir=/root/.${cname}_${ALIAS} getpeerinfo\"" >> .bashrc
	echo "alias ${ALIAS}_resync=\"/root/bin/${cname}d_${ALIAS}.sh -resync\"" >> .bashrc
	echo "alias ${ALIAS}_reindex=\"/root/bin/${cname}d_${ALIAS}.sh -reindex\"" >> .bashrc
	echo "alias ${ALIAS}_restart=\"systemctl restart ${cname}d$ALIAS\""  >> .bashrc
	## Config Systemctl
	configure_systemd
	COUNTER=$((COUNTER+1))
done
fi
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
echo "Made by lobo"
echo "Transcendence Address for donations: GWe4v6A6tLg9pHYEN5MoAsYLTadtefd9o6"
echo "Bitcoin Address for donations: 1NqYjVMA5DhuLytt33HYgP5qBajeHLYn4d"
exec bash
exit
