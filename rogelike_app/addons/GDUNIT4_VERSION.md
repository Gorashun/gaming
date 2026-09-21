# gdUnit4 – vendorerad version

- Version: **v6.2.1** (tagg `v6.2.1`, commit `08ffc7c65b61b1b2edd545616061a99973c13ce1`)
- Källa: https://github.com/MikeSchulze/gdUnit4
- Kompatibilitet: gdUnit4 6.x riktar sig mot Godot 4.6 (addonens egen `project.godot`
  deklarerar `config/features=PackedStringArray("4.6", "C#")`).
- Endast GDScript-delen används. C#-delen (gdUnit4Net) är inte installerad.

Uppgradering: byt ut hela `addons/gdUnit4/` mot en ny tagg och uppdatera den här filen
samt `.github/workflows/test.yml`.
