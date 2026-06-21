#######################################
# CORE
#######################################

variable "region" {
  type = string
}

variable "app_env" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

#######################################
# AUTH
#######################################

variable "access_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "secret_key" {
  type      = string
  default   = null
  sensitive = true
}

#######################################
# NETWORK
#######################################

variable "vpc_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "subnet_gateway_ip" {
  type = string
}

variable "dns_list" {
  type = list(string)
}

# CIDR autorizado para SSH (22) y, si quieres restringirlo, tambien HTTPS.
# El ECS tiene EIP directa; restringe a la IP de administracion (ej. "1.2.3.4/32").
variable "ssh_admin_cidr" {
  description = "CIDR autorizado para acceso SSH directo al ECS"
  type        = string
}

#######################################
# BANDWIDTH
#######################################

variable "bandwidth_size" {
  type = number
}

#######################################
# ECS
#######################################

# ECS de la app: GPU (NVIDIA Tesla T4). pi2.2xlarge.4 = 8 vCPU / 32 GB / 1x T4.
variable "ecs_flavor_app" {
  type = string
}

# Imagen del ECS app. RECOMENDADO: imagen GPU de Huawei con el driver Tesla
# preinstalado. Si se usa una Ubuntu limpia, el playbook instala el driver.
variable "ecs_image_name" {
  description = "Nombre de la imagen publica del ECS app (idealmente GPU con driver Tesla)"
  type        = string
  default     = "Ubuntu 22.04 server 64bit"
}

variable "key_pair_name" {
  type = string
}

variable "private_key_name" {
  description = "Nombre del secreto (DEW) con la llave privada del ECS"
  type        = string
}

variable "cloud_init_config" {
  description = "Cloud-init configuration for ECS instances"
  type        = string
}
