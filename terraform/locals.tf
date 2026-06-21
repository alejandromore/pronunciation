locals {
  prefix                  = var.app_env
  enterprise_project_name = "ep-${local.prefix}"

  ########################################
  # Network
  ########################################
  vpc_name    = "vpc-${local.prefix}"
  subnet_name = "subnet-${local.prefix}"

  sg = {
    app = "sg-${local.prefix}-app"
  }

  ########################################
  # Public Access
  ########################################
  bandwidth_name = "bw-${local.prefix}"

  eip = {
    app = "eip-${local.prefix}-app"
  }

  ########################################
  # ECS
  ########################################
  ecs = {
    app = "ecs-${local.prefix}-app"
  }

  ########################################
  # OBS  (bucket del CSV de palabras)
  ########################################
  obs = {
    data = "obs-${local.prefix}-data"
  }
  obs_csv_key = "data_en.csv"

  ########################################
  # IAM Agency (ECS -> OBS con credenciales temporales)
  ########################################
  agency_name = "agency-${local.prefix}-ecs"

  ########################################
  # Tags
  ########################################
  tags = merge(var.tags, {
    app_env = var.app_env
  })
}
