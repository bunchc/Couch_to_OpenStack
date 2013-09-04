apt-get install -y nagios3 nagios-nrpe-plugin
usermod -a -G nagios www-data
chmod -R g+x /var/lib/nagios3/
sed -i 's/check_external_commands=0/check_external_commands=1/g' /etc/nagios3/nagios.cfg
htpasswd -c /etc/nagios3/htpasswd.users nagiosadmin
service nagios3 restart && service apache2 restart