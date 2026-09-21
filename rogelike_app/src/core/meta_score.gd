class_name MetaScore
extends RefCounted
## Meta-poäng när en run tar slut. Ren funktion, ingen RNG.
##
## [b]Spec-läge:[/b] GAME_DESIGN §1 säger att döden ger meta-poäng ("innehåll,
## aldrig styrka") och §4 listar inget poängsystem. §7 fråga 7 parkerar
## meta-progressionens form tills affärsmodellen är beslutad. Formeln nedan är
## därför dev:s M1-placeholder, medvetet enkel och läsbar på död/vinst-skärmen.
## Den delar bara ut [b]innehåll[/b] (Kodex-poster, teman), aldrig statboost.
##
## [codeblock]
## poäng = rum_rensade × 10
##       + floor(största_kedja / 5)
##       + floor(HP_kvar / 10)
##       + 50 om runnen vanns
## [/codeblock]
##
## Egenskaper som gör den duglig som placeholder: den är monoton i alla fyra
## termerna (mer är aldrig sämre), den ger noll för en run som dör i rum 1 utan
## att göra något, och den belönar en stor kedja även i en förlorad run – vilket
## är hela "en run till"-kroken.

const POINTS_PER_ROOM: int = 10
## Skada per meta-poäng i "största kedja".
const CHAIN_DAMAGE_PER_POINT: int = 5
## HP kvar per meta-poäng.
const HP_LEFT_PER_POINT: int = 10
const WIN_BONUS: int = 50


static func score(rooms_cleared: int, best_chain: int, won: bool, hp_left: int) -> int:
	return int(breakdown(rooms_cleared, best_chain, won, hp_left)["total"])


## Samma beräkning men uppdelad, så att död/vinst-skärmen kan visa varje rad.
static func breakdown(rooms_cleared: int, best_chain: int, won: bool, hp_left: int) -> Dictionary:
	var rooms: int = maxi(0, rooms_cleared) * POINTS_PER_ROOM
	var chain: int = maxi(0, best_chain) / CHAIN_DAMAGE_PER_POINT
	var survival: int = maxi(0, hp_left) / HP_LEFT_PER_POINT
	var win: int = WIN_BONUS if won else 0
	return {
		"rooms": rooms,
		"chain": chain,
		"survival": survival,
		"win": win,
		"total": rooms + chain + survival + win,
	}


## Total skada mot fiender i EN rundas händelselogg.
## Definitionen är GAME_DESIGN §3 invariant 6: summan av alla
## [code]damage_dealt.amount[/code] plus alla [code]status_ticked.amount[/code].
## "Största kedja" i UI är maxvärdet av detta över runnens alla rundor.
static func chain_damage(events: Array[Dictionary]) -> int:
	var total: int = 0
	for event: Dictionary in events:
		match String(event.get("t", "")):
			"damage_dealt":
				total += int(event.get("amount", 0))
			"status_ticked":
				total += int(event.get("amount", 0))
	return total
