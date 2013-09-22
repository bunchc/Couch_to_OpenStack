. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Install some packages:
sudo apt-get -y install vim python-keystoneclient python-glanceclient python-novaclient python-cinderclient python-quantumclient

# Install Nagios
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
echo "nagios3-cgi nagios3/adminpassword password nagiosadmin" | sudo debconf-set-selections
echo "nagios3-cgi nagios3/adminpassword-repeat password nagiosadmin" | sudo debconf-set-selections

sudo apt-get install -y nagios3 nagios-nrpe-plugin

# Create our Nagios Hosts
sudo cat > /etc/nagios3/conf.d/controller.cfg <<EOF
# Generic host definition template - This is NOT a real host, just a template!

define host{
        host_name                       controller.cook.book
        address                         172.16.80.200
        notifications_enabled           1       ; Host notifications are enabled
        event_handler_enabled           1       ; Host event handler is enabled
        flap_detection_enabled          1       ; Flap detection is enabled
        failure_prediction_enabled      1       ; Failure prediction is enabled
        process_perf_data               1       ; Process performance data
        retain_status_information       1       ; Retain status information across program restarts
        retain_nonstatus_information    1       ; Retain non-status information across program restarts
                check_command                   check-host-alive
                max_check_attempts              10
                notification_interval           0
                notification_period             24x7
                notification_options            d,u,r
                contact_groups                  admins
        register                        1       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL HOST, JUST A TEMPLATE!
        }
EOF

sudo cp /etc/nagios3/conf.d/controller.cfg /etc/nagios3/conf.d/compute.cfg
sudo cp /etc/nagios3/conf.d/controller.cfg /etc/nagios3/conf.d/cinder.cfg
sudo cp /etc/nagios3/conf.d/controller.cfg /etc/nagios3/conf.d/quantum.cfg
sudo sed -i "s/controller/compute/" /etc/nagios3/conf.d/compute.cfg
sudo sed -i "s/172.16.80.200/172.16.80.201/" /etc/nagios3/conf.d/compute.cfg
sudo sed -i "s/controller/cinder/" /etc/nagios3/conf.d/cinder.cfg
sudo sed -i "s/172.16.80.200/172.16.80.211/" /etc/nagios3/conf.d/cinder.cfg
sudo sed -i "s/controller/quantum/" /etc/nagios3/conf.d/quantum.cfg
sudo sed -i "s/172.16.80.200/172.16.80.202/" /etc/nagios3/conf.d/quantum.cfg

# Nagios config for OpenStac "Controller"
# That is to say, Horizon, Keystone, Glance, Quantum-API, OVS
sudo cat > /etc/nagios3/conf.d/openstack_service.cfg <<EOF
# Controller Services

# Horizon
define service {
        host_name                       controller.cook.book
        service_description             Horizon
        check_command                   check_nrpe_1arg!check_horizon
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

# Keystone
define service {
        host_name                       controller.cook.book
        service_description             Keystone-HTTP
        check_command                   check_nrpe_1arg!check_keystone_http
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       controller.cook.book
        service_description             Keystone-Proc
        check_command                   check_nrpe_1arg!check_keystone_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

# Glance
define service {
        host_name                       controller.cook.book
        service_description             Glance-HTTP
        check_command                   check_nrpe_1arg!check_glance_http
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       controller.cook.book
        service_description             Glance-Proc
        check_command                   check_nrpe_1arg!check_glance_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

# Neutron / Quantum
define service {
        host_name                       controller.cook.book
        service_description             Quantum-API-HTTP
        check_command                   check_nrpe_1arg!check_quantum_api_http
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       controller.cook.book
        service_description             Quantum-API-Proc
        check_command                   check_nrpe_1arg!check_quantum_api_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}
EOF

# Nagios services configuration for Compute Services
sudo cat > /etc/nagios3/conf.d/openstack_compute_services.cfg <<EOF
# Compute all the computes

define service {
        host_name                       compute.cook.book
        service_description             Nova Processes
        check_command                   check_nrpe_1arg!check_nova_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       compute.cook.book
        service_description             Quantum Services
        check_command                   check_nrpe_1arg!check_quantum_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       compute.cook.book
        service_description             Open vSwitch - ovswitchd
        check_command                   check_nrpe_1arg!check_ovswitch_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}
define service {
        host_name                       compute.cook.book
        service_description             Open vSwitch - ovsdb-server
        check_command                   check_nrpe_1arg!check_ovswitch_server_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

EOF

# Nagios services configuration for Cinder Node
sudo cat > /etc/nagios3/conf.d/openstack_cinder_services.cfg <<EOF
# Cinder
define service {
        host_name                       cinder.cook.book
        service_description             Cinder-API-HTTP
        check_command                   check_nrpe_1arg!check_cinder_http
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       cinder.cook.book
        service_description             Cinder-API-Proc
        check_command                   check_nrpe_1arg!check_cinder_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}
EOF

# Nagios services configuration for Quantum Node
sudo cat > /etc/nagios3/conf.d/openstack_quantum_services.cfg <<EOF
# Yes Quantum, it's Grizzly, prior to the name change ;-)
define service {
        host_name                       quantum.cook.book
        service_description             Quantum-ovsdb-server
        check_command                   check_nrpe_1arg!check_ovsdbserver
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       quantum.cook.book
        service_description             Quantum-ovs-vswitchd
        check_command                   check_nrpe_1arg!check_ovsvswitchd
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}

define service {
        host_name                       quantum.cook.book
        service_description             Quantum-API-Proc
        check_command                   check_nrpe_1arg!check_quantum_proc
        use                             generic-service
        notification_interval           0 ; set > 0 if you want to be renotified
}
EOF

# Restart the service
sudo service nagios3 restart