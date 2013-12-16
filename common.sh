source /vagrant/.controller
source /vagrant/.proxy
export DEBIAN_FRONTEND=noninteractive

# Setup Proxy
export APT_PROXY=${PROXY_HOST}
export APT_PROXY_PORT=3142
#
# If you have a proxy outside of your VirtualBox environment, use it
if [[ ! -z "$APT_PROXY" ]]
then
	echo 'Acquire::http { Proxy "http://'${APT_PROXY}:${APT_PROXY_PORT}'"; };' | sudo tee /etc/apt/apt.conf.d/01apt-cacher-ng-proxy
fi

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update

# Grizzly Goodness
sudo apt-get -y install ubuntu-cloud-keyring
echo "grub-pc	grub-pc/install_devices	multiselect	/dev/sda" | sudo debconf-set-selections
echo "deb  http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/havana main" | sudo tee -a /etc/apt/sources.list.d/havana.list
sudo apt-get update && sudo apt-get dist-upgrade -y

