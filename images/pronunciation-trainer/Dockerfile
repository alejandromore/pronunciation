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
#  El icono "home" vuelve al SELECTOR de archivos ("/") para cambiar de set.
#  Subir el volumen del audio de referencia (TTS): 0.2 -> 0.8.
#  Voz en MOVIL: las voces TTS cargan async; reintentar al pulsar play y
#  re-seleccionar voz con onvoiceschanged.
#  Responsive (app.css) y mejoras didacticas (enhance.js) se anexan mas abajo.
RUN sed -i 's/^let AILanguage = "de";.*/let AILanguage = "en"; \/\/ Default English/' static/javascript/callbacks.js \
    && sed -i 's#>German</button>#>English</button>#' templates/main.html \
    && sed -i "s#onclick=\"history.go(0)\"#onclick=\"window.location.href='/'\"#" templates/main.html \
    && sed -i 's/linear_factor = 0.2/linear_factor = 0.8/' lambdaTTS.py \
    && sed -i 's#if (languageFound) {#if (!languageFound || voice_synth == null) { try { changeLanguage(AILanguage); } catch (e) {} }\n    if (languageFound) {#' static/javascript/callbacks.js \
    && printf '\n// Movil: las voces TTS cargan async; re-seleccionar voz al estar listas.\ntry { if (window.speechSynthesis) { window.speechSynthesis.onvoiceschanged = function(){ try { changeLanguage(AILanguage); } catch(e){} }; } } catch(e){}\n' >> static/javascript/callbacks.js

# Mejoras didacticas (imagen de palabra + leyenda): anexa enhance.js a callbacks.js
COPY enhance.js /tmp/enhance.js
RUN cat /tmp/enhance.js >> static/javascript/callbacks.js

# Responsive: anexa app.css al final del CSS del upstream (gana en cascada).
COPY app.css /tmp/app.css
RUN cat /tmp/app.css >> static/css/style-new.css

# Selector de archivos OBS + imagenes por palabra:
#  - "/"          lista los .csv de la raiz del bucket (via agency)
#  - "/select"    descarga el .csv, recarga dataset + indice de imagenes, va a "/trainer"
#  - "/wordImage" sirve la imagen de la palabra (carpeta con el nombre de la lista)
#  - "/trainer"   la app de pronunciacion
COPY webApp.py /app/webApp.py
COPY obs_files.py /app/obs_files.py

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
