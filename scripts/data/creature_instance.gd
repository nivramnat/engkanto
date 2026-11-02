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
