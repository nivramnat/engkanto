class_name BiomeMap
extends RefCounted
## The world's biome layout and per-biome look. Pure, deterministic functions
## so the terrain generator, scatter streamer, fog/light controller, and
## spawners all agree on "what biome is here" and blend the same way.
##
## Biomes are soft fields (distance-to-anchor softmax with a wavy distortion),
## so weights blend smoothly everywhere — there are no hard borders.

enum Biome { LOWLANDS, FOREST, MYSTIC, COAST }
const COUNT: int = 4
const WORLD_SIZE: float = 2048.0  ## ~2 km square, world coords [0, WORLD_SIZE]

## Anchor points (world XZ): south=low Z, north=high Z, east=high X, west=low X.
const CENTERS: Array[Vector2] = [
	Vector2(1024.0, 470.0),    # LOWLANDS  (south)
	Vector2(1024.0, 1580.0),   # FOREST    (north)
	Vector2(1600.0, 1024.0),   # MYSTIC    (east)
	Vector2(440.0, 1024.0),    # COAST     (west)
]
const BLEND: float = 360.0  ## softness of biome transitions (larger = wider blend)

const NAMES: Array[String] = ["Baryo Lowlands", "Bundok Forest", "Mystic Woods", "Sandy Coast"]

## Terrain height shaping per biome (metres). Coast dips below sea level (0).
const BASE_HEIGHT: Array[float] = [3.0, 24.0, 11.0, -7.0]
const HEIGHT_AMP: Array[float] = [2.5, 16.0, 8.0, 2.0]

const GROUND_COLOR: Array[Color] = [
	Color(0.45, 0.52, 0.27),   # rice/dirt green
	Color(0.14, 0.26, 0.15),   # dark forest green
	Color(0.30, 0.26, 0.38),   # purple-green
	Color(0.80, 0.74, 0.55),   # sand
]
const FOG_COLOR: Array[Color] = [
	Color(0.80, 0.85, 0.78),
	Color(0.22, 0.30, 0.24),
	Color(0.35, 0.28, 0.45),
	Color(0.75, 0.82, 0.88),
]
const LIGHT_COLOR: Array[Color] = [
	Color(1.00, 0.97, 0.88),
	Color(0.80, 0.90, 0.80),
	Color(0.78, 0.70, 0.92),
	Color(0.95, 0.97, 1.00),
]
const FOG_DENSITY: Array[float] = [0.004, 0.016, 0.022, 0.006]
const LIGHT_ENERGY: Array[float] = [1.0, 0.7, 0.65, 1.05]


## Normalised blend weights for each biome at a world XZ position.
static func weights(x: float, z: float) -> PackedFloat32Array:
	# Wavy distortion so biome borders meander instead of forming circles/lines.
	var px: float = x + sin(z * 0.011) * 130.0 + sin(z * 0.031) * 40.0
	var pz: float = z + cos(x * 0.011) * 130.0 + cos(x * 0.031) * 40.0
	var w := PackedFloat32Array()
	w.resize(COUNT)
	var total: float = 0.0
	for i in COUNT:
		var d2: float = Vector2(px, pz).distance_squared_to(CENTERS[i])
		var v: float = exp(-d2 / (2.0 * BLEND * BLEND))
		w[i] = v
		total += v
	if total <= 0.0:
		w[Biome.LOWLANDS] = 1.0
		return w
	for i in COUNT:
		w[i] /= total
	return w


static func dominant(x: float, z: float) -> int:
	var w := weights(x, z)
	var best: int = 0
	for i in COUNT:
		if w[i] > w[best]:
			best = i
	return best


static func blended_color(table: Array[Color], w: PackedFloat32Array) -> Color:
	var c := Color(0, 0, 0, 1)
	for i in COUNT:
		c += table[i] * w[i]
	c.a = 1.0
	return c


static func blended_float(table: Array[float], w: PackedFloat32Array) -> float:
	var v: float = 0.0
	for i in COUNT:
		v += table[i] * w[i]
	return v
