# Webbversion (artefakt i chatten)

Godot 4.6 web-export utan trådar (`Web`-presetet i export_presets.cfg). Wasm-filen är 38 MB, artefaktvärden tillåter 15 MB per binär, så wasm och pck gzippas och packas upp i webbläsaren av `index.html` (DecompressionStream), som sedan styr om Godots fetch/XHR till blob-URL:er.

```
godot --headless --export-release "Web" build/web/pipwreck.html
gzip -9 -k build/web/pipwreck.wasm && mv build/web/pipwreck.wasm.gz build/web/pipwreck.z.wasm
gzip -9 -k build/web/pipwreck.pck  && mv build/web/pipwreck.pck.gz  build/web/pipwreck.pck.z.wasm
cp tools/web/index.html build/web/index.html
```

Publicera `build/web/index.html` med filerna pipwreck.js, pipwreck.z.wasm, pipwreck.pck.z.wasm, båda audio-worklets och pipwreck.icon.png. `.wasm`-ändelsen på de gzippade filerna är bara för att artefaktvärden ska servera dem.

## Patch av pipwreck.js (Android WebView)

Emscriptens webbläsarkontroll i Godots web-JS läser Android-appars WebView-UA ("Version/4.0 … Chrome/… Safari/537.36") som Safari 4 och kastar "requires Safari v15.2.0 (detected v040000)". `pipwreck.patched.js` hoppar över Safari-kontrollen när UA innehåller "Chrome/" eller "Android". Applicera samma sed/python-patch efter varje ny export (mönstret `var currentSafariVersion=`).

## Felsökningsstart ur URL:en

`index.html` läser `?start=town|corridor|sheet` och `?seed=N` ur
`window.location.search` och skickar dem vidare som
`args: ['--', '--pipwreck-start=…', '--pipwreck-seed=…']` i Engine-konfigurationen.
Godots web-loader lägger dem sist på kommandoraden, och `GameController` läser
dem ur `OS.get_cmdline_user_args()` (se `docs/ARCHITECTURE.md`, "Felsökningsstart").
Värdena vitlistas i JS också, så en felstavning aldrig når motorn. **Utan
query-parametrar startar spelet exakt som förut.**

```
index.html?start=corridor&seed=7   ny run i korridoren med känd seed
index.html?start=town              torget
index.html?start=sheet             character sheetet ovanpå en ny run
```

## WebGL2-verifiering

`build/web_verify/` är en engångsbygge för verifiering (rör inte `build/web/`,
som är den publicerade artefakten). Skärmdumpar: `docs/screenshots/web_verify/`.
