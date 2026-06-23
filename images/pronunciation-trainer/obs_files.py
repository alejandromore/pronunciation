#!/usr/bin/env python3
# ============================================================================
#  obs_files.py
#  Lista/descarga objetos del bucket OBS usando la IAM Agency del ECS
#  (credenciales TEMPORALES del metadata). Lo usa webApp.py para:
#    - selector de archivos en "/"            -> list_keys()
#    - cargar el .csv elegido en "/select"    -> download_to()
#    - imagenes didacticas por palabra        -> list_image_index() / get_object()
#
#  IMAGENES POR LISTA:
#    Una lista "X.csv" puede tener una carpeta "X/" con imagenes de las palabras.
#    Al mostrar una palabra, la app busca en esa carpeta una imagen cuyo nombre
#    (normalizado) coincida con la palabra. Si existe, la muestra; si no, nada.
#
#  Variables de entorno: OBS_REGION, OBS_BUCKET.
# ============================================================================
import json
import os
import re
import urllib.request

META_URL = "http://169.254.169.254/openstack/latest/securitykey"

# Extensiones de imagen soportadas -> content-type
EXT_CT = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
}


def _temp_credentials():
    with urllib.request.urlopen(META_URL, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    c = data["credential"]
    return c["access"], c["secret"], c["securitytoken"]


def _client():
    import boto3
    from botocore.client import Config
    region = os.environ.get("OBS_REGION", "la-south-2")
    ak, sk, token = _temp_credentials()
    return boto3.client(
        "s3",
        endpoint_url=f"https://obs.{region}.myhuaweicloud.com",
        region_name=region,
        aws_access_key_id=ak,
        aws_secret_access_key=sk,
        aws_session_token=token,
        config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
    )


def normalize(s):
    """Clave de comparacion robusta: minusculas, sin signos, espacios colapsados.
    Asi 'blue-green_deployment' y 'Blue Green Deployment' coinciden."""
    s = re.sub(r"[^0-9a-zA-Z]+", " ", (s or "").lower()).strip()
    return re.sub(r"\s+", " ", s)


def list_keys():
    """Lista los .csv en la RAIZ del bucket (ordenada). Ignora los que estan
    dentro de carpetas (esos son imagenes de alguna lista)."""
    bucket = os.environ.get("OBS_BUCKET", "")
    if not bucket:
        return []
    s3 = _client()
    keys = []
    token = None
    while True:
        kwargs = {"Bucket": bucket}
        if token:
            kwargs["ContinuationToken"] = token
        resp = s3.list_objects_v2(**kwargs)
        for obj in resp.get("Contents", []):
            k = obj["Key"]
            if "/" in k:
                continue  # esta dentro de una carpeta, no es una lista raiz
            if k.lower().endswith(".csv"):
                keys.append(k)
        if resp.get("IsTruncated"):
            token = resp.get("NextContinuationToken")
        else:
            break
    return sorted(keys)


def download_to(key, dest="/app/databases/data_en.csv"):
    """Descarga bucket/key al destino (atomico)."""
    bucket = os.environ.get("OBS_BUCKET", "")
    if not bucket:
        raise RuntimeError("OBS_BUCKET no definido")
    s3 = _client()
    tmp = dest + ".tmp"
    s3.download_file(bucket, key, tmp)
    os.replace(tmp, dest)
    return dest


def list_image_index(folder):
    """Indexa las imagenes de la carpeta 'folder/' -> { nombre_normalizado: key }.
    Devuelve {} si no hay carpeta o no hay imagenes."""
    bucket = os.environ.get("OBS_BUCKET", "")
    if not bucket or not folder:
        return {}
    s3 = _client()
    prefix = folder.rstrip("/") + "/"
    index = {}
    token = None
    while True:
        kwargs = {"Bucket": bucket, "Prefix": prefix}
        if token:
            kwargs["ContinuationToken"] = token
        resp = s3.list_objects_v2(**kwargs)
        for obj in resp.get("Contents", []):
            key = obj["Key"]
            base = key[len(prefix):]
            if not base or "/" in base:
                continue  # subcarpetas: ignorar
            root, ext = os.path.splitext(base)
            if ext.lower() in EXT_CT:
                index[normalize(root)] = key
        if resp.get("IsTruncated"):
            token = resp.get("NextContinuationToken")
        else:
            break
    return index


def get_object(key):
    """Descarga un objeto a memoria -> (bytes, content_type)."""
    bucket = os.environ.get("OBS_BUCKET", "")
    s3 = _client()
    obj = s3.get_object(Bucket=bucket, Key=key)
    data = obj["Body"].read()
    ext = os.path.splitext(key)[1].lower()
    return data, EXT_CT.get(ext, "application/octet-stream")
