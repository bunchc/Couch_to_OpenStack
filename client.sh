#. /vagrant/common.sh

export DEBIAN_FRONTEND=noninteractive
export CONTROLLER_HOST=172.16.80.200
export CONTROLLER_HOST_PRIV=10.10.80.200
sudo apt-get update

# Grizzly Goodness
sudo apt-get -y install ubuntu-cloud-keyring
echo "deb  http://ubuntu-cloud.archive.canonical.com/ubuntu precise-proposed/grizzly main" | sudo tee -a /etc/apt/sources.list.d/grizzly.list
sudo apt-get update

sudo apt-get -y install vim
echo "source /vagrant/stackrc" >> ~/.bashrc

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')



# Install some packages:
sudo apt-get -y install vim python-keystoneclient python-glanceclient python-novaclient python-cinderclient python-quantumclient
