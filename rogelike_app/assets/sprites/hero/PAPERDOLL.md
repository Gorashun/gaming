# PAPERDOLL.md – Smeden (`SMITH`)

**Ägare:** UI/UX · **Uppdaterad:** 2026-09-21 · Gäller M1.
Implementationsbeslut: `DECISIONS.md` 2026-09-21 ("Paperdoll = Sprite2D-lager +
en AnimationPlayer som driver `frame_index`"). Teknisk bakgrund: research 04 §2.

Syftet med paperdollen är **en** sak: spelaren ska se sin build på figuren.
En relik som inte syns är en siffra i en meny; en relik som syns är en identitet.

---

## 1. Rutnätskontrakt (bryts det ska importen fallera, inte se konstig ut)

| Egenskap | Värde |
|---|---|
| Cellstorlek | **48 × 48 px** (inkl. oversize-marginal för vapen som sticker ut) |
| `hframes` | **8** |
| `vframes` | **4** |
| Arkstorlek | **384 × 192 px** |
| Origo | `centered = true`, samma i alla lager |
| Fotlinje | y = **44** i cellen (golvet), alla lager |
| Riktning | Figuren tittar **åt höger** (marschen går åt höger) |
| Palett | `docs/UI_GUIDE.md` §2 |
| Import | Lossless, Nearest, ingen mipmap (`assets/sprites/README.md` §6) |

Alla lagerark delar rutnät, frame-ordning och origo. Det är hela poängen:
byter spelaren vapen mitt i en animation hoppar det nya lagret in på exakt
samma `frame` och det finns ingen desync att städa upp.

**Föreslaget gdUnit4-test (dev):** ladda varje `smith_*.png`, kontrollera
`width == 384 and height == 192`. Ett lager som inte passar ska fälla testet.

---

## 2. Lagerordning (z-ordning, bakifrån och fram)

| z | Lager | M1-fil | Innehåll |
|---|---|---|---|
| 0 | `cape` | `smith_cape_ember.png` | Kappa, mantel, bläckfiskarmar. Ligger bakom allt. |
| 1 | `legs` | *(reserverad)* | Benrustning, byxor |
| 2 | `body` | `smith_body.png` | **Bas-kropp**: ben, bål, armar, huvud, skägg. Alltid synlig. |
| 3 | `torso` | *(reserverad)* | Bröstharnesk, bandolär, hängande relik |
| 4 | `head` | *(reserverad)* | Frisyr/ansiktsmarkör ovanpå baskroppen |
| 5 | `helm` | `smith_helm_iron.png` | Hjälm, huva, krona |
| 6 | `offhand` | *(reserverad)* | Vänsterhanden: sköld, fuskkub, våg |
| 7 | `weapon` | `smith_weapon_hammer.png`, `smith_weapon_tongs.png` | Högerhanden |
| 8 | `fx` | *(reserverad)* | Effekter. **Enda lagret som får hålla flera sprites samtidigt.** |

I M1 ritas ben, bål och huvud i `body` – `legs`, `torso` och `head` finns som
tomma slots med samma kontrakt så att M2 kan lägga in rustningsdelar utan att
röra vare sig noderna eller animationerna.

```
Paperdoll (Node2D, texture_filter = Nearest, scale = 4, position = heltal * 4)
 ├─ cape    (Sprite2D, hframes 8, vframes 4, z_index 0)
 ├─ legs    (Sprite2D, ... z_index 1)
 ├─ body    (Sprite2D, ... z_index 2)
 ├─ torso   (Sprite2D, ... z_index 3)
 ├─ head    (Sprite2D, ... z_index 4)
 ├─ helm    (Sprite2D, ... z_index 5)
 ├─ offhand (Sprite2D, ... z_index 6)
 ├─ weapon  (Sprite2D, ... z_index 7)
 ├─ fx      (Node2D som kan hålla N Sprite2D, z_index 8)
 └─ AnimationPlayer      // animerar ENBART föräldern Paperdoll.frame_index
```

`frame_index`-settern på föräldern skriver `frame` på varje `Sprite2D`.
`AnimationPlayer` rör aldrig ett enskilt lager. Se kodskiss i research 04 §2.

---

## 3. Vilken relik tänder vilket lager

Reliknamnen är exakt de id:n som ligger i `src/data/content.gd` (`RELICS`).

| `relic_id` | Namn | Rarity | Primärlager | Reservlager | Vad man ser |
|---|---|---|---|---|---|
| `BLOOD_PRICE` | Blodpriset | common | `fx` | – | Röda droppar faller från figurens händer, 2 per sekund |
| `BROKEN_SCALE` | Trasiga vågen | uncommon | `torso` | `offhand` | Kluven våg i kedja över bröstet, gungar med bob-frames |
| `OCTOPUS` | Bläckfisken | uncommon | `cape` | `fx` | Två armar ur ryggen som sträcker sig mot slot 1 och 3 |
| `ECHO_MIRROR` | Ekospegeln | rare | `cape` | `torso` | Spegelskärvor som svävar bakom axlarna |
| `CHEAT_CUBE` | Fuskkuben | rare | `offhand` | `torso` | Laddad tärning i vänsterhanden, visar alltid samma sida |
| `DOMINO` | Dominobrickan | rare | `helm` | `head` | En bricka vid tinningen som tippar när reliken avfyras |

**Kollisionsregel (normativ):** två reliker kan begära samma lager. Då vinner
**högst rarity**; vid lika rarity vinner den som plockades **senast**. Förloraren
flyttar till sitt reservlager. Är även reservlagret upptaget hamnar reliken
**bara** i relikbrickan i krit-UI:t – den försvinner aldrig, men figuren blir
inte en julgran. `fx` är undantaget: det lagret stackar hur många sprites som
helst, så reservkedjan tar aldrig slut.

`ANVIL_BLESSING` (Smedens startrelik) har inget eget lager – den syns i stället
på `ANVIL`-sloten i krit-UI:t, eftersom effekten sitter på sloten och inte på
figuren.

**Utrustning (vapen, hjälm) har företräde framför reliker på samma lager.**
Ett vapenbyte ska aldrig kunna döljas av en relik.

---

## 4. Frame-mappning för AnimationPlayer

`frame_index = row * 8 + col`. Kolumner utöver de authorade upprepar sista
authorade framen, så en felaktig `frame_index` ger en fryst pose, aldrig en
tom ruta.

| Rad | Animation | Authorade frames | `frame_index` | Längd | Loop | Anmärkning |
|---|---|---|---|---|---|---|
| 0 | `idle` | 4 (col 0–3) | 0–3 | 0,64 s (0,16 s/frame) | ja | Andning, 1 px bob |
| 1 | `walk` | 8 (col 0–7) | 8–15 | 0,64 s (0,08 s/frame) | ja | Kontakt–ned–pass–upp ×2 |
| 2 | `attack` | 6 (col 0–5) | 16–21 | 0,36 s (0,06 s/frame) | nej | **Kontakt på frame 3** (`frame_index 19`), t = 0,18 s |
| 3 | `hit` | 4 (col 0–3) | 24–27 | 0,32 s (0,08 s/frame) | nej | Stagger bakåt, används även av `die_cracked` |

### Spår i AnimationPlayer

Varje animation har **exakt två** spår:

1. `Value`-spår på `Paperdoll:frame_index`, `update mode = Discrete`
   (aldrig `Continuous` – interpolation mellan heltalsframes är meningslös).
2. `Call Method`-spår på föräldern, för de ögonblick UI-lagret behöver:

| Animation | Tid | Metod | Kopplas till |
|---|---|---|---|
| `attack` | 0,18 s | `on_attack_contact()` | `damage_dealt`-eventet (UI_GUIDE §5.3) |
| `attack` | 0,30 s | `on_attack_recover()` | frisläpp av nästa kedjesteg |
| `walk` | 0,08 s, 0,40 s | `on_footfall()` | fotsteg-ljud + 1 px dammpuff i `fx` |
| `hit` | 0,00 s | `on_stagger()` | skärmskak, haptik `medium` |

Marschen (sidescroll) spelar `walk` medan `ParallaxBackground.scroll_offset`
rör sig; vid en förgrening spelas `idle` och krit-UI:t ritar ut vägvalen.
Hjälten byter **aldrig** riktning i M1 – finns inget vänstergående ark.

### Tidsbudget mot kedjan

Kedjesteget i UI_GUIDE §5.1 är 220 ms och `damage_dealt` startar 150 ms in.
`attack` är 360 ms med kontakt vid 180 ms, dvs. attacken får börja **30 ms
före** kedjesteget och landar då ihop med träffen. Dev kan justera med
`AnimationPlayer.speed_scale = 1.0 / chain_speed` så att Blixt-tempo (0,35×)
komprimerar figuren lika mycket som siffrorna.

---

## 5. Vad som finns och vad som saknas

| Fil | Status |
|---|---|
| `smith_body.png` | **klar** – bas-kropp, läderförkläde, skägg, sotfläck |
| `smith_weapon_hammer.png` | **klar** – vapenvariant A (smideshammare) |
| `smith_weapon_tongs.png` | **klar** – vapenvariant B (tång med glödande ämne) |
| `smith_helm_iron.png` | **klar** – nitad järnhjälm med näsjärn |
| `smith_cape_ember.png` | **klar** – glödkappa som släpar bakåt |
| `smith_legs_*.png` | saknas (M2) |
| `smith_torso_*.png` | saknas (M2) |
| `smith_offhand_*.png` | saknas (M2, behövs för `CHEAT_CUBE` och `BROKEN_SCALE`) |
| `smith_fx_*.png` | saknas (M2, behövs för `BLOOD_PRICE`) |

Reliklagren är alltså **specificerade men inte ritade** i M1. Till dess visas
reliker enbart i relikbrickan (`items/relic_*.png`, 16×16). Det är ett medvetet
M1-snitt: kontraktet och kollisionsregeln är det som är dyrt att ändra senare,
sprites är billiga att lägga till.
