# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'securerandom'

nodes = {
    'controller'  => [1, 200],
    'compute'  => [1, 201],
}

# This is some magic to help avoid network collisions.
# If however, it still collides, comment out this line and uncomment the one below it
third_octet = SecureRandom.random_number(200)
#third_octet = 172

Vagrant.configure("2") do |config|
    # We assume virtualbox, if using Fusion, you'll want to change this as needed
    config.vm.box = "precise64"
    config.vm.box_url = "http://files.vagrantup.com/precise64.box"
    #VMware Fusion Users: Comment the line above and uncomment the line below
    #config.vm.box_url = "http://files.vagrantup.com/precise64_vmware.box"
    
    nodes.each do |prefix, (count, ip_start)|
        count.times do |i|
            hostname = "%s" % [prefix, (i+1)]

            config.vm.define "#{hostname}" do |box|
                box.vm.hostname = "#{hostname}.book"
                box.vm.network :private_network, ip: "172.16.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"
                box.vm.network :private_network, ip: "10.10.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"

                # Run the controller.sh file
                box.vm.provision :shell, :path => "#{prefix}.sh"

                # If using Fusion
                box.vm.provider :vmware_fusion do |v|
                # Default  
                  v.vmx["memsize"] = 1024
        	        if prefix == "compute"
	              	  v.vmx["memsize"] = 3128
                    v.vmx["numvcpus"] = 2
	                elsif prefix == "controller"
    	              v.vmx["memsize"] = 2048
	                end
                end

                # Otherwise using VirtualBox
                box.vm.provider :virtualbox do |vbox|
	              # Defaults
                  vbox.customize ["modifyvm", :id, "--memory", 1024]
                  vbox.customize ["modifyvm", :id, "--cpus", 1]
		              if prefix == "compute"
                    	vbox.customize ["modifyvm", :id, "--memory", 3128]
                      vbox.customize ["modifyvm", :id, "--cpus", 2]
		              elsif prefix == "controller"
		                  vbox.customize ["modifyvm", :id, "--memory", 2048]
		              end
                end
            end
        end
    end
end