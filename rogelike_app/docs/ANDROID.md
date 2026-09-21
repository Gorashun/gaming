# Android – bygga, signera och sidoladda PIPWRECK

*M4. Gäller Godot 4.6 stable. Normativ för allt som rör Android-bygget; koden
ligger i `export_presets.cfg`, `tools/gen_icons.py`,
`tools/godot_editor_settings.sh` och `.github/workflows/android-debug.yml`.*

> **Miljöanmärkning.** Den container agenterna kör i har inget `dl.google.com`
> och alltså ingen Android SDK. Därför byggs APK:n i GitHub Actions, där
> `ubuntu-latest` har SDK och JDK förinstallerade (DECISIONS 2026-09-21).
> Allt nedan är verifierat så långt containern tillåter; exakt vad som
> verifierats står i §11.

---

## 1. Projektinställningar (`project.godot`)

| Rad | Varför |
|---|---|
| `application/config/version="0.1.0"` | Första bygget som är tänkt att hamna på en telefon. Play läser `version/name` ur presetet, inte härifrån, men de två ska följas åt. |
| `boot_splash/show_image=false` | Tar bort Godot-loggan. Utan raden visar appen Godots logotyp innan första bildrutan. |
| `boot_splash/bg_color=#0E1216` | `surface/pit` ur UI_GUIDE §2.1. Samma färg som `Backdrop`-noden i `main.tscn`, så starten inte blinkar. |
| `boot_splash/minimum_display_time=200` | Utan spärr hinner en snabb telefon visa splashen i ett par bildrutor, vilket läser som en flimrande vit ruta. |
| `display/window/handheld/orientation=1` | 1 = PORTRAIT. Brädan är ritad för 1080×1920; liggande läge klipper tärningsbrickan (UI_GUIDE §2.9). |
| `input_devices/pointing/emulate_mouse_from_touch=true` | Hela UI:t är `Control`-noder som lyssnar på musknappar. Utan översättningen gör ett finger ingenting. |
| `input_devices/pointing/emulate_touch_from_mouse=false` | Motsatt riktning ger dubbla events på skrivbordet och får tap-catchern i `combat_screen.gd` att hoppa över kedjan två gånger. |
| `rendering/renderer/rendering_method.mobile="mobile"` | Fanns sedan M0. |

## 2. Ikoner

`tools/gen_icons.py` genererar fyra PNG:er till `assets/icons/android/`:

| Fil | Storlek | Roll |
|---|---|---|
| `icon_foreground.png` | 432×432 | Adaptive icon, förgrund (tärningen, transparent bakgrund) |
| `icon_background.png` | 432×432 | Adaptive icon, bakgrund (mörk, opak) |
| `icon_monochrome.png` | 432×432 | Themed icon, Android 13+ |
| `icon_legacy.png` | 192×192 | Launchers före Android 8 |

Tre saker att veta:

1. **Den monokroma layern är inte valfri.** Utan
   `launcher_icons/adaptive_monochrome_432x432` lägger Godot in sin egen
   `GodotMonochrome`-drawable, och spelet får en Godot-logga som tema-ikon på
   Android 13+.
2. **Säkerhetszonen.** Adaptive icons är 108 dp, men launchern garanterar bara
   den inre 72 dp-cirkeln. På 432 px betyder det radie 144 px från mitten.
   Tärningens yttersta kritpixel ligger på radie ~127 px.
3. **Reproducerbart.** Kritvobbel och korn kommer ur en heltalshash med fast
   seed, aldrig ur `random`. En omkörning ger byte-identiska filer, så en
   regenerering aldrig dyker upp som en diff.

Kör om efter en ändring och registrera resultatet:

```bash
cd rogelike_app/tools && python3 gen_icons.py --out ../assets/icons/android
cd .. && python3 tools/check_asset_licenses.py
```

## 3. Export-presets (`export_presets.cfg`)

Filen är **handskriven**, inte editor-genererad: CI har ingen editor-session
och en handhållen fil går att granska i en diff.

### Två presets

| | `Android Debug` | `Android Release` |
|---|---|---|
| Format | APK (`gradle_build/export_format=0`) | AAB (`=1`) |
| Bygge | Förbyggd mall (`use_gradle_build=false`) | Gradle (`=true`) |
| Min/target SDK | 24 / **35** (mallens) | 24 / **36** |
| Signering | debug keystore | egen keystore ur miljövariabler |
| Används till | sidoladdning på Anders telefon, CI-artefakt | Google Play |

### Rad för rad, det som inte är självklart

- **`gradle_build/use_gradle_build=false` i debug.** Godot använder då den
  förbyggda `android_debug.apk`-mallen. Bygget kräver ingen Gradle, ingen NDK
  och inget `cmdline-tools` – bara `build-tools` (för `apksigner` och
  `zipalign`) och `platform-tools`. Det är skillnaden mellan ~1 minut och
  ~10 minuter i CI.
- **`gradle_build/min_sdk` och `target_sdk` är TOMMA i debug.** Godot avvisar
  exporten med *"Min SDK can only be overridden when Use Gradle Build is
  enabled"* om de sätts utan gradle-bygge. Debug-APK:n ärver därför mallens
  värden: min 24, target 35 (`config.gradle` i `android_source.zip`).
  **Det är ingen Play-risk** – target-API-kravet gäller det som laddas upp
  till Play, alltså AAB:n, och den sätter 36.
- **`export_format`.** AAB kan bara byggas med gradle-bygge; Godot säger
  *"Export AAB is only valid when Use Gradle Build is enabled"*.
- **`keystore/release*` är tomma strängar.** Godot läser
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` och `_PASSWORD` ur miljön och
  låter dem vinna över presetets värden. Projektets egna hemligheter heter
  `PIPWRECK_KEYSTORE_BASE64` / `_USER` / `_PASS` och mappas om i workflowen
  (§5). Det betyder att **ingen keystore och inget lösenord någonsin står i
  repot**; `.gitignore` blockerar `*.keystore` och `*.jks`.
- **`permissions/vibrate=true`, inget annat.** `Juice.haptic()` anropar
  `Input.vibrate_handheld`, som kräver `android.permission.VIBRATE`. Spelet är
  offline-first och begär därför inte ens `INTERNET`. Varje ytterligare
  behörighet måste motiveras i Play Consoles Data safety-formulär.
- **`screen/immersive_mode=true`.** Göm system-barerna. Det är också skälet
  till att HUD:en måste räkna med skärmurtag – se `src/platform/safe_area.gd`.
- **`screen/edge_to_edge=false`.** Immersive räcker för M4. Slås `edge_to_edge`
  på ritas spelet under status- och navigeringsfälten även när de syns, och då
  måste även botten kompenseras, inte bara toppen.
- **`architectures`: `arm64-v8a` och `armeabi-v7a` på, x86 av.** CLAUDE.md.
  x86-telefoner finns inte längre; x86 behövs bara för emulatorer.
- **`package/unique_name="se.pipwreck.game"`.** Applikations-ID:t. Det går
  **inte** att ändra efter första uppladdningen till Play.
- **`version/code=1`.** Heltal som måste öka vid varje uppladdning till Play.
  `version/name` är strängen spelaren ser.
- **`export_filter="all_resources"`.** Allt under `res://` följer med. Ikonerna
  under `assets/icons/android/` hamnar därmed också i PCK:en (≈115 kB spill).
  Medvetet: exporten läser dem från projektkatalogen, och en exclude-regel som
  någon skriver fel tar ner hela bygget i stället för att spara 115 kB.
- **`script_export_mode=2`.** Binära tokens (standard). Ingen kryptering:
  `encrypt_pck=false`. Ett offline-spel utan köp har inget att skydda, och
  nyckeln skulle ändå ligga i binären.

## 4. Debug keystore och editor-inställningar

Godots Android-export läser tre saker ur **editor**-inställningarna, inte ur
projektet eller presetet:

```
export/android/android_sdk_path    där apksigner och zipalign bor
export/android/java_sdk_path       JDK:n som apksigner körs på
export/android/debug_keystore      nyckeln varje debug-APK signeras med
```

På en utvecklardator skriver editorn dem själv. Headless finns ingen editor,
så `tools/godot_editor_settings.sh` skriver
`~/.config/godot/editor_settings-4.6.tres` för hand och skapar keystoren med
`keytool`:

```bash
tools/godot_editor_settings.sh                      # ANDROID_HOME + JAVA_HOME
tools/godot_editor_settings.sh --sdk /opt/android-sdk --jdk /usr/lib/jvm/jdk-17
```

Alias `androiddebugkey` och lösenord `android` är Androids offentliga
standardvärden sedan 2009 – ingen hemlighet, men filen committas ändå aldrig.

## 5. CI: `.github/workflows/android-debug.yml`

Två jobb. `test.yml` är orörd.

### `apk-debug` – varje push som rör `rogelike_app/**`, alla grenar

| Steg | Kommentar |
|---|---|
| `actions/setup-java@v4`, temurin 17 | Godot 4.6 kräver JDK 17 (`config.gradle`: `javaVersion = VERSION_17`). `apksigner` körs på den. |
| `android-actions/setup-android@v3` | Installerar **bara** `platform-tools` och `build-tools;35.0.1`. Ingen NDK, ingen platform, ingen cmdline-gradle: utan gradle-bygge är det allt Godot behöver. |
| `actions/cache` på `~/godot` | Samma nyckel som `test.yml`. |
| `actions/cache` på export templates | ~1 GB. Ingen optimering utan en förutsättning – utan cache laddas ett gigabyte vid varje push. |
| `tools/godot_editor_settings.sh` | Keystore + editor-inställningar (§4). |
| `godot --headless --import` | Genererar `.godot/` och registrerar alla `class_name`. |
| `godot --headless --export-debug "Android Debug" build/pipwreck-debug.apk` | Godot returnerar 1 på exportfel; steget kontrollerar dessutom att filen finns och är > 5 MB, för en trunkerad APK kan annars smyga igenom. |
| Job summary | Storlek, sha256, paketnamn, commit. |
| `actions/upload-artifact` | Artefakten heter **`pipwreck-debug-apk`**, 30 dagars retention. |

### `aab-release` – bara `workflow_dispatch`

Kräver tre Actions-secrets. Saknas någon av dem hoppas jobbet över med en
notis i job summary i stället för att falla på ett kryptiskt keystore-fel.

| Secret | Innehåll |
|---|---|
| `PIPWRECK_KEYSTORE_BASE64` | `base64 -w0 pipwreck.keystore` |
| `PIPWRECK_KEYSTORE_USER` | nyckelns alias |
| `PIPWRECK_KEYSTORE_PASS` | lösenordet |

> **Avvikelse från M4-briefen:** briefen sa `PIPWRECK_KEYSTORE_PATH`. En sökväg
> är meningslös på en färsk runner – filen måste med. Därför base64. Workflowen
> skriver ut den till `$RUNNER_TEMP/signing/`, sätter
> `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` och raderar filen i ett
> `if: always()`-steg.

Jobbet installerar mer: `platforms;android-35` (gradle-byggets `compileSdk`),
`platforms;android-36` (target), och `ndk;28.1.13356709` – AGP vägrar bygga
utan exakt den NDK-version `build.gradle` deklarerar. Det kör också
`godot --headless --install-android-build-template`, som packar upp
`android_source.zip` i projektets `android/build/` (den katalogen är
gitignorerad).

## 6. Mobilanpassningar i koden

### Haptik

`Juice.haptic()` → `Input.vibrate_handheld()` → kräver
`android.permission.VIBRATE`, som presetet sätter. Nivåerna är 15/30/60 ms
(light/medium/heavy, DECISIONS 2026-09-21) och **ska utvärderas på Anders
riktiga telefon i M4** innan de ändras – det var villkoret när de sattes.

### Appen går i bakgrunden

`GameController._notification` fångar `NOTIFICATION_APPLICATION_PAUSED` och gör
två saker:

1. **Autosave** – men bara när det är säkert. `CombatScreen.is_safe_to_autosave()`
   säger nej så fort rundan dragit ett omkast eller är mitt i sin uppspelning.
   Skälet: sparfilen innehåller stridsläget som det såg ut när rundan började
   plus slumpströmmens position, och de två måste höra ihop. Ett omkast har
   redan rullat strömmen vidare. GAME_DESIGN §1: aldrig spara mitt i en kedja.
   Priset är att placeringar i en påbörjad runda går förlorade om Android
   dödar processen – det är rätt pris.
2. **Tystar ljudet** (`Juice.suspend_audio(true)`): stoppar kanalerna, mutar
   master-bussen och **släpper en pågående hit-stop**. Utan det sista vaknar
   appen med `Engine.time_scale` på 0,04.

`NOTIFICATION_APPLICATION_RESUMED` släpper på igen.

### Bakåtknappen

`application/config/quit_on_go_back=false` i `project.godot`. Standardvärdet
`true` gör att `SceneTree` **avslutar appen** på
`NOTIFICATION_WM_GO_BACK_REQUEST` – spelet stänger sig tyst mitt i en run.

`GameController.back_action(screen, settings_open, resolving)` är en ren
funktion, och ett test går igenom alla kombinationer och kräver att ingen av
dem svarar "avsluta":

| Läge | Svar |
|---|---|
| Inställningsmodal öppen | stäng modalen |
| Strid, kedjan spelas upp | hoppa till slutet (samma som en tapp) |
| Strid, march, belöning | öppna inställningarna |
| Död/vinst-skärmen | tillbaka till titeln |
| Titeln | ingenting |

### Skärmurtag (notch)

`src/platform/safe_area.gd`. `DisplayServer.get_display_safe_area()` svarar i
**skärmpixlar**; UI:t ritas i **viewport-enheter** (1080 brett, med
`stretch/mode=canvas_items` + `aspect=expand` blir en hög telefon högre än
1920). `SafeArea.top_inset_from()` gör om det ena till det andra och är en ren
funktion – den testas utan telefon. Nonsensrapporter (tomt område, noll
skärmhöjd, safe area större än skärmen) ger 0, och insetet är takat på
240 viewport-enheter så en delad skärm inte trycker ut HUD:en.

`GameScreen.apply_safe_area()` lägger insetet på skärmens `Margin`-container
**efter** `enter()`, eftersom varje skärm sätter sin egen `margin_top` i
`_style()`. Bastalet sparas i metadata så ett andra anrop inte dubblar.

## 7. Sidoladda APK:n på en telefon

### Ladda ner den ur GitHub Actions

1. GitHub → fliken **Actions** → workflowen **PIPWRECK Android** → den senaste
   körningen på din gren.
2. Längst ner under **Artifacts**: `pipwreck-debug-apk`. Klicka för att ladda
   ner. Du får en **ZIP** – GitHub packar alltid artefakter.
3. Packa upp. Inuti ligger `pipwreck-debug.apk`.

Job summary på samma sida visar storlek och sha256, så du kan kontrollera att
du fick rätt fil.

### Installera direkt på telefonen

1. Flytta över APK:n (USB, Google Drive, mejl till dig själv).
2. Öppna den i telefonens filhanterare. Android frågar om appen får installera
   okända appar: **Inställningar → Appar → Särskild åtkomst → Installera
   okända appar → (filhanteraren) → Tillåt**.
3. Play Protect varnar för en osignerad-från-Play-app. Välj "Installera ändå".
   Debug-APK:n är signerad, men med Androids publika debug-nyckel.

### Installera med adb (snabbare när man gör det ofta)

```bash
# Aktivera Utvecklaralternativ på telefonen: Inställningar -> Om telefonen ->
# tryck sju gånger på "Versionsnummer". Slå sedan på USB-felsökning.
adb devices                       # godkänn dialogen på telefonen
adb install -r pipwreck-debug.apk # -r ersätter en tidigare installation
adb logcat -s godot               # spelets utskrifter
```

Byter debug-nyckeln (ny runner, ny keystore) måste den gamla installationen
bort först: `adb uninstall se.pipwreck.game`.

## 8. Bygga lokalt (Anders egen dator)

Containern agenterna kör i når inte `dl.google.com` och kan därför inte göra
det här. På en vanlig dator:

```bash
# 1. Android SDK. Enklast via Android Studio (SDK Manager), eller cmdline-tools:
sdkmanager "platform-tools" "build-tools;35.0.1"
# För release-AAB dessutom:
sdkmanager "platforms;android-35" "platforms;android-36" "ndk;28.1.13356709"

# 2. JDK 17 (Temurin, eller det som följer med Android Studio).

# 3. Export templates: Godot-editorn -> Editor -> Manage Export Templates ->
#    Download and Install. Eller för hand:
curl -fL -o templates.tpz \
  https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz
unzip templates.tpz -d /tmp/t
mkdir -p ~/.local/share/godot/export_templates
mv /tmp/t/templates ~/.local/share/godot/export_templates/4.6.stable

# 4. Keystore + editor-inställningar (gör det editorn annars gör):
cd rogelike_app
tools/godot_editor_settings.sh --sdk "$ANDROID_HOME" --jdk "$JAVA_HOME"

# 5. Bygg.
godot --headless --import
mkdir -p build
godot --headless --export-debug "Android Debug" build/pipwreck-debug.apk
```

Kör du Godot-editorn grafiskt räcker **Project → Export → Android Debug →
Export Project**; editorn skriver sina egna inställningar och presetet läses
från `export_presets.cfg`.

## 9. Release-AAB: skapa och använd en egen keystore

**Den här nyckeln är oersättlig.** Tappar du bort den går appen inte att
uppdatera på Play (om inte Play App Signing är påslaget, vilket det ska vara).
Backa upp filen och lösenordet på minst två ställen, aldrig i repot.

```bash
keytool -genkeypair \
  -keystore pipwreck.keystore \
  -storetype pkcs12 \
  -alias pipwreck \
  -keyalg RSA -keysize 4096 \
  -validity 10950 \
  -dname "CN=Anders Ferrer, O=PIPWRECK, L=Stockholm, C=SE"
# keytool frågar efter lösenordet. Välj ett långt och spara det i en
# lösenordshanterare.
```

Bygg lokalt:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/pipwreck.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="pipwreck"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="..."
godot --headless --install-android-build-template
godot --headless --export-release "Android Release" build/pipwreck-release.aab
```

Bygg i CI: lägg in de tre secrets som §5 listar och kör workflowen manuellt
(Actions → PIPWRECK Android → Run workflow).

Kontrollera resultatet innan uppladdning:

```bash
# Att det är en AAB och vad den innehåller (bundletool, valfritt):
bundletool build-apks --bundle=pipwreck-release.aab --output=pipwreck.apks \
  --ks=pipwreck.keystore --ks-key-alias=pipwreck
# Signaturen:
jarsigner -verify -verbose -certs pipwreck-release.aab
```

**Versionskoden måste öka vid varje uppladdning.** Den står i
`export_presets.cfg` (`version/code`) och börjar på 1.

## 10. Play Console-checklista

Ordningen spelar roll: punkt 4 har 14 dagars ledtid och är den längsta i hela
flödet (research/02_tech_stack.md §"Plattformskrav").

1. **Konto.** Google Play Developer, 25 USD engångsavgift. Personliga konton
   skapade efter 2023-11-13 omfattas av testkravet i punkt 4.
2. **App skapad**, paketnamn `se.pipwreck.game`. **Går inte att ändra efteråt.**
3. **Play App Signing på.** Google håller den riktiga signeringsnyckeln; din
   upload-nyckel går att byta om den tappas bort. Utan det är en förlorad
   nyckel slutet för appen.
4. **Closed testing: 12 testare som är opt-in i 14 sammanhängande dagar.**
   Starta den här så tidigt som möjligt – den går inte att förkorta.
5. **IARC-åldersklassificering.** Frågeformulär i konsolen. PIPWRECK är 13+
   (CLAUDE.md): tecknat fantasivåld, ingen realistisk blodsutgjutelse, **inga
   simulerade pengaspel** (viktigt – svara "nej" på lootbox-/casinofrågorna,
   det stämmer: inga lootboxar för pengar, inga energi-timers, DECISIONS).
6. **Data safety-formuläret.** Krävs även när appen inte samlar in något.
   PIPWRECK är offline-first utan backend och begär bara `VIBRATE`; svaret är
   "ingen data samlas in, ingen data delas". Ändras det måste formuläret
   ändras samma dag.
7. **Integritetspolicy.** Krävs även utan datainsamling. En URL måste anges –
   en statisk sida räcker, men den måste finnas och vara publik.
8. **Target API 36.** Krav sedan 2026-08-31. Release-presetet sätter
   `gradle_build/target_sdk="36"`. Debug-APK:n ligger på 35 och berörs inte –
   Play ser bara AAB:n.
9. **16 KB page size.** Android kräver det för appar med nativ kod (hård spärr
   för uppdateringar 2027-02-01). Godot stödjer det från 4.3, så 4.6 är klar.
   Kontrollera ändå den första AAB:n innan uppladdning:
   ```bash
   unzip -o pipwreck-release.aab -d aab_check
   # Alla .so ska ha segment alignade på 16384:
   find aab_check -name "*.so" -exec llvm-readelf -l {} \; | grep -A1 LOAD
   ```
   Play Console flaggar det också själv i förhandsgranskningen.
10. **Butikssidan**: titel (PIPWRECK), kort och lång beskrivning, ikon 512×512,
    feature graphic 1024×500, minst två telefonskärmdumpar. Ikonen 512×512 går
    att generera med samma verktyg: `tools/gen_icons.py` ritar i valfri
    storlek via `draw_die()`.
11. **Innehållsdeklarationer**: annonser (nej), app-åtkomst (allt öppet, ingen
    inloggning), covid/finans (nej), regeringsapp (nej).

## 11. Vad som är verifierat och vad som inte är det

**Verifierat i den här miljön (2026-09-21):**

- Hela gdUnit4-sviten: **247 tester, 0 fel, 0 failures**.
- Rökprovet under Xvfb: `SMOKE OK`, seed 7, WIN, 4 rum.
- `project.godot` och `export_presets.cfg` parsas av Godot 4.6, med export
  templates 4.6.stable installerade. Exporten når hela vägen till
  signeringssteget och faller **bara** på den saknade Android SDK:n:
  ```
  ERROR: Cannot export project with preset "Android Debug" due to configuration errors:
  Invalid Android SDK path in Editor Settings. Missing 'platform-tools' directory!
  Unable to find Android SDK platform-tools' adb command. ...
  Invalid Android SDK path in Editor Settings. Missing 'build-tools' directory!
  Unable to find Android SDK build-tools' apksigner command. ...
  ```
  Inga fel om preset, mallar, ikoner eller projekt.
- Ikongeneratorn och licenschecken: 93/93 registrerade.
- Workflow-YAML:en parsas (`python3 -c "import yaml"`).

**Inte verifierat – kräver GitHub-runnern eller en riktig telefon:**

- Att APK:n faktiskt byggs och signeras.
- Att gradle-vägen (AAB) fungerar.
- Haptiknivåerna, bildfrekvensen och urtagsmarginalen på en riktig skärm.
- Att adaptive-ikonen ser rätt ut i en launcher-mask.
