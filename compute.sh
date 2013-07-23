. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Must define your environment
MYSQL_HOST=${CONTROLLER_HOST}
GLANCE_HOST=${CONTROLLER_HOST}

nova_compute_install() {

	# Install some packages:
	sudo apt-get -y install nova-api-metadata nova-compute nova-compute-qemu nova-doc nova-network
	sudo apt-get install -y vlan bridge-utils
	sudo apt-get install -y libvirt-bin pm-utils
	sudo service ntp restart
}

nova_configure() {

# Networking 
# ip forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
# To save you from rebooting, perform the following
sysctl net.ipv4.ip_forward=1

# restart libvirt
sudo service libvirt-bin restart

# Nova Conf
# Clobber the nova.conf file with the following
NOVA_CONF=/etc/nova/nova.conf
NOVA_API_PASTE=/etc/nova/api-paste.ini

cat > /tmp/nova.conf << EOF
[DEFAULT]
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
verbose=True

api_paste_config=/etc/nova/api-paste.ini
enabled_apis=ec2,osapi_compute,metadata

# Libvirt and Virtualization
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
libvirt_type=qemu

# Database
sql_connection=mysql://nova:openstack@${MYSQL_HOST}/nova

# Messaging
rabbit_host=${MYSQL_HOST}

# EC2 API Flags
ec2_host=${MYSQL_HOST}
ec2_dmz_host=${MYSQL_HOST}
ec2_private_dns_show_ip=True

# Network settings
public_interface=eth1
force_dhcp_release=True
auto_assign_floating_ip=True

#Metadata
#metadata_host = ${CONTROLLER_HOST}
#metadata_listen = ${CONTROLLER_HOST}
#metadata_listen_port = 8775

# Images
image_service=nova.image.glance.GlanceImageService
glance_api_servers=${GLANCE_HOST}:9292

# Scheduler
scheduler_default_filters=AllHostsFilter

# Object Storage
iscsi_helper=tgtadm

# Auth
auth_strategy=keystone
keystone_ec2_url=http://${KEYSTONE_ENDPOINT}:5000/v2.0/ec2tokens

EOF

  sudo rm -f $NOVA_CONF
  sudo mv /tmp/nova.conf $NOVA_CONF
  sudo chmod 0640 $NOVA_CONF
  sudo chown nova:nova $NOVA_CONF

# Paste file
  sudo sed -i "s/127.0.0.1/'$KEYSTONE_ENDPOINT'/g" $NOVA_API_PASTE
  sudo sed -i "s/%SERVICE_TENANT_NAME%/'service'/g" $NOVA_API_PASTE
  sudo sed -i "s/%SERVICE_USER%/nova/g" $NOVA_API_PASTE
  sudo sed -i "s/%SERVICE_PASSWORD%/'$SERVICE_PASS'/g" $NOVA_API_PASTE
  sudo nova-manage db sync
}

nova_restart() {
	for P in $(ls /etc/init/nova* | cut -d'/' -f4 | cut -d'.' -f1)
	do
		sudo stop ${P}
		sudo start ${P}
	done
}

# Main
nova_compute_install
nova_configure
nova_restart
