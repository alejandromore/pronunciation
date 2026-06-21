#######################################
# Enterprise Project
#######################################
data "huaweicloud_enterprise_project" "ep" {
  name = local.enterprise_project_name
}

#######################################
# Availability Zones
#######################################
data "huaweicloud_availability_zones" "myaz" {}

#######################################
# IAM Project (tenant_id) por region
#######################################
data "huaweicloud_identity_projects" "current" {
  name = var.region
}
