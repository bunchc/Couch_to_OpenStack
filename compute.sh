. /vagrant/common.sh

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH3_IP=$(ifconfig eth3 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# OpenStack Controller Private IP for use with generating Cinder target IP
OSC_PRIV_IP=${CONTROLLER_HOST_PRIV}

# Must define your environment
MYSQL_HOST=${CONTROLLER_HOST}
GLANCE_HOST=${CONTROLLER_HOST}

# Define environment variables to contain the OpenStack Controller Public and Private IP for later use with Cinder
export OSCONTROLLER_P=$OSC_PRIV_IP

nova_compute_install() {

	# Install some packages:
	sudo apt-get -y --force-yes install vim vlan bridge-utils
	sudo apt-get -y --force-yes install libvirt-bin pm-utils sysfsutils
	sudo service ntp restart
	sudo apt-get -y --force-yes install nova-compute-qemu nova-doc

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
sudo apt-get -y --force-yes install linux-headers-`uname -r` build-essential
sudo apt-get -y --force-yes install openvswitch-switch openvswitch-datapath-dkms

# Make the bridge br-int, used for VM integration
sudo ovs-vsctl add-br br-int
sudo ovs-vsctl add-br br-ex
sudo ovs-vsctl add-port br-ex eth3

sudo ifconfig eth3 0.0.0.0 up
sudo ip link set eth3 promisc on
sudo ifconfig br-ex $ETH3_IP netmask 255.255.255.0 up

# Neutron
sudo apt-get -y install neutron-plugin-openvswitch-agent python-cinderclient

# Configure Neutron
# Replace ovs_neutron_plugin.ini file with the following
sudo rm -f /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
echo "
[DATABASE]
reconnect_interval = 2
sql_connection=mysql://neutron:openstack@${CONTROLLER_HOST}/neutron
[AGENT]
# Agent's polling interval in seconds
polling_interval = 2
[OVS]
tenant_network_type=gre
tunnel_id_ranges=1:1000
integration_bridge=br-int
tunnel_bridge=br-tun
local_ip=${MY_IP}
enable_tunneling=True
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf
[SECURITYGROUP]
# Firewall driver for realizing quantum security group function
firewall_driver = quantum.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
" | sudo tee -a /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

# Replace /etc/neutron/api-paste.ini file with the following:
sudo rm -f /etc/neutron/api-paste.ini
echo "
[composite:neutron]
use = egg:Paste#urlmap
/: neutronversions
/v2.0: neutronapi_v2_0

[composite:neutronapi_v2_0]
use = call:neutron.auth:pipeline_factory
noauth = extensions neutronapiapp_v2_0
keystone = authtoken keystonecontext extensions neutronapiapp_v2_0

[filter:keystonecontext]
paste.filter_factory = neutron.auth:NeutronKeystoneContext.factory

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = ${CONTROLLER_HOST}
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = neutron
admin_password = neutron

[filter:extensions]
paste.filter_factory = neutron.api.extensions:plugin_aware_extension_middleware_factory

[app:neutronversions]
paste.app_factory = neutron.api.versions:Versions.factory

[app:neutronapiapp_v2_0]
paste.app_factory = neutron.api.v2.router:APIRouter.factory
" | sudo tee -a /etc/neutron/api-paste.ini

#Replace some lines in /etc/neutron/neutron.conf
MYSQL_NEUTRON_PASS='openstack'
# /etc/neutron/neutron.conf
sudo sed -i "s/# rabbit_host = localhost/rabbit_host = ${CONTROLLER_HOST}/g" /etc/neutron/neutron.conf
sudo sed -i 's/# auth_strategy = keystone/auth_strategy = keystone/g' /etc/neutron/neutron.conf
sudo sed -i "s/auth_host = 127.0.0.1/auth_host = ${CONTROLLER_HOST}/g" /etc/neutron/neutron.conf
sudo sed -i 's/admin_tenant_name = %SERVICE_TENANT_NAME%/admin_tenant_name = service/g' /etc/neutron/neutron.conf
sudo sed -i 's/admin_user = %SERVICE_USER%/admin_user = neutron/g' /etc/neutron/neutron.conf
sudo sed -i 's/admin_password = %SERVICE_PASSWORD%/admin_password = neutron/g' /etc/neutron/neutron.conf
sudo sed -i 's/^root_helper.*/root_helper = sudo/g' /etc/neutron/neutron.conf
sudo sed -i 's/# allow_overlapping_ips = False/allow_overlapping_ips = True/g' /etc/neutron/neutron.conf
sudo sed -i "s,^connection.*,connection = mysql://neutron:${MYSQL_NEUTRON_PASS}@${MYSQL_HOST}/neutron," /etc/neutron/neutron.conf

echo "
Defaults !requiretty
neutron ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

# Restart Neutron Services
service neutron-plugin-openvswitch-agent restart

# Nova Conf
# Clobber the nova.conf file with the following
NOVA_CONF=/etc/nova/nova.conf
NOVA_API_PASTE=/etc/nova/api-paste.ini

sudo rm -rf $NOVA_CONF

echo "
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

# VNC Settings
my_ip=${MY_IP}
vncserver_listen=0.0.0.0
vncserver_proxyclient_address=${MY_IP}
novncproxy_base_url=http://${CONTROLLER_HOST}:6080/vnc_auto.html

# Network settings
network_api_class=nova.network.neutronv2.api.API
neutron_url=http://${CONTROLLER_HOST}:9696
neutron_auth_strategy=keystone
neutron_admin_tenant_name=service
neutron_admin_username=neutron
neutron_admin_password=neutron
neutron_admin_auth_url=http://${CONTROLLER_HOST}:35357/v2.0
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
security_group_api=neutron
firewall_driver=nova.virt.firewall.NoopFirewallDriver

service_neutron_metadata_proxy=true
neutron_metadata_proxy_shared_secret=foo

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
glance_host=${GLANCE_HOST}

# Scheduler
scheduler_default_filters=AllHostsFilter

# Object Storage <- Placeholder for Swift?
#iscsi_helper=tgtadm

# Auth
auth_strategy=keystone
keystone_ec2_url=http://${CONTROLLER_HOST}:5000/v2.0/ec2tokens
" | sudo tee -a $NOVA_CONF

  sudo chmod 0640 $NOVA_CONF
  sudo chown nova:nova $NOVA_CONF
  sudo chmod 0644 /boot/vmlinuz*

# Paste file
sudo sed -i "s/^auth_host.*/auth_host = $CONTROLLER_HOST/g" $NOVA_API_PASTE
sudo sed -i "s/%SERVICE_TENANT_NAME%/service/g" $NOVA_API_PASTE
sudo sed -i "s/%SERVICE_USER%/nova/g" $NOVA_API_PASTE
sudo sed -i "s/%SERVICE_PASSWORD%/nova/g" $NOVA_API_PASTE
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
