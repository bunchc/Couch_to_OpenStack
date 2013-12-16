#!/bin/sh

source /vagrant/.stackrc

TENANT_ID=$(keystone tenant-list \
   | awk '/\ cookbook\ / {print $2}')

neutron net-create \
    --tenant-id ${TENANT_ID} \
    cookbook_network_1

neutron subnet-create \
    --tenant-id ${TENANT_ID} \
    --name cookbook_subnet_1 \
    cookbook_network_1 \
    10.200.0.0/24

neutron router-create \
    --tenant-id ${TENANT_ID} \
    cookbook_router_1

ROUTER_ID=$(neutron router-list \
  | awk '/\ cookbook_router_1\ / {print $2}')

SUBNET_ID=$(neutron subnet-list \
  | awk '/\ cookbook_subnet_1\ / {print $2}')

neutron router-interface-add \
    ${ROUTER_ID} \
    ${SUBNET_ID}

nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0

ssh-keygen -t rsa -f demokey -N ""

nova keypair-add --pub-key demokey.pub demokey
rm -f /vagrant/demokey
cp demokey /vagrant

CIRROS=$(nova image-list \
  | awk '/\ Cirros\ / {print $2}')


nova boot --flavor 1 --image ${CIRROS} --key_name demokey test1

neutron net-create --tenant-id ${TENANT_ID} ext_net --router:external=True

neutron subnet-create --tenant-id ${TENANT_ID} --name cookbook_float_subnet_1 --allocation-pool start=192.168.100.10,end=192.168.100.20 --gateway 192.168.100.1 ext_net 192.168.100.0/24 --enable_dhcp=False

ROUTER_ID=$(neutron router-list \
  | awk '/\ cookbook_router_1\ / {print $2}')

EXT_NET_ID=$(neutron net-list \
  | awk '/\ ext_net\ / {print $2}')

neutron router-gateway-set \
    ${ROUTER_ID} \
    ${EXT_NET_ID}

neutron floatingip-create --tenant-id ${TENANT_ID} ext_net
VM_PORT=$(neutron port-list | awk '/10.200.0.2/ {print $2}')
FLOAT_ID=$(neutron floatingip-list | awk '/192.168.100.11/ {print $2}')
neutron floatingip-associate ${FLOAT_ID} ${VM_PORT}

