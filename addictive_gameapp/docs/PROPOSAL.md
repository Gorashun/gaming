# Förslag: KLUNK – fysik-merge i en burk

Status: **FÖRSLAG, väntar på Anders beslut** · Projektledare · 2026-09-20
Underlag: `research/game-design-research.md`, `research/tech-stack-research.md`

## 1. Vad vi bygger (en mening)
Du tappar runda objekt i en glasburk. Två likadana som nuddar smälter ihop till nästa storlek med en fet pop. Burken fylls, fysiken rör om, och målet är att nå det största objektet innan det svämmar över.

## 2. Varför just detta
- **Fysiken är slumpgeneratorn.** Variabel belöning uppstår av sig själv och känns rättvis. Vi behöver inte bygga någon "dragning" (avgörande för barn, se research §2.1 och §6).
- **Noll text.** "Lika + lika = större" förstås av en 7-åring på två sekunder. Vuxna ser ett spatialt optimeringsproblem med hög skill-ceiling (Suika bevisade bredden).
- **Kicktrappan finns gratis:** små kickar var 2–5 s (merge), medel var 20–60 s (kedjemerge), stora var 2–5 min (kaskad/specialobjekt). Alla siffror är uppskattningar från researchen.
- **Lägst teknisk risk** för en webbutvecklare: 2D-fysik, en scen, inga assets utöver ~11 cirklar, inget nätverk.

## 3. "TikTok-känslan": Regissören
Det som skiljer oss från en vanlig Suika-klon. En liten, seedbar modul (`systems/director.ts`) som styr kön med **variabel kvot** i stället för ren slump:

| Läge | Vad spelaren upplever | Hur |
|---|---|---|
| Torka | "Lite tråkigt", kön ger bara små objekt, inget passar | 15–40 drops (slumpat) med låg matchsannolikhet |
| Flöde | Det passar hela tiden, kedjor, pitch stiger | Kön väljer med viss bias mot objekt som kan mergea nu |
| Kick | Sällsynt specialobjekt: **bomb** (rensar en zon), **regnbåge** (mergear med vad som helst), **magnet** (drar ihop likadana) | Dyker upp efter 25–60 drops, slumpat. Aldrig köpbart |
| Rekordjakt | Slow-mo och puls när du är 1 merge från rekord eller från förlust | Äkta near-miss, aldrig fejkad |

Regissören ändrar aldrig fysiken, bara **vilket objekt som kommer härnäst**. Spelaren ska aldrig kunna bevisa att den finns, men känna att "det vänder plötsligt".

## 4. Belöningsdesign (juice är produkten)
Bygg `systems/juice.ts` med **en** funktion, `Juice.trigger(event, intensity 0–1)`, som skalar allt proportionellt:
1. Ljud med pitch-stegring per combosteg (billigaste kicken, research §3)
2. Hit-stop 2–6 frames vid merge
3. Scale-punch med back-ease
4. Partiklar som ärver hastighet
5. Dämpad, riktad screen shake (klingar av inom 0,3 s)
6. Scorepop som flyger mot HUD
7. Haptik via Capacitor (10–30 ms, längre vid stor kick)
8. Kamerazoom endast vid kaskad
9. Slow-mo när burken är nästan full

Etiska/tillgänglighetsregler: max 3 blink/s (WCAG 2.3.1), ingen mättad röd stroboskop, ikon för "Lugnt läge" som halverar all juice, haptik avstängbar.

## 5. Meta-lager (gör "imorgon igen" av "en gång till")
V1 håller det minimalt men existerande, eftersom hypercasual utan meta har ~2 % D30 (research §2.6):
- Lokal highscore + "bästa objekt" visas som en hylla på startskärmen.
- Slumpad kosmetisk upplåsning (nytt objektset/tema) efter vissa milstolpar, à la Crossy Road. Inga pengar, ingen timer.
- **Inte** i v1: push-notiser, dagliga belöningar, konton, annonser, köp.

## 6. Teknik (beslut)
- **Phaser 4 + TypeScript + Vite**, Matter.js-fysik (inbyggt i Phaser). Fallback Phaser 3 om Phaser 4 strular.
- **Capacitor 8** för Android och iOS från samma kodbas. `@capacitor/haptics`, `@capacitor/preferences` för sparning.
- Spelet körs alltid i webbläsare först (`npm run dev`). Agenterna testar headless med Playwright i containern.
- **Android via GitHub Actions** på Linux: bygg, `cap sync`, `gradlew assembleRelease` + `bundleRelease`, keystore som secret. APK för sideload till din telefon direkt.
- **iOS i fas 4** på `macos-26`-runner. Kräver Apple Developer (99 USD/år). Flöde utan Mac är **inte verifierat**, se tech-research §6.
- Manifest **utan INTERNET-permission**. Inga SDK:er, ingen tracking. Det gör Data safety och Families-policy triviala.

## 7. Barn och butik
- Design: ett finger, en gest, noll obligatorisk text, touchmål ≥64 dp, hög kontrast.
- Play: målgrupp inkluderar barn → Families-policy gäller. Utan annonser/nätverk är det i praktiken bara formulär (Data safety, IARC, integritetspolicy-sida).
- Juridik: researchens bedömning är att COPPA/GDPR-K inte aktualiseras utan personuppgifter. Det är inte juridisk rådgivning. Granska inför butiksrelease.

## 8. Plan och uppskattningar
| Fas | Innehåll | Uppskattning | Klart när |
|---|---|---|---|
| 0 | Repo, Vite+Phaser+TS, Playwright, benchmark-scen (2 000 partiklar) | 1 dag | Körs i webbläsare, 60 fps-mätning finns |
| 1 | Kärnloop: burk, 11 nivåer, merge, förlust, instant restart | 2–3 dagar | Spelbart, tråkigt men fungerande |
| 2 | Juice-systemet (alla 9 effekter) + ljudsprite + haptik | 2–3 dagar | Varje merge känns |
| 3 | Regissören + specialobjekt + near-miss + highscore/hylla + Lugnt läge | 2–3 dagar | "Det vänder plötsligt" |
| 4 | Capacitor Android, Actions-workflow, signerad APK på Anders telefon | 1–2 dagar | APK installerad och testad |
| 5 | Speltest med barn + vuxna, balansera regissören i data | löpande | D1-återkomst observerad |
| 6 | iOS-build via macOS-runner, TestFlight | 2–4 dagar + väntan | Körs på iPhone |

Totalt till Android-APK i handen: **8–12 arbetsdagar (uppskattning)**. Agentteamet parallelliserar fas 1–3 delvis.

## 9. Alternativ som valdes bort
- **STUDS** (Ballz-lik): bra variabel belöning men sifferbaserad feedback och passiva väntetider passar 7-åringar sämre. 10–15 dagar.
- **MYRARMÉN** (bullet-heaven): störst kickdensitet sent men 15–25 dagar, veckor av balansering, och skärmkaos som krockar med epilepsikrav.

## 10. Beslut som behövs från Anders
1. **Go/no-go på KLUNK** (eller välj STUDS/MYRARMÉN).
2. **Har du Mac?** Styr hur vi planerar iOS-fasen.
3. **Google Play-konto:** finns det, och skapades det före eller efter 2023-11-13? Efter = krav på 12 testare i 14 dagar före publik release (verifiera själv, källan var blockerad i containern).
4. **Apple Developer-konto** (99 USD/år): finns eller skaffas senare?
5. **Arbetstitel** KLUNK ok? (Byts lätt, inga assets beror på den.)
