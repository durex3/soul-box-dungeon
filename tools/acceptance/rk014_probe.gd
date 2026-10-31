extends SceneTree
## 直接调用生产类及正式GdTest，不复制属性计算实现。

var failed: bool = false

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--query" in args:
		var stats: StatBlock = StatBlock.new()
		var before: Dictionary = stats.snapshot()
		_check(stats.value(&"max_hp_pct") == 0.0, "auxiliary modifier is not queryable")
		_check(stats.value(&"unknown") == 0.0, "unknown query returns zero")
		_check(stats.snapshot() == before and before.size() == 18, "invalid query leaves snapshot intact")
		print("RK014_QUERY: " + ("failed" if failed else "passed"))
		quit(1 if failed else 0)
		return
	if "--test" in args:
		_run_method(args[1], args[2])
	else:
		for path: String in ["res://tests/sim/combat/test_stat_block.gd", "res://tests/sim/combat/test_stat_sim.gd"]:
			var script: Script = load(path) as Script
			var methods: Array[String] = []
			for item: Dictionary in script.get_script_method_list():
				if str(item.name).begins_with("test_"):
					methods.append(item.name)
			methods.sort()
			_check(not methods.is_empty(), "methods present " + path)
			for method: String in methods:
				_run_method(path, method)
		_demo()
	print("RK014_PROBE: " + ("failed" if failed else "passed"))
	quit(1 if failed else 0)

func _run_method(path: String, method: String) -> void:
	print("RK014 RUN ", path, "::", method)
	var script: Script = load(path) as Script
	var test: GdTest = script.new() as GdTest
	test.call(method)
	for failure: String in test.get_failures():
		print("RK014 FAIL ", failure)
		failed = true

func _check(ok: bool, message: String) -> void:
	if not ok:
		print("RK014 FAIL ", message)
		failed = true

func _demo() -> void:
	var stats: StatBlock = StatBlock.new()
	print("RK014 18-field defaults ", JSON.stringify(stats.snapshot(), "", false))
	var glass: Dictionary = {}
	for row: Dictionary in RelicTable.ROWS:
		if row.id == &"glass_cannon":
			glass = row.mods
	_check(stats.set_modifier(&"glass_a", glass), "first glass")
	_check(stats.set_modifier(&"glass_b", glass), "second glass")
	print("RK014 two glass health=", stats.value(&"max_hp"), " damage=", stats.value(&"damage"))
	_check(stats.set_modifier(&"flat", {&"max_hp": 20}), "flat health")
	print("RK014 flat20 before glass health=", stats.value(&"max_hp"))
	for source: StringName in [&"glass_a", &"glass_b", &"flat"]:
		_check(stats.remove_modifier(source), "remove " + source)
		print("RK014 removed ", source, " health=", stats.value(&"max_hp"))
	for initial: float in [0.0, 0.5]:
		var sim: Sim = Sim.new(14, &"knight", initial)
		print("RK014 movement initial=", initial, " steps=60 distance=", _distance(sim))
	var sim: Sim = Sim.new(14, &"knight")
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SET_STAT_MODIFIER
	cmd.modifier_source = &"boots"
	cmd.stat_mods = {&"move_speed": 0.5}
	var events: Array[SimEvent] = sim.apply(cmd)
	_check(events.size() == 1, "one stats event")
	print("RK014 command kind=", events[0].kind, " player_id=", events[0].entity_id, " reason=", JSON.stringify(events[0].reason))
	print("RK014 movement command+50% steps=60 distance=", _distance(sim))
	cmd.stat_mods = {&"move_speed": 2.0}
	sim.apply(cmd)
	print("RK014 movement capped steps=60 distance=", _distance(sim), " mirror=", sim.state.player.move_speed_bonus)

func _distance(sim: Sim) -> float:
	var before: Vector2 = sim.state.player.position
	var input: InputFrame = InputFrame.new()
	input.move_direction = Vector2.RIGHT
	for i: int in 60:
		sim.step(input)
	return sim.state.player.position.distance_to(before)
