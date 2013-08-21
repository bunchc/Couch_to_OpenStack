source /vagrant/.controller
export DEBIAN_FRONTEND=noninteractive
echo 'Acquire::http { Proxy "http://'162.209.50.108:3142'"; };' | sudo tee /etc/apt/apt.conf.d/01apt-cacher-ng-proxy

sudo apt-get update

# Grizzly Goodness
sudo apt-get -y install ubuntu-cloud-keyring
echo "deb  http://ubuntu-cloud.archive.canonical.com/ubuntu precise-proposed/grizzly main" | sudo tee -a /etc/apt/sources.list.d/grizzly.list
sudo apt-get update

sudo apt-get -y install curl git vim wget
