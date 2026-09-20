# Teknikstack-research: enkelt 2D-touchspel, Android först, iOS sedan

Skriven av: game-programmer · Datum: 2026-09-20
Metod: webbresearch mot officiell dokumentation. **Notera:** `support.google.com`, `capacitorjs.com`, `docs.godotengine.org`, `developer.chrome.com` och `docs.github.com` var blockerade av containerns egress-proxy. Fakta därifrån är verifierade via sökmotorsammanfattningar och sekundärkällor och är **markerade** nedan. Allt som inte är belagt är markerat "uppskattning".

---

## 1. TL;DR – rekommenderad stack

1. **Phaser 4 + TypeScript + Vite** som spelmotor (Phaser 4 släpptes 2026-04-10 med helt omskriven WebGL-renderare). Närmast noll ny syntax för en webbutvecklare.
2. **Capacitor 8** som native-skal (Android + iOS från samma kodbas). Kräver Node 22+, compile/target SDK 36, minSdk 24.
3. **Android byggs helt utan GUI** på `ubuntu-latest` i GitHub Actions: `npm run build` → `npx cap sync android` → `./gradlew bundleRelease` med keystore som base64-secret.
4. **iOS senare** på `macos-26`-runner (Xcode 26 förinstallerat, GA sedan 2026-02-26). Teoretiskt går det utan egen Mac – men se risk 6.2.
5. **Undvik TWA/PWA-in-Play i v1**: kräver publik HTTPS-domän + `assetlinks.json`, vilket krockar med "helt offline, ingen server".
6. **Blockerare att lösa först:** Google Plays krav på 12 testare i 14 dagar för nya personliga konton, samt target API 36 från 2026-08-31.

---

## 2. Jämförelse: en kodbas → Android + iOS

| Kriterium | a) Phaser/Pixi + Capacitor | b) Godot 4 | c) Flutter + Flame | d) RN/Expo + Skia | e) PWA/TWA |
|---|---|---|---|---|---|
| Inlärning för webbutvecklare | **Lägst** – JS/TS, DOM-nära | Medel – GDScript + editor-centrerat | Medel/hög – Dart + widgets | Medel – JS/TS men React-modell | Lägst |
| 60 fps partiklar, mellanklass-Android | Bra i WebGL; WebView något sämre än Chrome | **Bäst** (native Vulkan/GL) | Bra, ~60 fps för 2D-casual | Möjligt via Skia `<Atlas>`, men ingen riktig spelmotor | Samma som (a) |
| Bygg utan GUI (CLI/Actions) | **Utmärkt** – gradle direkt | Bra men pillig: export-templates, JDK17, SDK, NDK måste förinstalleras i CI | Bra – `flutter build appbundle` | Bra – EAS/`expo prebuild` + gradle | Bra – Bubblewrap CLI |
| iOS-krav | macOS+Xcode (kan vara Actions-runner) | Genererar Xcode-projekt → macOS+Xcode | macOS+Xcode | macOS+Xcode (eller EAS-moln) | **Fungerar ej** – Apple tillåter inte TWA-wrappers |
| Haptik/ljud | `@capacitor/haptics`, Web Audio | Inbyggt ljud; haptik via plugin | Inbyggt + `flutter_vibrate` m.fl. | `expo-haptics`, `expo-audio` | Web Vibration API (**ej iOS**) |
| Offline | Ja (allt buntas i appen) | Ja | Ja | Ja | Kräver service worker + första nedladdning online |
| Appstorlek | **Minst** – tom Phaser+Vite-bundle <1 MB gzip | Störst – web-export "high single-digit MB" och uppåt; APK tyngre | Medel (Flutter-runtime) | Medel/stor (Hermes+Skia) | Minst |
| Community 2025–2026 | Mycket stor, aktiv (Phaser 4 2026) | Mycket stor, aktiv (Godot Mobile-update apr 2026) | Aktiv men mindre | Stor för RN, **men "det finns ingen RN-spelmotor 2026"** | Stabil |
| AI-agenter kan generera + testa i webbläsare | **Bäst** – körs headless i Playwright/Vitest i containern | Sämst – kräver Godot-binär, svår visuell verifiering | Svagt – Dart-testning men ingen browser-loop | Medel | Bäst |

**Slutsats:** (a) vinner på tre av de saker som faktiskt styr det här projektet – inlärningskurva, CI utan GUI, och att AI-agenter kan köra och verifiera spelet i en headless webbläsare i samma container. (b) Godot vinner på ren prestanda men förlorar på agent-loopen och CI-komplexitet. (e) faller på iOS och offline-kravet.

---

## 3. Konkret byggkedja för Phaser 4 + Capacitor 8

### Repo-struktur
```
addictive_gameapp/
├─ src/            # TS: scenes/, systems/, entities/
├─ public/         # sprites, ljudsprites, index.html-assets
├─ dist/           # Vite-output = Capacitors webDir
├─ android/        # genereras av `npx cap add android`, checkas in
├─ ios/            # senare
├─ capacitor.config.ts
├─ tests/          # Playwright/Vitest – agentens verifieringsloop
└─ .github/workflows/android.yml
```

### npm-kommandon
```
npm run dev            # vite – öppnas i browser, agenten testar här
npm run build          # vite build -> dist/
npx cap sync android   # kopierar dist/ + uppdaterar plugins
npx cap run android    # kräver ansluten enhet/emulator
```

### Signerad AAB via GitHub Actions (skiss)
1. Generera keystore lokalt: `keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. `base64 -w0 release.jks` → lägg som secret `KEYSTORE_B64`. Dessutom `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
3. Workflow på `ubuntu-latest`: `actions/setup-node@v4` (Node 22) → `actions/setup-java@v4` (**JDK 21** – rekommenderat för AGP 8.13 + SDK 36) → `android-actions/setup-android@v3` → `npm ci && npm run build && npx cap sync android` → återställ keystore med `echo "$KEYSTORE_B64" | base64 -d > android/app/release.jks` → `cd android && ./gradlew bundleRelease` (signConfig läser från `-P`-properties eller miljövariabler).
4. Output: `android/app/build/outputs/bundle/release/app-release.aab`. Lägg även till `assembleRelease` för en `.apk` att sideloada. Ladda upp båda som artifacts.
   - Alternativ till egen signering: `r0adkll/sign-android-release`.
   - **Viktigt:** kör aldrig `./gradlew` innan `cap sync`, annars byggs gammal `dist/`.

### Testa på egen Android-telefon
- **Enklast nu:** ladda ner `.apk`-artifacten från Actions, överför till telefonen, tillåt "installera okända appar". Eller `adb install app-release.apk` via USB.
- **Viktig förändring:** från 2026-08 rullar Google ut *developer verification*. Från 2026-09-30 gäller det Brasilien, Indonesien, Singapore, Thailand; **global utrullning 2027 och framåt**. Sverige påverkas alltså inte förrän tidigast 2027, men planera för det. Det finns ett gratis **"limited distribution account"** för studenter/hobbyister: ingen ID-kontroll, ingen avgift, **upp till 20 enheter**.
- **Play Internal testing**: upp till 100 testare, release på minuter, ingen granskningsväntan. Bra för egen telefon – men räknas **inte** mot 12-testarkravet.

### iOS – vad som krävs
- **Apple Developer Program: 99 USD/år** (299 USD/år för Enterprise). Obligatoriskt för TestFlight och App Store.
- Från **2026-04-28** måste appar byggas med **Xcode 26 / iOS 26 SDK** eller senare.
- Capacitor 8 kräver **Xcode 26.0+** och använder Swift Package Manager som standard.
- `macos-26`-runnern är GA sedan 2026-02-26 med Xcode 26 förinstallerat → `npx cap sync ios` + `xcodebuild archive` + `-exportArchive` + upload till TestFlight med App Store Connect API-nyckel (t.ex. via fastlane). **Ingen egen Mac behövs i teorin** (se risk 6.2).
- **Kostnad i Actions:** macOS-runners drar inkluderade minuter med **10x-multiplikator**. Privata repon på Free-planen har 2 000 inkluderade minuter/månad → ca 200 macOS-minuter. Sekundärkällor anger ~0,062 USD/min för macOS efter det (2026) – **verifiera i GitHubs egna prislistor innan iOS-fasen**.

### Kostnadssammanfattning
| Post | Kostnad |
|---|---|
| Google Play Console | **25 USD engångs**, ingen årsavgift |
| Apple Developer Program | **99 USD/år** |
| GitHub Actions Linux (Android) | Gratis inom 2 000 min/mån på privat repo |
| GitHub Actions macOS (iOS) | 10x-multiplikator; realistiskt några USD/månad (uppskattning) |

---

## 4. Butikskrav

### Google Play 2025/2026
- **AAB obligatoriskt** för alla nya appar sedan augusti 2021. APK endast för sideload.
- **Target API:** från **2026-08-31** måste nya appar och uppdateringar targeta **Android 16 (API 36)**. Befintliga appar måste minst targeta API 35 för att synas för nya användare på nyare Android. Förlängning kan begäras till 2026-11-01.
- **12 testare i 14 dagar:** gäller personliga konton skapade **efter 2023-11-13**, per app. Minimum sänktes från 20 till 12 den 2024-12-11. Testarna måste vara **kontinuerligt** opt-in i 14 dagar; hoppar någon av nollställs det. **(Primärkälla var blockerad – verifiera på support.google.com/.../14151465 innan ni planerar lanseringen.)** Organisationskonton är undantagna.
- **Data safety-formuläret** måste fyllas i även för en offline-app utan konton. Det blir enkelt: "ingen data samlas in, ingen data delas" – men det måste deklareras och stämma.
- **Families policy:** om målgruppen inkluderar barn gäller Families-programmet – certifierade annons-SDK:er, förbud mot personaliserad annonsering, striktare innehållskrav. **Rekommendation: sätt åldersgrupp till 13+ i v1** för att slippa hela spåret. Åldersklassificeringsformuläret måste också besvaras.

### App Store i korthet
- 99 USD/år, Xcode 26 / iOS 26 SDK från 2026-04-28, App Privacy-deklaration (motsvarande Data safety), Age Rating (uppdaterade frågor sedan 2026-01-31), manuell review, TestFlight för beta. Wrappade webbsajter utan eget värde avvisas normalt – ett riktigt spel i Capacitor är däremot helt OK.

---

## 5. Rekommenderade bibliotek

- **Partiklar:** Phaser 4:s inbyggda `ParticleEmitter` + `SpriteGPULayer`. Phaser 3.60+ bytte till en enda bunden textur och tog bort blockerande `bufferSubData`, vilket var den stora mobilflaskhalsen. Använd **en enda texture atlas** för alla partiklar.
- **Tweens:** Phasers inbyggda `this.tweens.add()` räcker. Behövs mer: **GSAP är 100 % gratis sedan 2025-04-30, inklusive alla tidigare betalplugins, även kommersiellt.**
- **Ljud:** Phasers Web Audio-backend i första hand. **Använd audio sprites** (en fil, offsets) – det är det enda som ger acceptabel latens på Android. Alternativ: **Howler.js** (Web Audio med HTML5-fallback, `autoUnlock` på första användarinteraktion). Ljud måste startas i en user-gesture, annars är AudioContext suspended. Latensen i WebView är märkbart högre än native – **uppskattning: håll kritisk feedback (träff/klick) på haptik + visuellt, låt ljudet vara sekundärt.**
- **Haptik:** `@capacitor/haptics` – `impact()`, `notification()`, `vibrate()`, `selectionStart/Changed/End()`. Faller tyst tillbaka på enheter utan vibrator. Fungerar även på web (begränsat).
- **Spara data:** `@capacitor/preferences` (UserDefaults på iOS, SharedPreferences på Android). **Använd detta, inte localStorage** – mobil-OS kan rensa `window.localStorage` periodvis. Endast strängvärden, så `JSON.stringify` state. localStorage kan användas som cache i webb-dev-läget.
- **WebView-fällor att stänga av direkt** i `index.html`/CSS:
  - `<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">` – tar bort 300 ms tap-delay (Chrome sedan v32, Safari med `width=device-width`).
  - `touch-action: manipulation` (helst `none` på canvas) – stoppar double-tap-zoom.
  - `overscroll-behavior: none` på `html, body` – stoppar scroll-bounce/pull-to-refresh.
  - `-webkit-user-select: none; -webkit-touch-callout: none;` – stoppar långtrycks-meny och textmarkering.
  - `position: fixed; overflow: hidden` på body, plus `preventDefault()` på `touchmove`.
  - Använd `pointerdown`, aldrig `click`, för spelinput.

---

## 6. Risker och osäkerheter

1. **Mac-frågan är öppen och måste besvaras.** Hela iOS-planen bygger på att `macos-26`-runnern räcker. Att bygga, signera och ladda upp till TestFlight helt via CI är väl beprövat – men **felsökning av iOS-specifika buggar utan en Mac att köra simulator på är smärtsamt**. Uppskattning: räkna med att låna en Mac minst en gång vid första iOS-releasen.
2. **Certifikat och provisioning-profiler** måste skapas utan Xcode-GUI (App Store Connect API-nyckel + fastlane match). Jag har **inte** kunnat verifiera detta flöde mot Apples officiella dokumentation i den här sessionen – behandla som osäkert tills det testats.
3. **12 testare i 14 dagar** är den största icke-tekniska blockeraren. Den kräver 12 riktiga Google-konton som stannar opt-in i två veckor. Planera in detta ~4 veckor före tänkt lansering.
4. **WebView-prestanda ≠ Chrome-prestanda.** Det finns dokumenterade fall där appar som flyter i mobil-Chrome hackar i Capacitor på Android. Bygg en prestanda-benchmark-scen (t.ex. 2 000 partiklar) tidigt och mät på en riktig mellanklasstelefon innan spellogiken är låst.
5. **Android WebView kraschar vid för hög minnesanvändning.** Håll texturatlaser små, pool:a alla objekt, undvik allokeringar i `update()`.
6. **Target API 36-deadline 2026-08-31** har redan passerat vid skrivande stund – Capacitor 8 targetar SDK 36, så det är täckt, men lås fast versionerna i `variables.gradle`.
7. **Developer verification (global 2027)** kan påverka hur ni distribuerar APK:er utanför Play. Bevaka.
8. **Phaser 4 är ung** (april 2026). Uppskattning: räkna med enstaka buggar och tunnare community-exempel än för Phaser 3. Fallback: Phaser 3 fungerar fortfarande utmärkt för ett enkelt spel.

---

## Källor

- [Meet Google Play's target API level requirement – Android Developers](https://developer.android.com/google/play/requirements/target-sdk)
- [Android developer verification – Android Developers](https://developer.android.com/developer-verification)
- [Android developer verification: Rolling out to all developers – Android Developers Blog](https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html)
- [Android App Bundle FAQ – Android Developers](https://developer.android.com/guide/app-bundle/faq)
- [Trusted Web Activities Quick Start Guide – Android Developers](https://developer.android.com/develop/ui/views/layout/webapps/guide-trusted-web-activities-version2)
- [Upcoming SDK minimum requirements – Apple Developer](https://developer.apple.com/news/upcoming-requirements/)
- [App testing requirements for new personal developer accounts – Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465) *(blockerad i containern – verifiera manuellt)*
- [Provide information for Google Play's Data safety section – Play Console Help](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Google Play Families Policies – Play Console Help](https://support.google.com/googleplay/android-developer/answer/9893335)
- [Updating to Capacitor 8.0 – Capacitor Documentation](https://capacitorjs.com/docs/updating/8-0)
- [Haptics Capacitor Plugin API](https://capacitorjs.com/docs/apis/haptics) · [Preferences Capacitor Plugin API](https://capacitorjs.com/docs/apis/preferences)
- [Announcing Capacitor 8 – Ionic Blog](https://ionic.io/blog/announcing-capacitor-8)
- [Phaser 4 Renderer: Faster, Cleaner, and Built for Modern Games](https://phaser.io/news/2026/04/phaser-4-renderer-faster-cleaner-and-built-for-modern-games)
- [Phaser 3.60 Mobile Performance changelog](https://github.com/phaserjs/phaser/blob/v3.60.0/changelog/3.60/MobilePerformance.md)
- [Exporting projects – Godot Engine docs](https://docs.godotengine.org/en/latest/tutorials/export/exporting_projects.html)
- [Godot Mobile update — April 2026](https://godotengine.org/article/godot-mobile-update-apr-2026/)
- [Flame Engine](https://flame-engine.org/) · [flame on pub.dev](https://pub.dev/packages/flame)
- [macos-26 is now generally available for GitHub-hosted runners – GitHub Changelog](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/)
- [Actions runner pricing – GitHub Docs](https://docs.github.com/en/billing/reference/actions-runner-pricing) *(blockerad i containern – verifiera manuellt)*
- [Sign Android release – GitHub Marketplace](https://github.com/marketplace/actions/sign-android-release)
- [300ms tap delay, gone away – Chrome for Developers](https://developer.chrome.com/blog/300ms-tap-delay-gone-away)
- [howler.js](https://howlerjs.com/) · [Webflow makes GSAP 100% free](https://webflow.com/blog/gsap-becomes-free)
