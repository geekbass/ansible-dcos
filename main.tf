# Find Public IP
data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

# Begin Variables 
variable "aws_ami" {
    description = "AMI to use"
    default = "ami-4bf3d731"
}

variable "cluster_name" {
    description = "Name of your DC/OS Cluster"
    default = "dcos-ansible"
}


variable "num_masters" {
    description = "Number of Masters"
    default = "3"
}

variable "num_private_agents" {
    description = "Number of Private Agents"
    default = "3"
}

variable "num_public_agents" {
    description = "Number of Public Agents"
    default = "1"
}

variable "ssh_public_key_file" {
    description = "SSH Key Location"
    default = "~/.ssh/id_rsa.pub"
}

# Begin Module
module "dcos-infrastructure" {
  source  = "dcos-terraform/infrastructure/aws"
  #version = "~> 0.1"

  admin_ips              = ["${data.http.whatismyip.body}/32"]
  aws_ami                = "${var.aws_ami}"
  cluster_name           = "${var.cluster_name}"
  num_masters            = "${var.num_masters}"
  num_private_agents     = "${var.num_private_agents}"
  num_public_agents      = "${var.num_public_agents}"
  ssh_public_key_file    = "${var.ssh_public_key_file}"
}

# Begin Outputs
output "bootstraps" {
    description = "bootsrap IPs"
    value = "${join("\n", flatten(list(module.dcos-infrastructure.bootstrap.public_ip)))}"
}

output "bootstrap_private_ip" {
    description = "bootsrap IPs"
    value = "${module.dcos-infrastructure.bootstrap.private_ip}"
}
output "masters" {
    description = "masters IPs"
    value = "${join("\n", flatten(list(module.dcos-infrastructure.masters.public_ips)))}"
}

output "masters_private_ips" {
    description = "List of private IPs for Masters (for DCOS config)"
    value       = "${join("\n", flatten(list(module.dcos-infrastructure.masters.private_ips)))}"
}

output "private_agents" {
    description = "Private Agents IPs"
    value = "${join("\n", flatten(list(module.dcos-infrastructure.private_agents.public_ips)))}"    
}

output "public_agents" {
    description = "Public Agents IPs"
    value = "${join("\n", flatten(list(module.dcos-infrastructure.public_agents.public_ips)))}"
}

# Locals
locals {
    bootstrap_ansible_ips = "${join("\n", flatten(list(module.dcos-infrastructure.bootstrap.public_ip)))}"
    bootstrap_ansible_private_ips = "${module.dcos-infrastructure.bootstrap.private_ip}"
    masters_ansible_ips = "${join("\n", flatten(list(module.dcos-infrastructure.masters.public_ips)))}"
    masters_ansible_private_ips = "${join("\n - ", flatten(list(module.dcos-infrastructure.masters.private_ips)))}"
    private_agents_ansible_ips = "${join("\n", flatten(list(module.dcos-infrastructure.private_agents.public_ips)))}"    
    public_agents_ansible_ips = "${join("\n", flatten(list(module.dcos-infrastructure.public_agents.public_ips)))}"
}

resource "local_file" "inventory" {
  filename = "./inventory"

  content = <<EOF
[bootstraps]
${local.bootstrap_ansible_ips}

[masters]
${local.masters_ansible_ips}

[agents_private]
${local.private_agents_ansible_ips}

[agents_public]
${local.public_agents_ansible_ips}

[bootstraps:vars]
node_type=bootstrap

[masters:vars]
node_type=master
dcos_legacy_node_type_name=master

[agents_private:vars]
node_type=agent
dcos_legacy_node_type_name=slave

[agents_public:vars]
node_type=agent_public
dcos_legacy_node_type_name=slave_public

[agents:children]
agents_private
agents_public

[common:children]
bootstraps
masters
agents
agents_public
EOF
}

/*
---
dcos:
  download: "https://downloads.dcos.io/dcos/EarlyAccess/dcos_generate_config.sh"
  version: "1.12.0-beta1"
  # version_to_upgrade_from: "1.12.0-dev"
  # image_commit: "acc9fe548aea5b1b5b5858a4b9d2c96e07eeb9de"
  enterprise_dcos: true

  selinux_mode: enforcing

  config:
    # This is a direct yaml representation of the DC/OS config.yaml
    # Please see https://docs.mesosphere.com/1.12/installing/production/advanced-configuration/configuration-reference/
    # for parameter reference.
    cluster_name: "examplecluster"
    security: strict
    bootstrap_url: http://int-bootstrap1-examplecluster.example.com:8080
    exhibitor_storage_backend: static
    master_discovery: static
    master_list:
      - 172.31.2.95
*/
