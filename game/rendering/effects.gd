class_name Effects
## Small particle effects, PSX style: square sprites, few of them, unlit and additive (or plain for
## dust), facing the camera. Each factory returns a CPUParticles3D set up and emitting, to be added
## where it's wanted (its -Z the way it sprays, unless it says otherwise).
##   leak     O2 venting from a breached suit: a thin white jet of puffs
##   sparks   a live cable arcing: hot white-blue points spitting and falling
##   steam    a pipe or a hull venting: grey puffs spreading as they go
##   dust     grit and flakes falling from a ceiling about to give
##   spores   wet flecks and cyan motes, something bursting out of its growth


static func _material(colour: Color, additive := true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = colour
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.disable_receive_shadows = true
	return material


static func _particles(name: String, amount: int, lifetime: float, size: float, colour: Color, additive := true) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = name
	particles.amount = amount
	particles.lifetime = lifetime
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _material(colour, additive)
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.local_coords = false
	particles.direction = Vector3(0, 0, -1)
	particles.layers = Deck.INTERIOR_LAYER
	return particles


## A fade from `colour` at birth to nothing at death.
static func _fade(colour: Color, middle := 0.4) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, colour)
	gradient.set_color(1, Color(colour, 0.0))
	gradient.add_point(middle, Color(colour, colour.a * 0.7))
	return gradient


static func leak() -> CPUParticles3D:
	var p := _particles("Leak", 18, 0.6, 0.05, Color(0.85, 0.92, 1.0, 0.5))
	p.spread = 14.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.6
	p.gravity = Vector3.ZERO
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	p.color_ramp = _fade(Color(0.85, 0.92, 1.0, 0.5))
	return p


static func sparks() -> CPUParticles3D:
	var p := _particles("Sparks", 24, 0.45, 0.025, Color(0.75, 0.9, 1.0, 1.0))
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -9.8, 0)
	p.explosiveness = 0.6
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.color_ramp = _fade(Color(0.85, 0.95, 1.0, 1.0), 0.2)
	return p


static func steam() -> CPUParticles3D:
	var p := _particles("Steam", 32, 1.4, 0.16, Color(0.7, 0.72, 0.74, 0.35), false)
	p.spread = 22.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3.ZERO
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 2.4
	p.color_ramp = _fade(Color(0.7, 0.72, 0.74, 0.35), 0.5)
	return p


static func dust() -> CPUParticles3D:
	var p := _particles("Dust", 40, 1.2, 0.035, Color(0.42, 0.4, 0.37, 0.8), false)
	p.direction = Vector3(0, -1, 0)
	p.spread = 12.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.2, 0.05, 1.2)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.color_ramp = _fade(Color(0.42, 0.4, 0.37, 0.8), 0.7)
	return p


static func spores() -> CPUParticles3D:
	var p := _particles("Spores", 60, 1.6, 0.04, Color(0.5, 0.95, 1.0, 0.9))
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -3.0, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.explosiveness = 0.85
	p.one_shot = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 2.0
	p.color_ramp = _fade(Color(0.5, 0.95, 1.0, 0.9), 0.5)
	return p
