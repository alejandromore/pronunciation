from flask import Flask, render_template, request, redirect, abort, Response
import webbrowser
import os
import html
from flask_cors import CORS
import json

import lambdaTTS
import lambdaSpeechToScore
import lambdaGetSample
import pandas as pd

try:
    import obs_files
except Exception as _e:  # pragma: no cover
    obs_files = None
    print("WARN: obs_files no disponible:", _e)

app = Flask(__name__)
cors = CORS(app)
app.config['CORS_HEADERS'] = '*'

rootPath = ''

CSV_DEST = "./databases/data_en.csv"

# Lista activa + indice de imagenes de esa lista (carpeta con el mismo nombre).
ACTIVE_FOLDER = None
ACTIVE_IMG_INDEX = {}


def _reload_en_dataset():
    """Recarga en memoria el dataset 'en' desde el CSV en disco.
    lambdaGetSample lee el CSV SOLO al importar, asi que tras cambiar el archivo
    hay que reasignar el dataset para que /getSample use las nuevas frases."""
    df = pd.read_csv(CSV_DEST, delimiter=';')
    lambdaGetSample.lambda_database['en'] = lambdaGetSample.TextDataset(df)


def _set_active_folder(csv_key):
    """Define la lista activa y construye el indice de imagenes de su carpeta.
    Carpeta esperada = nombre del .csv sin extension (X.csv -> X/)."""
    global ACTIVE_FOLDER, ACTIVE_IMG_INDEX
    folder = csv_key[:-4] if csv_key.lower().endswith('.csv') else csv_key
    ACTIVE_FOLDER = folder
    ACTIVE_IMG_INDEX = {}
    if obs_files is None:
        return
    try:
        ACTIVE_IMG_INDEX = obs_files.list_image_index(folder)
        print(f"[img] lista='{folder}' imagenes={len(ACTIVE_IMG_INDEX)}")
    except Exception as e:
        print("WARN indice de imagenes:", e)


# Inicializa el indice para la lista por defecto (best-effort).
try:
    _set_active_folder(os.environ.get('OBS_CSV_KEY', 'data_en.csv'))
except Exception as _e:
    print("WARN init folder:", _e)


# ----------------------------------------------------------------------------
#  "/"  -> Selector: lista los .csv del bucket OBS
# ----------------------------------------------------------------------------
@app.route(rootPath + '/')
def file_picker():
    keys, err = [], None
    if obs_files is None:
        err = "Modulo OBS no disponible en la imagen."
    else:
        try:
            keys = obs_files.list_keys()
        except Exception as e:
            err = "No se pudo listar OBS: " + str(e)

    bucket = html.escape(os.environ.get("OBS_BUCKET", ""))

    if keys:
        items = "".join(
            f'<li><a class="file" href="/select?key={html.escape(k)}">'
            f'<span class="ico">📄</span><span class="nm">{html.escape(k)}</span>'
            f'<span class="go">▶</span></a></li>'
            for k in keys
        )
    else:
        items = '<li class="empty">No hay archivos .csv en el bucket.</li>'

    err_html = f'<p class="err">{html.escape(err)}</p>' if err else ""

    return f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AI Pronunciation Trainer — elige un set</title>
<style>
  :root {{ --navy:#1F3864; --teal:#2f7d8c; --bg:#f4f6f9; }}
  * {{ box-sizing:border-box; }}
  body {{ font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
          background:var(--bg); color:#1b1f24; margin:0; padding:clamp(20px,5vw,48px) 16px; }}
  .wrap {{ max-width:680px; margin:0 auto; }}
  h1 {{ font-size:clamp(1.4rem,5vw,1.9rem); margin:0 0 4px; color:#111; }}
  .sub {{ color:#5b6573; margin:0 0 24px; font-size:clamp(.95rem,3vw,1.05rem); }}
  .sub b {{ color:var(--navy); }}
  ul {{ list-style:none; padding:0; margin:0; background:#fff; border-radius:14px;
        box-shadow:0 6px 24px rgba(20,30,60,.08); overflow:hidden; }}
  li + li {{ border-top:1px solid #eef1f5; }}
  a.file {{ display:flex; align-items:center; gap:12px; padding:16px 18px;
            text-decoration:none; color:#1b1f24; font-size:clamp(1rem,3.4vw,1.1rem); }}
  a.file:hover {{ background:#eef4ff; color:var(--navy); }}
  a.file .nm {{ flex:1 1 auto; overflow-wrap:anywhere; }}
  a.file .go {{ color:#9aa4b2; }}
  a.file:hover .go {{ color:var(--teal); }}
  .ico {{ font-size:1.2rem; }}
  .empty {{ padding:18px 20px; color:#8a93a0; }}
  .err {{ background:#fdecec; color:#b3261e; padding:12px 16px; border-radius:10px; }}
  footer {{ margin-top:22px; color:#8a93a0; font-size:.85rem; line-height:1.5; }}
</style>
</head>
<body>
  <div class="wrap">
    <h1>🎙️ AI Pronunciation Trainer</h1>
    <p class="sub">Elige un set de práctica del bucket <b>{bucket}</b>:</p>
    {err_html}
    <ul>{items}</ul>
    <footer>Cada lista <b>X.csv</b> puede tener una carpeta <b>X/</b> con imágenes de las palabras
    (ej. <code>X/Kubernetes.png</code>); si existe, se muestra junto a la palabra. Sube o edita
    archivos en el OBS y vuelve aquí.</footer>
  </div>
</body>
</html>"""


# ----------------------------------------------------------------------------
#  "/select?key=..."  -> descarga el CSV, recarga dataset + indice de imagenes
# ----------------------------------------------------------------------------
@app.route(rootPath + '/select')
def select_file():
    key = request.args.get('key', '').strip()
    if obs_files is None:
        abort(503)
    if not key or not key.lower().endswith('.csv') or '..' in key:
        abort(400)
    try:
        obs_files.download_to(key, CSV_DEST)
        _reload_en_dataset()
        _set_active_folder(key)
    except Exception as e:
        return (f"<p>Error cargando <b>{html.escape(key)}</b>: "
                f"{html.escape(str(e))}</p><p><a href='/'>← Volver</a></p>"), 500
    return redirect('/trainer')


# ----------------------------------------------------------------------------
#  "/wordImage?word=..."  -> imagen de la palabra (o 404 si no existe)
# ----------------------------------------------------------------------------
@app.route(rootPath + '/wordImage')
def word_image():
    if obs_files is None:
        abort(404)
    word = request.args.get('word', '')
    norm = obs_files.normalize(word)
    if not norm:
        abort(404)
    key = ACTIVE_IMG_INDEX.get(norm)
    if not key:
        abort(404)
    try:
        data, ctype = obs_files.get_object(key)
    except Exception:
        abort(404)
    return Response(data, mimetype=ctype,
                    headers={'Cache-Control': 'public, max-age=86400'})


# ----------------------------------------------------------------------------
#  "/trainer"  -> la app de pronunciacion
# ----------------------------------------------------------------------------
@app.route(rootPath + '/trainer')
def trainer():
    return render_template('main.html')


# ----------------------------------------------------------------------------
#  APIs (sin cambios)
# ----------------------------------------------------------------------------
@app.route(rootPath + '/getAudioFromText', methods=['POST'])
def getAudioFromText():
    event = {'body': json.dumps(request.get_json(force=True))}
    return lambdaTTS.lambda_handler(event, [])


@app.route(rootPath + '/getSample', methods=['POST'])
def getNext():
    event = {'body': json.dumps(request.get_json(force=True))}
    return lambdaGetSample.lambda_handler(event, [])


@app.route(rootPath + '/GetAccuracyFromRecordedAudio', methods=['POST'])
def GetAccuracyFromRecordedAudio():
    try:
        event = {'body': json.dumps(request.get_json(force=True))}
        lambda_correct_output = lambdaSpeechToScore.lambda_handler(event, [])
    except Exception as e:
        print('Error: ', str(e))
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Credentials': "true",
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
            },
            'body': ''
        }
    return lambda_correct_output


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000)
