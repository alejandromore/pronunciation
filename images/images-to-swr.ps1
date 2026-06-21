# ============================================================================
#  images-to-swr.ps1
#  Construye y sube la imagen del Pronunciation Trainer a SWR.
#
#  Ubicacion esperada del script: images/ (raiz de los contextos de build).
#
#  Uso:
#    .\images-to-swr.ps1 -SwrUser "la-south-2@HST3WARDF7OXIEACWCLV" -SwrPassword "cf6d50dd50ed623380cca26d6fa56047d30606cf1cb404310240963932a52525"
#docker login 
-u la-south-2@HST3WARDF7OXIEACWCLV 
-p cf6d50dd50ed623380cca26d6fa56047d30606cf1cb404310240963932a52525 
swr.la-south-2.myhuaweicloud.com
#  Notas:
#   - El build baja la base CUDA (pytorch/pytorch) y clona el upstream; necesita
#     salida a internet durante el build.
#   - SWR solo acepta Docker V2 Schema2: build con --format docker, push v2s2.
#   - El namespace (organization) sigue la convencion swr-<env> = swr-pronunciation.
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$SwrUser,

    [Parameter(Mandatory=$true)]
    [string]$SwrPassword,

    [string]$SwrRegistry  = "swr.la-south-2.myhuaweicloud.com",
    [string]$Organization = "swr-pronunciation",
    [string]$Tag          = "1.0"
)

$ErrorActionPreference = "Stop"

$builds = @(
    @{ name = "pronunciation-trainer"; context = "pronunciation-trainer"; tag = $Tag }
)

Write-Host "Login a SWR ($SwrRegistry)..." -ForegroundColor Cyan
podman login $SwrRegistry -u $SwrUser -p $SwrPassword
if ($LASTEXITCODE -ne 0) { throw "Login SWR fallo" }

$published = @()
foreach ($b in $builds) {
    $contextDir = Join-Path $PSScriptRoot $b.context
    if (-not (Test-Path (Join-Path $contextDir "Dockerfile"))) {
        throw "No existe $contextDir\Dockerfile."
    }

    $image = "$SwrRegistry/$Organization/$($b.name):$($b.tag)"

    Write-Host ""
    Write-Host "==== [$($b.name)] ====" -ForegroundColor Cyan
    Write-Host "Build $image ..." -ForegroundColor Cyan
    # --platform linux/amd64: el ECS es x86_64. --format docker: SWR exige V2S2.
    podman build --platform linux/amd64 --format docker -t $image $contextDir
    if ($LASTEXITCODE -ne 0) { throw "Build de $($b.name) fallo" }

    Write-Host "Push $image ..." -ForegroundColor Cyan
    podman push --format v2s2 $image
    if ($LASTEXITCODE -ne 0) { throw "Push de $($b.name) fallo" }

    Write-Host "OK: $image" -ForegroundColor Green
    $published += $image
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Imagenes publicadas en SWR:" -ForegroundColor Green
$published | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Siguiente: Jenkins -> RUN_TERRAFORM=true (primera vez) + DEPLOY_PRONUNCIATION=true"
