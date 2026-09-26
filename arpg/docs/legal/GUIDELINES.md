# Legal Guidelines for all team agents

> Owner: legal-counsel (holds a veto on infringement risk). Short rules; details in BLOCKLIST.md, THIRD_PARTY.md, TITLE_CHECK.md, ASSET_SOURCES.md. Not legal advice. Anything uncertain goes to legal-counsel, and from there to a real lawyer if needed.

## 1. Idea vs. expression
- **Free to use (ideas and mechanics):** difficulty ladders, permadeath mode, timed dungeons, post-cap progression, crafting devices, rarity tiers, pity timers, skill trees, loot filters, set bonuses.
- **Never copy (expression):** names, text, dialogue, lore, item and skill names, icons, UI layouts and screen compositions, character designs, logos, fonts from games, music, sound effects, VFX signatures, trailers, store copy.
- Test: *"Would a fan recognize the source from our name, screen or sound alone?"* If yes, redesign.

## 2. Never copy
1. **Text and names:** no Diablo, PoE, Last Epoch, Grim Dawn, Torchlight or Warhammer terms (BLOCKLIST.md). Do not use them in code identifiers or file names that players can see.
2. **UI:** do not replicate another game's inventory grid proportions, paper-doll layout, skill bar arrangement, tooltip frame art or rarity-beam style. Design from our own lantern/light language.
3. **Icons and art:** no tracing, no "paint-over" of screenshots, no reference image kept open while drawing a specific asset. Mood boards are allowed for *style study*, not for copying one asset.
4. **Audio:** no sound-alikes of iconic cues (e.g. legendary-drop chimes, level-up stingers).
5. **Research files** may name competitor systems for analysis (e.g. `research/arpg-system.md`). Those names must **never** migrate into `game/` or store text.

## 3. Logos and branding
- No look-alike logos: avoid gothic red/orange flaming wordmarks in the Diablo style, PoE-style emblems and double-headed eagles.
- Our logo must be distinct in shape, color and type. Before the logo is final, run a reverse-image search against the top-50 ARPGs and a quick check in the EUIPO/USPTO figurative-mark classes (via the attorney).
- Do not use platform or engine logos (Google Play, App Store, Godot) outside their official badge and brand rules.

## 4. Naming process (mandatory for every player-facing proper noun)
1. **Propose.** Write the name, its meaning, and where it will be used in `arpg/docs/legal/NAME_REQUESTS.md` (created on first use).
2. **Self-check.** Compare against BLOCKLIST.md, then web-search `"<name>" game`, `"<name>" app` and `"<name>" trademark`.
3. **Legal check.** legal-counsel approves, rejects or suggests changes, and records the verdict. Titles, the logo and the studio name also need **attorney clearance** before launch.
4. **Adopt.** Only approved names go into `game/data/*.json` or UI strings.
Low-risk defaults: invent names from our own lore vocabulary (lanterns, wicks, embers-as-prose, hush, dim, glow) and plain English, and avoid other games' capitalized compound nouns.

## 5. Third-party material
- Code, fonts, tools and assets **only** as allowed by THIRD_PARTY.md, and every asset must be logged in ASSET_SOURCES.md *before* merge.
- CC0 and OFL are pre-approved (with provenance). Everything else needs a written OK.
- Keep generator scripts, seeds and SFX parameter files in the repo as proof of independent creation.

## 6. Children's privacy (brief; the child-safety agent owns the details)
- The audience is 7+, so **COPPA** (US, under 13) and **GDPR Art. 8 / "GDPR-K"** (EU: parental consent below age 13–16 depending on member state) apply to any personal-data processing.
- Default design: **offline, no accounts, no ads, no third-party analytics or SDKs, no runtime web fonts or CDNs, no open chat**. Any new SDK or network call needs child-safety + legal review first.
- Follow the Google Play Families policy and the App Store Kids Category rules. The child-safety agent maintains those requirements.

## 7. When in doubt
Stop, flag legal-counsel, and pick the more original option. A unique name costs nothing now; a rename after launch costs the store listing, reviews and marketing.
