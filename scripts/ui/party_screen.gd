extends Control
## Simple party viewer. Lists each party creature's name, level, element, and
## HP, plus a count of any creatures resting in the Albularyo's Hut (storage).

signal closed

@onready var _list: VBoxContainer = %List
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_close_button.pressed.connect(close)
	hide()


func open() -> void:
	_populate()
	show()


func close() -> void:
	hide()
	closed.emit()


func _populate() -> void:
	for child in _list.get_children():
		child.queue_free()

	for inst in GameState.party:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 28)
		row.text = "%s    Lv %d    %s    HP %d/%d" % [
			inst.display_name(), inst.level,
			GameTypes.element_name(inst.data.element_type),
			inst.current_hp, inst.max_hp()]
		_list.add_child(row)

	if GameState.party.is_empty():
		var empty := Label.new()
		empty.text = "No creatures yet."
		_list.add_child(empty)

	if GameState.storage.size() > 0:
		var stored := Label.new()
		stored.add_theme_font_size_override("font_size", 22)
		stored.text = "Albularyo's Hut: %d resting" % GameState.storage.size()
		_list.add_child(stored)
