# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrant configuration for Elastic Stack 9.x development environment
# Creates a 3-node Docker Swarm cluster for running Elasticsearch, Kibana, and Beats

$docker_swarm_init = <<SCRIPT
docker swarm init --advertise-addr 192.168.99.101 --listen-addr 192.168.99.101:2377
docker swarm join-token --quiet worker > /vagrant/worker_token
docker swarm join-token --quiet manager > /vagrant/manager_token
SCRIPT

$system_setup = <<SCRIPT
# Update system
apt-get update -qq

# Install required packages
apt-get install -y -qq auditd audispd-plugins curl jq

# Set vm.max_map_count for Elasticsearch (persists across reboots)
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
sysctl -w vm.max_map_count=262144

# Set file descriptor limits for Elasticsearch
cat >> /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 4096
* hard nproc 4096
EOF

# Disable swap (recommended for Elasticsearch)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
SCRIPT

Vagrant.configure("2") do |config|
  # Ubuntu 22.04 LTS (Jammy Jellyfish)
  # https://app.vagrantup.com/bento/boxes/ubuntu-22.04
  config.vm.box = "bento/ubuntu-22.04"

  # Host Manager plugin configuration
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true

  # Common provisioning for all nodes
  config.vm.provision :shell, inline: $system_setup
  config.vm.provision "docker"

  # Node 1: Docker Swarm Manager (Elasticsearch Master)
  config.vm.define "node1", primary: true do |node1|
    node1.vm.hostname = 'node1'
    node1.vm.network :private_network, ip: "192.168.99.101"
    node1.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 10240]  # 10GB for ES master
      v.customize ["modifyvm", :id, "--cpus", 2]
      v.customize ["modifyvm", :id, "--name", "node1"]
    end
    node1.vm.provision :shell, inline: $docker_swarm_init
  end

  # Node 2: Docker Swarm Worker (Elasticsearch Data Node)
  config.vm.define "node2" do |node2|
    node2.vm.hostname = 'node2'
    node2.vm.network :private_network, ip: "192.168.99.102"
    node2.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 10240]  # 10GB for ES data
      v.customize ["modifyvm", :id, "--cpus", 2]
      v.customize ["modifyvm", :id, "--name", "node2"]
    end
    node2.vm.provision :shell, inline: "docker swarm join --token $(cat /vagrant/worker_token) 192.168.99.101:2377"
  end

  # Node 3: Separate Swarm for Beats testing
  config.vm.define "node3" do |node3|
    node3.vm.hostname = 'node3'
    node3.vm.network :private_network, ip: "192.168.99.103"
    node3.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 4096]  # 4GB for Beats
      v.customize ["modifyvm", :id, "--cpus", 1]
      v.customize ["modifyvm", :id, "--name", "node3"]
    end
    node3.vm.provision :shell, inline: "docker swarm init --advertise-addr 192.168.99.103 --listen-addr 192.168.99.103:2377"
  end

end
