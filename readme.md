# Pronunciation Trainer - Infra (Huawei Cloud)

Despliegue del **AI Pronunciation Trainer** (Flask + Whisper sobre **GPU Tesla T4**)
en Huawei Cloud, con **HTTPS** y orquestado por **Jenkins**. Mismo patron base
(Terraform + Ansible + Jenkins + images).

Ambiente (PROJECT / app_env): `pronunciation`.

## Arquitectura

```
Usuario --HTTPS(443)--> ECS app (EIP directa, GPU T4)
                          nginx:443 (TLS self-signed) -> trainer:3000 (Whisper)
                          |
                          |  el contenedor, al ARRANCAR, descarga el CSV de
                          v  palabras desde OBS usando la AGENCY del ECS
                       OBS  obs-<env>-data/data_en.csv  (editable por el usuario)
```

Sin bastion y sin ELB: el **ECS tiene una EIP directa**. nginx termina **TLS en
el propio ECS** (cert self-signed). La EIP da entrada (HTTPS/SSH) y salida a
internet, asi que **tampoco hace falta NAT**.

- El microfono del navegador exige contexto seguro -> acceso **HTTPS**. El cert
  es self-signed: la 1a vez el navegador avisa; al aceptarlo, la pagina queda en
  `https://` (contexto seguro) y el microfono funciona. Para produccion con
  dominio, reemplaza el cert self-signed por uno emitido.

## CSV de palabras en OBS (editable)

- Terraform crea el bucket `obs-<env>-data` y **sube** `data_en.csv`
  (el que generamos, con el material de la entrevista Revolut por niveles).
- El ECS accede a OBS por **IAM Agency** (`agency-<env>-ecs`, rol OBS): el
  contenedor obtiene credenciales **temporales** del metadata y descarga el CSV.
- **Flujo de actualizacion:** edita el objeto `data_en.csv` en OBS (consola/CLI)
  y **reinicia el ECS** (o `docker compose restart trainer`). El entrypoint del
  contenedor vuelve a descargar la ultima version. Si la descarga falla, usa el
  CSV **horneado** en la imagen como respaldo.

## 1) Construir y subir la imagen a SWR

```powershell
cd images
.\images-to-swr.ps1 -SwrUser "la-south-2@<AK>" -SwrPassword "<TOKEN>"
```
Publica `swr.la-south-2.myhuaweicloud.com/swr-common/pronunciation-trainer:1.0`.

## 2) Jenkins

Parametros: `PROJECT=pronunciation`, `ACTION=deploy`, `RUN_TERRAFORM=true`
(la 1a vez), `DEPLOY_PRONUNCIATION=true`.

Credenciales: `hwc-access-key`, `hwc-secret-key`, `swr-jenkins`. tfstate en OBS
(`backend-s3.tf`). Al terminar: `App (HTTPS): https://<app-eip>`.

## Notas

- **Flavor GPU:** `pi2.2xlarge.4` (1x Tesla T4). Verifica que exista en
  `la-south-2`; si no, usa el GPU-T4 mas cercano (g6.*) en `terraform.tfvars`.
- **Driver NVIDIA:** idealmente una imagen GPU de Huawei con el driver Tesla
  preinstalado (`ecs_image_name`). Con Ubuntu limpia, el playbook lo instala
  (best-effort) + reinicio, y luego el NVIDIA Container Toolkit.
- **FinOps:** la GPU se factura por hora; detén el ECS cuando no practiques
  (o `ACTION=destroy`). Al volver a encender el ECS, el contenedor re-baja el CSV.
- **Niveles del CSV:** Easy <=8, Medium 9-20, Hard 21+ palabras (la dificultad
  la decide el numero de palabras de cada linea).
