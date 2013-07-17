source /vagrant/common.sh

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

export CONTROLLER_HOST=${MY_IP}
export GLANCE_HOST=${CONTROLLER_HOST}
export MYSQL_HOST=${CONTROLLER_HOST}
export KEYSTONE_ENDPOINT=${CONTROLLER_HOST}
export SERVICE_TENANT_NAME=service
export SERVICE_PASS=openstack
export ENDPOINT=${KEYSTONE_ENDPOINT}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://${ENDPOINT}:35357/v2.0

# MySQL
export MYSQL_HOST=$MY_IP
export MYSQL_ROOT_PASS=openstack
export MYSQL_DB_PASS=openstack

echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password seen true" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again seen true" | sudo debconf-set-selections

sudo apt-get -y install mysql-server python-mysqldb

sudo sed -i "s/^bind\-address.*/bind-address = 0.0.0.0/g" /etc/mysql/my.cnf
sudo sed -i "s/^#max_connections.*/max_connections = 512/g" /etc/mysql/my.cnf

# Skip Name Resolve
echo "[mysqld]
skip-name-resolve" > /etc/mysql/conf.d/skip-name-resolve.cnf

sudo restart mysql

# Ensure root can do its job
mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"localhost\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"
mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"${MYSQL_HOST}\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"
mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"%\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"

mysqladmin -uroot -p${MYSQL_ROOT_PASS} flush-privileges

sudo apt-get -y install keystone python-keyring

MYSQL_ROOT_PASS=openstack
MYSQL_KEYSTONE_PASS=openstack
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE keystone;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "SET PASSWORD FOR 'keystone'@'%' = PASSWORD('$MYSQL_KEYSTONE_PASS');"

sudo sed -i "s#^connection.*#connection = mysql://keystone:openstack@${MYSQL_HOST}/keystone#" /etc/keystone/keystone.conf

sudo sed -i 's/^# admin_token.*/admin_token = ADMIN/' /etc/keystone/keystone.conf

sudo stop keystone
sudo start keystone

sudo keystone-manage db_sync

sudo apt-get -y install python-keystoneclient

export ENDPOINT=${MY_IP}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://${ENDPOINT}:35357/v2.0

# admin role
keystone role-create --name admin

# Member role
keystone role-create --name Member

keystone tenant-create --name cookbook --description "Default Cookbook Tenant" --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ cookbook\ / {print $2}')

export PASSWORD=openstack
keystone user-create --name admin --tenant_id $TENANT_ID --pass $PASSWORD --email root@localhost --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ cookbook\ / {print $2}')

ROLE_ID=$(keystone role-list | awk '/\ admin\ / {print $2}')

USER_ID=$(keystone user-list | awk '/\ admin\ / {print $2}')

keystone user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

# Create the user
PASSWORD=openstack
keystone user-create --name demo --tenant_id $TENANT_ID --pass $PASSWORD --email demo@localhost --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ cookbook\ / {print $2}')

ROLE_ID=$(keystone role-list | awk '/\ Member\ / {print $2}')

USER_ID=$(keystone user-list | awk '/\ demo\ / {print $2}')

# Assign the Member role to the demo user in cookbook
keystone user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

# Keystone Identity Service Endpoint
keystone service-create --name keystone --type identity --description 'OpenStack Identity Service'

# Keystone OpenStack Identity Service
KEYSTONE_SERVICE_ID=$(keystone service-list | awk '/\ keystone\ / {print $2}')

PUBLIC="http://$ENDPOINT:5000/v2.0"
ADMIN="http://$ENDPOINT:35357/v2.0"
INTERNAL=$PUBLIC

keystone endpoint-create --region RegionOne --service_id $KEYSTONE_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# Service Tenant
keystone tenant-create --name service --description "Service Tenant" --enabled true

SERVICE_TENANT_ID=$(keystone tenant-list | awk '/\ service\ / {print $2}')
keystone user-create --name keystone --pass keystone --tenant_id $SERVICE_TENANT_ID --email keystone@localhost --enabled true

# Get the admin role id
ADMIN_ROLE_ID=$(keystone role-list | awk '/\ admin\ / {print $2}')
KEYSTONE_USER_ID=$(keystone user-list | awk '/\ keystone\ / {print $2}')

# Assign the keystone user the admin role in service tenant
keystone user-role-add --user $KEYSTONE_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

# Create a .stackrc file
cat > /root/.stackrc <<EOF
export OS_TENANT_NAME=cookbook
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://${MY_IP}:5000/v2.0/
EOF
