extends Control
## Albularyo's Hut screen: party (6 slots) on the left, a creature's details in
## the middle, and storage as a scrollable grid on the right.
##
## Tap/click a creature to see its details. Move it with the Move button
## (touch and mouse) or by dragging it to the other panel (mouse only, since a
## touch drag scrolls the storage grid). Party rules live in GameState: the
## last party creature can't be stored and the party holds at most 6.
## Heal All restores the party. Pauses the tree while open and autosaves when
## it closes.

signal closed

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/creature_slot.tscn")
const DRAG_KEY: String = "hut_creature"
const SIDE_PARTY: String = "party"
const SIDE_STORAGE: String = "storage"

var _selected: CreatureInstance
var _touch_input: bool = false  ## last pointer input came from a touchscreen

@onready var _status: Label = %Status
@onready var _heal_button: Button = %HealButton
@onready var _close_button: Button = %CloseButton
@onready var _party_box: Control = %PartyBox
@onready var _party_header: Label = %PartyHeader
@onready var _party_list: VBoxContainer = %PartyList
@onready var _storage_box: Control = %StorageBox
@onready var _storage_header: Label = %StorageHeader
@onready var _storage_grid: GridContainer = %StorageGrid
@onready var _storage_empty: Label = %StorageEmpty
@onready var _detail_name: Label = %DetailName
@onready var _info_row: Control = %InfoRow
@onready var _level: Label = %Level
@onready var _element_badge: PanelContainer = %ElementBadge
@onready var _element: Label = %Element
@onready var _hp_label: Label = %HPLabel
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _origin: Label = %Origin
@onready var _lore: Label = %Lore
@onready var _move_hint: Label = %MoveHint
@onready var _move_button: Button = %MoveButton


func _ready() -> void:
	_heal_button.pressed.connect(_on_heal_pressed)
	_close_button.pressed.connect(close)
	_move_button.pressed.connect(_on_move_pressed)
	# Dropping anywhere on a panel moves the creature to that side.
	_party_box.set_drag_forwarding(Callable(), _can_drop.bind(SIDE_PARTY), _drop.bind(SIDE_PARTY))
	_storage_box.set_drag_forwarding(Callable(), _can_drop.bind(SIDE_STORAGE), _drop.bind(SIDE_STORAGE))
	hide()


func open() -> void:
	if visible or GameState.is_in_battle():
		return
	_selected = GameState.party[0] if not GameState.party.is_empty() else null
	_status.text = ""
	_refresh()
	show()
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	if SaveManager.autosave_enabled:
		SaveManager.save_game()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input = true
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		_touch_input = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


# --- Actions (also called by tests) ---

func select(creature: CreatureInstance) -> void:
	_selected = creature
	_refresh()


## Move a creature to the other side, or explain why it can't go.
func try_move(creature: CreatureInstance) -> bool:
	var reason: String = GameState.move_blocked_reason(creature)
	if reason != "":
		_status.text = reason
		return false
	var to_storage: bool = creature in GameState.party
	GameState.move_creature(creature)
	_status.text = "%s moved to %s." % [creature.display_name(), "storage" if to_storage else "your party"]
	_selected = creature
	_refresh()
	return true


func _on_move_pressed() -> void:
	if _selected != null:
		try_move(_selected)


func _on_heal_pressed() -> void:
	GameState.heal_party()
	_status.text = "The albularyo tends to your party. Everyone is at full HP."
	_refresh()


# --- Drag and drop (mouse) ---

func _get_drag(_at: Vector2, slot: Control) -> Variant:
	var creature: CreatureInstance = slot.creature
	if _touch_input or creature == null:
		return null
	var preview := Label.new()
	preview.text = creature.display_name()
	preview.add_theme_font_size_override("font_size", 26)
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 6)
	slot.set_drag_preview(preview)
	# Don't select (rebuild the slots) here: freeing the source cancels the drag.
	return {DRAG_KEY: creature}


## Accept any cross-side drop, even a blocked one, so try_move can explain why.
func _can_drop(_at: Vector2, data: Variant, side: String) -> bool:
	if not (data is Dictionary and data.has(DRAG_KEY)):
		return false
	var in_party: bool = data[DRAG_KEY] in GameState.party
	return in_party != (side == SIDE_PARTY)


func _drop(_at: Vector2, data: Variant, _side: String) -> void:
	try_move(data[DRAG_KEY])


# --- Display ---

func _refresh() -> void:
	if _selected != null and not (_selected in GameState.party or _selected in GameState.storage):
		_selected = null
	_party_header.text = "Party  %d/%d" % [GameState.party.size(), GameState.MAX_PARTY]
	_storage_header.text = "Storage  %d" % GameState.storage.size()

	_clear(_party_list)
	for i in GameState.MAX_PARTY:
		var c: CreatureInstance = GameState.party[i] if i < GameState.party.size() else null
		_party_list.add_child(_make_slot(c, SIDE_PARTY))
	_clear(_storage_grid)
	for c in GameState.storage:
		_storage_grid.add_child(_make_slot(c, SIDE_STORAGE))
	_storage_empty.visible = GameState.storage.is_empty()
	_show_details()


func _make_slot(creature: CreatureInstance, side: String) -> Control:
	var slot: Button = SLOT_SCENE.instantiate()
	slot.setup(creature, creature != null and creature == _selected)
	slot.set_drag_forwarding(_get_drag.bind(slot), _can_drop.bind(side), _drop.bind(side))
	slot.pressed.connect(func() -> void:
		if slot.creature != null:
			select(slot.creature))
	return slot


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _show_details() -> void:
	var c: CreatureInstance = _selected
	var has: bool = c != null
	for n: Control in [_info_row, _hp_label, _hp_bar, _origin, _move_button, _move_hint]:
		n.visible = has
	if not has:
		_detail_name.text = "Select a creature"
		_lore.text = "Tap or click a creature to see its details."
		return
	_detail_name.text = c.display_name()
	_level.text = "Lv %d" % c.level
	_element.text = GameTypes.element_name(c.data.element_type)
	var badge: StyleBoxFlat = _element_badge.get_theme_stylebox("panel").duplicate()
	badge.bg_color = GameTypes.element_color(c.data.element_type)
	_element_badge.add_theme_stylebox_override("panel", badge)
	_element.add_theme_color_override("font_color",
		Color.BLACK if badge.bg_color.get_luminance() > 0.55 else Color.WHITE)
	_hp_label.text = "HP %d / %d" % [c.current_hp, c.max_hp()]
	_hp_bar.max_value = c.max_hp()
	_hp_bar.value = c.current_hp
	_origin.text = c.data.folklore_origin
	_origin.visible = c.data.folklore_origin != ""
	_lore.text = c.data.lore_text if c.data.lore_text != "" else "Little is known about this engkanto."

	var in_party: bool = c in GameState.party
	_move_button.text = "Move to Storage  >" if in_party else "<  Move to Party"
	var reason: String = GameState.move_blocked_reason(c)
	_move_button.disabled = reason != ""
	_move_hint.text = reason
	_move_hint.visible = reason != ""
