# ============================================================================
#  AI Pronunciation Trainer - imagen GPU
#
#  Base CUDA + PyTorch (Tesla T4). Clona el upstream y le superpone:
#    - whisper_wrapper.py : usa la GPU (device=0) y whisper-base.
#    - databases/data_en.csv : CSV de palabras HORNEADO (respaldo / fallback).
#    - fetch_csv.py + entrypoint.sh : al ARRANCAR, descarga el CSV desde OBS
#      via la agency del ECS (creds temporales). Reiniciar = ultima version.
# ============================================================================
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg git build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Codigo upstream
RUN git clone --depth 1 https://github.com/Thiagohgl/ai-pronunciation-trainer .

# Personalizaciones (GPU + CSV horneado de respaldo)
COPY whisper_wrapper.py /app/whisper_wrapper.py
COPY data_en.csv /app/databases/data_en.csv

# Mantener el torch CUDA de la base; agregar torchaudio CUDA + deps; boto3 para OBS
RUN sed -i '/^torch/d' requirements.txt \
    && pip install --no-cache-dir torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121 \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir boto3

# Entrypoint que refresca el CSV desde OBS y arranca la app
COPY fetch_csv.py /app/fetch_csv.py
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV PYTHONUTF8=1
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
