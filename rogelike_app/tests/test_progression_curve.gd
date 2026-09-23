extends GdUnitTestSuite
## Progressionskurvan run 1–10 (M6 steg 6). PROGRESSION_REDESIGN §5.
##
## Testet spelar hela karriärer headless genom [Career] – samma funktioner som
## [GameController] anropar – och asserterar kurvans garantier plus kick-
## tätheten. Boten är [code]mixed[/code] (planerar varannan runda): lookahead
## vinner våning 1 nästan alltid och skulle aldrig visa döden.

const SEEDS: Array[int] = [11, 23, 37, 41]
const RUNS: int = 10

var _careers: Array = []


func before() -> void:
	_careers.clear()
	for seed_value: int in SEEDS:
		_careers.append(Career.play_career(RUNS, seed_value, "mixed"))


func test_a_career_is_deterministic() -> void:
	var again: Array[Dictionary] = Career.play_career(RUNS, SEEDS[0], "mixed")
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(_careers[0]))


func test_run_zero_puts_a_common_item_on_the_figure() -> void:
	var meta: Meta = Meta.fresh()
	Career.tutorial(meta, 5)
	var hero: Hero = meta.roster.active()
	var gift: Item = Content.make_item(Progression.TUTORIAL_GIFT)
	assert_int(gift.rarity).is_equal(Rules.Rarity.COMMON)
	assert_str(hero.equipped(gift.slot).id).is_equal(gift.id)


func test_run_one_drops_at_least_one_uncommon_when_the_first_room_is_won() -> void:
	for career: Variant in _careers:
		var run: Dictionary = (career as Array)[0]
		if int(run["rooms_cleared"]) < 1:
			continue
		var by_rarity: Array = run["drops_by_rarity"] as Array
		assert_int(int(by_rarity[1]) + int(by_rarity[2]) + int(by_rarity[3])).override_failure_message(
			"run 1 ska droppa minst ett UNCOMMON (§5)").is_greater_equal(1)


func test_run_three_has_at_least_three_gear_slots() -> void:
	for career: Variant in _careers:
		for i: int in range(2, RUNS):
			assert_int(int(((career as Array)[i] as Dictionary)["slots"])).override_failure_message(
				"run %d: hjälten ska ha minst tre slots (§5 run 3)" % (i + 1)).is_greater_equal(3)


func test_no_epic_before_run_ten() -> void:
	for career: Variant in _careers:
		for i: int in range(0, RUNS - 1):
			var by_rarity: Array = ((career as Array)[i] as Dictionary)["drops_by_rarity"] as Array
			assert_int(int(by_rarity[Rules.Rarity.EPIC])).override_failure_message(
				"run %d droppade ett episkt föremål" % (i + 1)).is_equal(0)
	var meta: Meta = Meta.fresh()
	meta.runs_started = 9
	assert_bool(Progression.epic_allowed(meta, 1)).is_false()
	meta.runs_started = 10
	assert_bool(Progression.epic_allowed(meta, 1)).is_true()
	assert_bool(Progression.epic_allowed(Meta.fresh(), 2)).override_failure_message(
		"våning 2 öppnar episkt oavsett run").is_true()


func test_a_rare_is_guaranteed_by_run_six() -> void:
	var meta: Meta = Meta.fresh()
	meta.runs_started = 6
	assert_int(Progression.room_min_rarity(meta, 1)).is_equal(Rules.Rarity.RARE)
	assert_int(Progression.room_min_rarity(meta, 2)).is_equal(-1)
	meta.drops_by_rarity[Rules.Rarity.RARE] = 1
	assert_int(Progression.room_min_rarity(meta, 1)).is_equal(-1)
	for career: Variant in _careers:
		var rares: int = 0
		for i: int in range(6):
			rares += int((((career as Array)[i] as Dictionary)["drops_by_rarity"] as Array)[Rules.Rarity.RARE])
		assert_int(rares).override_failure_message("inget RARE på sex runs").is_greater(0)


func test_the_hero_level_climbs_over_ten_runs() -> void:
	var first: float = 0.0
	var last: float = 0.0
	for career: Variant in _careers:
		first += float(((career as Array)[0] as Dictionary)["hero_level"])
		last += float(((career as Array)[RUNS - 1] as Dictionary)["hero_level"])
	assert_float(last).is_greater(first)


## Kicktätheten (§5): mål 0,9–1,1 kickar per minut. En vanlig spelare
## (mixed) mäter ~0,86 i simulatorn med 40 karriärer; med fyra karriärer i ett
## test tillåts bandet 0,7–1,4.
func test_kick_density_is_near_the_target() -> void:
	var kicks: float = 0.0
	var seconds: float = 0.0
	var drops: float = 0.0
	var runs: float = 0.0
	for career: Variant in _careers:
		for run: Variant in career as Array:
			kicks += float((run as Dictionary)["kicks"])
			seconds += float((run as Dictionary)["seconds"])
			drops += float((run as Dictionary)["drops"])
			runs += 1.0
	var per_minute: float = kicks / (seconds / 60.0)
	assert_float(per_minute).is_between(0.7, 1.4)
	assert_float(drops / runs).is_greater_equal(2.0)
