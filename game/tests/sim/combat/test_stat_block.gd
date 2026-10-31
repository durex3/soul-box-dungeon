extends GdTest

# 独立GDD/RK004参考，禁止用被测快照或Balance表生成期望。
const DEFAULTS: Dictionary = {&"max_hp": 100.0, &"hp_regen": 0.0, &"lifesteal": 0.0, &"armor": 0.0, &"dodge": 0.0, &"damage": 0.0, &"melee_damage": 0.0, &"ranged_damage": 0.0, &"elemental_damage": 0.0, &"attack_speed": 0.0, &"crit_chance": 0.05, &"area": 0.0, &"move_speed": 0.0, &"range": 0.0, &"pickup_range": 2.0, &"luck": 0.0, &"income": 0.0, &"max_energy": 200.0}
const CAPS: Dictionary = {&"lifesteal": 0.25, &"dodge": 0.6, &"attack_speed": 3.0, &"crit_chance": 1.0, &"area": 2.0, &"move_speed": 1.0, &"range": 1.0}

func test_01_defaults_exact_keys_units_and_isolation() -> void:
	var a: StatBlock = StatBlock.new()
	var b: StatBlock = StatBlock.new()
	eq(a.snapshot().size(), 18)
	eq(a.snapshot().keys(), DEFAULTS.keys())
	for key: StringName in DEFAULTS:
		near(a.value(key), DEFAULTS[key])
		eq(typeof(a.snapshot()[key]), TYPE_FLOAT)
	ok(a.set_modifier(&"fraction", {&"crit_chance": 0.02, &"pickup_range": 0.5, &"income": 0.125}))
	near(a.value(&"crit_chance"), 0.07, 0.000001)
	near(a.value(&"pickup_range"), 2.5)
	near(a.value(&"income"), 0.125)
	eq(b.snapshot(), DEFAULTS)

func test_02_all_caps_floors_and_uncapped_values() -> void:
	for key: StringName in DEFAULTS:
		var stats: StatBlock = StatBlock.new()
		ok(stats.set_modifier(&"large", {key: 1000000.125}))
		if CAPS.has(key):
			near(stats.value(key), CAPS[key], 0.000001, "cap " + str(key))
		else:
			near(stats.value(key), DEFAULTS[key] + 1000000.125, 0.000001, "uncapped " + str(key))
		ok(stats.set_modifier(&"large", {key: -1000000.125}))
		var floor_value: float = 10.0 if key == &"max_hp" else (-20.0 if key == &"armor" else 0.0)
		near(stats.value(key), floor_value, 0.000001, "floor " + str(key))
		ok(stats.remove_modifier(&"large"))
		near(stats.value(key), DEFAULTS[key])

func test_03_glass_from_relic_table_fixed_health_and_removal() -> void:
	var before: String = var_to_str(RelicTable.ROWS)
	var glass: Dictionary = _glass()
	eq(glass, {&"damage": 0.3, &"max_hp_pct": -0.25})
	var stats: StatBlock = StatBlock.new()
	ok(stats.set_modifier(&"glass_1", glass))
	ok(stats.set_modifier(&"glass_2", glass))
	near(stats.value(&"max_hp"), 56.25, 0.000001, "two glass health")
	near(stats.value(&"damage"), 0.6)
	ok(stats.set_modifier(&"health_flat", {&"max_hp": 20}))
	near(stats.value(&"max_hp"), 67.5, 0.000001, "flat before health factors")
	ok(stats.remove_modifier(&"glass_1"))
	near(stats.value(&"max_hp"), 90)
	near(stats.value(&"damage"), 0.3)
	ok(stats.remove_modifier(&"glass_2"))
	near(stats.value(&"max_hp"), 120)
	ok(stats.remove_modifier(&"health_flat"))
	near(stats.value(&"max_hp"), 100)
	eq(var_to_str(RelicTable.ROWS), before)

func test_03_health_floor_and_nonnegative_factors_recover_raw_sources() -> void:
	var stats: StatBlock = StatBlock.new()
	for i: int in 10:
		ok(stats.set_modifier(StringName("glass_%02d" % i), _glass()))
	near(stats.value(&"max_hp"), 10, 0.000001, "ten glass minimum health")
	for i: int in range(2, 10):
		ok(stats.remove_modifier(StringName("glass_%02d" % i)))
	near(stats.value(&"max_hp"), 56.25, 0.000001, "restore sources hidden by minimum")
	ok(stats.set_modifier(&"negative_flat", {&"max_hp": -200}))
	near(stats.value(&"max_hp"), 10)
	ok(stats.set_modifier(&"extreme_1", {&"max_hp_pct": -2.0}))
	ok(stats.set_modifier(&"extreme_2", {&"max_hp_pct": -3.0}))
	ok(stats.remove_modifier(&"negative_flat"))
	near(stats.value(&"max_hp"), 10, 0.000001, "negative factors never heal")
	ok(stats.set_modifier(&"zero_factor", {&"max_hp_pct": -1.0}))
	near(stats.value(&"max_hp"), 10)
	for key: StringName in [&"extreme_1", &"extreme_2", &"zero_factor", &"glass_00", &"glass_01"]:
		ok(stats.remove_modifier(key))
	near(stats.value(&"max_hp"), 100)

func test_04_raw_sum_then_clamp_and_source_restoration() -> void:
	var stats: StatBlock = StatBlock.new()
	ok(stats.set_modifier(&"a", {&"move_speed": 0.8}))
	ok(stats.set_modifier(&"b", {&"move_speed": 0.8}))
	ok(stats.set_modifier(&"c", {&"move_speed": -0.9}))
	near(stats.value(&"move_speed"), 0.7, 0.000001, "raw sum 0.8+0.8-0.9")
	ok(stats.remove_modifier(&"c"))
	near(stats.value(&"move_speed"), 1.0, 0.000001, "remove negative restores cap")
	ok(stats.remove_modifier(&"a"))
	near(stats.value(&"move_speed"), 0.8, 0.000001, "remove capped positive retains raw other")
	ok(stats.remove_modifier(&"b"))
	ok(stats.set_modifier(&"negative", {&"move_speed": -0.3}))
	near(stats.value(&"move_speed"), 0)
	ok(stats.set_modifier(&"positive", {&"move_speed": 0.5}))
	near(stats.value(&"move_speed"), 0.2, 0.000001, "negative raw source retained")

func test_05_replace_remove_deep_copy_and_deterministic_order() -> void:
	var stats: StatBlock = StatBlock.new()
	var mods: Dictionary = {&"move_speed": 0.5, &"max_hp_pct": -0.25}
	ok(stats.set_modifier(&"one", mods))
	ok(stats.set_modifier(&"one", mods))
	near(stats.value(&"move_speed"), 0.5, 0.000001, "same instance replaces rather than stacks")
	near(stats.value(&"max_hp"), 75)
	mods[&"move_speed"] = 99
	mods.clear()
	ok(stats.set_modifier(&"empty", {}))
	near(stats.value(&"move_speed"), 0.5, 0.000001, "stored copy survives future recompute")
	var copy: Dictionary = stats.snapshot()
	copy[&"max_hp"] = -100
	copy[&"fake"] = 1
	near(stats.value(&"max_hp"), 75)
	eq(stats.snapshot().size(), 18)
	ok(stats.set_modifier(&"one", {&"crit_chance": 0.02}))
	near(stats.value(&"move_speed"), 0)
	near(stats.value(&"max_hp"), 100)
	near(stats.value(&"crit_chance"), 0.07)
	ok(stats.remove_modifier(&"empty"))
	ok(not stats.remove_modifier(&"empty"))
	var a: StatBlock = StatBlock.new()
	var b: StatBlock = StatBlock.new()
	var sources: Dictionary = {&"z": {&"income": 0.125, &"max_hp_pct": -0.25}, &"a": {&"income": 1e16, &"max_hp": 20}, &"m": {&"income": -1e16, &"max_hp_pct": -0.25}}
	for source: StringName in [&"z", &"a", &"m"]:
		ok(a.set_modifier(source, sources[source]))
	for source: StringName in [&"m", &"a", &"z"]:
		var reversed: Dictionary = {}
		var keys: Array = sources[source].keys()
		keys.reverse()
		for key: StringName in keys:
			reversed[key] = sources[source][key]
		ok(b.set_modifier(source, reversed))
	eq(a.snapshot().keys(), DEFAULTS.keys())
	eq(a.snapshot(), b.snapshot(), "fixed source ordering defeats non-associative insertion histories")
	near(a.value(&"income"), 0.125)
	near(a.value(&"max_hp"), 67.5)

func test_05_invalid_input_is_atomic_and_extras_rejected() -> void:
	var stats: StatBlock = StatBlock.new()
	ok(stats.set_modifier(&"existing", {&"damage": 0.3, &"max_hp_pct": -0.25}))
	var before: Dictionary = stats.snapshot()
	var invalid: Array[Dictionary] = [{&"damage": 9, &"unknown": 1}, {"damage": 0.5}, {3: 0.5}, {&"move_speed": true}, {&"move_speed": "0.5"}, {&"move_speed": NAN}, {&"move_speed": INF}, {&"move_speed": -INF}, {&"max_hp_pct": 0.01}, {&"damage": 9, &"max_hp_pct": 0.5}]
	for extra: StringName in Balance.RELIC_EXTRA_MODS:
		if extra != &"max_hp_pct":
			invalid.append({&"damage": 9, extra: -0.1})
	for bad: Dictionary in invalid:
		ok(not stats.set_modifier(&"existing", bad), "reject " + str(bad))
		eq(stats.snapshot(), before, "failed replacement preserves all fields")
	ok(not stats.set_modifier(&"", {&"damage": 2}))
	ok(not stats.remove_modifier(&"missing"))
	eq(stats.snapshot(), before)
	ok(stats.set_modifier(&"zero", {&"max_hp_pct": 0, &"armor": 1}))
	near(stats.value(&"armor"), 1)
	near(stats.value(&"max_hp"), 75)
	ok(stats.set_modifier(&"trigger", {}))
	near(stats.value(&"damage"), 0.3, 0.000001, "invalid source not retained invisibly")

func _glass() -> Dictionary:
	for row: Dictionary in RelicTable.ROWS:
		if row["id"] == &"glass_cannon":
			return row["mods"].duplicate(true)
	ok(false, "glass_cannon must exist")
	return {}
