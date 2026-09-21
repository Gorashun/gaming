# 02 – Tech stack för solo-dev med webbakgrund: Android först, iOS utan omskrivning

**Ägare:** rnd-roguelike · **Datum:** 2026-09-21 · **Status:** underlag till PM; byte av tech stack kräver Anders (team/README.md)

Källor `[n]` med URL i slutet. Fakta = källbelagt. **Uppskattning** = egen bedömning.

---

## Fråga
Vilken stack ger en solo-utvecklare med HTML/JS-bakgrund, som bygger med AI-agenter, snabbast väg till ett 2D-roguelike med *deterministisk, headless-testbar spellogik*, bra "juice", Android först och iOS utan omskrivning?

## Slutsats (först)
**Rekommendation: 1) Godot 4.x med GDScript, 2) Flutter + Flame, 3) Capacitor + PixiJS.** Unity och React Native/Expo avråds för detta projekt.

Motivering i en mening per rad:
- **Godot 4 (GDScript)** har i 2025–2026 blivit en trovärdig mobilmotor (krascher i skarpa spel ned från ~4 % till < 1 %, officiella Play Billing/Play Games/StoreKit 2-plugins, Android-spegling i editorn [1][2]), är MIT-licensierad utan intäktstak, har inbyggda verktyg för juice (Tween, AnimationPlayer, GPUParticles2D, shaders, pitch-shift i audio), headless-testramverk (gdUnit4/GUT) [3], och frontier-LLM:er skriver bra GDScript [4]. Brotato – ett av våra referensspel – är byggt i Godot [5]. Nackdelar: nytt språk (Python-likt), APK ≈ 40 MB, iOS-export kräver Xcode ⇒ moln-Mac.
- **Flutter + Flame** är närmast Anders "app-hjärna": Dart liknar TypeScript, hot reload är bäst i klassen, ren Dart-logik testas med `dart test` utan motor, minsta binär (~7 MB tom app), Codemagic ger 500 gratis Mac-minuter/mån [6][7][8]. Nackdel: game-tooling är en bråkdel av Godots, få shippade roguelikes, mer juice-kod att skriva själv.
- **Capacitor + PixiJS/Phaser** = noll inlärningskurva, men WebView på mid-range Android throttlar termiskt (Phaser 3: 60 → 46 FPS efter 8 min på Galaxy A54; PixiJS 8 håller 58–60) [9], audio-latens och haptik går via plugins, och det "känns" mindre nativt. Bra för en snabb prototyp av kärnloopen, inte för slutprodukten.
- **Unity**: gratis under 200 k USD [10] men C#, tung editor, 30–50 MB minimal APK [11] och överdimensionerad för ett 2D-hobbyprojekt.
- **React Native/Expo (Skia + Reanimated)**: fungerar för turbaserat 2D, men "det finns ingen RN-spelmotor 2026, bara fyra partiella alternativ" [12]; du bygger motorn själv.

**iOS-krav oavsett stack:** Apple Developer Program 99 USD/år (krävs för TestFlight/App Store) [13]; signering/arkivering kräver Xcode på macOS – utan egen Mac används Codemagic (500 gratis M2-minuter/mån för individ, därefter ~0,095 USD/min) [8] eller GitHub Actions (macOS 0,062 USD/min; privata repos: 2 000 gratis minuter men 10× multiplikator ⇒ ~200 Mac-minuter; publika repos obegränsat gratis) [14].

---

## Evidens – jämförelse per kriterium

| Kriterium | Godot 4 (GDScript) | Flutter + Flame | Capacitor + PixiJS/Phaser | Unity 6 | RN/Expo + Skia |
|---|---|---|---|---|---|
| **Inlärning från JS/HTML** | Medel. GDScript är Python-likt, men scen/nod-modellen är ny. | Låg–medel. Dart ≈ TypeScript; widgets ≈ React-komponenter. | Ingen. Det *är* JS. | Hög. C#, stor editor, prefab/ECS-begrepp. | Låg för RN, men spelloop/rendering måste byggas. |
| **2D-prestanda mid-range Android** | Bra. Mobile-renderer optimerad 4.5–4.7; kraschfrekvens < 1 % i shippade spel [1][2]. | Bra för casual 2D, 60 FPS "comfortably" [6]. Impeller-renderer. | Risk. WebView-throttling: Phaser 3 60→46 FPS efter 8 min, PixiJS 8 58–60 FPS, 2× lägre batteridrag för Pixi [9]. | Bra. | OK för turbaserat; olämpligt för twitch [12]. |
| **Binärstorlek (minimal)** | ~40 MB för 4 arkitekturer med custom template; default större [15]. | ~7 MB tom APK [7] (äldre mätning; uppskattning 15–25 MB med Flame + assets). | Liten (Pixi 450 kB vs Phaser 1,2 MB + WebView) [16]. | 30–50 MB [11]. | ~20–30 MB (uppskattning). |
| **iOS utan Mac** | Export kräver Xcode ⇒ Codemagic (Xcode förinstallerat på M2 Mac mini, Godot-pipeline dokumenterad) [17] eller GitHub Actions (`build-ios` ger osignerad IPA) [18]. | Codemagic är byggt för Flutter; 500 gratis min/mån [8]. | Codemagic/GH Actions, Xcode krävs. | Unity Cloud Build eller GH Actions. | **Bäst:** EAS Build i molnet, 15 iOS + 15 Android builds/mån gratis, 45 min timeout [19]. |
| **Hot reload** | Delvis: "Synchronize Script Changes" i inbyggd editor; buggigt med externt editor (VS Code) [20]. Android-spegling i editorn från 4.6 [2]. | **Bäst i klassen** (stateful hot reload). | Vite-liknande reload i browser; på enhet via live-reload. | Domain reload långsamt; Hot Reload-paket i Unity 6 (uppskattning: sämre än Flutter). | Fast Refresh. |
| **Headless-testbar spellogik** | gdUnit4/GUT via `godot --headless`, JUnit-XML för CI [3]. Kräver Godot-binär i CI (~1–2 min extra). | **Bäst:** ren Dart-logik utan Flame-beroende testas med `dart test`; `flame_test` för komponenter [21]. | Vitest/Jest på ren TS – trivialt. | NUnit via Unity Test Runner (kräver Unity i CI). | Jest på ren TS. |
| **Ljud/haptik** | AudioStreamPlayer med pitch_scale (Balatro-effekten), `Input.vibrate_handheld`; finkornig haptik via plugin (godot-haptics: light/medium/heavy) [22]. | `HapticFeedback` i Flutter SDK (light/medium/heavy/selection), `audioplayers`/`flame_audio`; pitch via `soloud`-paket (uppskattning: mer plumbing än Godot). | Web Audio API OK; haptik via Capacitor Haptics-plugin; latens i WebView (uppskattning). | Fullt stöd. | expo-haptics, expo-av. |
| **Community / AI-kodbarhet** | Stort community; ~850 klasser i konsekvent API ger låg hallucinationsgrad; Claude Opus bäst på GDScript 2026, risk att lokala/äldre modeller skriver Godot 3-syntax [4]. | Flutter Q2 2026-enkät: 32 % använder Claude Code; officiell Dart/Flutter MCP-server och Agent Skills [23]. Flame-specifik kod mindre representerad i träningsdata (uppskattning). | Enorm JS-corpus; PixiJS v8-API ändrades 2024 ⇒ viss förvirring (uppskattning). | Störst corpus, men mycket föråldrad kod i träningsdata (uppskattning). | Stor RN-corpus; Skia-spelmönster sällsynta. |
| **Licens** | MIT, 0 kr, inga tak. | BSD, 0 kr. | MIT, 0 kr. | Personal gratis < 200 k USD omsättning; Runtime Fee avskaffad sept 2024; Pro 2 200 USD/år +5 % jan 2026 [10]. | MIT; EAS enligt ovan. |
| **Publiceringsflöde** | Codemagic Godot-pipeline [17]; GH Actions med `godot-export`. Play: AAB, target API 36 (krav sedan 2026-08-31), 16 KB page size (Godot 4.3+ OK) [24]. | Codemagic first-class; `flutter build appbundle`. | Capacitor CLI → Android Studio/Xcode-projekt. | Unity Cloud Build. | EAS Submit. |
| **Shippade referenser** | Brotato [5], Rift Riff (okt 2025), Kamaeru (dec 2025) – alla premium/pay-once [1]. | I/O Pinball (Google), enstaka casual-spel på Play [6]. | Många hyper-casual; få premium-roguelikes (uppskattning). | Otaliga. | Nästan inga spel [12]. |

### Plattformskrav som gäller alla stackar (fakta)
- **Google Play:** 25 USD engångsavgift; personliga konton skapade efter 2023-11-13 måste köra closed test med 12 testare i 14 dagar före produktion [25]. Target API 36 sedan 2026-08-31; appar med nativ kod måste stödja 16 KB page size (hård spärr för uppdateringar 2027-02-01) [24]. Data safety + privacy policy krävs även utan datainsamling (se 01_engagement_mekanik.md).
- **Apple:** Developer Program 99 USD/år, TestFlight upp till 10 000 externa testare ingår; Xcode kör bara på macOS [13]. Nya åldersnivåer 13+/16+/18+ (se 01).

### Varför Godot före Flutter (egen avvägning)
Kärnkravet är *juice* (partiklar, skärmskak, tweens, ljud som stiger i tonhöjd, sekventiella animationer) plus deterministisk logik. I Godot är juice-verktygen inbyggda och visuellt redigerbara; i Flame skriver man dem i kod. Godots scen-editor låter UI-agenten (`ui-roguelike`) jobba visuellt medan dev-agenten håller `src/core/` ren från noder. Flutter vinner på testbarhet och hot reload, men båda är "tillräckligt bra" i Godot (gdUnit4 headless, Android-spegling). Godot har dessutom ett shippat referensspel i exakt vår genre (Brotato). **Om Anders efter vecka 1 upplever GDScript/editor som friktion är Flutter + Flame en fullgod plan B utan att designdokumenten behöver ändras.**

### Risker med Godot och hur de hanteras
| Risk | Åtgärd |
|---|---|
| LLM skriver Godot 3-syntax [4] | Pinna version i `CLAUDE.md` ("Godot 4.6, GDScript 2.0, typed"), lägg in gdUnit4-tester som fångar fel tidigt, använd Godot-docs-MCP eller lokal docs-kopia. |
| APK-storlek ~40 MB | Acceptabelt (Balatro mobil ≈ 100+ MB); custom export template kan strippa till ~30 MB [15]. |
| iOS-signering utan Mac | Codemagic gratis-tier räcker för veckovisa TestFlight-builds (uppskattning ~15 min/build ⇒ ~30 builds/mån). |
| C# lockar (bekant för vissa LLM:er) | Nej: C#-export till iOS/Android är experimentell [26]. GDScript enbart. |
| Hot reload sämre än Flutter | Kompensera med headless-tester för logik och Android-spegling för UI [2]. |

## Osäkerhet
- Binärstorlekar bygger på community-mätningar av olika ålder, inte egna builds.
- WebView-benchmarken [9] är en enskild test på en enhet (Galaxy A54).
- LLM-kvalitet för Flame vs GDScript är inte mätt jämförbart; båda källorna är leverantörs-/bloggkällor.

---

## Skiss: mappstruktur (Godot 4.6, GDScript)
```
rogelike_app/
├── project.godot
├── export_presets.cfg              # Android (AAB, arm64+armv7), iOS
├── CLAUDE.md                       # projektregler (finns)
├── docs/                           # PROPOSAL, DECISIONS, GAME_DESIGN, research/
├── src/
│   ├── core/                       # REN spellogik: inga Node-beroenden, deterministisk
│   │   ├── rng.gd                  # seedad RandomNumberGenerator-wrapper
│   │   ├── run_state.gd            # hela runnen som data (serialiserbar → autosave)
│   │   ├── combat.gd               # resolver, returnerar händelselogg (för juice-uppspelning)
│   │   ├── rewards.gd              # 3-vals-generator, rarity-vikter, pity-fri
│   │   ├── synergies.gd            # multiplikatorkedjor, ordnad aktivering
│   │   └── meta.gd                 # unlock-poäng, unlock-pool
│   ├── data/                       # innehåll som .tres/.json: items, fiender, synergier, unlocks
│   ├── game/                       # Node-världen: spelar upp händelseloggen
│   │   ├── run/                    # run.tscn, wave.tscn
│   │   ├── juice/                  # screen_shake.gd, number_pop.tscn, hit_stop.gd, sfx_pitch.gd
│   │   └── ui/                     # reward_pick.tscn, hud.tscn, meta_screen.tscn
│   └── platform/                   # haptics.gd, save_io.gd, (senare) play_games.gd
├── assets/                         # sprites/, sfx/, fonts/ (CC0/egna)
├── tests/                          # gdUnit4: test_rng.gd, test_rewards.gd, test_synergies.gd, sim/
│   └── sim/run_simulator.gd        # kör 10 000 seedade runs headless → balansstatistik (StS-metoden)
├── addons/gdUnit4/
├── tools/                          # export.sh, balance_report.py
└── .github/workflows/
    ├── test.yml                    # godot --headless, gdUnit4 → JUnit
    └── android-debug.yml           # bygger APK på push till main
```
Princip: `src/core/` får aldrig importera något från `src/game/`. Allt som ska "kännas" (juice) drivs av en händelselogg som core returnerar – det gör Balatro-stilens sekventiella uppspelning trivial och 100 % testbar.

## "Första veckan"-plan (Godot)
| Dag | Mål | Klart när |
|---|---|---|
| 1 | Installera Godot 4.6 (stable), skapa projekt, portrait 1080×1920, lägg in gdUnit4, GitHub-repo + `test.yml` | CI kör ett grönt dummy-test headless |
| 2 | `src/core/rng.gd` + `run_state.gd` + `rewards.gd` med tester: samma seed ⇒ identisk sekvens av 3-val | 10+ tester gröna, `run_simulator` kör 1 000 runs på < 5 s |
| 3 | Vertikal slice utan grafik: 1 arena, 1 fiendetyp, 8 vågor, belöningsval efter varje våg, död ⇒ meta-poäng | Kan spelas i editorn med rektanglar |
| 4 | Juice-pass: hit-stop, screen shake, number pop, sfx med `pitch_scale` som stiger per synergisteg, `vibrate_handheld` | Rollspelsnörd-agenten ger "kick"-betyg ≥ 3/5 |
| 5 | Android-export: keystore, AAB, target API 36, sidoladda på Anders telefon; mät FPS och run-längd | Spelbart på telefon, 60 FPS, autosave per våg |
| 6 | Codemagic-konto, `codemagic.yaml` för Android + (osignerad) iOS-build; skapa Google Play-konto (25 USD), starta 12-testare-listan | En grön Codemagic-build av båda plattformarna |
| 7 | Retro: run-längd, antal val/min, upplevd "en run till"; besluta Godot vs plan B; PM uppdaterar DECISIONS.md | Beslut loggat |

Kostnad vecka 1: 25 USD (Play). Apple 99 USD kan vänta tills iOS-test behövs (månad 2–3, uppskattning).

## Rekommendation till PM
1. **Välj Godot 4.6 + GDScript (typed) som primär stack**, med explicit plan B = Flutter + Flame om vecka-1-retro visar friktion. Beslut hos Anders.
2. **Kräv arkitekturregeln "core returnerar händelselogg, game spelar upp"** i ARCHITECTURE.md innan första raden spellogik – det är vad som gör juice och tester kompatibla.
3. **Sätt upp headless-CI dag 1** (gdUnit4 + run-simulator) så att balansen kan mätas som Mega Crit gjorde, inte gissas.
4. **Använd Codemagic gratis-tier för iOS**, köp Apple-medlemskap först när en Android-build är spelbar i 2 veckor.
5. **Starta Play-kontot och 12-testare-processen redan vecka 1** – 14-dagarskravet är den längsta ledtiden i hela flödet.

---

## Källor (alla hämtade 2026-09-21)
1. Godot Engine, "Godot Mobile update — April 2026" (kraschfrekvens ~4 % → < 1 %, Rift Riff, Kamaeru, plugins) – https://godotengine.org/article/godot-mobile-update-apr-2026/ ; sammanfattning: https://ziva.sh/blogs/godot-mobile
2. StraySpark, "How to Export Godot 4.6 Games to Web, Android, and iOS: 2026 Guide" (4.6 jan 2026, Android-spegling, Play Billing/Games, StoreKit 2) – https://www.strayspark.studio/blog/godot-46-export-web-android-ios-guide ; Godot 4.7: https://godotlearning.com/blog/godot-4-7-whats-new
3. gdUnit4 (headless CLI, JUnit) – https://github.com/godot-gdunit-labs/gdUnit4 ; GUT i CI – https://medium.com/@kpicaza/ci-tested-gut-for-godot-4-fast-green-and-reliable-c56f16cde73d
4. Summer Engine, "The Best LLM for GDScript in 2026" – https://www.summerengine.com/blog/best-llm-for-godot ; Oreate, AI-agenter och Godots ~850 klasser – https://learn.oreateai.com/learn/how-ai-agents-are-transforming-the-godot-engine-game-development-workflow
5. Wikipedia, "Brotato" (utvecklad i Godot) – https://en.wikipedia.org/wiki/Brotato
6. Synfinity Dynamics, "Flutter Game Development in 2026", 2026-07 – https://medium.com/@synfinitydynamics/flutter-game-development-in-2026-can-you-build-real-games-with-flutter-2b09f11c3a0a ; Flame – https://flame-engine.org/
7. flutter/flutter issue #12456 (tom APK ≈ 6,8 MB) – https://github.com/flutter/flutter/issues/12456
8. Codemagic, "Pricing" (500 gratis macOS M2-minuter/mån för individ, 0,095 USD/min) – https://docs.codemagic.io/billing/pricing/ ; https://codemagic.io/pricing/
9. HackMD, "Mobile Web Game Runtimes: CPU, Thermals, and FPS Test" (Galaxy A54, Phaser 3 vs PixiJS 8 i WebView) – https://hackmd.io/@dashichen1/Hkdt29DFMe
10. Unity, "Unity is Canceling the Runtime Fee" (2024-09) och "Pricing updates" (Personal < 200 k USD; Pro 2 200 USD/år; +5 % 2026-01-12) – https://unity.com/blog/unity-is-canceling-the-runtime-fee ; https://unity.com/products/pricing-updates
11. Oceanview Games, "Unity vs Godot vs Unreal for Mobile Games" (minimal APK 30–50 MB) – https://oceanviewgames.co.uk/blog/posts/unity-vs-godot-vs-unreal-mobile-games
12. DEV Community, "The React Native game engine gap in 2026" – https://dev.to/grzott/the-react-native-game-engine-gap-in-2026-rnge-skia-phaser-in-webview-expo-gl-55hp ; Expo-blogg, Matter.js + Skia – https://expo.dev/blog/build-2d-game-style-physics-with-matter-js-and-react-native-skia
13. Apple, "Apple Developer Program – What's included" (99 USD/år, TestFlight 10 000 testare) – https://developer.apple.com/programs/whats-included/
14. GitHub Changelog, "Update to GitHub Actions pricing", 2025-12-16 (macOS 0,062 USD/min från 2026-01-01; 10× multiplikator; publika repos gratis) – https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/ ; https://cicdcalculator.com/github-actions
15. GameSiProjects, "Optimize Godot lib size for simple Android game" (~40 MB för 4 arkitekturer) – https://github.com/GameSiProjects/OptimizeGodotLibSizeGuide ; godot issue #78780 – https://github.com/godotengine/godot/issues/78780
16. Generalist Programmer, "Phaser vs PixiJS (2026)" – https://generalistprogrammer.com/comparisons/phaser-vs-pixijs ; Capacitor, "Games" – https://capacitorjs.com/docs/guides/games
17. Codemagic, "Setting up CI/CD for a Godot game" och Codemagic Godot Pipeline (iOS-workflow, Xcode på M2 Mac mini) – https://blog.codemagic.io/godot-games-cicd/ ; https://sabinayo.github.io/codemagic-godot-pipeline/workflows/ios-workflow.html
18. mak448a, "build-ios: Build a Godot Project to a .ipa without a Mac" – https://github.com/mak448a/build-ios ; Godot docs, "Exporting for iOS" – https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
19. Expo, "Plans, billing, and payment FAQs" (Free: 15 Android + 15 iOS builds/mån, 45 min timeout) – https://docs.expo.dev/billing/faq/ ; https://docs.expo.dev/billing/plans/
20. godot issue #72825, "Hot-reloading of scripts doesn't work when using external editor" – https://github.com/godotengine/godot/issues/72825
21. Flame docs, "Writing tests" och paketet `flame_test` – https://docs.flame-engine.org/latest/development/testing_guide.html ; https://pub.dev/packages/flame_test
22. Godot docs, `Input.vibrate_handheld` (VIBRATE-permission) – https://trinovantes.github.io/godot-docs/tutorials/inputs/controllers_gamepads_joysticks.html ; kyoz/godot-haptics – https://github.com/kyoz/godot-haptics
23. Ryz Labs, "The Best 5 AI Coding Assistants for Flutter in 2026" (Flutter Q2 2026-enkät, Dart/Flutter MCP) – https://learn.ryzlabs.com/ai-coding-assistants/the-best-5-ai-coding-assistants-for-flutter-in-2026
24. Android Developers, "Meet Google Play's target API level requirement" (API 36 från 2026-08-31) och "Support 16 KB page sizes" – https://developer.android.com/google/play/requirements/target-sdk ; https://developer.android.com/guide/practices/page-sizes
25. Google Play Console Help, "App testing requirements for new personal developer accounts" (12 testare, 14 dagar) – https://support.google.com/googleplay/android-developer/answer/14151465
26. Godot docs, C#/.NET-plattformsstöd (Android/iOS experimentellt) – https://github.com/godotengine/godot-docs/blob/master/tutorials/scripting/c_sharp/index.rst ; StraySpark, "GDScript vs C# in Godot 2026" – https://www.strayspark.studio/blog/gdscript-vs-csharp-godot-2026-choosing-scripting-language
