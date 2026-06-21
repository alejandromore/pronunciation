#######################################
# VPC
#######################################
resource "huaweicloud_vpc" "vpc_service" {
  name   = local.vpc_name
  cidr   = var.vpc_cidr
  region = var.region

  enterprise_project_id = data.huaweicloud_enterprise_project.ep.id
  tags                  = local.tags
}

#######################################
# Subnet
#######################################
resource "huaweicloud_vpc_subnet" "subnet_main" {
  vpc_id            = huaweicloud_vpc.vpc_service.id
  name              = local.subnet_name
  cidr              = var.subnet_cidr
  gateway_ip        = var.subnet_gateway_ip
  description       = "Pronunciation Trainer Main Subnet"
  dns_list          = var.dns_list
  dhcp_enable       = true
  availability_zone = data.huaweicloud_availability_zones.myaz.names[0]

  tags = local.tags
}

#######################################
# Shared Bandwidth
#######################################
resource "huaweicloud_vpc_bandwidth" "bandwidth_shared" {
  name = local.bandwidth_name
  size = var.bandwidth_size
}
