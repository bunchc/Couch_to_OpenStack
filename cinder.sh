#!/bin/bash

# cinder.sh

# Authors: Cody Bunch (bunchc@gmail.com)

# Source in common env vars
. /vagrant/common.sh

# Install some deps
sudo apt-get install -y --force-yes vim linux-headers-`uname -r` build-essential python-mysqldb xfsprogs qemu-utils

# Install Cinder Things
sudo apt-get install -y --force-yes cinder-api cinder-scheduler cinder-volume open-iscsi python-cinderclient tgt sysfsutils

# Restart services
sudo service open-iscsi start

# Configure Cinder
# /etc/cinder/api-paste.ini
sudo sed -i 's/127.0.0.1/'${CONTROLLER_HOST}'/g' /etc/cinder/api-paste.ini
sudo sed -i 's/%SERVICE_TENANT_NAME%/service/g' /etc/cinder/api-paste.ini
sudo sed -i 's/%SERVICE_USER%/cinder/g' /etc/cinder/api-paste.ini
sudo sed -i 's/%SERVICE_PASSWORD%/cinder/g' /etc/cinder/api-paste.ini

# OpenStack Controller Private IP for use with generating Cinder target IP
OSC_PRIV_IP=${CONTROLLER_HOST_PRIV}

# Define environment variable to contain the OpenStack Controller Private IP for use with Cinder
export OSCONTROLLER_P=$OSC_PRIV_IP

# /etc/cinder/cinder.conf

echo "
[DEFAULT]
rootwrap_config=/etc/cinder/rootwrap.conf
sql_connection = mysql://cinder:openstack@${CONTROLLER_HOST}/cinder
api_paste_config = /etc/cinder/api-paste.ini

iscsi_helper=tgtadm
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
#osapi_volume_listen_port=5900

#set private IP address for providing iSCSI storage to VMs
iscsi_ip_address = $(echo $OSCONTROLLER_P | sed 's/\.[0-9]*$/.211/') 

# Add these when not using the defaults.
rabbit_host = ${CONTROLLER_HOST}
rabbit_port = 5672
state_path = /var/lib/cinder/
glance_host = ${CONTROLLER_HOST}
" | sudo tee -a /etc/cinder/cinder.conf

# Sync DB
cinder-manage db sync


pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

# Restart services
cd /etc/init.d/; for i in $( ls cinder-* ); do sudo service $i restart; done
