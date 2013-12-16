#!/bin/bash

# network.sh

# Authors: Kevin Jackson (kevin@linuxservices.co.uk)
#          Cody Bunch (bunchc@gmail.com)

# Source in common env vars
. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH3_IP=$(ifconfig eth3 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

sysctl net.ipv4.ip_forward=1

sudo apt-get update
#sudo apt-get -y upgrade

sudo apt-get -y --force-yes install vim linux-headers-`uname -r`

sudo apt-get -y --force-yes install vlan bridge-utils dnsmasq-base dnsmasq-utils

sudo apt-get -y --force-yes install openvswitch-switch openvswitch-datapath-dkms

sudo apt-get -y --force-yes install neutron-dhcp-agent neutron-l3-agent neutron-plugin-openvswitch neutron-plugin-openvswitch-agent 

sudo /etc/init.d/openvswitch-switch start

# OpenVSwitch Configuration
#br-int will be used for VM integration
sudo ovs-vsctl add-br br-int

#br-ex is used to make to VM accessible from the internet
sudo ovs-vsctl add-br br-ex
sudo ovs-vsctl add-port br-ex eth3

# Edit the /etc/network/interfaces file for eth3?
sudo ifconfig eth3 0.0.0.0 up
sudo ip link set eth3 promisc on
sudo ifconfig br-ex $ETH3_IP netmask 255.255.255.0

# Configuration

# /etc/neutron/api-paste.ini
rm -f /etc/neutron/api-paste.ini
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

# /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
echo "
[DATABASE]
sql_connection=mysql://neutron:openstack@${CONTROLLER_HOST}/neutron
[OVS]
tenant_network_type=gre
tunnel_id_ranges=1:1000
integration_bridge=br-int
tunnel_bridge=br-tun
local_ip=${MY_IP}
enable_tunneling=True
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf
[SECURITYGROUP]
# Firewall driver for realizing neutron security group function
firewall_driver = quantum.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
" | tee -a /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

# /etc/neutron/dhcp_agent.ini 
#echo "root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf" >> /etc/neutron/dhcp_agent.ini
echo "
root_helper = sudo
use_namespaces = True
" | tee -a /etc/neutron/dhcp_agent.ini

echo "
Defaults !requiretty
neutron ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers


# Configure Neutron
sudo sed -i "s/# rabbit_host = localhost/rabbit_host = ${CONTROLLER_HOST}/g" /etc/neutron/neutron.conf
sudo sed -i 's/# auth_strategy = keystone/auth_strategy = keystone/g' /etc/neutron/neutron.conf
sudo sed -i "s/auth_host = 127.0.0.1/auth_host = ${CONTROLLER_HOST}/g" /etc/neutron/neutron.conf
sudo sed -i 's/admin_tenant_name = %SERVICE_TENANT_NAME%/admin_tenant_name = service/g' /etc/neutron/neutron.conf
sudo sed -i 's/admin_user = %SERVICE_USER%/admin_user = neutron/g' /etc/neutron/neutron.conf
sudo sed -i 's/admin_password = %SERVICE_PASSWORD%/admin_password = neutron/g' /etc/neutron/neutron.conf
sudo sed -i 's/^root_helper.*/root_helper = sudo/g' /etc/neutron/neutron.conf
sudo sed -i 's/# allow_overlapping_ips = False/allow_overlapping_ips = True/g' /etc/neutron/neutron.conf
sudo sed -i "s,^connection.*,connection = mysql://neutron:openstack@${CONTROLLER_HOST}/neutron," /etc/neutron/neutron.conf
sudo sed -i "s,^sql_connection.*,sql_connection = mysql://neutron:openstack@${CONTROLLER_HOST}/neutron," /etc/neutron/dhcp_agent.ini
sudo sed -i "s/# interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/g" /etc/neutron/l3_agent.ini

# /etc/neutron/l3_agent.ini
sudo rm -rf /etc/neutron/l3_agent.ini
echo "
[DEFAULT]
# Show debugging output in log (sets DEBUG log level output)
# debug = False

# L3 requires that an interface driver be set. Choose the one that best
# matches your plugin.
# interface_driver =

# Example of interface_driver option for OVS based plugins (OVS, Ryu, NEC)
# that supports L3 agent
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver

# Use veth for an OVS interface or not.
# Support kernels with limited namespace support
# (e.g. RHEL 6.5) so long as ovs_use_veth is set to True.
# ovs_use_veth = False

# Example of interface_driver option for LinuxBridge
# interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver

# Allow overlapping IP (Must have kernel build with CONFIG_NET_NS=y and
# iproute2 package that supports namespaces).
# use_namespaces = True

# If use_namespaces is set as False then the agent can only configure one router.

# This is done by setting the specific router_id.
# router_id =

# Each L3 agent can be associated with at most one external network.  This
# value should be set to the UUID of that external network.  If empty,
# the agent will enforce that only a single external networks exists and
# use that external network id
# gateway_external_network_id =

# Indicates that this L3 agent should also handle routers that do not have
# an external network gateway configured.  This option should be True only
# for a single agent in a Neutron deployment, and may be False for all agents
# if all routers must have an external network gateway
# handle_internal_only_routers = True

# Name of bridge used for external network traffic. This should be set to
# empty value for the linux bridge
# external_network_bridge = br-ex

# TCP Port used by Neutron metadata server
# metadata_port = 9697

# Send this many gratuitous ARPs for HA setup. Set it below or equal to 0
# to disable this feature.
# send_arp_for_ha = 3

# seconds between re-sync routers' data if needed
# periodic_interval = 40

# seconds to start to sync routers' data after
# starting agent
# periodic_fuzzy_delay = 5

# enable_metadata_proxy, which is true by default, can be set to False
# if the Nova metadata server is not available
# enable_metadata_proxy = True

# Location of Metadata Proxy UNIX domain socket
# metadata_proxy_socket = $state_path/metadata_proxy

auth_url = http://${CONTROLLER_HOST}:35357/v2.0
auth_region = regionOne
admin_tenant_name = service
admin_user = neutron
admin_password = neutron
metadata_ip = ${CONTROLLER_HOST}
metadata_port = 8775
use_namespaces = True
" | sudo tee -a /etc/neutron/l3_agent.ini

# Metadata Agent

sudo rm -rf /etc/neutron/metadata_agent.ini
echo "[DEFAULT]
# Show debugging output in log (sets DEBUG log level output)
# debug = True

# The Neutron user information for accessing the Neutron API.
auth_url = http://${CONTROLLER_HOST}:5000/v2.0
auth_region = regionOne
admin_tenant_name = service
admin_user = neutron
admin_password = neutron

# Network service endpoint type to pull from the keystone catalog
# endpoint_type = adminURL

# IP address used by Nova metadata server
nova_metadata_ip = ${CONTROLLER_HOST}

# TCP Port used by Nova metadata server
nova_metadata_port = 8775

# When proxying metadata requests, Neutron signs the Instance-ID header with a
# shared secret to prevent spoofing.  You may select any string for a secret,
# but it must match here and in the configuration used by the Nova Metadata
# Server. NOTE: Nova uses a different key: neutron_metadata_proxy_shared_secret
metadata_proxy_shared_secret = foo
" | sudo tee -a /etc/neutron/metadata_agent.ini

#DHCP Agent

sudo rm -rf /etc/neutron/dhcp_agent.ini
echo "[DEFAULT]
# Show debugging output in log (sets DEBUG log level output)
# debug = False

# The DHCP agent will resync its state with Neutron to recover from any
# transient notification or rpc errors. The interval is number of
# seconds between attempts.
# resync_interval = 5

# The DHCP agent requires an interface driver be set. Choose the one that best
# matches your plugin.
# interface_driver =

# Example of interface_driver option for OVS based plugins(OVS, Ryu, NEC, NVP,
# BigSwitch/Floodlight)
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver

# Use veth for an OVS interface or not.
# Support kernels with limited namespace support
# (e.g. RHEL 6.5) so long as ovs_use_veth is set to True.
# ovs_use_veth = False

# Example of interface_driver option for LinuxBridge
# interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver

# The agent can use other DHCP drivers.  Dnsmasq is the simplest and requires
# no additional setup of the DHCP server.
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq

# Allow overlapping IP (Must have kernel build with CONFIG_NET_NS=y and
# iproute2 package that supports namespaces).
use_namespaces = True

# The DHCP server can assist with providing metadata support on isolated
# networks. Setting this value to True will cause the DHCP server to append
# specific host routes to the DHCP request.  The metadata service will only
# be activated when the subnet gateway_ip is None.  The guest instance must
# be configured to request host routes via DHCP (Option 121).
enable_isolated_metadata = True

# Allows for serving metadata requests coming from a dedicated metadata
# access network whose cidr is 169.254.169.254/16 (or larger prefix), and
# is connected to a Neutron router from which the VMs send metadata
# request. In this case DHCP Option 121 will not be injected in VMs, as
# they will be able to reach 169.254.169.254 through a router.
# This option requires enable_isolated_metadata = True
# enable_metadata_network = False

# Number of threads to use during sync process. Should not exceed connection
# pool size configured on server.
# num_sync_threads = 4

# Location to store DHCP server config files
# dhcp_confs = $state_path/dhcp

# Domain to use for building the hostnames
# dhcp_domain = openstacklocal

# Override the default dnsmasq settings with this file
# dnsmasq_config_file =

# Use another DNS server before any in /etc/resolv.conf.
# dnsmasq_dns_server =

# Limit number of leases to prevent a denial-of-service.
# dnsmasq_lease_max = 16777216

# Location to DHCP lease relay UNIX domain socket
# dhcp_lease_relay_socket = $state_path/dhcp/lease_relay

# Location of Metadata Proxy UNIX domain socket
# metadata_proxy_socket = $state_path/metadata_proxy

#Custom MTU value to support GRE tunneling within 1500MTU max
dnsmasq_config_file=/etc/neutron/dnsmasq-neutron.conf
" | sudo tee -a /etc/neutron/dhcp_agent.ini

echo "dhcp-option-force=26,1400" | sudo tee -a /etc/neutron/dnsmasq-neutron.conf

sudo service neutron-plugin-openvswitch-agent restart
sudo service neutron-dhcp-agent restart
sudo service neutron-l3-agent restart
sudo service neutron-metadata-agent restart
