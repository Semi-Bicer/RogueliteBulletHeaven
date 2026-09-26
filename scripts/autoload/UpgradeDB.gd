extends Node
## Upgrade catalogue and the roll that builds a legal set of level-up choices.
##
## Weapons only for now; passives are still to come. docs/DESIGN.md section 7
## lists the rest of the catalogue, the entry shapes, and the rules `roll()`
## has to respect. Orbital Shield is on hold (DESIGN.md §5).

const MAX_WEAPONS := 3

## Entry shapes:
##   weapon  -> { id, name, desc, kind = "weapon",  scene, max_level, color }
##   passive -> { id, name, desc, kind = "passive", stat, amount, max_level, color }
const UPGRADES: Array[Dictionary] = [
	{"id": "magic_missile", "name": "Magic Missile", "desc": "Fires homing bolts at the nearest enemy.",
		"kind": "weapon", "scene": "res://scenes/weapons/MagicMissile.tscn", "max_level": 8,
		"color": Color(0.55, 0.85, 1.0)},
	{"id": "fire_ball", "name": "Fire Ball", "desc": "Piercing fireball; hits 2 enemies, +1 per level.",
		"kind": "weapon", "scene": "res://scenes/weapons/FireBall.tscn", "max_level": 8,
		"color": Color(1.0, 0.55, 0.2)},
	{"id": "shock_nova", "name": "Shock Nova", "desc": "Periodic shockwave around you.",
		"kind": "weapon", "scene": "res://scenes/weapons/ShockNova.tscn", "max_level": 8,
		"color": Color(0.7, 0.6, 1.0)},
]

## Offered when fewer than `count` real choices remain (everything maxed).
const FALLBACK := {"id": "ration", "name": "Ration", "desc": "Heal 30 HP.",
	"kind": "consumable", "max_level": 999999, "color": Color(0.5, 1.0, 0.6)}


func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	if id == FALLBACK["id"]:
		return FALLBACK
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
	if choices.size() < count:
		choices.append(_as_choice(FALLBACK, owned))
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
