# Spelkontrakt

Ett spel räknas som "verkligt" när en headless-webbläsare kan ladda det, spela det via dess eget API och inget går sönder. Verifieraren (`forge/lib/verify.mjs`) kräver:

- En självständig fil: `games/<slug>/index.html`. Inga externa resurser (CDN, typsnitt, bilder över nätet).
- Ett rot-element med attributet `data-game-root`.
- `window.GameAPI` med:
  - `name: string`
  - `reset()` startar nytt spel
  - `getState()` returnerar JSON-serialiserbart objekt som minst innehåller `{ over: boolean, score: number }`
  - `actions()` returnerar giltiga handlings-id:n just nu (tom lista bara när `over === true`)
  - `act(id)` utför en handling och **kastar fel** på ogiltigt id
- Tillståndet måste ändras minst en gång under en slumpad genomspelning (60 steg, fast seed).
- Noll konsolfel och noll ohanterade undantag.
- Valfria uppdragsspecifika kontroller: `{type:"text", selector, includes}`, `{type:"state", path, equals}`, `{type:"exists", selector}`.
