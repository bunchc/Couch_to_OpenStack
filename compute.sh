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
echo "source /vagrant/.stackrc" >> ~/.bashrc

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# OpenStack Controller Private IP for use with generating Cinder target IP
OSC_PRIV_IP=${CONTROLLER_HOST_PRIV}

# Must define your environment
MYSQL_HOST=${CONTROLLER_HOST}
GLANCE_HOST=${CONTROLLER_HOST}

# Define environment variables to contain the OpenStack Controller Public and Private IP for later use with Cinder
export OSCONTROLLER_P=$OSC_PRIV_IP

nova_compute_install() {

	# Install some packages:
	sudo apt-get -y --force-yes install nova-api-metadata nova-compute nova-compute-qemu nova-doc
	sudo apt-get install -y vim vlan bridge-utils
	sudo apt-get install -y libvirt-bin pm-utils sysfsutils
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

# OpenVSwitch
sudo apt-get install -y linux-headers-`uname -r` build-essential
sudo apt-get install -y openvswitch-switch openvswitch-datapath-dkms

# Make the bridge br-int, used for VM integration
ovs-vsctl add-br br-int

# Quantum
sudo apt-get install -y quantum-plugin-openvswitch-agent python-cinderclient

# Configure Quantum
# /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
#sudo sed -i "s|sql_connection = sqlite:////var/lib/quantum/ovs.sqlite|sql_connection = mysql://quantum:openstack@${CONTROLLER_HOST}/quantum|g"  /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
#sudo sed -i 's/# Default: integration_bridge = br-int/integration_bridge = br-int/g' /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
#sudo sed -i 's/# Default: tunnel_bridge = br-tun/tunnel_bridge = br-tun/g' /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
#sudo sed -i 's/# Default: enable_tunneling = False/enable_tunneling = True/g' /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
#sudo sed -i 's/# Example: tenant_network_type = gre/tenant_network_type = gre/g' /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
#sudo sed -i 's/# Example: tunnel_id_ranges = 1:1000/tunnel_id_ranges = 1:1000/g' /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
#sudo sed -i "s/# Default: local_ip =/local_ip = ${MY_IP}/g" /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
echo "
[DATABASE]
sql_connection=mysql://quantum:openstack@${CONTROLLER_HOST}/quantum
[OVS]
tenant_network_type=gre
tunnel_id_ranges=1:1000
integration_bridge=br-int
tunnel_bridge=br-tun
local_ip=${MY_IP}
enable_tunneling=True
root_helper = sudo /usr/bin/quantum-rootwrap /etc/quantum/rootwrap.conf
[SECURITYGROUP]
# Firewall driver for realizing quantum security group function
firewall_driver = quantum.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
" | tee -a /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini


# /etc/quantum/quantum.conf
sudo sed -i "s/# rabbit_host = localhost/rabbit_host = ${CONTROLLER_HOST}/g" /etc/quantum/quantum.conf
sudo sed -i 's/# auth_strategy = keystone/auth_strategy = keystone/g' /etc/quantum/quantum.conf
sudo sed -i "s/auth_host = 127.0.0.1/auth_host = ${CONTROLLER_HOST}/g" /etc/quantum/quantum.conf
sudo sed -i 's/admin_tenant_name = %SERVICE_TENANT_NAME%/admin_tenant_name = service/g' /etc/quantum/quantum.conf
sudo sed -i 's/admin_user = %SERVICE_USER%/admin_user = quantum/g' /etc/quantum/quantum.conf
sudo sed -i 's/admin_password = %SERVICE_PASSWORD%/admin_password = quantum/g' /etc/quantum/quantum.conf
sudo sed -i 's/^root_helper.*/root_helper = sudo/g' /etc/quantum/quantum.conf

echo "
Defaults !requiretty
quantum ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

# Restart Quantum Services
service quantum-plugin-openvswitch-agent restart

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
network_api_class=nova.network.quantumv2.api.API
quantum_url=http://${CONTROLLER_HOST}:9696
quantum_auth_strategy=keystone
quantum_admin_tenant_name=service
quantum_admin_username=quantum
quantum_admin_password=quantum
quantum_admin_auth_url=http://${CONTROLLER_HOST}:35357/v2.0
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
#firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
security_group_api=quantum
firewall_driver=nova.virt.firewall.NoopFirewallDriver

service_quantum_metadata_proxy=true
quantum_metadata_proxy_shared_secret=foo

#Metadata
#metadata_host = ${CONTROLLER_HOST}
#metadata_listen = ${CONTROLLER_HOST}
#metadata_listen_port = 8775

# Cinder #
volume_driver=nova.volume.driver.ISCSIDriver
enabled_apis=ec2,osapi_compute,metadata
volume_api_class=nova.volume.cinder.API
iscsi_helper=tgtadm
#set private IP address for providing iSCSI storage to VMs
iscsi_ip_address = $(echo $OSCONTROLLER_P | sed 's/\.[0-9]*$/.211/')
#may not be necessary
volume_name_template = volume-%s
#LVM Group name generated by cinder.sh
volume_group = cinder-volumes

# Images
image_service=nova.image.glance.GlanceImageService
glance_api_servers=${GLANCE_HOST}:9292

# Scheduler
scheduler_default_filters=AllHostsFilter

# Object Storage <- Placeholder for Swift?
#iscsi_helper=tgtadm

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

# Copy files to local system for easy access in case the vagrant share drops
mkdir c2os && cp /vagrant/* ./c2os/ && cp /vagrant/.stackrc ./c2os/ && sed "s/\/vagrant/~/g" .bashrc
