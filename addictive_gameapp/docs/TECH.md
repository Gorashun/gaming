# TECH.md – stack och byggkedja

## Beslut
- **Phaser 3.90** (inte Phaser 4) för v1. Skäl: Phaser 4 är fem månader gammal och Matter-integrationen och exempelbasen är tunnare. Phaser 3 har Matter.js inbyggt och lägst risk. Omprövas i v2.
- **TypeScript + Vite 8**, strikt läge.
- **Capacitor 8** för Android (fas 4) och iOS (fas 6).
- **Playwright** (Chromium finns i `/opt/pw-browsers`, sätt aldrig igång `playwright install`) för headless-verifiering, **Vitest** för logik (director, merge-regler, save).
- Android SDK kan **inte** installeras i utvecklingscontainern (dl.google.com blockerad). APK byggs uteslutande i GitHub Actions.

## Mappstruktur
```
addictive_gameapp/app/
├─ index.html
├─ package.json
├─ vite.config.ts
├─ capacitor.config.ts        # fas 4
├─ src/
│  ├─ main.ts                 # Phaser.Game-konfig
│  ├─ scenes/  Boot, Start, Game, GameOver
│  ├─ systems/ director.ts, juice.ts, audio.ts, haptics.ts, save.ts, merge.ts
│  ├─ data/    levels.ts, director.ts, juice.ts, theme.ts
│  └─ ui/      hud.ts, icons.ts (SVG som strängar)
├─ public/  (endast om ljudfiler behövs; ljud genereras helst med Web Audio)
├─ tests/   unit/ (vitest), e2e/ (playwright)
└─ android/ (genereras i fas 4, checkas in)
```

## Kommandon
```
npm run dev       # vite, öppna på mobilviewport
npm run build     # vite build -> dist/
npm run test      # vitest run
npm run e2e       # playwright test (headless chromium)
npx cap sync android
```

## Kodregler
- All balansering i `src/data/`. Inga magiska siffror i scener.
- `systems/` får inte importera Phaser-scener. Director, merge-regler och save måste gå att enhetstesta utan renderare.
- Objektpool för bodies och partiklar. Inga allokeringar i `update()`.
- Input via `pointerdown/pointermove/pointerup`, aldrig `click`.
- Ljud startas först efter första user-gesture (AudioContext unlock). Ljud genereras syntetiskt med Web Audio (oscillator + envelope) så att inga ljudfiler behövs och pitch-stegring blir trivial.
- Ingen `INTERNET`-permission i Android-manifestet. Inga tredjepartsberoenden utöver phaser, @capacitor/*.

## WebView-fällor (måste finnas i index.html/CSS från dag 1)
```html
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
```
```css
html, body { margin:0; height:100%; overflow:hidden; overscroll-behavior:none; touch-action:none;
  -webkit-user-select:none; user-select:none; -webkit-touch-callout:none; background:#000; }
```
Plus `preventDefault()` på `touchmove` på document.

## GitHub Actions (fas 4)
`.github/workflows/android.yml` på `ubuntu-latest`: setup-node 22, setup-java 21 (temurin), android-actions/setup-android, `npm ci && npm run build && npx cap sync android`, `./gradlew assembleDebug` → artifact `klunk-debug.apk`. Debug-APK är installerbar via sideload utan egen keystore. Signerad release-build läggs till när Play-konto finns (secrets `KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`).
