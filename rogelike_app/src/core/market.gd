class_name Market
extends RefCounted
## Skrotmarknaden efter M6: säljer [b]gear ur en seedad rotation[/b], inte
## poolposter (DECISIONS 2026-09-23, PROGRESSION_REDESIGN §4.1/§6).
##
## Hyllorna fylls om efter varje run ([method rotate]) med samma seed-regel som
## allt annat: profilens rotationsräknare + runnens seed. Ingen pity-timer, ingen
## rabatt, inget som ändrar sig när spelaren tittar bort – priset står på hyllan
## och är [method Buildings.gear_price] för sällsyntheten.
##
## Episka föremål säljs aldrig: det är "drömdropparna" (§3.5) och får bara komma
## ur Gropen.


## Fyller hyllorna. [param seed_value] är runnens seed (eller 0 före första
## run). Antal varor och högsta sällsynthet kommer ur marknadens nivå.
static func rotate(meta: Meta, seed_value: int) -> void:
	var rng: Rng = Rng.new(seed_value ^ (meta.market_rotation * 7919 + 17)).fork("market")
	meta.market_rotation += 1
	meta.market_stock = stock_for(Buildings.market_wares(meta.buildings),
		Buildings.market_max_rarity(meta.buildings), rng)


## Ren funktion: [param count] olika föremål upp till [param max_rarity].
## Sällsynthetsvikter 60/30/10 inom det tillåtna.
static func stock_for(count: int, max_rarity: int, rng: Rng) -> Array[Dictionary]:
	var weights_by_rarity: Array[float] = [60.0, 30.0, 10.0]
	var ids: Array = []
	var weights: Array = []
	var catalogue: Array = Content.GEAR.keys()
	catalogue.sort()
	for id: Variant in catalogue:
		var rarity: int = int((Content.GEAR[id] as Dictionary)["rarity"])
		if rarity > max_rarity or rarity >= Rules.Rarity.EPIC:
			continue
		ids.append(String(id))
		weights.append(weights_by_rarity[rarity])
	var picked: Array = rng.weighted_sample(ids, weights, mini(count, ids.size()))
	var stock: Array[Dictionary] = []
	for raw: Variant in picked:
		var item: Item = Content.make_item(String(raw))
		stock.append({"item": item.to_dict(), "price": Buildings.gear_price(item.rarity)})
	return stock
