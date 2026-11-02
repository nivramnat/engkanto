extends Node
## Configures a referenced Terrain3D node at runtime (kept separate so we don't
## override the GDExtension's own _ready): gives it a white base texture so the
## baked biome colour map shows, enables dynamic streaming collision + the
## ocean, and makes it follow the player.

const DATA_DIR: String = "res://world/terrain_data"

@export var terrain_path: NodePath


func _ready() -> void:
	call_deferred("_configure")


func _configure() -> void:
	var t: Terrain3D = get_node_or_null(terrain_path) as Terrain3D
	if t == null:
		return

	if t.get_data_directory() == "":
		t.set_data_directory(DATA_DIR)

	if t.get_material() == null:
		t.set_material(Terrain3DMaterial.new())

	var assets: Terrain3DAssets = t.get_assets()
	if assets == null:
		assets = Terrain3DAssets.new()
		t.set_assets(assets)
	if assets.get_texture_count() == 0:
		var tex := Terrain3DTextureAsset.new()
		tex.id = 0
		tex.name = "ground"
		tex.albedo_color = Color.WHITE  # the biome colour map tints this
		assets.set_texture_asset(0, tex)

	t.set_collision_mode(Terrain3DCollision.DYNAMIC_GAME)
	t.set_ocean_enabled(true)

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		t.set_clipmap_target(player)
		t.set_collision_target(player)
