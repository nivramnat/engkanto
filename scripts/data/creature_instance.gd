class_name CreatureInstance
extends Resource
## A creature in play: wraps immutable Creature data with per-instance level and
## current HP. Effective stats scale with level, keeping the Creature resource
## itself read-only shared data.

@export var data: Creature
@export var level: int = 1
@export var current_hp: int = 0


static func create(p_data: Creature, p_level: int) -> CreatureInstance:
	var inst := CreatureInstance.new()
	inst.data = p_data
	inst.level = p_level
	inst.current_hp = inst.max_hp()
	return inst


func max_hp() -> int:
	return data.hp + level * 3


func attack() -> int:
	return data.attack + level * 2


func defense() -> int:
	return data.defense + level * 2


func speed() -> int:
	return data.speed + level


func is_fainted() -> bool:
	return current_hp <= 0


func take_damage(amount: int) -> void:
	current_hp = clampi(current_hp - amount, 0, max_hp())


func full_heal() -> void:
	current_hp = max_hp()


func display_name() -> String:
	return data.name if data != null else "???"


# --- Save data ---

## Plain-data form for the save file. Creature data is stored by resource path
## so the .tres stays the single source of truth for stats and moves.
func to_dict() -> Dictionary:
	var d: Dictionary = {
		"resource": data.resource_path if data != null else "",
		"level": level,
		"current_hp": current_hp,
	}
	var xp: Variant = get("xp")  # only saved once the XP system adds the field
	if xp != null:
		d["xp"] = xp
	return d


## Rebuild from to_dict() output. Returns null if the creature resource is
## missing, so one bad entry doesn't break the whole save.
static func from_dict(d: Dictionary) -> CreatureInstance:
	var path: String = str(d.get("resource", ""))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Save: skipping creature with missing resource '%s'" % path)
		return null
	var res: Creature = load(path) as Creature
	if res == null:
		push_warning("Save: '%s' is not a Creature resource" % path)
		return null
	var inst := CreatureInstance.create(res, maxi(1, int(d.get("level", 1))))
	inst.current_hp = clampi(int(d.get("current_hp", inst.max_hp())), 0, inst.max_hp())
	if d.has("xp") and "xp" in inst:
		inst.set("xp", int(d["xp"]))
	return inst
