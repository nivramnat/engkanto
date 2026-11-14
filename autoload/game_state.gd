extends Node
## Global game state (autoload): the player's party, inventory, storage, and
## battle orchestration.
##
## Battles run as an overlay that pauses the overworld, so returning drops the
## player back exactly where they were.

## Emitted after a battle closes and the tree is unpaused. result is "win",
## "lose", "run" or "caught"; wild is the creature that was fought.
signal battle_finished(result: String, wild: CreatureInstance)
## Emitted when party/storage contents or party HP change outside battle.
signal party_changed

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const STARTER_PATH: String = "res://data/creatures/duwende.tres"
const ANTING_ANTING: String = "anting-anting"
const MAX_PARTY: int = 6

var party: Array[CreatureInstance] = []
var storage: Array[CreatureInstance] = []  ## the Albularyo's Hut (party overflow)
var inventory: Dictionary = {}
var _in_battle: bool = false


func _ready() -> void:
	new_game()  # sensible default so the world scene also runs on its own


## Reset to a fresh game: the starter creature and a few anting-anting.
func new_game() -> void:
	party.clear()
	storage.clear()
	inventory = {ANTING_ANTING: 10}
	var starter: Creature = load(STARTER_PATH)
	if starter != null:
		party.append(CreatureInstance.create(starter, 5))


func is_in_battle() -> bool:
	return _in_battle


# --- Inventory ---

func item_count(item: String) -> int:
	return inventory.get(item, 0)


func add_item(item: String, amount: int = 1) -> void:
	inventory[item] = item_count(item) + amount


func use_item(item: String) -> bool:
	if item_count(item) <= 0:
		return false
	inventory[item] -= 1
	return true


# --- Party / storage ---

func first_able() -> CreatureInstance:
	for c in party:
		if not c.is_fainted():
			return c
	return null


## Add a bound creature to the party, or to storage if the party is full.
## Returns "party" or "storage".
func capture(creature: CreatureInstance) -> String:
	if party.size() < MAX_PARTY:
		party.append(creature)
		return "party"
	storage.append(creature)
	return "storage"


## Why `creature` can't move to the other side right now ("" if it can). The
## party may never be emptied, and may never grow past MAX_PARTY.
func move_blocked_reason(creature: CreatureInstance) -> String:
	if creature in party:
		if party.size() <= 1:
			return "Your last party creature has to stay with you."
		return ""
	if creature in storage:
		if party.size() >= MAX_PARTY:
			return "Your party is full (%d). Move one to storage first." % MAX_PARTY
		return ""
	return "That creature isn't yours."


## Move a creature between party and storage (whichever side it is on).
## Returns false, changing nothing, when move_blocked_reason() says no.
func move_creature(creature: CreatureInstance) -> bool:
	if move_blocked_reason(creature) != "":
		return false
	if creature in party:
		party.erase(creature)
		storage.append(creature)
	else:
		storage.erase(creature)
		party.append(creature)
	party_changed.emit()
	return true


## Restore every party creature to full HP (the hut's Heal All).
func heal_party() -> void:
	for c in party:
		c.full_heal()
	party_changed.emit()


# --- Save data ---

func to_dict() -> Dictionary:
	return {
		"party": party.map(func(c: CreatureInstance) -> Dictionary: return c.to_dict()),
		"storage": storage.map(func(c: CreatureInstance) -> Dictionary: return c.to_dict()),
		"inventory": inventory.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	party = _creatures_from(d.get("party", []))
	storage = _creatures_from(d.get("storage", []))
	# Overflow from an edited/old save goes to the hut rather than being lost.
	while party.size() > MAX_PARTY:
		storage.push_front(party.pop_back())
	inventory = {}
	var inv: Variant = d.get("inventory", {})
	if inv is Dictionary:
		for key in inv:
			inventory[str(key)] = maxi(0, int(inv[key]))  # JSON numbers load as floats


func _creatures_from(list: Variant) -> Array[CreatureInstance]:
	var out: Array[CreatureInstance] = []
	if not list is Array:
		return out
	for entry in list:
		if entry is Dictionary:
			var c := CreatureInstance.from_dict(entry)
			if c != null:
				out.append(c)
	return out


# --- Battle ---

## Start a battle against `wild`. Returns false if one couldn't start (already
## in battle, or no able party creature). The overworld isn't touched here:
## whoever started the battle listens for battle_finished and reacts to it.
func start_battle(wild: CreatureInstance) -> bool:
	if _in_battle or wild == null:
		return false
	var player_creature := first_able()
	if player_creature == null:
		return false
	_in_battle = true

	var battle := BATTLE_SCENE.instantiate()
	battle.process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while the tree is paused
	get_tree().root.add_child(battle)
	battle.finished.connect(_on_battle_finished.bind(battle, player_creature, wild), CONNECT_ONE_SHOT)
	battle.setup(player_creature, wild)
	get_tree().paused = true
	return true


func _on_battle_finished(result: String, battle: Node, player_creature: CreatureInstance, wild: CreatureInstance) -> void:
	get_tree().paused = false
	if is_instance_valid(battle):
		battle.queue_free()
	# A wiped party recovers on return (placeholder until a proper faint flow).
	if player_creature != null and player_creature.is_fainted():
		for c in party:
			c.full_heal()
	_in_battle = false
	battle_finished.emit(result, wild)
