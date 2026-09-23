class_name Bank
extends RefCounted
## Trappbanken: "skicka upp med kärran". PROGRESSION_REDESIGN §3.4.
##
## Vid trappan väljer spelaren vilka föremål som skickas upp. De är säkra för
## alltid – men bärs inte resten av runen. Det är spelets frivilliga
## press-your-luck-beslut, och det enda sättet att säkra något mitt i en run.
##
## Banken ligger i profilen ([Meta]) och överlever död, omstart och "Reset save".

var items: Array[Item] = []


## Skickar upp föremål. Kopior läggs i banken, markerade som säkrade.
func deposit(sent: Array) -> void:
	for raw: Variant in sent:
		if raw is Item:
			var item: Item = (raw as Item).copy()
			item.secured = true
			items.append(item)


func take(index: int) -> Item:
	if index < 0 or index >= items.size():
		return null
	var item: Item = items[index]
	items.remove_at(index)
	return item


func to_dict() -> Dictionary:
	return {"items": Item.list_to_dicts(items)}


static func from_dict(data: Dictionary) -> Bank:
	var bank: Bank = Bank.new()
	bank.items = Item.list_from_dicts(data.get("items", []))
	for item: Item in bank.items:
		item.secured = true
	return bank
