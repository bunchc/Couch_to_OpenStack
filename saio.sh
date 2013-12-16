. /vagrant/common.sh

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH3_IP=$(ifconfig eth3 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

apt-get install -y memcached swift swift-proxy swift-object swift-account swift-container xfsprogs

echo "
n
p


t
83
w
" | sudo fdisk /dev/sdb

sudo mkfs -t xfs -L swift /dev/sdb1
sudo mkdir -p /mnt/sdb1
sudo mount /mnt/sdb1
sudo mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown -R swift:swift /mnt/sdb1/*
mkdir /srv
for x in {1..4}; do sudo ln -s /mnt/sdb1/$x /srv/$x; done
sudo mkdir -p /etc/swift/object-server /etc/swift/container-server /etc/swift/account-server /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4 /var/run/swift
sudo chown -R swift:swift /etc/swift /srv/[1-4]/ /var/run/swift

echo "
mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown swift:swift /var/cache/swift*
mkdir -p /var/run/swift
chown swift:swift /var/run/swift" | sudo tee -a /etc/rc.local

sudo rm -rf /etc/rsyncd.conf
echo "
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = ${MY_IP}

[account6012]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/account6012.lock

[account6022]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/account6022.lock

[account6032]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/account6032.lock

[account6042]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/account6042.lock

[container6011]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/container6011.lock

[container6021]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/container6021.lock

[container6031]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/container6031.lock

[container6041]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/container6041.lock

[object6010]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/object6010.lock

[object6020]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/object6020.lock

[object6030]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/object6030.lock

[object6040]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/object6040.lock" | sudo tee -a /etc/rsyncd.conf

sudo sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync

sudo service rsync restart
sudo sed -i 's/-l 127.0.0.1/-l ${MY_IP}/g' /etc/memcached.conf
sudo service memcached restart

echo "
# Uncomment the following to have a log containing all logs together
#local1,local2,local3,local4,local5.*   /var/log/swift/all.log

# Uncomment the following to have hourly proxy logs for stats processing
#$template HourlyProxyLog,"/var/log/swift/hourly/%$YEAR%%$MONTH%%$DAY%%$HOUR%"
#local1.*;local1.!notice ?HourlyProxyLog

local1.*;local1.!notice /var/log/swift/proxy.log
local1.notice           /var/log/swift/proxy.error
local1.*                ~

local2.*;local2.!notice /var/log/swift/storage1.log
local2.notice           /var/log/swift/storage1.error
local2.*                ~

local3.*;local3.!notice /var/log/swift/storage2.log
local3.notice           /var/log/swift/storage2.error
local3.*                ~

local4.*;local4.!notice /var/log/swift/storage3.log
local4.notice           /var/log/swift/storage3.error
local4.*                ~

local5.*;local5.!notice /var/log/swift/storage4.log
local5.notice           /var/log/swift/storage4.error
local5.*                ~" | sudo tee -a /etc/rsyslog.d/10-swift.conf

sudo sed -i 's/$PrivDropToGroup syslog/$PrivDropToGroup adm/g' /etc/rsyslog.conf
sudo mkdir -p /var/log/swift/hourly
sudo chown -R syslog.adm /var/log/swift
sudo chmod -R g+w /var/log/swift
sudo service rsyslog restart

echo "
[DEFAULT]
bind_ip = ${MY_IP}
bind_port = 8080
backlog = 4096
swift_dir = /etc/swift
workers = 8
user = swift
expiring_objects_container_divisor = 86400

# You can specify default log routing here if you want:
log_name = swift
log_facility = LOG_LOCAL0
log_level = INFO

[pipeline:main]
pipeline = catch_errors healthcheck cache authtoken keystoneauth proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true
set log_name = swift-proxy-server
set log_facility = LOG_LOCAL0
set log_level = DEBUG
set access_log_name = swift-proxy-server
set access_log_facility = LOG_LOCAL0
set access_log_level = DEBUG
set log_headers = True
 
[filter:healthcheck]
use = egg:swift#healthcheck
 
[filter:catch_errors]
use = egg:swift#catch_errors

[filter:cache]
use = egg:swift#memcache
memcache_servers = ${MY_IP}:11211
set log_name = cache

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = ${CONTROLLER_HOST}
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = swift
admin_password = swift
delay_auth_decision = 1
cache = swift.cache
signing_dir = /var/cache/swift

[filter:keystoneauth]
use = egg:swift#keystoneauth
# Operator roles is the role which user would be allowed to manage a
# tenant and be able to create container or give ACL to others.
operator_roles = admin, swiftoperator" | sudo tee -a /etc/swift/proxy-server.conf

echo "
[swift-hash]
# random unique strings that can never change (DO NOT LOSE)
swift_hash_path_prefix = changeme
swift_hash_path_suffix = changeme" | sudo tee -a /etc/swift/swift.conf

echo "
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6012
workers = 1
user = swift
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/1.conf

echo "
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6022
workers = 1
user = swift
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/2.conf

echo "
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6032
workers = 1
user = swift
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/3.conf

echo "
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6042
workers = 1
user = swift
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/4.conf

echo "
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6011
workers = 1
user = swift
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/1.conf

echo "
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6021
workers = 1
user = swift
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/2.conf

echo "
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6031
workers = 1
user = swift
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/3.conf

echo "
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6041
workers = 1
user = swift
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/4.conf

echo "
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6010
workers = 1
user = swift
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/1.conf

echo "
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6020
workers = 1
user = swift
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/2.conf

echo "
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6030
workers = 1
user = swift
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/3.conf

echo "
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6040
workers = 1
user = swift
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/4.conf

mkdir -p /home/swift/bin
sudo chown -R swift:swift /home/swift

echo "#!/bin/bash

swift-init all stop
find /var/log/swift -type f -exec rm -f {} \;
sudo umount /mnt/sdb1
sudo mkfs.xfs -f /dev/sdb1
sudo mount /mnt/sdb1
sudo mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown swift:swift /mnt/sdb1/*
mkdir -p /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4
sudo rm -f /var/log/debug /var/log/messages /var/log/rsyncd.log /var/log/syslog
find /var/cache/swift* -type f -name *.recon -exec rm -f {} \;
sudo service rsyslog restart
sudo service memcached restart" | sudo -u swift tee -a /home/swift/bin/resetswift

echo "
#!/bin/bash

cd /etc/swift

rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

swift-ring-builder object.builder create 18 3 1
swift-ring-builder object.builder add r1z1-172.16.80.220:6010/sdb1 1
swift-ring-builder object.builder add r1z2-172.16.80.220:6020/sdb2 1
swift-ring-builder object.builder add r1z3-172.16.80.220:6030/sdb3 1
swift-ring-builder object.builder add r1z4-172.16.80.220:6040/sdb4 1
swift-ring-builder object.builder rebalance
swift-ring-builder container.builder create 18 3 1
swift-ring-builder container.builder add r1z1-172.16.80.220:6011/sdb1 1
swift-ring-builder container.builder add r1z2-172.16.80.220:6021/sdb2 1
swift-ring-builder container.builder add r1z3-172.16.80.220:6031/sdb3 1
swift-ring-builder container.builder add r1z4-172.16.80.220:6041/sdb4 1
swift-ring-builder container.builder rebalance
swift-ring-builder account.builder create 18 3 1
swift-ring-builder account.builder add r1z1-172.16.80.220:6012/sdb1 1
swift-ring-builder account.builder add r1z2-172.16.80.220:6022/sdb2 1
swift-ring-builder account.builder add r1z3-172.16.80.220:6032/sdb3 1
swift-ring-builder account.builder add r1z4-172.16.80.220:6042/sdb4 1
swift-ring-builder account.builder rebalance" | sudo -u swift tee -a /home/swift/bin/remakerings

echo "
#!/bin/bash

swift-init main start" | sudo -u swift tee -a /home/swift/bin/startmain

echo "
#!/bin/bash

swift-init rest start" | sudo -u swift tee -a /home/swift/bin/startrest

sudo -u swift chmod +x /home/swift/bin/*
sudo -u swift /home/swift/bin/remakerings
sudo -u swift /home/swift/bin/startmain
sudo -u swift /home/swift/bin/startrest
