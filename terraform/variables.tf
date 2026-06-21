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

# OS de la imagen del ECS app. Se COMBINA con flavor_id al buscar la imagen, de
# modo que Terraform solo elige imagenes COMPATIBLES con el flavor GPU. Esto
# evita el error Ecs.0005 "The flavor does not match the image" (la imagen
# publica generica no trae el tag de soporte GPU). Ej: "Ubuntu", "CentOS".
variable "ecs_image_os" {
  description = "OS de la imagen publica del ECS app (se filtra junto al flavor GPU)"
  type        = string
  default     = "Ubuntu"
}

# (Opcional) Forzar una imagen por NOMBRE exacto. Vacio = elegir por OS+flavor
# (recomendado para GPU). Util si quieres una imagen GPU especifica del catalogo
# que ya trae el driver Tesla. Aun asi se aplica el filtro flavor_id.
variable "ecs_image_name" {
  description = "Nombre exacto de imagen (opcional; vacio = elegir por OS+flavor)"
  type        = string
  default     = ""
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
