# ASSET_SOURCES: third-party asset provenance log

> Owner: legal-counsel. Policy: THIRD_PARTY.md §8. **A row is required before a third-party asset is merged.** One row per pack or single asset.
> Allowed licenses: `CC0-1.0` (models, animations, textures, HDRIs, sounds, fonts) and `OFL-1.1` (fonts). Anything else needs written legal approval (noted in the Notes column).

## Columns
| Column | Meaning |
|---|---|
| **ID** | `A-###`, sequential |
| **Asset / pack (version)** | Exact name as published, with version |
| **Type** | model / animation / texture / HDRI / sound / font |
| **Author / provider** | Person or studio that created it |
| **Source page URL** | The page where the license was read (not a mirror) |
| **Download URL / commit** | Exact file URL or git commit hash |
| **License (SPDX)** | e.g. `CC0-1.0`, `OFL-1.1` |
| **License proof** | Repo path to the saved LICENSE file (+ archived page/screenshot, if any) |
| **Download date** | ISO date (YYYY-MM-DD) |
| **Downloaded by** | Agent role or person |
| **Local path** | Where it lives under `arpg/game/` |
| **Modifications** | None / what we changed |
| **Credit shown** | Optional credit line used in the Credits screen, or "—" |
| **Checked (brands/logos/text)** | Yes/No: no trademarks, real brands or readable real text in the asset |
| **Legal OK** | Reviewer + date |
| **Notes** | Caveats |

## Log
| ID | Asset / pack (version) | Type | Author / provider | Source page URL | Download URL / commit | License | License proof | Download date | Downloaded by | Local path | Modifications | Credit shown | Checked | Legal OK | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A-001 | KayKit Character Pack: Adventurers (1.0) | model/animation | Kay Lousberg (KayKit) | https://kaylousberg.itch.io/kaykit-adventurers | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 @ 672074b73ba276876a19e8816ecdc5241817ab47 | CC0-1.0 | `game/assets/thirdparty/kaykit/adventurers/LICENSE.txt` | 2026-09-26 | (unrecorded, fill in) | `game/assets/thirdparty/kaykit/adventurers/` | None (TBC) | "3D assets by Kay Lousberg (KayKit), CC0" | Pending | legal-counsel 2026-09-26: license OK; brand check pending | Commit verified against GitHub via `git ls-remote`. The pack also offers an optional "brand resource" for crediting. The itch page is blocked from our proxy; re-check the page manually |
| A-002 | KayKit Character Pack: Skeletons (1.0) | model/animation | Kay Lousberg (KayKit) | https://kaylousberg.itch.io/ (pack page TBC) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 @ 15b62b9bad122f72926c10fb14d622c73819fa54 | CC0-1.0 | `game/assets/thirdparty/kaykit/skeletons/LICENSE.txt` | 2026-09-26 | (unrecorded, fill in) | `game/assets/thirdparty/kaykit/skeletons/` | None (TBC) | as A-001 | Pending | legal-counsel 2026-09-26: license OK | Skeleton enemies are fine for 7+ only if the art style stays non-gory (child-safety review) |
| A-003 | KayKit Dungeon Remastered (1.0) | model/texture | Kay Lousberg (KayKit) | https://kaylousberg.itch.io/kaykit-dungeon-remastered (TBC) | https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 @ b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07 | CC0-1.0 | `game/assets/thirdparty/kaykit/dungeon/LICENSE.txt` | 2026-09-26 | (unrecorded, fill in) | `game/assets/thirdparty/kaykit/dungeon/` | None (TBC) | as A-001 | Pending | legal-counsel 2026-09-26: license OK | |
| A-004 | KayKit Halloween Bits (1.0) | model | Kay Lousberg (KayKit) | https://kaylousberg.itch.io/halloween-bits | https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0 @ 6dc69bf6b2fa766a985754f35ec6a0324090e6c6 | CC0-1.0 | `game/assets/thirdparty/kaykit/halloween/LICENSE.txt` | 2026-09-26 | (unrecorded, fill in) | `game/assets/thirdparty/kaykit/halloween/` | None (TBC) | as A-001 | Pending | legal-counsel 2026-09-26: license OK | |
