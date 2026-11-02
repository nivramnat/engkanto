class_name Creature
extends Resource
## A catchable engkanto. Data only — spawning, battle, and capture logic read
## from this resource but live in their own systems.

@export var name: String = ""
@export var folklore_origin: String = ""
@export var element_type: GameTypes.Element = GameTypes.Element.NEUTRAL

@export_group("Base Stats")
@export var hp: int = 1
@export var attack: int = 1
@export var defense: int = 1
@export var speed: int = 1

@export_group("Gameplay")
@export var moves: Array[Move] = []
@export_range(1, 255) var catch_rate: int = 100  ## higher = easier to bind
@export var spawn_time: GameTypes.SpawnTime = GameTypes.SpawnTime.BOTH

@export_group("Lore")
@export_multiline var lore_text: String = ""
