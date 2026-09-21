# Webbversion (artefakt i chatten)

Godot 4.6 web-export utan trådar (`Web`-presetet i export_presets.cfg). Wasm-filen är 38 MB, artefaktvärden tillåter 15 MB per binär, så wasm och pck gzippas och packas upp i webbläsaren av `index.html` (DecompressionStream), som sedan styr om Godots fetch/XHR till blob-URL:er.

```
godot --headless --export-release "Web" build/web/pipwreck.html
gzip -9 -k build/web/pipwreck.wasm && mv build/web/pipwreck.wasm.gz build/web/pipwreck.z.wasm
gzip -9 -k build/web/pipwreck.pck  && mv build/web/pipwreck.pck.gz  build/web/pipwreck.pck.z.wasm
cp tools/web/index.html build/web/index.html
```

Publicera `build/web/index.html` med filerna pipwreck.js, pipwreck.z.wasm, pipwreck.pck.z.wasm, båda audio-worklets och pipwreck.icon.png. `.wasm`-ändelsen på de gzippade filerna är bara för att artefaktvärden ska servera dem.
