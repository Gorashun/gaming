# rogelike_app – projektregler

Roguelike-mobilspel, Android först, iOS därefter. Målgrupp 13+. Kärnkrav: täta, variabla dopaminkickar och "en run till"-känsla utan dark patterns eller pengaspel.

## Läs först
- `docs/PROPOSAL.md` – konceptförslag och tech-val (beslutsunderlag)
- `docs/DECISIONS.md` – fattade beslut, ändra inte utan nytt beslut
- `docs/GAME_DESIGN.md` – speldesign
- `team/README.md` – agentroller

## Regler
- Spellogik är deterministisk, seedad och testbar utan UI.
- Ingen backend för MVP. Offline-first.
- Inga lootboxar för pengar, inga energi-timers, inga pay-to-win. Belöningsvariation sker inuti spelet, inte i butiken.
- Svenska i dokumentation, engelska i kod. Commits på engelska.
- Varje leverans: build + tester körda, resultat rapporterat ordagrant.
