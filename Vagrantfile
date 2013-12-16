# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'securerandom'

# comment the 'proxy' entry to below to save on host resources
# swift all-in-one (saio) node is disabled by default, uncomment to enable 
nodes = {
    'proxy' => [1,10],
    'controller'  => [1, 200],
    'compute'  => [1, 201],
    'cinder' => [1, 211],
    'neutron' => [1, 202],
#    'saio'   => [1, 220],
}



# This is some magic to help avoid network collisions.
# If however, it still collides, or if you need to vagrant up machines one at a time, comment out this line and uncomment the one below it
#third_octet = SecureRandom.random_number(200)
third_octet = 80

Vagrant.configure("2") do |config|
  # We assume virtualbox, if using Fusion, you'll want to change this as needed
  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  config.vm.provider "vmware_fusion" do |v, override|
    override.vm.box = "precise64"
    override.vm.box_url = "http://files.vagrantup.com/precise64_vmware.box"
  end

#  config.vm.synced_folder ".", "/vagrant", nfs: true

  nodes.each do |prefix, (count, ip_start)|
    count.times do |i|
      hostname = "%s" % [prefix, (i+1)]
        config.vm.define "#{hostname}" do |box|
          box.vm.hostname = "#{hostname}.book"
          box.vm.network :private_network, ip: "172.16.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"
          box.vm.network :private_network, ip: "10.10.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"
          box.vm.network :private_network, ip: "192.168.#{third_octet}.#{ip_start+i}", :netmask => "255.255.255.0"

          # Run the Shell Provisioning Script file
          box.vm.provision :shell, :path => "#{prefix}.sh"

          # If using VMware Fusion
          box.vm.provider :vmware_fusion do |v|
          # Default  
            v.vmx["memsize"] = 1024
            if prefix == "compute"
              v.vmx["memsize"] = 2048
              v.vmx["numvcpus"] = 2
            elsif prefix == "controller"
              v.vmx["memsize"] = 1024
            elsif prefix == "client" or prefix == "proxy"
              v.vmx["memsize"] = 512
            end
          end

          # If using VMware Workstation
          box.vm.provider :vmware_workstation do |v|
          # Default  
            v.vmx["memsize"] = 1024
            if prefix == "compute"
              v.vmx["memsize"] = 3128
              v.vmx["numvcpus"] = 2
            elsif prefix == "controller"
              v.vmx["memsize"] = 2048
            elsif prefix == "client" or prefix == "proxy"
              v.vmx["memsize"] = 512
            end
          end

          # If using VirtualBox
          box.vm.provider :virtualbox do |vbox|
	  # Defaults
            vbox.customize ["modifyvm", :id, "--memory", 768]
            vbox.customize ["modifyvm", :id, "--cpus", 1]
            if prefix == "compute"
              vbox.customize ["modifyvm", :id, "--memory", 2048]
              vbox.customize ["modifyvm", :id, "--cpus", 2]
              vbox.customize ["modifyvm", :id, "--nicpromisc4", "allow-all"]
            elsif prefix == "client" or prefix == "proxy"
              vbox.customize ["modifyvm", :id, "--memory", 512]
	        elsif prefix == "neutron"
              vbox.customize ["modifyvm", :id, "--nicpromisc4", "allow-all"]
            elsif prefix == "cinder"
              vbox.customize ["createhd", "--filename", "cinder_disk_2.vdi", "--size", 2000 * 1024]
              vbox.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--type","hdd", "--medium","cinder_disk_2.vdi"]
           end
          end  
        end
      end
    end
  end

