# Android – bygga, signera och sidoladda PIPWRECK

*M4. Gäller Godot 4.6 stable. Normativ för allt som rör Android-bygget; koden
ligger i `export_presets.cfg`, `tools/gen_icons.py`,
`tools/godot_editor_settings.sh` och `.github/workflows/android-debug.yml`.*

> **Miljöanmärkning.** Den container agenterna kör i har inget `dl.google.com`
> och alltså ingen Android SDK. Därför byggs APK:n i GitHub Actions, där
> `ubuntu-latest` har SDK och JDK förinstallerade (DECISIONS 2026-09-21).
> Allt nedan är verifierat så långt containern tillåter; exakt vad som
> verifierats står i §8.

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
  `PIPWRECK_KEYSTORE_PATH` / `_USER` / `_PASS` och mappas om i workflowen
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
