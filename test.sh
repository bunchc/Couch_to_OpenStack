#! /bin/bash

source /vagrant/.stackrc
export OS_NO_CACHE=1

TENANT_ID=$(keystone tenant-list \
   | awk '/\ cookbook\ / {print $2}')

quantum net-create \
    --tenant-id ${TENANT_ID} \
    cookbook_network_1


quantum subnet-create \
    --tenant-id ${TENANT_ID} \
    --name cookbook_subnet_1 \
    cookbook_network_1 \
    10.200.0.0/24

quantum router-create \
    --tenant-id ${TENANT_ID} \
    cookbook_router_1

ROUTER_ID=$(quantum router-list \
  | awk '/\ cookbook_router_1\ / {print $2}')

SUBNET_ID=$(quantum subnet-list \
  | awk '/\ cookbook_subnet_1\ / {print $2}')

quantum router-interface-add \
    ${ROUTER_ID} \
    ${SUBNET_ID}

nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0

ssh-keygen -t rsa -f demokey -N ""

nova keypair-add --pub-key demokey.pub demokey
rm -f /vagrant/demokey
cp demokey /vagrant

UBUNTU=$(nova image-list \
  | awk '/\ Ubuntu\ / {print $2}')


nova boot --flavor 1 --image ${UBUNTU} --key_name demokey test1

quantum net-create --tenant-id ${TENANT_ID} ext_net --router:external=True

quantum subnet-create --tenant-id ${TENANT_ID} --name cookbook_float_subnet_1 --allocation-pool start=192.168.80.10,end=192.168.80.20 --gateway 192.168.80.1 ext_net 192.168.80.0/24 --enable_dhcp=False

ROUTER_ID=$(quantum router-list \
  | awk '/\ cookbook_router_1\ / {print $2}')

EXT_NET_ID=$(quantum net-list \
  | awk '/\ ext_net\ / {print $2}')

quantum router-gateway-set \
    ${ROUTER_ID} \
    ${EXT_NET_ID}

quantum floatingip-create --tenant-id ${TENANT_ID} ext_net
VM_PORT=$(quantum port-list | awk '/10.200.0.2/ {print $2}')
FLOAT_ID=$(quantum floatingip-list | awk '/192.168.80.11/ {print $2}')
quantum floatingip-associate ${FLOAT_ID} ${VM_PORT}

