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

# Ajustes de frontend:
#  Idioma por defecto = English (en vez de German) y label del boton.
#  Para pasar de frase se usa el boton "Next" (arriba a la derecha del recuadro),
#  que ya viene en el upstream.
RUN sed -i 's/^let AILanguage = "de";.*/let AILanguage = "en"; \/\/ Default English/' static/javascript/callbacks.js \
    && sed -i 's#>German</button>#>English</button>#' templates/main.html

# Personalizaciones (GPU + CSV horneado de respaldo)
COPY whisper_wrapper.py /app/whisper_wrapper.py
COPY data_en.csv /app/databases/data_en.csv

# Mantener el torch CUDA de la base; agregar torchaudio CUDA + deps; boto3 para OBS.
# IMPORTANTE: fijar transformers a una version compatible con torch 2.3.1. Las
# versiones nuevas exigen torch >= 2.4 y, si no lo encuentran, DESACTIVAN el
# backend de PyTorch -> "NameError: name 'torch' is not defined" al crear el
# pipeline de Whisper. 4.44.2 es la ultima linea que funciona con torch 2.3.x.
RUN sed -i '/^torch/d' requirements.txt \
    && sed -i '/^transformers/d' requirements.txt \
    && pip install --no-cache-dir torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121 \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir "transformers==4.44.2" \
    && pip install --no-cache-dir boto3

# Pre-cargar (HORNEAR) los modelos que la app descarga al ARRANCAR, para que el
# contenedor NO los baje en cada reinicio. Importar estos modulos ejecuta los
# mismos loads que el arranque real:
#   - lambdaTTS        -> silero-models (repo 130MB) + TTS aleman  -> /root/.cache/torch/hub
#   - lambdaSpeechToScore -> Whisper base (ASR) de HuggingFace      -> /root/.cache/huggingface
# Best-effort: si HF limita la descarga, el build no falla (se reintenta en runtime).
RUN python -c "import lambdaTTS, lambdaSpeechToScore" || echo "WARN: warm-up parcial de modelos (se completara en runtime)"

# Entrypoint que refresca el CSV desde OBS y arranca la app
COPY fetch_csv.py /app/fetch_csv.py
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV PYTHONUTF8=1
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
