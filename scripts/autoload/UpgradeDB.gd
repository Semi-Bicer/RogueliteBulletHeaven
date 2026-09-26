extends Node
## Upgrade catalogue and the roll that builds a legal set of level-up choices.
##
## Only the starting weapon is registered so far. docs/DESIGN.md section 7
## lists the rest of the catalogue, the two entry shapes, and the rules
## `roll()` has to respect.

const MAX_WEAPONS := 3

## Entry shapes:
##   weapon  -> { id, name, desc, kind = "weapon",  scene, max_level, color }
##   passive -> { id, name, desc, kind = "passive", stat, amount, max_level, color }
const UPGRADES: Array[Dictionary] = [
	{"id": "magic_missile", "name": "Magic Missile", "desc": "Fires homing bolts at the nearest enemy.",
		"kind": "weapon", "scene": "res://scenes/weapons/MagicMissile.tscn", "max_level": 8,
		"color": Color(0.55, 0.85, 1.0)},
]


func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


## `owned` maps upgrade id -> current level. Returns up to `count` choices.
func roll(owned: Dictionary, count: int = 3) -> Array:
	var weapon_count := 0
	for id in owned:
		if get_upgrade(id).get("kind", "") == "weapon":
			weapon_count += 1

	var pool: Array[Dictionary] = []
	for u in UPGRADES:
		var lv: int = owned.get(u["id"], 0)
		if lv >= int(u["max_level"]):
			continue
		if u["kind"] == "weapon" and lv == 0 and weapon_count >= MAX_WEAPONS:
			continue
		pool.append(u)

	pool.shuffle()
	var choices: Array = []
	for u in pool:
		if choices.size() >= count:
			break
		choices.append(_as_choice(u, owned))
	return choices


func _as_choice(u: Dictionary, owned: Dictionary) -> Dictionary:
	var lv: int = owned.get(u["id"], 0)
	return {
		"id": u["id"],
		"name": u["name"],
		"desc": u["desc"],
		"kind": u["kind"],
		"color": u["color"],
		"current_level": lv,
		"next_level": lv + 1,
		"is_new": lv == 0,
	}
