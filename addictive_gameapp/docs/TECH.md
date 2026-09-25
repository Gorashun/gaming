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

## Abilities: hur man lägger till en förmåga (K3, DESIGN §14.5)
Förmågor är data + en nyckel. Parametrarna per nivå ligger i `src/data/avatars.ts` (`ability: { key, params: { I, II, III } }`), implementationsvärden som inte skalar med nivån (färger, tider, positioner) i `src/data/abilities.ts` (`ABILITY_FX`). Inga siffror i scener.

1. **Data**: ge figuren `ability.key` och parametrar för I/II/III i `avatars.ts`. Håll spelpåverkande parametrar inom ~30 % mellan I och III (DESIGN §14.4).
2. **Logik** (`src/systems/abilities.ts`, ren TS, ingen Phaser):
   - Påverkar förmågan ett befintligt system? Lägg ett fält i `AbilityOverrides` och mappa det i `overridesFor()`. Scenen skickar det vidare vid rundstart genom systemets lilla gränssnitt: `director.setSeedQueue()`, `dangerTracker.graceMs`, near-miss-konfigens `minLevel`, `CollectionState.shinyMul`, `juice.chainShakeMul` / `juice.setAvatarParticles()` / `juice.ringAt()`, `audio.setMergeMelody()` / `setMergeEcho()` / `setMergeLayer()` / `setDangerStyle()`. Rör aldrig scenens interna fält från ett system.
   - Har den en räknare "per runda" (N gånger, en budget)? Lägg den i klassen `Abilities`, fyll på i `resetRound()` och exponera en metod som förbrukar (`tryMagnet`, `lossGrace`, `tickAim`, `takeNoBounce`).
   - **Aldrig poäng direkt**: inga poängfält i overrides, poängtabellen (`data/levels.ts`) rörs inte. Förmågor får bara skapa situationer där vanliga merges ger poäng.
3. **Bild och ljud**: rena känsloeffekter (sällsynt) i `src/ui/abilityFx.ts` (`onMerge`, `onChain`, `onDanger`, `onNewRecord`, `onComboEnd`). Effekter som behöver burkens objekt (Lisa, Sixten, Bubbel, Ekko, Maja, Klick) ligger i `Game.ts` bakom `this.abil.key`. Allt skapas vid rundstart och återanvänds; inga allokeringar i `update()`. Flash-guard: ljusändringar ≤ 2 Hz, inga vitblixtar, Lugnt läge halverar/stänger av.
4. **Test**: Vitest i `tests/unit/abilities.test.ts` (overrides per nivå läses ur `avatars.ts`, räknare nollställs, poängtabellen oförändrad). E2E via `__game.equipForTest(id, level)` och `__game.abilityState`.

Kompisens kosmetik (vanlig/ovanlig) går inte via abilities: `src/ui/buddy.ts` (Släpparen, spår, gester, ljud) + `juice.setAvatarParticles()`. Ritning: `src/ui/avatarArt.ts` (bakar en textur per figur och storlek, siluett i vitt), rörelser: `src/ui/avatarRig.ts`, showcase-effekter: `src/ui/avatarFx.ts`.
