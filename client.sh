. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')



	# Install some packages:
	sudo apt-get -y install python-keystoneclient python-glanceclient python-novaclient 

