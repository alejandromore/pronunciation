#!/bin/sh
# Entrypoint del trainer: intenta refrescar el CSV desde OBS (via agency) y
# luego arranca la app. Si la descarga falla, usa el CSV horneado en la imagen.
set -e

if [ -n "$OBS_BUCKET" ]; then
    echo "[entrypoint] Refrescando CSV desde OBS ($OBS_BUCKET/${OBS_CSV_KEY:-data_en.csv})..."
    if python /app/fetch_csv.py; then
        echo "[entrypoint] CSV actualizado desde OBS."
    else
        echo "[entrypoint] WARN: no se pudo bajar el CSV de OBS; uso el horneado en la imagen."
    fi
else
    echo "[entrypoint] OBS_BUCKET no definido; uso el CSV horneado en la imagen."
fi

exec python webApp.py
