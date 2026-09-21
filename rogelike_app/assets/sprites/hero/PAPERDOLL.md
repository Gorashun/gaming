# PAPERDOLL.md – Smeden (`SMITH`)

**Ägare:** UI/UX · **Uppdaterad:** 2026-09-21 · Gäller M2.5.
Implementationsbeslut: `DECISIONS.md` 2026-09-21 ("Paperdoll = Sprite2D-lager +
en AnimationPlayer som driver `frame_index`"). Teknisk bakgrund: research 04 §2.

Syftet med paperdollen är **en** sak: spelaren ska se sin build på figuren.
En relik som inte syns är en siffra i en meny; en relik som syns är en identitet.

**Nytt i M2.5:** figuren finns i **två kroppsvarianter** (DECISIONS 2026-09-21,
"Könsval för spelarfiguren") plus ett valfritt `hair`-lager, och paperdollen
visas dessutom stor på **character sheetet** (§6). Kontraktet som gör allt det
billigt är detsamma som förut: *alla lager delar rutnät, origo och rigg.*

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

### 1.1 Kroppsvarianter (normativt kontrakt)

| Fil | Variant | Etikett i UI (i18n) | Läsning |
|---|---|---|---|
| `smith_body_a.png` | A | `SMITH_VARIANT_A` = `Broad` / `Bredvuxen` | Bred kil: fullt läderförkläde, skägg, tung axellinje |
| `smith_body_b.png` | B | `SMITH_VARIANT_B` = `Lean` / `Smalvuxen` | Smal pelare: midja, **delad kjortel** med glipa, bar käke, lindade underarmar, halsduk |

`smith_body.png` (M1–M2) är **borttagen**; A är samma konst under nytt namn.
Dev byter en rad i `Art.HERO_LAYERS` (`hero/smith_body_a.png`) – vilket redan
är gjort via `Art.smith_layer(&"body", variant)`.

**Kontraktet, i en mening: utrustnings- och reliklager är kroppsoberoende.**
Ingen av de 15 gear-/relikfilerna vet vilken kropp som ligger under. Det är
garanterat av att variant B behåller **exakt** de ankare som gear-lagren läser
ur `pose()` i `tools/gen_pixel_assets.py`:

| Ankare | Värde (båda varianterna) | Läses av |
|---|---|---|
| Fotlinje | y = 44 | `legs`, `fx` (stänk) |
| Höft / benkolumner | `hip = 32 + bob`, samma två benmål, 3 px breda | `smith_legs_iron.png` |
| Bålcentrum | `(24 + lean, 26 + bob)`, minst 11 px brett bröst | alla `torso`-lager |
| Huvudcentrum | `(25 + lean, 16 + bob)` | `helm`, `head`, `hair` |
| Högerhand | `pose()["hand"]` | `weapon` |
| Vänsterhand | `(18 + lean, 33 + bob)` | `offhand` |
| Kappfäste | axel vid `(19 + lean, 20 + bob)` | `cape` |

Varianterna är **jämbördiga**: A bär sin massa i bredd, B i höjd och räckvidd.
Ingen av dem är "den lilla". Spelet omtalar figuren könsneutralt ("The Smith")
och etiketterna i valskärmen är kroppsformer, inte könsord.

Håret är ett **valfritt** lager: `smith_hair_a.png` (knut i nacken, rustfärgad
snodd) och `smith_hair_b.png` (lång fläta som svänger med gången). Vilken
frisyr som helst går på vilken kropp som helst – de läser bara huvudankaret.

**Föreslaget gdUnit4-test (dev), utökat:** ladda alla `smith_*.png` utom
`smith_portrait_*.png` och kontrollera `384×192`; ladda porträtten och
kontrollera `96×96`.

**Föreslaget gdUnit4-test (dev):** ladda varje `smith_*.png`, kontrollera
`width == 384 and height == 192`. Ett lager som inte passar ska fälla testet.

---

## 2. Lagerordning (z-ordning, bakifrån och fram)

Ordningen ändrades i M2.5: `hair` kom in mellan `body` och `torso`, så allt
under det flyttade ett steg. `HeroFigure.LAYERS` har redan den nya listan.

| z | Lager | Filer | Innehåll |
|---|---|---|---|
| 0 | `cape` | `smith_cape_ember.png`, `smith_cape_octopus.png`, `smith_cape_echo_mirror.png` | Kappa, mantel, bläckfiskarmar, spegelskärvor. Ligger bakom allt. |
| 1 | `legs` | `smith_legs_iron.png` | Benrustning, byxor |
| 2 | `body` | `smith_body_a.png`, `smith_body_b.png` | **Bas-kropp**, en av två varianter: ben, bål, armar, huvud. Alltid synlig. |
| 3 | `hair` | `smith_hair_a.png`, `smith_hair_b.png` | **Valfritt.** Frisyr. Ligger under hjälmen: en hjälm ska kunna täcka håret. |
| 4 | `torso` | `smith_torso_broken_scale.png`, `smith_torso_echo_mirror.png`, `smith_torso_cheat_cube.png` | Bröstharnesk, bandolär, hängande relik |
| 5 | `head` | `smith_head_domino.png` | Markör ovanpå baskroppen men **under** hjälmen |
| 6 | `helm` | `smith_helm_iron.png`, `smith_helm_domino.png` | Hjälm, huva, krona |
| 7 | `offhand` | `smith_offhand_cheat_cube.png`, `smith_offhand_broken_scale.png` | Vänsterhanden: sköld, fuskkub, våg |
| 8 | `weapon` | `smith_weapon_hammer.png`, `smith_weapon_tongs.png` | Högerhanden |
| 9 | `fx` | `smith_fx_blood_price.png`, `smith_fx_octopus.png` | Effekter. **Enda lagret som får hålla flera sprites samtidigt.** |

Ben, bål och huvud ritas fortfarande i `body`; `hair`, `legs`, `torso`, `head`,
`offhand` och `fx` lägger **ovanpå** och ritar aldrig om baskroppen.

**Namnkontrakt:** `smith_<lager>_<id i gemener>.png`, där `<id>` är antingen
ett relik-id ur `content.gd` eller ett utrustningsnamn (`iron`, `ember`,
`hammer`, `tongs`). Filnamnet går alltså alltid att räkna ut ur (lager, id)
och behöver inte en egen uppslagstabell utöver `Art.RELIC_LAYERS`.

**Lager 5 (`head`) ligger under lager 6 (`helm`).** Allt som en relik ritar på
`head` vid tinningen döljs därför av en hjälm. `smith_head_domino.png` hänger
brickan i ett snöre nedanför hjälmbrättet i stället – synlig med och utan
hjälm. Det är regeln för varje framtida `head`-relik.

```
Paperdoll (Node2D, texture_filter = Nearest, scale = 4, position = heltal * 4)
 ├─ cape    (Sprite2D, hframes 8, vframes 4, z_index 0)
 ├─ legs    (Sprite2D, ... z_index 1)
 ├─ body    (Sprite2D, ... z_index 2)   smith_body_<a|b>.png
 ├─ hair    (Sprite2D, ... z_index 3)   smith_hair_<a|b>.png, får vara tom
 ├─ torso   (Sprite2D, ... z_index 4)
 ├─ head    (Sprite2D, ... z_index 5)
 ├─ helm    (Sprite2D, ... z_index 6)
 ├─ offhand (Sprite2D, ... z_index 7)
 ├─ weapon  (Sprite2D, ... z_index 8)
 ├─ fx      (Node2D som kan hålla N Sprite2D, z_index 9)
 └─ AnimationPlayer      // animerar ENBART föräldern Paperdoll.frame_index
```

`frame_index`-settern på föräldern skriver `frame` på varje `Sprite2D`.
`AnimationPlayer` rör aldrig ett enskilt lager. Se kodskiss i research 04 §2.

---

## 3. Vilken relik tänder vilket lager

Reliknamnen är exakt de id:n som ligger i `src/data/content.gd` (`RELICS`).

| `relic_id` | Namn | Rarity | Primärlager | Fil | Reservlager | Fil | Vad man ser |
|---|---|---|---|---|---|---|---|
| `BLOOD_PRICE` | Blodpriset | common | `fx` | `smith_fx_blood_price.png` | – | – | Röda droppar faller från båda händerna, 2 per sekund, och stänker på golvlinjen |
| `BROKEN_SCALE` | Trasiga vågen | uncommon | `torso` | `smith_torso_broken_scale.png` | `offhand` | `smith_offhand_broken_scale.png` | Våg i kedja över bröstet. **Skålarna väger aldrig jämnt** och högra kedjan är av |
| `OCTOPUS` | Bläckfisken | uncommon | `cape` | `smith_cape_octopus.png` | `fx` | `smith_fx_octopus.png` | Två armar ur ryggen som sträcker sig vänsterut mot slot 1 och 3. Reservlagret är samma armar en pixel tunna |
| `ECHO_MIRROR` | Ekospegeln | rare | `cape` | `smith_cape_echo_mirror.png` | `torso` | `smith_torso_echo_mirror.png` | En skärva och **samma form i mindre två gånger till** – en sak och dess eko, inte slumpad splitter |
| `CHEAT_CUBE` | Fuskkuben | rare | `offhand` | `smith_offhand_cheat_cube.png` | `torso` | `smith_torso_cheat_cube.png` | Laddad tärning som visar **exakt samma sida i alla 32 frames**. Allt annat i spelet tumlar; den här gör det aldrig |
| `DOMINO` | Dominobrickan | rare | `helm` | `smith_helm_domino.png` | `head` | `smith_head_domino.png` | Bricka i snöre vid käken som **tippar över på attackframe 2–3** |

I praktiken tänds alltid `DOMINO`:s **reservlager**: Smeden bär hjälm, och
utrustning slår relik på delat lager (se nedan). `smith_helm_domino.png` finns
för att kollisionskedjan ska ha konst i båda ändar och aldrig kunna landa på
ett tomt lager.

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

Alla 20 ark är 384×192 och genereras av `tools/gen_pixel_assets.py`
(`HERO_LAYERS`), plus två porträtt på 96×96 (§6). Inget lager saknas längre.

| Fil | Lager | Status |
|---|---|---|
| `smith_body_a.png` | `body` | **klar** – variant A "Broad": läderförkläde, skägg, sotfläck |
| `smith_body_b.png` | `body` | **klar (M2.5)** – variant B "Lean": delad kjortel, halsduk, lindade underarmar |
| `smith_hair_a.png` | `hair` | **klar (M2.5)** – knut i nacken, valfritt lager |
| `smith_hair_b.png` | `hair` | **klar (M2.5)** – lång fläta som svänger med gången |
| `smith_weapon_hammer.png` | `weapon` | **klar** – vapenvariant A (smideshammare) |
| `smith_weapon_tongs.png` | `weapon` | **klar** – vapenvariant B (tång med glödande ämne) |
| `smith_helm_iron.png` | `helm` | **klar** – nitad järnhjälm med näsjärn |
| `smith_cape_ember.png` | `cape` | **klar** – glödkappa som släpar bakåt |
| `smith_legs_iron.png` | `legs` | **klar (M2)** – benskenor med knäkupor, utrustning |
| `smith_fx_blood_price.png` | `fx` | **klar (M2)** – `BLOOD_PRICE` |
| `smith_torso_broken_scale.png` | `torso` | **klar (M2)** – `BROKEN_SCALE` primär |
| `smith_offhand_broken_scale.png` | `offhand` | **klar (M2)** – `BROKEN_SCALE` reserv |
| `smith_cape_octopus.png` | `cape` | **klar (M2)** – `OCTOPUS` primär |
| `smith_fx_octopus.png` | `fx` | **klar (M2)** – `OCTOPUS` reserv |
| `smith_cape_echo_mirror.png` | `cape` | **klar (M2)** – `ECHO_MIRROR` primär |
| `smith_torso_echo_mirror.png` | `torso` | **klar (M2)** – `ECHO_MIRROR` reserv |
| `smith_offhand_cheat_cube.png` | `offhand` | **klar (M2)** – `CHEAT_CUBE` primär |
| `smith_torso_cheat_cube.png` | `torso` | **klar (M2)** – `CHEAT_CUBE` reserv |
| `smith_helm_domino.png` | `helm` | **klar (M2)** – `DOMINO` primär |
| `smith_head_domino.png` | `head` | **klar (M2)** – `DOMINO` reserv (den som faktiskt tänds) |

### Vad dev behöver göra

`Art.RELIC_LAYERS` finns redan och `HeroFigure.apply_relics()` kör
kollisionsregeln. Det som saknas är uppslaget **(lager, relik-id) → fil**.
Det är en rad per relik och lager enligt namnkontraktet i §2, t.ex.:

```gdscript
static func relic_layer_texture(layer: StringName, relic_id: String) -> Texture2D:
    return texture("hero/smith_%s_%s.png" % [layer, relic_id.to_lower()])
```

Ingen annan ändring krävs: rutnät, origo, frame-ordning och `frame_index`-
settern är identiska med de befintliga lagren.

### Verifiering

`tools/gen_pixel_assets.py` skriver alla ark; storlekskontrollen
(`384×192`) kördes på alla 17 och passerade. Kompositionen granskades i
×4-förhandsvisning på frames `idle 0–3`, `walk 2`, `attack 2–3` och `hit 1`:
varje relik syns på figuren i både primär- och reservlager, och inget lager
döljer en annan reliks tell.


---

## 6. Porträtt och character sheet (M2.5)

### 6.1 Porträtten

| Fil | Storlek | Innehåll |
|---|---|---|
| `smith_portrait_a.png` | **96 × 96** | Byst, variant A: breda axlar, förklädesbröst med nitar, fullt skägg, hårknut med snodd |
| `smith_portrait_b.png` | **96 × 96** | Byst, variant B: smalare axlar, bandolär, rostfärgad halsduk, bar käke, fläta över axeln |

Porträttet är **inte** en uppskalning av `idle 0` – vid ×2 blir 48-px-cellen
gröt. Bysten är ritad i porträttupplösning och bär samma tre avläsningar som
kroppsarket (axelbredd, käke, hår), så figuren man väljer är figuren man får.

Används på två ställen: **könsvalskärmen** (UI_GUIDE §15, två porträtt sida vid
sida, tapp = välj) och som ansikte uppe till vänster på **character sheetet**.
Bakgrunden är transparent; ramen ritas i krita av UI-lagret, aldrig i PNG:n.

Skala: 96 px i **×1** på 360 dp-skärmar (96 dp), **×1,5** på ≥ 390 dp (144 dp).
Heltalsmultiplar krävs inte för porträttet eftersom det inte delar rutnät med
världen, men ×1,5 ska bara användas med Nearest-filter och jämn dp-position.

### 6.2 Paperdollen på character sheetet

Character sheetet (first person-vyn har ingen figur i korridoren – hela
identiteten bor här) visar **samma paperdoll-noder**, inget nytt ark:

* `Paperdoll.scale = 4` → 48 × 48 blir **192 × 192** skärmpixlar.
* Rad 0 (`idle`), 4 frames, 0,16 s/frame – figuren andas medan man byter grejer.
* Alla nio lager är tända samtidigt; det är den enda vyn där spelaren ser hela
  sin build i ett svep.
* Reducerad rörelse: frysta på `frame_index = 0`.
* Vid byte av utrustning spelas **inte** om animationen – bara det berörda
  lagrets `texture` byts, och en 120 ms kritblänk ritas över sloten.

Ett separat 192 × 192-ark vore fel: då skulle varje gear- och relikfil behöva
en andra upplaga i dubbel upplösning, och nästa relik skulle kosta två bilder i
stället för en. Skalan är en nodegenskap, inte en asset.
