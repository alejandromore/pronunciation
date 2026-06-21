#######################################
# Security Group del ECS app
#  El ECS tiene EIP directa: nginx termina TLS en el propio ECS.
#   - 443 (HTTPS) desde Internet  -> microfono del navegador exige contexto seguro.
#   - 80  (HTTP) desde Internet   -> redireccion a HTTPS.
#   - 22  (SSH) solo desde ssh_admin_cidr (runner Jenkins / admin).
#######################################

resource "huaweicloud_networking_secgroup" "sg_app" {
  name                  = local.sg.app
  enterprise_project_id = data.huaweicloud_enterprise_project.ep.id
}

resource "huaweicloud_networking_secgroup_rule" "app_https" {
  security_group_id = huaweicloud_networking_secgroup.sg_app.id

  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 443
  port_range_max   = 443
  remote_ip_prefix = "0.0.0.0/0"

  description = "Allow HTTPS from Internet"
}

resource "huaweicloud_networking_secgroup_rule" "app_http" {
  security_group_id = huaweicloud_networking_secgroup.sg_app.id

  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 80
  port_range_max   = 80
  remote_ip_prefix = "0.0.0.0/0"

  description = "Allow HTTP from Internet (redirect to HTTPS)"
}

resource "huaweicloud_networking_secgroup_rule" "app_ssh" {
  security_group_id = huaweicloud_networking_secgroup.sg_app.id

  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 22
  port_range_max   = 22
  remote_ip_prefix = var.ssh_admin_cidr

  description = "SSH directo desde la red de administracion/Jenkins"
}
