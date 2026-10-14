class_name Seeds
## Every random thing in a run comes from the run's seed and a stable label (TECH §6), e.g.
## `Seeds.of(run_seed, "sector1/row3/node2")`: the same on every peer, and the same whatever else
## was generated first. Nothing in generation uses global randomness.


## The seed for `label` in the run seeded `run_seed`.
static func of(run_seed: int, label: String) -> int:
	return hash([run_seed, label])


## A generator seeded for `label` in the run seeded `run_seed`.
static func rng(run_seed: int, label: String) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = of(run_seed, label)
	return generator


## A key from a weighted `table` ({key: {"weight": n, ...}}), rolled on `generator`.
static func pick(generator: RandomNumberGenerator, table: Dictionary) -> Variant:
	var total := 0
	for key: Variant in table:
		total += table[key].weight
	var roll := generator.randi_range(1, total)
	for key: Variant in table:
		roll -= table[key].weight
		if roll <= 0:
			return key
	return table.keys()[0]
