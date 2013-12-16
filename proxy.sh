#!/bin/bash

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Install squid
export DEBIAN_FRONTEND=noninteractive
apt-get update && sudo apt-get install ubuntu-cloud-keyring apt-cacher-ng -y
sudo cp -R /vagrant/apt-cacher-ng/* /var/cache/apt-cacher-ng/
sudo chown -R apt-cacher-ng:apt-cacher-ng /var/cache/apt-cacher-ng/
sudo service apt-cacher-ng restart

# Setup our repo's
sudo apt-get install python-software-properties -y
echo "deb  http://ubuntu-cloud.archive.canonical.com/ubuntu precise-proposed/havana main" | sudo tee -a /etc/apt/sources.list.d/havana.list
sudo apt-get update
sudo apt-get install iftop iptraf vim curl wget lighttpd -y

echo "Acquire::http { Proxy 'http://${MY_IP}:3142'; };" | sudo tee /etc/apt/apt.conf.d/01apt-cacher-ng-proxy

sudo iptables -t nat -A POSTROUTING -s 192.168.80.0/24 -o eth0 -j MASQUERADE
sudo sysctl net.ipv4.conf.all.forwarding=1

#Pass Proxy IP to Common.sh and other nodes
cat > /vagrant/.proxy <<EOF
export PROXY_HOST=${MY_IP}
EOF
