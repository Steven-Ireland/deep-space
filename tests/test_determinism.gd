extends SceneTree
## Generation determinism (TECH §6, §8): the same seed gives the same hash, for the sector chart,
## the star system (its planets and their survey traits) and the derived seeds; different seeds
## give different ones.
##   tools/godot.sh --headless -s tests/test_determinism.gd

var failures := 0


func _initialize() -> void:
	_check(Seeds.of(42, "sector1/row3/node2") == Seeds.of(42, "sector1/row3/node2"), "Seeds.of differs for the same label")
	_check(Seeds.of(42, "sector1/row3/node2") != Seeds.of(42, "sector1/row3/node1"), "Seeds.of ignores the label")
	_check(Seeds.of(42, "a") != Seeds.of(43, "a"), "Seeds.of ignores the run seed")
	for run_seed in [1, 7, 12345, 987654321]:
		_check(SectorMap.generate(run_seed, 1).checksum() == SectorMap.generate(run_seed, 1).checksum(), "chart %d differs" % run_seed)
	# Loaded now, not named: it reaches the game's autoloads, which a test script can't see when
	# it's compiled.
	var system: Node3D = load("res://game/space/star_system.gd").new()
	root.add_child(system)
	var seen := {}
	for seed in range(1, 60):
		system.generate(seed)
		var first: int = system.checksum()
		var planets: int = system.planets.size()
		_check(planets >= 1 and planets <= 5, "system %d has %d planets" % [seed, planets])
		for planet in system.planets:
			for key in ["atmosphere", "temperature", "gravity", "water", "biosigns", "data"]:
				_check(planet.traits.has(key), "system %d planet lacks %s" % [seed, key])
		system.generate(seed + 1000)
		system.generate(seed)
		_check(system.checksum() == first, "system %d differs when built again" % seed)
		seen[first] = true
		system.generate(seed, "gas giant")
		_check(system.planets[0].kind == "gas giant", "system %d: no gas giant ahead when asked for one" % seed)
	_check(seen.size() == 59, "different seeds built the same system")
	print("test_determinism: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
