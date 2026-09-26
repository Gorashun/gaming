# Title Check: preliminary trademark and store-conflict screen

> Owner: legal-counsel. Date: 2026-09-26. Status: **PRELIMINARY, NOT A CLEARANCE.**
> This is a screen for obvious conflicts, not legal advice. **Before any public announcement, store listing or trademark filing, a trademark attorney must run a formal clearance search** (full USPTO / EUIPO / WIPO Madrid / national registers incl. Swedish PRV, common-law and app-store searches) in Nice classes **9** (downloadable game software), **41** (online game services) and ideally **28** (toys/merch). The attorney should also advise on filing our own EUTM + US application once a title is picked.

## 1. Method and limitations (read first)

| Source | Result |
|---|---|
| General web search (engine results that cover Steam, Google Play, App Store, itch.io, Trademarkia/Justia) | **Used.** All findings below come from this. |
| EUIPO eSearch (`euipo.europa.eu`) | **BLOCKED** by our network egress proxy. Not searched. |
| USPTO Trademark Search (`tmsearch.uspto.gov`) | **BLOCKED.** Not searched directly; some USPTO records seen via Justia/Trademarkia snippets in search results. |
| WIPO Global Brand Database (`branddb.wipo.int`) | **BLOCKED.** Not searched directly. |
| Steam / Google Play / App Store / itch.io direct search pages | **BLOCKED** (fetch and curl). Only search-engine results were checked. |

Consequence: "no hit" below means "**no hit in web search**". It does not mean the name is free. Every row is **UNVERIFIED against official registers.**

Risk scale: **Low** = no same-field hit found. **Medium** = hits in adjacent fields, or weak/descriptive. **High** = a live game or app with the same or near-identical name, or a registered mark covering class 9/41. **Reject** = clear conflict.

## 2. Candidates from the brief

| Candidate | Findings | Risk |
|---|---|---|
| **Lanterna** | LANTERNA is an international registration owned by **Panasonic**, which covers visual display units and electronics. That points to class 9, the class our software also falls in ([TrademarkElite WIPO 1424993](https://www.trademarkelite.com/wipo/trademark/trademark-detail/1424993/Lanterna)). A US LANTERNA mark (serial 79241638, also Panasonic) covers clothing ([Justia](https://trademark.justia.com/792/41/lanterna-79241638.html)). "Lanterna Education" claims an EU mark ([lanterna.com](https://lanterna.com/company-details)). "Lanterna" means *flashlight/lantern* in Portuguese and Italian, so Google Play has many "Lanterna" flashlight apps ([example](https://play.google.com/store/apps/details?id=com.galvadesenvolvimento.Lanterna&hl=en&gl=US)). That makes the name undiscoverable in store search and weak as a mark. There is also a well-known Java library called Lanterna ([GitHub](https://github.com/mabe02/lanterna)). A US LANTERN mark covers video game software in class 9 ([Justia 85582817](https://trademark.justia.com/855/82/lantern-85582817.html)), and there are many "Lantern" games on Steam ([Lantern](https://store.steampowered.com/app/487630/Lantern/), [Lantern Light](https://store.steampowered.com/app/2192100/Lantern_Light_DEMO/)). | **High** |
| **Glimmerfall** | **GlimmerFall TCG** is a *digital trading card game of Light & Void*, which is our exact theme and our class ([glimmerfalltcg.com](https://www.glimmerfalltcg.com/)). There is also an itch.io jam game "GlimmerFall" with a "Light" theme ([itch](https://lucastaniolo.itch.io/glimmerfall)) and an item called "Glimmerfall Lights" in *Infinity Nikki* ([Game8](https://game8.co/games/Infinity-Nikki/archives/507421)). | **High, reject** |
| **Emberkin** | "Emberkin" is a Paizo *Pathfinder* lineage/feat term ([Archives of Nethys](https://2e.aonprd.com/Feats.aspx?ID=2283)). A small Unity fantasy game with that name exists on GitHub ([repo](https://github.com/johndrochers/emberkin)). The "Ember" space is crowded, and **Torchlight uses "Ember" as its signature resource and "Embermage" as a class** (see BLOCKLIST). No store listing was found. | **Medium** |
| **Nightwick** | *Nightwick Abbey* is a known OSR tabletop megadungeon setting, and the brand has an active community ([blog](https://icastlight.blogspot.com/p/the-nightwick-abbey-campaign-bx-d.html)). NightWick Candles is a small US candle maker ([Facebook](https://www.facebook.com/nightwickcandles/)). No video game with the name was found. "Night" also reads as scarier than ideal for a 7+ audience. | **Medium** |
| **Lykta** | This is the ordinary Swedish word for "lantern". In Sweden it is descriptive, so it is weak or unregistrable for lantern-themed goods. Near-identical game names exist: *Lykt.* (a 2020 Japanese BL game by Parade) and *LYKT* (an itch.io light puzzle game) ([itch](https://guillaumepauli.itch.io/lykt)). The "y" is hard for English-speaking 7-year-olds to pronounce. | **Medium-High** |

## 3. New candidates (theme: "carry the last light into a world that forgot itself")

| Candidate | Findings | Risk |
|---|---|---|
| **Wickwright** ("wick-maker": the hero who re-lights the world and crafts light into items) | No game or app found. The closest hits are **WickRight Inc.** and "Wickwright General Contracting", building-restoration contractors in Chicago ([LinkedIn](https://www.linkedin.com/company/wickright-inc-)). They sit in unrelated classes (37/19). *Wick* (2015 horror game, [Steam](https://store.steampowered.com/app/418300/Wick/)) and the Lionsgate *John Wick* franchise use "Wick" alone, but "Wickwright" is a distinct coined compound. | **Low** |
| **Lumenholm** (already our world name) | No game, app or brand found (web search, 2026-09-26: only fantasy-name-list pages). "Lumen" is a crowded prefix: *Lumen Technologies* holds LUMEN marks in class 9 ([uspto.report](https://uspto.report/TM/88642330)), and *Lumencraft* is on Steam ([Steam](https://store.steampowered.com/app/1713810/Lumencraft/)). The compound is distinct, but expect "Lumen"-based objections in class 9. | **Low-Medium** |
| **Wickhollow** | No game found. There is a UK construction-recruitment firm, "Wick Hollow Ltd" ([site](https://wickhollow.co.uk/)), and a street in Houston. | **Low-Medium** |
| **Kindlewick** | No game found, but it collides with Amazon's famous **KINDLE** mark, which Amazon also uses for games and apps. A **KINDLE WICK** candle mark also exists ([Justia](https://trademarks.justia.com/850/37/kindle-wick-85037969.html)). The name is also close to *Spiderwick*. | **High, reject** |
| **Glimmerwick** | *Songs of Glimmerwick* (Eastshade Studios) launches on Steam on 2026-09-30 ([Steam](https://store.steampowered.com/app/1706510/Songs_of_Glimmerwick/)). | **Reject** |
| **Emberwake** | *Emberwake* is a dark-fantasy survival game on Steam ([Steam](https://store.steampowered.com/app/3239340/Emberwake/)). A second *Emberwake* on itch.io is literally about re-lighting fires in a dead world ([itch](https://potentialnova-games.itch.io/emberwake)). | **Reject** |
| **Lumenfall** | Several games use this name: *LumenFall* on Steam and on Google Play, and several on itch.io ([Steam](https://store.steampowered.com/app/4700180/LumenFall/), [Play](https://play.google.com/store/apps/details?id=com.DavidCzepielBabiarz.LumenFall)). | **Reject** |
| **Wicklings** / Wickling | *Wicklings* is a strategy game on the iOS App Store ([App Store](https://apps.apple.com/us/app/wicklings/id6802045809)). | **Reject** |
| **Lanternbound** | An itch.io JRPG with the same lantern mechanic uses this name ([itch](https://csaf.itch.io/lanternbound)). | **High** |
| **Hushwick** | A named character in *Age of Wonders III* (Paradox/Triumph) ([wiki](https://age-of-wonders-3.fandom.com/wiki/Pre-Made_Leaders)). | **Medium-High** |
| **Last Lantern** | *Last Lantern* is a 2026 family board game about a dimming lantern and fog ([BGG](https://boardgamegeek.com/boardgame/439519/last-lantern)). | **High** |
| **Tallowlight** | An itch.io game uses this name ([itch](https://kennehh.itch.io/tallowlight)), and it is close to *Tallowmere* (Steam/Switch/Android). | **Medium-High** |

## 4. Ranking (lowest risk first)

1. **Wickwright** (Low)
2. **Lumenholm** (Low-Medium)
3. **Wickhollow** (Low-Medium)
4. **Emberkin** (Medium)
5. **Nightwick** (Medium)
6. **Lykta** (Medium-High)
7. **Lanterna** (High)
8. **Glimmerfall** (High, reject)

Rejected outright: Kindlewick, Glimmerwick, Emberwake, Lumenfall, Wicklings, Lanternbound, Last Lantern.

## 5. Recommendation

**Working title: WICKWRIGHT**. Suggested store form: *"Wickwright: Carry the Light"*.

- It is a coined compound with no game or app hits, it is easy for a 7-year-old to say ("WICK-rite"), and it ties the lore (re-lighting the world) to the crafting fantasy (lighting items in the kettle).
- Backup: **Lumenholm**. Keep it as the world name either way.
- **Drop "Lanterna"** as the working title now. It is weak (a generic foreign word for flashlight), undiscoverable in Google Play, and near a Panasonic class-9 international registration.
- Tagline: "Carry the light" is fine. **Do not use "Last Light" as a title element.** *Metro: Last Light* (Deep Silver/4A Games) makes that phrase risky in games (**unverified** registration status; it is in the attorney's scope).

### Next steps (in order)
1. Attorney clearance search for **WICKWRIGHT** and **LUMENHOLM** in classes 9, 41 and 28 in the EU, US, UK and WIPO, plus common-law and store searches. **Required before launch.**
2. Check that the `wickwright` domains (.com/.game/.se) and social handles are free (**not checked**).
3. Search the Google Play and App Store developer consoles for exact-name listings. The console name check is authoritative for store conflicts.
4. If cleared, file an EUTM + US application (intent-to-use) early, before the public reveal.
