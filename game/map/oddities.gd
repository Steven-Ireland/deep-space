class_name Oddities
## What the long-range scan identifies in a system (GDD §6): the oddity's name and what it is,
## from the node's type and its system's seed. Names only for now; the encounters themselves are
## generated derelicts (DerelictLayout) and placeholders.

## Short enough that a hull and a name fit across the round scanner screen (24 characters).
const HULLS := ["ORE HAULER", "SURVEY SHIP", "COLONY BARGE", "SALVAGE TUG", "SCIENCE RIG", "FUEL TANKER",
		"MINING SHIP", "CARGO LIFTER"]
const NAMES := ["KESTREL", "ORPHEUS", "MERIDIAN", "HALCYON", "VESPER", "TALOS", "ARGENT", "CALLISTO", "PELICAN",
		"SOLACE", "WAYFARER", "OBERON", "CASSIA", "TERN", "PROVIDENCE", "LODESTAR", "MARGRAVE", "ISOLDE", "HERON",
		"CORMORANT", "ANSELM", "TIDEWATER", "KITTIWAKE", "HELIOS"]


## [name, what it is] for a `type` node whose system has seed `seed`, its planets in `system`.
static func of(type: StringName, seed: int, system: StarSystem) -> Array[String]:
	var roll := RandomNumberGenerator.new()
	roll.seed = hash(["oddity", seed])
	var name: String = NAMES[roll.randi_range(0, NAMES.size() - 1)]
	var code := "%s-%d" % ["ABCDEFGHJKLMNPRSTVX"[roll.randi_range(0, 18)], roll.randi_range(10, 99)]
	var out: Array[String] = []
	match type:
		&"derelict":
			out.assign(["%s %s" % [HULLS[roll.randi_range(0, HULLS.size() - 1)], name], "DERELICT, ADRIFT"])
		&"colony":
			out.assign(["OUTPOST %s" % name, "MINING COLONY ON A MOONLET"])
		&"relay":
			out.assign(["RELAY %s" % code, "SATELLITE IN HIGH ORBIT"])
		&"signal":
			out.assign(["UNIDENTIFIED SIGNAL", "SOURCE UNKNOWN"])
		&"anomaly":
			out.assign(["ANOMALY %s" % code, "UNRESOLVED READINGS"])
		&"gas_giant":
			var giant: String = system.planets[0].name if system != null and not system.planets.is_empty() else "PRIMARY"
			out.assign([giant.to_upper(), "GAS GIANT: FUEL TO SKIM"])
		&"depot":
			out.assign(["DEPOT %s" % code, "AUTOMATED CACHE"])
		&"boss":
			out.assign(["GUARDIAN", "SECTOR EXIT, GUARDED"])
		_:
			out.assign(["NO CONTACTS", "DEPARTURE POINT"])
	return out
