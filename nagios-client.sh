apt-get install -y nagios-plugins nagios-nrpe-server
sed -i 's/127.0.0.1/172.16.80.100/g' /etc/nagios/nrpe.cfg
service nagios-nrpe-server restart
