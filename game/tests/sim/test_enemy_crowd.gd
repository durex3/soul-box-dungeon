extends GdTest

func test_standard_200_density_600_steps() -> void:
	var sim: Sim = Sim.new(49, &"knight")
	EnemyTestFixture.standard(sim)
	var valid: bool = true
	for i: int in 600:
		sim.step(InputFrame.new())
		valid = valid and EnemyTestFixture.valid(sim, 200) and sim.state.enemies.size() == 200
	ok(valid, "all 200 identities and whole circles retained for 600 steps")
	var result: Dictionary = EnemyTestFixture.density(sim)
	print("RK041 density 200/600 iterations=%d min=%.6f p5=%.6f median=%.6f below14=%d" % [EnemyConfig.SEPARATION_ITERATIONS, result.min, result.p5, result.median, result.below14])
	ok(result.min >= 8.0, "200 density minimum >=8")
	ok(result.below14 <= 10, "200 density at least190 >=14")
	ok(EnemyTestFixture.index_matches(sim), "200 final index exact reference")

func test_200_follow_right_then_down() -> void:
	var sim: Sim = Sim.new(50, &"knight")
	EnemyTestFixture.standard(sim)
	var initial: Vector2 = _mean(sim)
	var input: InputFrame = InputFrame.new()
	var valid: bool = true
	input.move_direction = Vector2.RIGHT
	for i: int in 300:
		sim.step(input)
		valid = valid and EnemyTestFixture.valid(sim, 200) and sim.state.enemies.size() == 200
	var turn: Vector2 = _mean(sim)
	input.move_direction = Vector2.DOWN
	for i: int in 300:
		sim.step(input)
		valid = valid and EnemyTestFixture.valid(sim, 200) and sim.state.enemies.size() == 200
	ok(valid, "moving 200 remain bounded with exact identities")
	ok(turn.x > initial.x + 100 and _mean(sim).y > turn.y + 80, "crowd follows direction change")
	ok(EnemyTestFixture.index_matches(sim))

func test_replay_queries_lifecycle_and_rng_unchanged() -> void:
	for seed_value: int in [51, 7419]:
		var a: Sim = Sim.new(seed_value, &"knight")
		var b: Sim = Sim.new(seed_value, &"knight")
		var rng_before: Array[int] = EnemyTestFixture.rng_states(a)
		for sim: Sim in [a, b]:
			for i: int in 24:
				EnemyTestFixture.spawn(sim, Vector2(640, 360), &"crypt_zombie", 12, 5)
		var input: InputFrame = InputFrame.new()
		for step_number: int in 90:
			if step_number == 20:
				for sim: Sim in [a, b]:
					var cmd: Command = Command.new()
					cmd.kind = Command.Kind.DESPAWN_ENEMY
					cmd.entity_id = 3
					sim.apply(cmd)
					EnemyTestFixture.spawn(sim, Vector2(640, 360))
			input.move_direction = Vector2.RIGHT if step_number < 45 else Vector2.DOWN
			a.step(input)
			# 观察者可多做查询，不能影响本步或下一步结果。
			var snapshot: Array = EnemyTestFixture.snapshot(b)
			for radius: float in [0, 16, 64, 500]:
				b.query_enemies(b.state.player.position, radius)
			eq(EnemyTestFixture.snapshot(b), snapshot)
			b.step(input)
			eq(EnemyTestFixture.snapshot(a), EnemyTestFixture.snapshot(b), "per-field deterministic replay")
			eq(EnemyTestFixture.rng_states(a), rng_before)
			eq(EnemyTestFixture.rng_states(b), rng_before)
		ok(EnemyTestFixture.index_matches(a))
		for e: EnemyState in a.state.enemies:
			near(e.hp, e.max_hp)
			if e.enemy_type == &"crypt_zombie":
				near(e.max_hp, 12 * 3.42 * 1.15)
				near(e.damage, 6 * 2.32 * 1.10)
				near(e.xp, 2 * 1.66)

func _mean(sim: Sim) -> Vector2:
	var total: Vector2 = Vector2.ZERO
	for e: EnemyState in sim.state.enemies:
		total += e.position
	return total / sim.state.enemies.size()
