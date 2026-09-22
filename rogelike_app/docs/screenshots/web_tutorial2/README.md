# M5.8 i webbläsaren

Chromium (swiftshader), `build/web/` serverat på 127.0.0.1, start på
`index.html` med `?start=tutorial&seed=7` respektive `?start=corridor&seed=7` –
samma metod som `web_tutorial/`.

## 1. Källaren går att återuppta

| Bild | Vad den visar |
|---|---|
| `03_room04_before_reload` | Spelat rum 0.1–0.3 (loot taget) och in i **rum 0.4**: 92/100 HP, Tick Pup 26/26 rustning 3, tärningarna 3-3-5-5-1 |
| `04_title_after_reload` | **Sidan omladdad utan query.** Titeln erbjuder `CONTINUE` som primärknapp – inte en omstart på 0.1 |
| `05_room04_after_continue` | Efter `CONTINUE`: **samma rum, samma tärningar, samma HP, samma fiende.** Kritpilen står över kvittot, som rummet ber om |

## 2. Rum 0.6 säger vad lektionen är

| Bild | Vad den visar |
|---|---|
| `21_room05_480x900` | Rum 0.5 (Spegeln) på vägen dit |
| `22_room06_tip_480x900` | **`TUT_06_CHARGE` = "Leave slot 1 empty. The charge goes to the Mirror." och kritpilen står över slot 1.** Porten är 44/44 rustning 8 |

Jämför `../web_tutorial/21_room06_charge_through_mirror.png`: där pekade tipset
på laddningsmätaren och sa bara *"Dice you don't place go in the bank"*.

## 3. Ingen text klipps

| Bild | Vad den visar |
|---|---|
| `01_reward_title_480` / `20_reward_title_480x900` | `CORRIDOR_REWARD_TITLE` på 480×900: **"THE ROOM LEAVES SOMETHING" ryms med marginal i båda kanterna** |
| `20_reward_title_360x640` | Samma rubrik på 360×640 |
| `10_corridor_reward_480x900` | `?start=corridor&seed=7`, rum 1 vunnet: rubrik + tre kortnamn |
| `11_corridor_reward_360x640` | Samma på 360×640 – kortnamnen krymper i stället för att klippas |
| `02_loot_480` | Källarens loot-val, tre kortnamn på en rad var |
