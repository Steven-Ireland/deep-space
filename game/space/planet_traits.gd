class_name PlanetTraits
## A planet's survey readout (GDD §7): atmosphere, temperature, gravity, water and biosignatures,
## each a short line for the Survey Console, and how much Survey Data scanning it yields. Made
## from the planet's kind and size, its star and distance, and a seed of its own, so the look of
## the system never depends on it.

## Each kind: atmospheres to choose from, surface temperature range (K), surface gravity per km
## of radius (g), and what water it can have.
const KINDS := {
	"gas giant": {"air": ["H2-HE, CRUSHING", "H2-HE-NH3, CRUSHING"], "kelvin": [90, 170], "g": [1.6, 3.0],
			"water": ["NONE", "TRACE VAPOUR"]},
	"ice giant": {"air": ["H2-HE-CH4, CRUSHING", "H2-CH4, DENSE"], "kelvin": [50, 90], "g": [0.9, 1.4],
			"water": ["ICE MANTLE", "DEEP ICE MANTLE"]},
	"rocky": {"air": ["NONE", "TRACE CO2", "THIN CO2", "THIN N2-CO2", "DENSE CO2"], "kelvin": [160, 720], "g": [0.3, 1.3],
			"water": ["NONE", "NONE", "TRACE", "POLAR ICE"]},
	"ice": {"air": ["NONE", "TRACE N2", "THIN N2-CH4"], "kelvin": [40, 120], "g": [0.1, 0.5],
			"water": ["SURFACE ICE", "SUBSURFACE OCEAN"]},
	"lava": {"air": ["THIN SO2", "DENSE SO2-CO2"], "kelvin": [900, 1500], "g": [0.4, 1.1], "water": ["NONE"]},
	"ocean": {"air": ["THIN N2-O2", "N2-O2", "DENSE N2-CO2"], "kelvin": [255, 315], "g": [0.7, 1.4],
			"water": ["GLOBAL OCEAN", "OCEANS, ISLANDS"]},
}


## The readout for a `kind` planet `radius` across (scene units), `distance` out from a
## `star_type` star: {"atmosphere", "temperature", "gravity", "water", "biosigns", "data"}.
static func of(kind: String, radius: float, distance: float, star_type: String, seed: int) -> Dictionary:
	var roll := RandomNumberGenerator.new()
	roll.seed = seed
	var spec: Dictionary = KINDS.get(kind, KINDS["rocky"])
	var air: String = spec.air[roll.randi_range(0, spec.air.size() - 1)]
	var water: String = spec.water[roll.randi_range(0, spec.water.size() - 1)]
	var kelvin := roll.randf_range(spec.kelvin[0], spec.kelvin[1])
	if star_type in ["red dwarf", "white dwarf"]:
		kelvin *= 0.85
	elif star_type == "blue giant":
		kelvin *= 1.2
	kelvin *= clampf(1.4 - distance / 6000.0, 0.8, 1.3)
	var gravity := roll.randf_range(spec.g[0], spec.g[1])
	# Biosignatures want water and air that could hold life, and luck.
	var life := 0.0
	if kind == "ocean":
		life = 0.5 if air.contains("O2") else 0.3
	elif water == "SUBSURFACE OCEAN":
		life = 0.25
	elif water == "POLAR ICE" and air != "NONE":
		life = 0.08
	var signs := "NONE"
	var odds := roll.randf()
	if odds < life * 0.3:
		signs = "DETECTED"
	elif odds < life:
		signs = "AMBIGUOUS"
	var data := 1
	if water in ["SUBSURFACE OCEAN", "GLOBAL OCEAN", "OCEANS, ISLANDS"]:
		data += 1
	data += {"NONE": 0, "AMBIGUOUS": 2, "DETECTED": 4}[signs]
	return {"atmosphere": air, "temperature": "%d K" % roundi(kelvin), "gravity": "%.2f G" % gravity,
			"water": water, "biosigns": signs, "data": data}
