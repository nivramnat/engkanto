extends SceneTree
## One-time tool: procedurally generates the 2 km terrain (heightmap + blended
## biome colour map) with Terrain3D and saves it to res://world/terrain_data/.
## Run headless to (re)generate:
##   godot_console --headless --script res://scripts/world/generate_world.gd
## The runtime scene just loads the saved data, so startup stays fast.

const DATA_DIR: String = "res://world/terrain_data"
const REGION_SIZE: int = 1024
const SPACING: float = 2.0  # metres per vertex -> 1024 * 2 = 2048 m world

var _terrain: Terrain3D
var _frames: int = 0


func _initialize() -> void:
	_terrain = Terrain3D.new()
	_terrain.change_region_size(REGION_SIZE)
	_terrain.set_vertex_spacing(SPACING)
	_terrain.set_save_16_bit(false)
	root.add_child(_terrain)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 2:
		return  # let the Terrain3D node initialise

	print("Generating %dx%d heightmap (world %d m)..." % [REGION_SIZE, REGION_SIZE, int(REGION_SIZE * SPACING)])
	var height_img := Image.create(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF)
	var color_img := Image.create(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RGBA8)

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0038
	noise.fractal_octaves = 4

	for pz in REGION_SIZE:
		var z: float = pz * SPACING
		for px in REGION_SIZE:
			var x: float = px * SPACING
			var w := BiomeMap.weights(x, z)
			var base: float = BiomeMap.blended_float(BiomeMap.BASE_HEIGHT, w)
			var amp: float = BiomeMap.blended_float(BiomeMap.HEIGHT_AMP, w)
			var n: float = noise.get_noise_2d(x, z)          # -1..1
			var h: float = base + n * amp + absf(n) * amp * 0.4  # ridged lift for hills
			height_img.set_pixel(px, pz, Color(h, 0.0, 0.0, 1.0))
			color_img.set_pixel(px, pz, BiomeMap.blended_color(BiomeMap.GROUND_COLOR, w))
		if pz % 128 == 0:
			print("  row %d / %d" % [pz, REGION_SIZE])

	print("Importing into Terrain3D...")
	# Import into a fresh in-memory terrain (don't set_data_directory first, or it
	# loads any existing data and import_images conflicts with it). Clear old files.
	_clear_dir(DATA_DIR)
	var data := _terrain.get_data()
	data.import_images([height_img, null, color_img], Vector3.ZERO, 0.0, 1.0)
	data.calc_height_range(true)
	print("regions: %d  height range: %s" % [data.get_region_count(), str(data.get_height_range())])

	data.save_directory(DATA_DIR)
	print("Saved to %s" % DATA_DIR)

	# Sanity: sample a point in each biome.
	for i in BiomeMap.COUNT:
		var c: Vector2 = BiomeMap.CENTERS[i]
		print("  %s center height = %.1f" % [BiomeMap.NAMES[i], data.get_height(Vector3(c.x, 0.0, c.y))])

	quit()


func _clear_dir(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs)
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".res"):
			d.remove(f)
