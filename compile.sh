#/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo -e "$0 must be run as root."
   exit 1
fi
echo "Enter number of threads to compile (~1.5gb ram usage per thread)"
read thr
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo ""
echo "Please wait. Stopping nodes."
systemctl stop transcendenced*
sudo add-apt-repository universe -y
apt-get update
apt-get install -y git gcc-5 g++-5 zip software-properties-common unzip build-essential libtool autotools-dev autoconf pkg-config libssl-dev libcrypto++-dev libevent-dev libminiupnpc-dev libgmp-dev libboost-all-dev devscripts libsodium-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libcrypto++-dev libminiupnpc-dev qt5-default
add-apt-repository ppa:bitcoin/bitcoin -y
apt-get update
apt-get install libdb4.8-dev libdb4.8++-dev gcc-5 g++-5 -y --auto-remove
apt-get install libssl1.0-dev libzmq3-dev -y --auto-remove
git clone https://github.com/phoenixkonsole/transcendence.git
cd transcendence
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 100
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 100
./autogen.sh
./configure
make -j $thr
make install
systemctl start transcendenced*
