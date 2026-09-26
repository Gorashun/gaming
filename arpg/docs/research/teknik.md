# Teknikval: motor, prestandabudget, asset-pipeline, build/CI

*R&D, 2026-09-26. Gäller en 3D-ARPG i chibi-/dark fantasy-stil för mobil (Android först, sedan iOS), byggd av AI-agenter i en Linux-container utan GUI.*
*Källa (URL) anges per påstående. **(U)** = egen uppskattning som måste verifieras med en spike.*

---

## 0. Rekommendation i korthet

**Välj Godot 4.7 (stable) med GDScript, Mobile-renderaren (Vulkan) och Compatibility (GLES3) som fallback.**
Assets tas fram med Blender 4.x headless (`blender -b -P script.py`) och exporteras som `.glb`. Android byggs på Linux-CI och iOS på GitHub Actions `macos`-runners med xcodebuild och fastlane.

Varför:
1. **Allt är text och går att köra headless.** Scener (`.tscn`), resurser (`.tres`), `project.godot` och `export_presets.cfg` är textfiler. Export görs med `godot --headless --export-release`. Ingen licens behöver aktiveras. ([GitHub Marketplace: Godot Export](https://github.com/marketplace/actions/godot-export), [StraySpark 4.6-exportguide](https://www.strayspark.studio/blog/godot-46-export-web-android-ios-guide))
2. **MIT-licens: inga avgifter och inga royalties.** ([Wikipedia: Godot](https://en.wikipedia.org/wiki/Godot_(game_engine)))
3. **Vår art style passar motorn.** Chibi low-poly kräver ingen Nanite/Lumen, så Unreals styrkor spelar liten roll för oss. **(U)**

Största riskerna med Godot, som ska testas först med spikes:
- Det finns kända prestandaregressioner på Android. ([issue #109251](https://github.com/godotengine/godot/issues/109251))
- Det finns få publicerade kommersiella 3D-ARPG:er i Godot på mobil. Vi har inte hittat någon. ([sökresultat, forum](https://forum.godotengine.org/t/rpg-equivalent-to-diablo-in-godot/131612))

---

## 1. Motorjämförelse

### 1.1 Översikt

| Kriterium | Godot 4.7 | Unity 6 | Unreal 5.7+ | Defold | Bevy |
|---|---|---|---|---|---|
| Licens/avgift | MIT, 0 kr | Personal gratis upp till 200k USD i intäkt+finansiering. Pro kostar 2 200 USD/år/plats och +5 % från 2026-01-12 | 5 % royalty på intäkter över 1 MUSD (3,5 % vid samtidig release i Epic Games Store) | Gratis, inga royalties | MIT/Apache, 0 kr |
| Headless CLI-build | Ja, `--headless --export-release` | Ja (`-batchmode`), men kräver aktiverad licens även i CI | Ja (UAT/BuildCookRun). Android kan packas från Linux-värd | Ja (bob.jar) **(U)** | Ja (cargo) |
| Licens i CI | Behövs inte | Krångligt: Personal-licens kan inte längre aktiveras offline med .ulf | Epic-konto/EULA, ingen aktivering i CI **(U)** | Behövs inte | Behövs inte |
| Textbaserade projektfiler | Ja: .tscn/.tres/.gd | Delvis: YAML med GUID-referenser och .meta-filer, svårt att redigera för hand **(U)** | Nej, .uasset/.umap är binära | Ja | Ja, allt är Rust-kod |
| Skriptspråk | GDScript (C# är experimentellt på mobil) | C# | C++ plus Blueprints (visuellt/binärt) | Lua | Rust |
| 3D-mognad på mobil | God, med vissa regressioner | Mycket god, branschstandard | Mycket god men tung (APK ≥ ~60 MB) | Begränsad 3D | Omogen på mobil |
| iOS utan Mac | Nej, kräver Xcode | Nej, kräver Xcode (eller Unity Build Automation) | Nej, kräver Mac med Xcode | Nej **(U)** | Nej |

Källor till tabellen:
- **Unity:** [pricing-updates](https://unity.com/products/pricing-updates), [CG Channel](https://www.cgchannel.com/2024/09/unity-scraps-controversial-runtime-fee-but-raises-prices/), [game-ci/cli PR #246](https://github.com/game-ci/cli/pull/246), [Unity-manual iOS-build](https://docs.unity3d.com/Manual/iphone-BuildProcess.html)
- **Unreal:** [licens](https://www.unrealengine.com/license), [PocketGamer 3,5 %](https://www.pocketgamer.biz/unreal-engine-royalty-fee-reducing-to-35-for-games-landing-on-epic-games-store-on-launch-day/), [Linux-quickstart](https://dev.epicgames.com/documentation/unreal-engine/linux-development-quickstart-for-unreal-engine?lang=en-US), [APK-storlek](https://forums.unrealengine.com/t/what-is-the-minimum-size-one-can-achieve-for-android-apk/296898), [mobilsetup / Mac-krav](https://dev.epicgames.com/documentation/en-us/unreal-engine/setting-up-an-unreal-engine-project-for-mobile-platforms)
- **Defold:** [defold.com](https://defold.com/), [licens](https://defold.com/license/), [generalistprogrammer: begränsad 3D](https://generalistprogrammer.com/tutorials/defold-game-engine-complete-tutorial)
- **Bevy:** [discussion #20998](https://github.com/bevyengine/bevy/discussions/20998), [Bevy Cheat Book](https://bevy-cheatbook.github.io/platforms.html)
- **Godot C# på mobil:** [Godot C# platform state](https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/)

### 1.2 Godot – läget 2025–2026

- **Aktuella versioner.**
  - Godot 4.6 kom i januari 2026. Den gjorde Jolt till standardfysik för 3D och ökade cachningen av Vulkan-descriptorer, vilket gav 10–20 % lägre CPU-tid i scener med många draw calls. ([GamingOnLinux](https://www.gamingonlinux.com/2026/01/the-free-and-open-source-godot-engine-4-6-is-out-now-with-major-upgrades/), [StraySpark rendering](https://www.strayspark.studio/blog/godot-46-rendering-deep-dive-ssr-lightmapper-performance))
  - Godot 4.7 kom 2026-06-18 och har en inbyggd VirtualJoystick-nod samt förbättrad Android-export. ([80.lv](https://80.lv/articles/godot-4-7-has-been-released), [linuxcompatible](https://www.linuxcompatible.org/story/godot-47-release-brings-hdr-output-faster-asset-store-and-smoother-mobile-development-to-your-projects/))
- **Vulkan-optimeringar.** Samarbetet med Google och The Forge gav 10–20 % lägre GPU-frametid på Android. ([Android Developers story](https://developer.android.com/stories/games/godot-vulkan), [Phoronix](https://www.phoronix.com/news/Godot-Better-Vulkan))
- **Renderer-fallback.** Mobile-renderaren faller tillbaka till Compatibility om Vulkan saknas. ([StraySpark/sammanfattning](https://www.strayspark.studio/blog/godot-46-rendering-deep-dive-ssr-lightmapper-performance))
  - Observera: om man byter från gl_compatibility till mobile minskar antalet stödda enheter i Play-filtret. ([issue #111729](https://github.com/godotengine/godot/issues/111729))
- **16 KB-sidstorlek.** Godot 4.5 stöder Android 15:s 16 KB-sidor direkt. ([Godot 4.5](https://godotengine.org/releases/4.5/))
- **Risk: prestandaregression.** En enkel 3D-scen gick från 60 till ~45 fps mellan 4.4dev3 och 4.4dev4, och problemet finns kvar i 4.5-snapshots. Vi måste mäta på riktig hårdvara. ([issue #109251](https://github.com/godotengine/godot/issues/109251))
- **Tester.** GdUnit4 har CLI-körning, JUnit-XML-rapporter och en GitHub Action. ([gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), [gdUnit4-action](https://github.com/MikeSchulze/gdUnit4-action))
- **AI-agenter.**
  - Det finns MCP-servrar för Godot, men de kräver en körande editor. För oss räcker filredigering plus CLI, och MCP är ett tillval. ([Godot AI](https://store.godotengine.org/asset/dlight/godot-ai/), [mcp.directory](https://mcp.directory/blog/godot-vs-unity-vs-blender-mcp-skills-2026))
  - GDScript är kompakt och har mycket träningsdata. Språket är ändå dynamiskt typat, så vi ska kräva statiska typannoteringar och ha lint i CI. **(U)**
- **ARPG-exempel.** Det finns en tutorialserie "Diablo-like ARPG in Godot 4.5+" och exempel i godot-gameplay-systems, men vi har inte hittat någon stor kommersiell mobil-ARPG i Godot. ([YouTube](https://www.youtube.com/playlist?list=PLDvxSFN380vB2Z4USAJugo7bpiioE_arz), [DeepWiki GGS](https://deepwiki.com/OctoD/godot-gameplay-systems/3.1-diablo-like-arpg-example))

### 1.3 Unity 6 – starkaste alternativet

**Fördelar:**
- Bäst beprövad för mobil-ARPG. Branschstandard **(U)**.
- Mogen verktygskedja för mobil: ASTC, Addressables, profilering.
- Officiell MCP-server för Claude Code finns. ([Unity blog MCP](https://unity.com/blog/unity-ai-mcp-how-to-get-started))

**Nackdelar för vår setup:**
- **Licens i CI.** Personal-licens kan inte längre aktiveras manuellt via .ulf. CI måste logga in med användarnamn och lösenord via Licensing Client, och en plats är upptagen tills den lämnas tillbaka. ([game-ci/cli PR #246](https://github.com/game-ci/cli/pull/246), [ankursheel](https://www.ankursheel.com/blog/unity-personal-license-manual-activation-workaround))
- **Scenfiler.** Scen- och prefab-YAML med `fileID`/GUID och `.meta`-filer är skört för agenter att redigera direkt. **(U)**
- **Kostnad.** Vid över 200k USD krävs Pro, 2 200 USD/år per plats. ([Unity](https://unity.com/products/pricing-updates))

**Välj Unity om** Godot-spikarna faller: färre än ~40 fiender vid 30 fps på referensenheten, eller oacceptabla regressioner.

### 1.4 Unreal 5 – avråds

- **Binära assets.** `.uasset` och Blueprints är binära, vilket gör dem nästan omöjliga för textagenter att arbeta med.
- **Tung motor.** Minsta APK är runt 60 MB. ([forum](https://forums.unrealengine.com/t/what-is-the-minimum-size-one-can-achieve-for-android-apk/296898))
- **Krav på version.** UE 5.7+ krävs för target SDK 35 på Google Play. ([Epic: Android-krav](https://dev.epicgames.com/documentation/unreal-engine/android-development-requirements-for-unreal-engine))
- **Bygge från källkod.** På Linux måste motorn byggas från källkod för Android-stöd. ([Epic community tutorial](https://dev.epicgames.com/community/learning/tutorials/epGK/building-unreal-engine-5-6-from-the-github-source-code-on-gnu-linux-with-android-support))
- **Fel verktyg för stilen.** Kraften (Nanite/Lumen) är i stort sett oanvändbar i en chibi-mobilstil. **(U)**

### 1.5 Defold och Bevy – avråds för detta projekt

- **Defold** är främst en 2D-motor med begränsad 3D. ([generalistprogrammer](https://generalistprogrammer.com/tutorials/defold-game-engine-complete-tutorial))
- **Bevy** går att få ut på Android och iOS, men ett kärnteammedlem säger att det "är möjligt men inte lätt", och Android-stödet är svagare än iOS-stödet. ([Bevy discussion #20998](https://github.com/bevyengine/bevy/discussions/20998), [Cheat Book](https://bevy-cheatbook.github.io/platforms.html))
- För båda gäller: för mycket egen infrastruktur (animation, UI, export) för ett agentteam. **(U)**

---

## 2. Prestandabudget för mellanklass-Android (2024–2026)

**Referensklass:** Mali-G57/G68 och Adreno 610–619 med 4–6 GB RAM.
- Mali-GPU:er finns i över 60 % av Android-telefonerna. ([sammanställning via Arm/Notebookcheck](https://www.arm.com/products/silicon-ip-multimedia/gpu/mali-g57))
- G57 MP2 ligger ungefär i nivå med Adreno 618. ([Notebookcheck](https://www.notebookcheck.net/ARM-Mali-G57-MP2-GPU-Benchmarks-and-Specs.537758.0.html))
- 4–8 GB RAM är det största segmentet. ([accio](https://www.accio.com/business/best-4gb-ram-smartphone))

**Mål:** 30 fps låst på referensklassen och 60 fps som tillval på bättre enheter. **(U)** ARPG-kameran ovanifrån visar mycket på skärmen samtidigt, så 30 fps är standard för genren.

### 2.1 Budget per frame

| Resurs | Budget (referens, 30 fps) | Grund |
|---|---|---|
| Trianglar på skärmen | 100–200k (tak ~300k) | 50–200k tris för 60 fps på mellanklass ([MessyPoly](https://www.messypoly.com/learn/polygon-budgets-mobile-games)). Googles Armies-demo klarar ~210k tris vid 30 fps ([Android Developers: Geometry](https://developer.android.com/games/optimize/geometry)) |
| Spelarkaraktär (LOD0) | 3–6k tris | Actionspel använder 5–20k för hjälten ([MessyPoly](https://www.messypoly.com/learn/polygon-budgets-mobile-games)). Chibi-stil och topdown-kamera tillåter lägre **(U)** |
| Vanlig fiende | 0,8–2k tris (LOD1 ~500) | 1–8k tris, lägre ände för flockar ([MessyPoly](https://www.messypoly.com/learn/polygon-budgets-mobile-games)). Halvera per LOD-nivå ([Android Developers](https://developer.android.com/games/optimize/geometry)) |
| Props / miljöbitar | 100–500 / 500–2 000 tris | [MessyPoly](https://www.messypoly.com/learn/polygon-budgets-mobile-games) |
| Draw calls | ≤ 150 (mål 100) | Mellanklass klarar 100–200 och lågklass 50–120 (sammanfattning av Arm-/branschguider, [Arm GPU Best Practices](https://developer.arm.com/documentation/101897/v2-2/Buffers-and-textures/Texture-sampling-performance)). För Vulkan är <1 000 ett allmänt tak |
| Texturer | ASTC, mipmaps alltid. Totalt ≤ 150–250 MB texturminne **(U)** | ASTC rekommenderas, och mipmaps för all 3D ([Arm GPU Best Practices](https://developer.arm.com/documentation/101897/v2-2/Buffers-and-textures/Texture-sampling-performance)). Texturbandbredd i snitt ≤ 1 GB/s och topp ≤ 3 GB/s ([samma](https://developer.arm.com/documentation/101897/v2-2/Buffers-and-textures/Texture-sampling-performance)) |
| Texturstorlek | Karaktär 512² (hjälte 1024²), fiender en gemensam atlas på 1024² | **(U)**. Chibi med handmålade eller gradientbaserade texturer behöver få texlar |
| Ljus | 1 riktat ljus med skugga plus ≤ 4–8 omni-/spotljus per vy utan skuggor. Bakade lightmaps för miljö | **(U)**. Godots Mobile-renderare har en begränsning på antal ljus per mesh, som måste verifieras i spike |
| Transparens/overdraw | Minimera partiklar i helskärm. Använd additiva sprites i låg upplösning | Overdraw kostar ofta mer än trianglar ([MessyPoly](https://www.messypoly.com/learn/polygon-budgets-mobile-games)) |
| Mikrotrianglar | Inga trianglar under ~10 px | [Android Developers](https://developer.android.com/games/optimize/geometry) |

### 2.2 Hur många fiender samtidigt?

Uppskattningarna nedan är **(U)** och ska verifieras med en spike.

| Nivå | Fiender | Förutsättningar |
|---|---|---|
| Skelettanimerade fiender (Skeleton3D) | 30–50 synliga | Skinning och AnimationTree kostar CPU per instans. Ungefär 50 × 1,5k = 75k tris, vilket ryms i budgeten |
| Horder | 100–300 | Vertex Animation Textures (VAT) och MultiMeshInstance3D: bakad animation i textur, en draw call per fiendetyp, per-instans-animation och blending. Kräver förenklad AI (flow-field) och fysik utan CharacterBody3D per fiende |
| Designrekommendation | "Elit/champion" skinnas, "fodder" körs med VAT | Blandning av de två nivåerna ovan |

Källor för VAT och MultiMesh: [AnimatedMultimeshInstance3D](https://github.com/shadecoredev/AnimatedMultimeshInstance3D), [Godot docs: thousands of fish](https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/animating_thousands_of_fish.html), [slashskill](https://www.slashskill.com/godot-4-characterbody3d-vs-multimesh-scaling-hundreds-of-units-without-killing-performance/).

**Spike 1 (blockerande):** 50 skinnade plus 200 VAT-fiender, 1 riktat ljus och 150k tris på en Mali-G57-enhet. Gräns för godkänt: 30 fps under 10 minuter utan termisk throttling under 25 fps.

---

## 3. Asset-pipeline (Blender headless + bpy)

### 3.1 Flöde

```
assets_src/*.py  (bpy-skript, versionerade)
  → blender -b -P build_asset.py -- --name goblin --lod 0,1,2
  → assets_src/out/goblin.blend (valfri cache)
  → bpy.ops.export_scene.gltf(filepath=..., export_format='GLB')
  → game/assets/models/goblin.glb   (Godot importerar .glb nativt)
```

- **Körning utan GUI.** Headless-körning görs med `-b`/`--background` plus `-P script.py`. Argument efter `--` går till skriptet. ([jakelazaroff TIL](https://til.jakelazaroff.com/blender/export-a-blender-file-to-glb-from-the-command-line/), [Khronos glTF-Tutorials](https://github.khronos.org/glTF-Tutorials/BlenderGltfConverter/))
- **Kontroll av importen i Godot.** Varje `.glb` får en textbaserad `.import`-fil. Sätt importparametrar (LOD, komprimering) där, så att de versioneras. **(U, Godot-konvention)**

### 3.2 Chibi low-poly procedurellt

- **Proportioner.** Chibi har ungefär 2–2,5 huvudlängder. Huvudet är en egen mesh med stor andel av tris-budgeten och kroppen är en enkel cylinder-/box-bas. Proceduren använder Skin-/Subdivision-modifier med låg nivå och applicerar sedan Decimate för LOD1 och LOD2 (–50 % per nivå enligt Googles riktlinje ovan). **(U)**
- **Utseende.** Använd vertexfärg eller en liten gradient-/palettatlas (256² eller 512²) i stället för målade texturer. Det ger konsekvent dark-fantasy-palett, nästan inget texturminne och är trivialt att generera med kod. **(U)**
- **Validering i CI.** Ett bpy-skript räknar tris, material, ben och UV-överlapp och avbryter bygget om budgeten i §2.1 överskrids. **(U)**

### 3.3 Rigging och animation (Mixamo-alternativ vi äger)

Mixamo passar oss inte: det kräver webbgränssnitt och Adobe-konto och kan inte köras headless. **(U)**

| Alternativ | Ägande/licens | Headless | Bedömning |
|---|---|---|---|
| **Eget standardskelett i bpy** (~20–25 ben, chibi-proportioner), skinnat med `parent_set(type='ARMATURE_AUTO')` och programmatiska keyframes | 100 % vårt | Ja | **Rekommenderas.** Chibi-animationer (idle-studs, spring, attack, död) är korta och stiliserade och lämpar sig för procedurella keyframes och kurvor **(U)** |
| **Rigify** (inbyggt i Blender), generera rig från metarig via Python | Blender-tillägg (GPL-verktyg; genererad rig är vår) | Möjligt men krångligt API | För tungt för spel (många kontrollben). Bara deform-benen exporteras ([Rigify API](https://developer.blender.org/docs/features/animation/rigify/), [BlenderArtists](https://blenderartists.org/t/rigify-using-python-to-run-the-generate-rig-operation/1517713)) |
| **Quaternius Universal Animation Library 1/2** (120–130+ klipp, glTF) | CC0, fri även kommersiellt | Ja, filer | Bryter mot kravet "egenproducerat" men är juridiskt fritt. Kan användas som referens eller placeholder och retargetas till vår rig ([quaternius.com](https://quaternius.com/packs/universalanimationlibrary.html), [OpenGameArt](https://opengameart.org/content/universal-animation-library)) |

- **Retargeting.** Godot har `SkeletonProfileHumanoid` och retargeting vid import. Om vi namnger benen enligt den profilen kan animationer delas mellan alla humanoida fiender. **(U, verifiera i spike)**
- **Export.** Använd glTF med `export_animations=True` och ett NLA-spår per klipp. Godot skapar då ett AnimationLibrary med namngivna klipp. **(U)**

---

## 4. Build/CI

### 4.1 Android (Linux, GitHub Actions `ubuntu-latest`)

1. **Förberedelser.** Installera Godot headless och export templates, JDK 17 och Android SDK. Kör `godot --headless --editor --quit` för att värma importcachen. ([thedigitalspell](https://thedigitalspell.com/godot-github-actions-2/), [issue #69511](https://github.com/godotengine/godot/issues/69511))
2. **Bygge.** `godot --headless --install-android-build-template --export-release "Android - Google Play" build/game.aab` ([thedigitalspell](https://thedigitalspell.com/godot-github-actions-2/))
3. **Signering.**
   - Upload-keystore lagras base64-kodad i GitHub Secrets och avkodas i jobbet. ([StraySpark](https://www.strayspark.studio/blog/godot-46-export-web-android-ios-guide))
   - Använd Play App Signing: Google har app-nyckeln och vi har bara upload-nyckeln, som kan återställas om den läcker. **(U, standardpraxis)**
4. **Play-krav att bevaka.**
   - Från 2025-08-31 krävs targetSdk 35. Från **2026-08-31 krävs targetSdk 36** för nya appar och uppdateringar, med förlängning möjlig till 2026-11-01. ([Android Developers](https://developer.android.com/google/play/requirements/target-sdk), [Median](https://median.co/blog/google-plays-target-api-level-requirement-for-android-apps))
   - Stöd för 16 KB-sidor krävs, med deadline förlängd till 2026-05-31. ([Android Dev Blog](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html), [Median](https://median.co/blog/how-to-prepare-android-apps-google-play-16-kb-page-size-requirement))
   - Verifiera att Godot 4.7:s mall sätter API 36.
5. **Upload.** Ladda upp till Play internal track med fastlane `supply` eller Play Developer API. **(U)**
6. **Tester.** GdUnit4 i headless-läge före export, med JUnit-rapport. ([gdUnit4-action](https://github.com/MikeSchulze/gdUnit4-action))

### 4.2 iOS (GitHub Actions macOS-runner)

- **Mac krävs alltid.** Det finns ingen väg till App Store från Linux: Godot genererar ett Xcode-projekt som bara Xcode på macOS kan kompilera, signera och ladda upp. ([StraySpark](https://www.strayspark.studio/blog/godot-46-export-web-android-ios-guide), [godot-docs källfil](https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_ios.rst))
- **Pipeline.**
  1. `godot --headless --export-release "iOS"` på macOS-runnern.
  2. `xcodebuild archive` och `-exportArchive`.
  3. fastlane `match` (certifikat i privat repo) och `pilot` till TestFlight med App Store Connect API-nyckel.

  Det finns färdiga Godot-exempel. ([superhighfives/griss PR #2](https://github.com/superhighfives/griss/pull/2), [godot_app_release](https://github.com/chris-prenissl/godot_app_release), [Bright Inventions](https://brightinventions.pl/blog/ios-testflight-github-actions-fastlane-match/))
- **Runner-version.** Nyare Godot-mallar kräver nyare Xcode, så använd den senaste macOS-imagen. ([searoom issue #47](https://github.com/mark-brannan/searoom/issues/47))
- **Kostnad.**
  - macOS-minuter kostar 0,062 USD/min från 2026-01-01, ungefär 10 gånger Linux. ([GitHub changelog](https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/), [GitSpider](https://gitspider.com/guides/github-actions-macos-runner-cost))
  - Ett iOS-bygge på ~20 min kostar ~1,2 USD. Kör bara vid release-taggar. **(U)**
- **Övriga krav.**
  - Apple Developer Program kostar 99 USD/år. **(U, välkänt pris, verifiera)**
  - En fysisk iPhone behövs för prestandatest, alternativt en molntjänst med enhetsfarm. **(U)**
- **Alternativ.** Codemagic har macOS-byggen och stöd för Unity och Godot. ([Codemagic docs](https://docs.codemagic.io/yaml-quick-start/building-a-unity-app/))

### 4.3 Föreslagen CI-struktur (U)

| Workflow | Trigger | Runner | Steg |
|---|---|---|---|
| `ci.yml` | Varje PR | ubuntu | lint (gdlint), GdUnit4, asset-validering (bpy-budget), headless smoke-run (starta en scen och avsluta efter N frames) |
| `android.yml` | Merge till main | ubuntu | Signerad AAB, sedan Play internal track |
| `ios.yml` | Tagg `v*` | macos-latest | Export, xcodebuild, sedan TestFlight |

---

## 5. Trade-offs och alternativ

| Val | Vinst | Risk | Plan B |
|---|---|---|---|
| Godot | Allt i text, headless, 0 kr, ingen licens i CI | Mobil-3D-prestanda och regressioner, få ARPG-referenser | Unity 6 med GameCI och Personal-licens via Licensing Client |
| GDScript (inte C#) | Stabil export till Android och iOS | Dynamisk typning | Statisk typning obligatorisk. GDExtension (C++) för heta loopar |
| Egen rig och animation i bpy | Full ägandeskap, reproducerbart | Kvaliteten kan bli stel | Quaternius CC0 som referens eller placeholder |
| 30 fps-mål | Ryms för 50 plus 200 fiender **(U)** | Genren upplevs bättre i 60 fps | 60 fps-läge på bättre enheter, dynamisk upplösning |

**Nästa steg (spikes, i ordning):**
1. Prestanda för fiendehorder på Mali-G57 (§2.2).
2. AAB-bygge från CI med targetSdk 36 och 16 KB-stöd.
3. Chibi-karaktär med rig och 4 animationer, helt från bpy, importerad i Godot.
4. iOS-pipeline till TestFlight.
