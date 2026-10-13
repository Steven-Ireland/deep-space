class_name StarSystem
extends Node3D
## A star system as seen from the LANTERN (GDD §6, §14): its star (a sun light and a glaring disc
## in the sky), a nebula-tinted starfield, and a few planets hanging in the dark, all made from a
## seed so every peer builds the same system (TECH §6). The station stays at the origin; the system
## is built around it and swapped on each jump.

const SKY := preload("res://game/space/space_sky.gdshader")
const PLANET := preload("res://game/space/planet.gdshader")

const STARS := {
	"yellow dwarf": {"weight": 3, "colour": Color(1.0, 0.92, 0.78), "energy": 1.5, "size": 0.014},
	"orange dwarf": {"weight": 3, "colour": Color(1.0, 0.74, 0.5), "energy": 1.3, "size": 0.016},
	"red dwarf": {"weight": 3, "colour": Color(1.0, 0.5, 0.34), "energy": 1.0, "size": 0.022},
	"blue giant": {"weight": 1, "colour": Color(0.74, 0.84, 1.0), "energy": 2.0, "size": 0.02},
	"white dwarf": {"weight": 1, "colour": Color(0.94, 0.96, 1.0), "energy": 1.2, "size": 0.007},
}

## Planet kinds: weight, banding, three surface colours (dark to light), atmosphere, radius range.
const PLANETS := {
	"gas giant": {"weight": 3, "banded": 1.0, "bands": [5.0, 9.0], "radius": [180.0, 320.0], "atmosphere": 0.5,
			"palettes": [[Color("5a3b26"), Color("b07a4a"), Color("ead2a6")], [Color("3a2f45"), Color("8a6a7a"), Color("d8c0b8")],
				[Color("4a3a1e"), Color("a08a50"), Color("e8e0b0")]], "air": [Color("ffd9a0"), Color("e0b0c0")]},
	"ice giant": {"weight": 2, "banded": 0.7, "bands": [3.0, 5.0], "radius": [120.0, 200.0], "atmosphere": 0.8,
			"palettes": [[Color("1e3a5a"), Color("4a86b0"), Color("a8d8e8")], [Color("1a4a4a"), Color("3a9a9a"), Color("b0e8e0")]],
			"air": [Color("a0d0ff"), Color("90f0e0")]},
	"rocky": {"weight": 3, "banded": 0.0, "bands": [1.0, 1.0], "radius": [30.0, 80.0], "atmosphere": 0.15,
			"palettes": [[Color("2a2622"), Color("6a5e52"), Color("a89a88")], [Color("3a2418"), Color("8a5a3a"), Color("c09a7a")]],
			"air": [Color("c0b0a0"), Color("d0c0b0")]},
	"ice": {"weight": 2, "banded": 0.0, "bands": [1.0, 1.0], "radius": [25.0, 70.0], "atmosphere": 0.3,
			"palettes": [[Color("4a5a6a"), Color("9ab0c0"), Color("eef4f8")]], "air": [Color("c8e8ff"), Color("e0f0ff")]},
	"lava": {"weight": 1, "banded": 0.0, "bands": [1.0, 1.0], "radius": [30.0, 60.0], "atmosphere": 0.35,
			"palettes": [[Color("120806"), Color("3a1a10"), Color("e05a18")]], "air": [Color("ff7a30"), Color("ff9a50")]},
	"ocean": {"weight": 1, "banded": 0.25, "bands": [2.0, 4.0], "radius": [50.0, 100.0], "atmosphere": 0.9,
			"palettes": [[Color("0a2a4a"), Color("1e5a7a"), Color("d8e8f0")], [Color("0a3a3a"), Color("2a6a4a"), Color("e0ecea")]],
			"air": [Color("80c0ff"), Color("90e0ff")]},
}

const NEBULAE := [
	[Color("3a1048"), Color("0c2a4a")], [Color("4a1a14"), Color("2a0c30")], [Color("0a3038"), Color("1a1440")],
	[Color("402a10"), Color("10203a")], [Color("123a1a"), Color("0a1a30")], [Color("2a0a1a"), Color("0a0a20")],
]

## The WorldEnvironment whose sky this system paints.
@export var environment: WorldEnvironment
@export var seed := 1

var star_type := ""
## The system's catalogue name, e.g. "GJ-0042"; planets are this plus a letter (b, c, ...).
var designation := ""
## Each planet: {"kind", "radius", "distance", "direction", "node"}.
var planets: Array[Dictionary] = []
var sun: DirectionalLight3D


func _ready() -> void:
	add_to_group(&"star_system")
	generate(int(Args.value("--system-seed", str(seed))))


## Rebuilds the system from `new_seed`.
func generate(new_seed: int) -> void:
	seed = new_seed
	for child in get_children():
		child.queue_free()
	planets.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["system", new_seed])

	designation = "%s-%04d" % [["KX", "HD", "GJ", "TY", "LH", "VX", "RK"][rng.randi_range(0, 6)], rng.randi_range(1, 9999)]
	star_type = _pick(rng, STARS)
	var star: Dictionary = STARS[star_type]
	# The primary hangs ahead of the bridge viewport (fore is -Z), where the crew first sees it; the
	# star lights it from the side, for a strong terminator.
	var yaw := deg_to_rad(rng.randf_range(-28.0, 28.0))
	var pitch := deg_to_rad(rng.randf_range(-8.0, 12.0))
	var ahead := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	var sun_direction := _direction(rng, -15.0, 35.0)
	for attempt in 16:
		var facing := sun_direction.dot(ahead)
		if facing > -0.2 and facing < 0.6:
			break
		sun_direction = _direction(rng, -15.0, 35.0)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = star.colour
	sun.light_energy = star.energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 0.0
	sun.light_cull_mask = ~Deck.INTERIOR_LAYER # interiors are lit by their own practicals
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_direction, Vector3.UP if absf(sun_direction.y) < 0.99 else Vector3.RIGHT)

	var nebula: Array = NEBULAE[rng.randi_range(0, NEBULAE.size() - 1)]
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY
	sky_material.set_shader_parameter("seed", rng.randf_range(0.0, 100.0))
	sky_material.set_shader_parameter("nebula_a", nebula[0])
	sky_material.set_shader_parameter("nebula_b", nebula[1])
	sky_material.set_shader_parameter("nebula_strength", rng.randf_range(0.6, 1.2))
	sky_material.set_shader_parameter("star_density", rng.randf_range(0.04, 0.07))
	sky_material.set_shader_parameter("sun_size", star.size)
	if environment != null:
		var sky := Sky.new()
		sky.sky_material = sky_material
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		environment.environment.background_mode = Environment.BG_SKY
		environment.environment.sky = sky

	var count := rng.randi_range(1, 4)
	for i in count:
		_add_planet(rng, sun_direction, ahead if i == 0 else Vector3.ZERO)


## Adds a planet; `ahead`, if not zero, is the primary's direction (it's drawn large there).
func _add_planet(rng: RandomNumberGenerator, sun_direction: Vector3, ahead: Vector3) -> void:
	var kind := _pick(rng, PLANETS)
	var spec: Dictionary = PLANETS[kind]
	var radius := rng.randf_range(spec.radius[0], spec.radius[1])
	var distance := rng.randf_range(900.0, 2600.0) * (1.0 + radius / 400.0)
	# Somewhere off the star, so planets don't hide in its glare.
	var direction := _direction(rng, -35.0, 45.0)
	if ahead != Vector3.ZERO:
		direction = ahead
		distance = radius / tan(rng.randf_range(0.09, 0.26))
	else:
		for attempt in 8:
			if direction.dot(sun_direction) < 0.85:
				break
			direction = _direction(rng, -35.0, 45.0)

	var palette: Array = spec.palettes[rng.randi_range(0, spec.palettes.size() - 1)]
	var material := ShaderMaterial.new()
	material.shader = PLANET
	material.set_shader_parameter("colour_a", palette[0])
	material.set_shader_parameter("colour_b", palette[1])
	material.set_shader_parameter("colour_c", palette[2])
	material.set_shader_parameter("banded", spec.banded)
	material.set_shader_parameter("bands", rng.randf_range(spec.bands[0], spec.bands[1]))
	material.set_shader_parameter("turbulence", rng.randf_range(0.2, 0.8))
	material.set_shader_parameter("detail", rng.randf_range(2.0, 4.5))
	material.set_shader_parameter("seed", rng.randf_range(0.0, 100.0))
	var air: Array = spec.air
	material.set_shader_parameter("atmosphere", air[rng.randi_range(0, air.size() - 1)])
	material.set_shader_parameter("atmosphere_strength", spec.atmosphere)

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	mesh.material = material
	var planet := MeshInstance3D.new()
	planet.name = "Planet%d" % planets.size()
	planet.mesh = mesh
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.position = direction * distance
	planet.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))
	add_child(planet)
	var letter := "bcdefg"[planets.size()]
	planets.append({"kind": kind, "radius": radius, "distance": distance, "direction": direction, "node": planet,
			"name": "%s %s" % [designation, letter]})


## A random unit direction between two elevations (degrees) at any azimuth.
static func _direction(rng: RandomNumberGenerator, min_elevation: float, max_elevation: float) -> Vector3:
	var azimuth := rng.randf_range(0.0, TAU)
	var elevation := deg_to_rad(rng.randf_range(min_elevation, max_elevation))
	return Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))


static func _pick(rng: RandomNumberGenerator, table: Dictionary) -> String:
	var total := 0
	for key in table:
		total += table[key].weight
	var roll := rng.randi_range(1, total)
	for key in table:
		roll -= table[key].weight
		if roll <= 0:
			return key
	return table.keys()[0]
