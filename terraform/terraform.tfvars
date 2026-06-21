region = "la-south-2"
# app_env lo inyecta Jenkins (PROJECT). Para un `terraform apply` manual:
# app_env = "pronunciation"

tags = {
  environment = "pronunciation"
  project     = "pronunciation-trainer"
  owner       = "alejandro"
  costcenter  = "it-001"
}

#######################################
# NETWORK
#######################################

vpc_cidr          = "10.0.0.0/24"
subnet_cidr       = "10.0.0.0/26"
subnet_gateway_ip = "10.0.0.1"

dns_list = [
  "100.125.1.250",
  "100.125.21.250"
]

# CIDR autorizado para SSH (y HTTPS si lo restringes). El ECS tiene EIP directa.
# CAMBIAR a la IP del runner Jenkins/admin (/32). 0.0.0.0/0 = inseguro para SSH.
ssh_admin_cidr = "0.0.0.0/0"

#######################################
# BANDWIDTH
#######################################

bandwidth_size = 5

#######################################
# ECS
#######################################

# GPU: NVIDIA Tesla T4. Verifica que el flavor exista en la-south-2; si no,
# usa el flavor GPU-T4 mas cercano (g6.*).
ecs_flavor_app = "pi2.2xlarge.4"

# Idealmente una imagen GPU de Huawei con el driver Tesla preinstalado.
ecs_image_name = "Ubuntu 22.04 server 64bit"

cloud_init_config = <<-EOT
  #cloud-config
  timezone: America/Lima
  runcmd:
    - [ timedatectl, set-timezone, America/Lima ]
EOT

#######################################
# ACCESS
#######################################

key_pair_name    = "basic-project-key"
private_key_name = "basic-project-private-key"
