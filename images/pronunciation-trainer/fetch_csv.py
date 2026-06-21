#!/usr/bin/env python3
# ============================================================================
#  fetch_csv.py  --  Descarga el CSV de palabras desde OBS usando la IAM Agency
#  del ECS (credenciales TEMPORALES del metadata). Se ejecuta en el ARRANQUE
#  del contenedor (entrypoint). Si algo falla, sale != 0 y el entrypoint deja
#  el CSV horneado en la imagen.
#
#  OBS es compatible con S3 -> se usa boto3 con el security token temporal.
#  Variables de entorno:
#    OBS_REGION   (ej. la-south-2)
#    OBS_BUCKET   (bucket del CSV)
#    OBS_CSV_KEY  (key del objeto, default data_en.csv)
#    CSV_DEST     (destino, default /app/databases/data_en.csv)
# ============================================================================
import json
import os
import sys
import urllib.request

META_URL = "http://169.254.169.254/openstack/latest/securitykey"


def get_temp_credentials():
    with urllib.request.urlopen(META_URL, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    c = data["credential"]
    return c["access"], c["secret"], c["securitytoken"]


def main():
    region = os.environ.get("OBS_REGION", "la-south-2")
    bucket = os.environ.get("OBS_BUCKET", "")
    key = os.environ.get("OBS_CSV_KEY", "data_en.csv")
    dest = os.environ.get("CSV_DEST", "/app/databases/data_en.csv")

    if not bucket:
        print("[fetch_csv] OBS_BUCKET vacio; no descargo nada.", file=sys.stderr)
        return 1

    try:
        import boto3
        from botocore.client import Config
    except ImportError:
        print("[fetch_csv] boto3 no instalado.", file=sys.stderr)
        return 1

    try:
        ak, sk, token = get_temp_credentials()
    except Exception as e:
        print(f"[fetch_csv] No pude leer credenciales temporales del metadata: {e}", file=sys.stderr)
        return 1

    endpoint = f"https://obs.{region}.myhuaweicloud.com"
    try:
        s3 = boto3.client(
            "s3",
            endpoint_url=endpoint,
            region_name=region,
            aws_access_key_id=ak,
            aws_secret_access_key=sk,
            aws_session_token=token,
            config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
        )
        tmp = dest + ".tmp"
        s3.download_file(bucket, key, tmp)
        os.replace(tmp, dest)
        print(f"[fetch_csv] OK: {bucket}/{key} -> {dest}")
        return 0
    except Exception as e:
        print(f"[fetch_csv] Fallo la descarga de {bucket}/{key}: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
