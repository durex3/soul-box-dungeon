extends GdTest

func test_06_events_failures_and_enemy_identity_index_rng_unchanged() -> void:
	var sim: Sim = Sim.new(1401, &"knight")
	eq(EnemyTestFixture.spawn(sim, Vector2(100, 100)).entity_id, 1)
	var enemies_before: Array = EnemyTestFixture.snapshot(sim)
	var streams_before: Array[int] = EnemyTestFixture.rng_states(sim)
	var mods: Dictionary = {&"move_speed": 100.0, &"armor": -3.0}
	_check_event(_apply_modifier(sim, &"speed", mods), SimEvent.Kind.STATS_CHANGED)
	near(sim.state.player.stats.value(&"move_speed"), 1.0)
	near(sim.state.player.move_speed_bonus, 1.0)
	mods.clear()
	_check_event(_apply_modifier(sim, &"empty", {}), SimEvent.Kind.STATS_CHANGED)
	_check_event(_apply_modifier(sim, &"speed", {&"move_speed": 100.0, &"armor": -3.0}), SimEvent.Kind.STATS_CHANGED)
	_check_event(_apply_modifier(sim, &"slow", {&"move_speed": -99.2}), SimEvent.Kind.STATS_CHANGED)
	near(sim.state.player.stats.value(&"move_speed"), 0.8, 0.000001, "successful capped source retains original 100")
	near(sim.state.player.move_speed_bonus, 0.8, 0.000001)
	var before: Dictionary = sim.state.player.stats.snapshot()
	for cmd: Command in [_command(Command.Kind.SET_STAT_MODIFIER, &"speed", {&"move_speed": 0.1, &"invalid": 2}), _command(Command.Kind.SET_STAT_MODIFIER, &"", {}), _command(Command.Kind.SET_STAT_MODIFIER, &"speed", {&"max_hp_pct": 0.1}), _command(Command.Kind.REMOVE_STAT_MODIFIER, &"missing"), _command(Command.Kind.SET_STAT_MODIFIER, Sim.INITIAL_MOVE_SPEED_SOURCE, {&"move_speed": 0.9}), _command(Command.Kind.REMOVE_STAT_MODIFIER, Sim.INITIAL_MOVE_SPEED_SOURCE)]:
		var events: Array[SimEvent] = sim.apply(cmd)
		eq(events.size(), 1)
		eq(events[0].kind, SimEvent.Kind.COMMAND_FAILED)
		ok(not events[0].reason.is_empty())
		eq(sim.state.player.stats.snapshot(), before)
		near(sim.state.player.move_speed_bonus, 0.8, 0.000001)
	_check_event(sim.apply(_command(Command.Kind.REMOVE_STAT_MODIFIER, &"empty")), SimEvent.Kind.STATS_CHANGED)
	eq(EnemyTestFixture.snapshot(sim), enemies_before)
	ok(EnemyTestFixture.index_matches(sim))
	eq(EnemyTestFixture.rng_states(sim), streams_before)
	eq(EnemyTestFixture.spawn(sim, Vector2(200, 100)).entity_id, 2, "stat commands never consume enemy ID")

func test_06_initial_compatibility_reserved_source_and_independent_runs() -> void:
	for initial: float in [-2.0, 0.0, 0.5, 2.0]:
		var sim: Sim = Sim.new(1402, &"knight", initial)
		var expected: float = 0.0 if initial < 0 else (1.0 if initial > 1 else initial)
		near(sim.state.player.stats.value(&"move_speed"), expected)
		near(sim.state.player.move_speed_bonus, expected)
		_check_event(_apply_modifier(sim, &"change", {&"move_speed": -0.2 if initial > 1 else 0.3}), SimEvent.Kind.STATS_CHANGED)
		near(sim.state.player.stats.value(&"move_speed"), minf(1.0, expected + (-0.2 if initial > 1 else 0.3)), 0.000001, "constructor stores preclamped source")
		var before: Dictionary = sim.state.player.stats.snapshot()
		for kind: int in [Command.Kind.SET_STAT_MODIFIER, Command.Kind.REMOVE_STAT_MODIFIER]:
			var events: Array[SimEvent] = sim.apply(_command(kind, Sim.INITIAL_MOVE_SPEED_SOURCE, {&"move_speed": 1.0}))
			eq(events[0].kind, SimEvent.Kind.COMMAND_FAILED)
			eq(sim.state.player.stats.snapshot(), before)
	var a: Sim = Sim.new(1403, &"knight")
	var b: Sim = Sim.new(1403, &"knight")
	_apply_modifier(a, &"only_a", {&"damage": 0.3, &"move_speed": 0.5})
	near(b.state.player.stats.value(&"damage"), 0)
	near(b.state.player.stats.value(&"move_speed"), 0)

func test_06_movement_initial_command_replace_remove_half_and_diagonal() -> void:
	for initial: float in [0.0, 0.5]:
		var sim: Sim = Sim.new(1404, &"knight", initial)
		near(_walk(sim, Vector2.RIGHT).length(), 64.0 if initial == 0 else 96.0, 0.02, "initial speed distance")
	var sim: Sim = Sim.new(1405, &"knight")
	_check_event(_apply_modifier(sim, &"boots", {&"move_speed": 0.5}), SimEvent.Kind.STATS_CHANGED)
	near(_walk(sim, Vector2.RIGHT).length(), 96.0, 0.02, "command modifier distance")
	_check_event(_apply_modifier(sim, &"boots", {&"move_speed": 2.0}), SimEvent.Kind.STATS_CHANGED)
	near(_walk(sim, Vector2.RIGHT).length(), 128.0, 0.02, "command cap distance")
	_check_event(_apply_modifier(sim, &"boots", {&"move_speed": 0.25}), SimEvent.Kind.STATS_CHANGED)
	near(_walk(sim, Vector2.RIGHT).length(), 80.0, 0.02, "replacement distance")
	_check_event(sim.apply(_command(Command.Kind.REMOVE_STAT_MODIFIER, &"boots")), SimEvent.Kind.STATS_CHANGED)
	near(_walk(sim, Vector2.RIGHT).length(), 64.0, 0.02, "removal distance")
	for direction: Vector2 in [Vector2(0.5, 0), Vector2(1, 1)]:
		var other: Sim = Sim.new(1406, &"knight")
		_apply_modifier(other, &"speed", {&"move_speed": 0.5})
		var displacement: Vector2 = _walk(other, direction)
		var expected: Vector2 = Vector2(48, 0) if direction.y == 0 else Vector2(1, 1).normalized() * 96.0
		ok(displacement.distance_to(expected) <= 0.02, "half/diagonal magnitude preserved")
		near(other.state.player.move_speed_bonus, other.state.player.stats.value(&"move_speed"))

func test_06_replay_mixed_source_histories_and_input() -> void:
	var a: Sim = Sim.new(1407, &"knight", 0.5)
	var b: Sim = Sim.new(1407, &"knight", 0.5)
	for sim: Sim in [a, b]:
		EnemyTestFixture.spawn(sim, Vector2(100, 100), &"crypt_zombie")
	var rng_before: Array[int] = EnemyTestFixture.rng_states(a)
	var input: InputFrame = InputFrame.new()
	for i: int in 120:
		for sim: Sim in [a, b]:
			if i == 0:
				_apply_modifier(sim, &"slow", {&"move_speed": -0.9, &"max_hp_pct": -0.25})
			if i == 30:
				_apply_modifier(sim, &"boost", {&"move_speed": 0.8, &"max_hp": 20})
			if i == 60:
				_apply_modifier(sim, &"slow", {&"move_speed": -0.2})
			if i == 90:
				sim.apply(_command(Command.Kind.REMOVE_STAT_MODIFIER, &"boost"))
		input.move_direction = Vector2(1, 0) if i < 60 else Vector2(0.5, 0.5)
		a.step(input)
		b.step(input)
		eq(EnemyTestFixture.snapshot(a), EnemyTestFixture.snapshot(b))
		eq(a.state.player.stats.snapshot(), b.state.player.stats.snapshot())
		near(a.state.player.move_speed_bonus, a.state.player.stats.value(&"move_speed"))
		eq(EnemyTestFixture.rng_states(a), rng_before)
		eq(EnemyTestFixture.rng_states(b), rng_before)
	ok(EnemyTestFixture.index_matches(a))

func _command(kind: int, source: StringName, mods: Dictionary = {}) -> Command:
	var cmd: Command = Command.new()
	cmd.kind = kind
	cmd.modifier_source = source
	cmd.stat_mods = mods
	return cmd

func _apply_modifier(sim: Sim, source: StringName, mods: Dictionary) -> Array[SimEvent]:
	return sim.apply(_command(Command.Kind.SET_STAT_MODIFIER, source, mods))

func _check_event(events: Array[SimEvent], kind: SimEvent.Kind) -> void:
	eq(events.size(), 1)
	eq(events[0].kind, kind)
	eq(events[0].entity_id, 0)
	eq(events[0].reason, "")

func _walk(sim: Sim, direction: Vector2) -> Vector2:
	var before: Vector2 = sim.state.player.position
	var input: InputFrame = InputFrame.new()
	input.move_direction = direction
	for i: int in 60:
		sim.step(input)
	return sim.state.player.position - before
