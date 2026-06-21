#######################################
# 05-iam-agency.tf
#
# IAM Agency para el ECS app.
#
# Permite que el ECS acceda a OBS usando credenciales TEMPORALES obtenidas del
# servicio de metadata (http://169.254.169.254/openstack/latest/securitykey).
# Asi el contenedor del trainer descarga el CSV de palabras desde OBS SIN
# inyectar AK/SK estaticas: lee el bucket via la agency.
#
# Recordatorio Huawei: solo se asocia UNA agency por ECS. OBS es GLOBAL, asi
# que basta el rol de sistema "OBS OperateAccess" en all_resources_roles.
# (Para minimo privilegio podrias usar "OBS ReadOnlyAccess": el ECS solo LEE.)
#######################################

resource "huaweicloud_identity_agency" "ecs" {
  name                   = local.agency_name
  description            = "Agencia ECS para leer el CSV de OBS con credenciales temporales"
  delegated_service_name = "op_svc_ecs"

  all_resources_roles = [
    "OBS OperateAccess",
  ]
}
