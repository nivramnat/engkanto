extends Button
## One creature tile in the Albularyo's Hut screen (party or storage). Shows
## name, level, HP and an element-coloured stripe; empty when creature is null.
## Taps arrive through the Button's `pressed` signal. The hut screen hooks up
## drag and drop with set_drag_forwarding, so this script stays display-only.

var creature: CreatureInstance

var _is_selected: bool = false
var _selected_style: StyleBoxFlat

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel
@onready var _hp_bar: ProgressBar = %HPBar


func _ready() -> void:
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.3, 0.26, 0.12, 1)
	_selected_style.set_border_width_all(3)
	_selected_style.border_color = Color(0.95, 0.82, 0.4, 1)
	_selected_style.set_corner_radius_all(8)
	_show()


## Fill the slot (call before or after adding to the tree).
func setup(inst: CreatureInstance, selected: bool = false) -> void:
	creature = inst
	_is_selected = selected
	if is_node_ready():
		_show()


func is_selected() -> bool:
	return _is_selected


func _show() -> void:
	if _is_selected:
		for s in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(s, _selected_style)
	if creature == null:
		_swatch.color = Color(0.3, 0.3, 0.3, 0.5)
		_name_label.text = "Empty"
		_name_label.modulate = Color(1, 1, 1, 0.45)
		_info_label.text = ""
		_hp_bar.visible = false
		return
	_swatch.color = GameTypes.element_color(creature.data.element_type)
	_name_label.text = creature.display_name()
	_name_label.modulate = Color.WHITE
	_info_label.text = "Lv %d   HP %d/%d" % [creature.level, creature.current_hp, creature.max_hp()]
	_hp_bar.visible = true
	_hp_bar.max_value = creature.max_hp()
	_hp_bar.value = creature.current_hp
