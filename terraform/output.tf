#######################################
# ECS App (IP publica directa)
#######################################
output "app_public_ip" {
  value = huaweicloud_vpc_eip.eip_app.address
}

output "app_private_ip" {
  value = huaweicloud_compute_instance.ecs_app.network[0].fixed_ip_v4
}

# URL HTTPS publica de la app (acepta el aviso de cert self-signed la 1a vez).
output "app_https_url" {
  value = "https://${huaweicloud_vpc_eip.eip_app.address}"
}

#######################################
# Llave privada del ECS (desde DEW) para que Jenkins/Ansible hagan SSH directo
#######################################
data "huaweicloud_csms_secret_version" "key_data" {
  secret_name = var.private_key_name
}

output "ecs_private_key" {
  value     = data.huaweicloud_csms_secret_version.key_data.secret_text
  sensitive = true
}

#######################################
# OBS: bucket del CSV (lo consume el contenedor via agency)
#######################################
output "obs_data_bucket" {
  value = huaweicloud_obs_bucket.data.bucket
}

output "obs_csv_key" {
  value = local.obs_csv_key
}

output "project_id" {
  value = data.huaweicloud_identity_projects.current.projects[0].id
}
