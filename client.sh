. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Install client packages:
sudo apt-get -y install vim python-keystoneclient python-glanceclient python-novaclient python-cinderclient python-quantumclient

# Install horizon dashboard (Available at http://MY_IP/horizon)
sudo apt-get install -y memcached libapache2-mod-wsgi openstack-dashboard

sudo sed -i "s/^OPENSTACK_HOST.*/OPENSTACK_HOST = \"${CONTROLLER_HOST}\"/g" /etc/openstack-dashboard/local_settings.py

# TODO: turn off memcached
# sed -e '//,+4 s/^/#/' 
