#!/usr/bin/env python3
# ============================================================================
#  obs_files.py
#  Lista y descarga CSVs del bucket OBS usando la IAM Agency del ECS
#  (credenciales TEMPORALES del metadata). Lo usa webApp.py para:
#    - mostrar el selector de archivos en "/"
#    - descargar el elegido en "/select"
#  Variables de entorno: OBS_REGION, OBS_BUCKET (las pasa docker-compose).
# ============================================================================
import json
import os
import urllib.request

META_URL = "http://169.254.169.254/openstack/latest/securitykey"


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


def list_keys():
    """Devuelve la lista de objetos .csv del bucket OBS (ordenada)."""
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
