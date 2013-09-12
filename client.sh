. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Install some packages:
sudo apt-get -y install vim python-keystoneclient python-glanceclient python-novaclient python-cinderclient python-quantumclient

# Install Nagios
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
echo "nagios3-cgi nagios3/adminpassword password nagiosadmin" | sudo debconf-set-selections
echo "nagios3-cgi nagios3/adminpassword-repeat password nagiosadmin" | sudo debconf-set-selections

sudo apt-get install -y nagios3 nagios-nrpe-plugin