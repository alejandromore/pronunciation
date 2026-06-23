
/* ===========================================================================
   enhance.js  — mejoras didacticas (se anexa a callbacks.js)
     1) Imagen de la palabra: si la lista activa tiene carpeta de imagenes y
        existe una para la palabra mostrada, la inserta sobre el texto.
        Si no existe -> no muestra nada (img oculta).
     2) Leyenda didactica: explica los colores y las lineas de IPA.
   Todo se inyecta por DOM (no depende de editar el HTML del upstream).
   =========================================================================== */
(function () {
    function onReady(fn) {
        if (document.readyState !== 'loading') fn();
        else document.addEventListener('DOMContentLoaded', fn);
    }

    onReady(function () {
        // ---- 1) Imagen de la palabra -------------------------------------
        var textArea = document.getElementById('text-area');
        var origin = document.getElementById('original_script');
        if (textArea && origin) {
            var img = document.getElementById('word_image');
            if (!img) {
                img = document.createElement('img');
                img.id = 'word_image';
                img.alt = '';
                img.style.display = 'none';
                textArea.insertBefore(img, textArea.firstChild);
            }
            var lastWord = '';
            function updateImage() {
                var w = (origin.innerText || origin.textContent || '').trim();
                if (w === lastWord) return;
                lastWord = w;
                if (!w) { img.style.display = 'none'; return; }
                img.onerror = function () { img.style.display = 'none'; };
                img.onload = function () { img.style.display = 'block'; };
                img.src = '/wordImage?word=' + encodeURIComponent(w) + '&t=' + Date.now();
            }
            try {
                new MutationObserver(updateImage).observe(origin, {
                    childList: true, characterData: true, subtree: true
                });
            } catch (e) { }
            updateImage();
        }

        // ---- 2) Leyenda didactica ----------------------------------------
        var card = document.querySelector('.container');
        if (card && card.parentNode && !document.getElementById('didactic-legend')) {
            var lg = document.createElement('div');
            lg.id = 'didactic-legend';
            lg.innerHTML =
                '<span class="lg"><b class="ok">verde</b> bien</span>' +
                '<span class="lg"><b class="bad">rojo</b> mejorar</span>' +
                '<span class="lg"><b class="ref">gris</b> referencia (IPA)</span>' +
                '<span class="lg"><b class="you">azul</b> lo que dijiste</span>';
            card.parentNode.insertBefore(lg, card.nextSibling);
        }
    });
})();
