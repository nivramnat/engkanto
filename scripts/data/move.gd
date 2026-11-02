class_name Move
extends Resource
## A battle move a creature can use. Data only — battle resolution lives in
## the battle system (Key System 5).

@export var name: String = ""
@export var element_type: GameTypes.Element = GameTypes.Element.NEUTRAL
@export var power: int = 0
@export_range(0, 100) var accuracy: int = 100
@export_multiline var description: String = ""
