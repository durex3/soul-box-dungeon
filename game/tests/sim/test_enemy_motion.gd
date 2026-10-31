extends GdTest

func test_isolated_axial_and_diagonal_speed() -> void:
	for species: Array in [[&"skeleton_rat", 72.0], [&"crypt_zombie", 40.0]]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2(1, 1).normalized()]:
			var sim: Sim = Sim.new(44, &"knight")
			var at: Vector2 = sim.state.player.position - direction * 200.0
			EnemyTestFixture.spawn(sim, at, species[0])
			for i: int in 60:
				sim.step(InputFrame.new())
			near(sim.state.enemies[0].position.distance_to(at), species[1], 0.02)
			ok((sim.state.enemies[0].position - (at + direction * species[1])).length() <= 0.02)

func test_player_first_retarget_arrive_and_exact_coincidence() -> void:
	var sim: Sim = Sim.new(45, &"knight")
	EnemyTestFixture.spawn(sim, sim.state.player.position - Vector2(0.5, 0))
	sim.step(InputFrame.new())
	eq(sim.state.enemies[0].position, sim.state.player.position, "near target never overshoots")
	for i: int in 20:
		sim.step(InputFrame.new())
	eq(sim.state.enemies[0].position, sim.state.player.position, "coincidence finite stationary")
	var input: InputFrame = InputFrame.new()
	input.move_direction = Vector2.DOWN
	sim.step(input)
	eq(sim.state.enemies[0].position, sim.state.player.position, "chase uses this step's updated player")
	input.move_direction = Vector2.RIGHT
	sim.step(input)
	eq(sim.state.enemies[0].position, sim.state.player.position)

func test_pairs_apart_tangent_overlap_and_coincident() -> void:
	for distance: float in [32.0, 16.0, 12.0, 0.0]:
		var sim: Sim = Sim.new(46, &"knight")
		EnemyTestFixture.spawn(sim, Vector2(100, 100))
		EnemyTestFixture.spawn(sim, Vector2(100 + distance, 100))
		var a: Vector2 = sim.state.enemies[0].position.move_toward(sim.state.player.position, 1.2)
		var b: Vector2 = sim.state.enemies[1].position.move_toward(sim.state.player.position, 1.2)
		sim.step(InputFrame.new())
		if distance == 32.0:
			eq(sim.state.enemies[0].position, a)
			eq(sim.state.enemies[1].position, b)
		else:
			near(sim.state.enemies[0].position.distance_to(sim.state.enemies[1].position), 16.0, 0.001, "pair overlap/coincidence separates")
		ok(EnemyTestFixture.valid(sim))
		ok(EnemyTestFixture.index_matches(sim), "self candidate filtered")

func test_three_coincident_resolve_non_collinear_deterministically() -> void:
	var first: Sim = Sim.new(47, &"knight")
	var second: Sim = Sim.new(47, &"knight")
	for sim: Sim in [first, second]:
		for i: int in 3:
			EnemyTestFixture.spawn(sim, Vector2(640, 360))
		for i: int in 8:
			sim.step(InputFrame.new())
		ok(EnemyTestFixture.valid(sim))
		ok(EnemyTestFixture.density(sim).min > 14.0, "three coincident resolve")
		var a: Vector2 = sim.state.enemies[1].position - sim.state.enemies[0].position
		var b: Vector2 = sim.state.enemies[2].position - sim.state.enemies[0].position
		ok(absf(a.cross(b)) > 1.0, "not forced onto one line")
	eq(EnemyTestFixture.snapshot(first), EnemyTestFixture.snapshot(second))

func test_four_walls_four_corners_stay_bounded_and_leave_wall() -> void:
	for at: Vector2 in [Vector2(0, 0), Vector2(1280, 0), Vector2(0, 720), Vector2(1280, 720), Vector2(0, 360), Vector2(1280, 360), Vector2(640, 0), Vector2(640, 720)]:
		var sim: Sim = Sim.new(48, &"knight")
		for i: int in 3:
			EnemyTestFixture.spawn(sim, at)
		ok(EnemyTestFixture.valid(sim), "spawn whole circle clamp")
		for i: int in 90:
			sim.step(InputFrame.new())
			ok(EnemyTestFixture.valid(sim), "separation whole circle clamp")
		for e: EnemyState in sim.state.enemies:
			ok(ArenaBounds.play_rect().grow(-9.0).has_point(e.position), "leaves boundary")
		ok(EnemyTestFixture.index_matches(sim))

func test_coincident_direction_uses_full_id_history() -> void:
	var sim: Sim = Sim.new(49, &"knight")
	for i: int in 17:
		EnemyTestFixture.spawn(sim, Vector2(640, 360))
	for id: int in range(1, 18):
		if id not in [1, 9, 17]:
			var cmd: Command = Command.new()
			cmd.kind = Command.Kind.DESPAWN_ENEMY
			cmd.entity_id = id
			sim.apply(cmd)
	for i: int in 8:
		sim.step(InputFrame.new())
	ok(EnemyTestFixture.density(sim).min > 14.0)
	var a: Vector2 = sim.state.enemies[1].position - sim.state.enemies[0].position
	var b: Vector2 = sim.state.enemies[2].position - sim.state.enemies[0].position
	ok(absf(a.cross(b)) > 1.0, "same low three ID bits still spread in two dimensions")
	ok(EnemyTestFixture.index_matches(sim))
