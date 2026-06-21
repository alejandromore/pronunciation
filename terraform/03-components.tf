#######################################
# EIP del ECS app (IP publica directa)
#  Da entrada (HTTPS/SSH) y salida a internet (pull de imagenes, apt, NVIDIA
#  toolkit, modelo Whisper). Por eso ya NO hace falta NAT Gateway.
#######################################
resource "huaweicloud_vpc_eip" "eip_app" {
  name = local.eip.app

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    share_type = "WHOLE"
    id         = huaweicloud_vpc_bandwidth.bandwidth_shared.id
  }

  charging_mode         = "postPaid"
  enterprise_project_id = data.huaweicloud_enterprise_project.ep.id
  tags                  = local.tags
}

#######################################
# OBS: bucket del CSV de palabras
#  Terraform crea el bucket y SUBE el data_en.csv que generamos. El usuario
#  puede editar ese objeto en la consola/OBS; al reiniciar el ECS, el contenedor
#  vuelve a descargarlo (ver entrypoint del trainer).
#######################################
resource "huaweicloud_obs_bucket" "data" {
  bucket                = local.obs.data
  acl                   = "private"
  force_destroy         = true
  enterprise_project_id = data.huaweicloud_enterprise_project.ep.id

  tags = local.tags
}

resource "huaweicloud_obs_bucket_object" "data_en" {
  bucket       = huaweicloud_obs_bucket.data.bucket
  key          = local.obs_csv_key
  source       = "${path.module}/../images/pronunciation-trainer/data_en.csv"
  content_type = "text/csv"

  # Si vuelves a aplicar Terraform tras editar el objeto en OBS a mano, este
  # recurso lo re-subiria (sobreescribe con la version del repo). Si quieres que
  # OBS sea la fuente de verdad y Terraform NO lo pise, descomenta:
  # lifecycle {
  #   ignore_changes = [source, content, etag]
  # }
}

#######################################
# Imagen del ECS app
#######################################
data "huaweicloud_images_image" "app" {
  name        = var.ecs_image_name
  visibility  = "public"
  most_recent = true
}

#######################################
# ECS App (GPU: NVIDIA Tesla T4) con EIP directa + agency OBS
#######################################
resource "huaweicloud_compute_instance" "ecs_app" {
  name      = local.ecs.app
  flavor_id = var.ecs_flavor_app
  image_id  = data.huaweicloud_images_image.app.id

  security_group_ids = [
    huaweicloud_networking_secgroup.sg_app.id
  ]

  network {
    uuid = huaweicloud_vpc_subnet.subnet_main.id
  }

  key_pair = var.key_pair_name

  system_disk_type      = "SSD"
  system_disk_size      = 100
  user_data             = var.cloud_init_config
  enterprise_project_id = data.huaweicloud_enterprise_project.ep.id
  agency_name           = huaweicloud_identity_agency.ecs.name
  tags                  = local.tags
}

#######################################
# Asociar la EIP al ECS app
#######################################
resource "huaweicloud_compute_eip_associate" "app" {
  instance_id = huaweicloud_compute_instance.ecs_app.id
  public_ip   = huaweicloud_vpc_eip.eip_app.address
}
