extends Node
## Global game state (autoload): the player's party and battle orchestration.
##
## Battles run as an overlay that pauses the overworld, so returning drops the
## player back exactly where they were.

var party: Array[CreatureInstance] = []
var _in_battle: bool = false

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const STARTER_PATH: String = "res://data/creatures/duwende.tres"


func _ready() -> void:
	var starter: Creature = load(STARTER_PATH)
	if starter != null:
		party.append(CreatureInstance.create(starter, 5))


## First party member that can still fight, or null if the party is wiped.
func first_able() -> CreatureInstance:
	for c in party:
		if not c.is_fainted():
			return c
	return null


func start_battle(wild: CreatureInstance, wild_node: Node = null) -> void:
	if _in_battle:
		return
	var player_creature := first_able()
	if player_creature == null:
		return
	_in_battle = true

	# Remove the wild creature from the overworld so it can't retrigger.
	if wild_node != null and is_instance_valid(wild_node):
		wild_node.queue_free()

	var battle := BATTLE_SCENE.instantiate()
	battle.process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while the tree is paused
	get_tree().root.add_child(battle)
	battle.finished.connect(_on_battle_finished.bind(battle, player_creature))
	battle.setup(player_creature, wild)
	get_tree().paused = true


func _on_battle_finished(_result: String, battle: Node, player_creature: CreatureInstance) -> void:
	get_tree().paused = false
	if is_instance_valid(battle):
		battle.queue_free()
	# A wiped party recovers on return (placeholder until a proper faint flow).
	if player_creature != null and player_creature.is_fainted():
		for c in party:
			c.full_heal()
	_in_battle = false
