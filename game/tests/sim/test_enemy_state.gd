extends GdTest

func test_eight_species_wave_danger_and_table_unchanged() -> void:
	var before: String = var_to_str(EnemyTable.ROWS)
	# 独立于工厂公式的GDD参考：[id,hp,damage,px/s,xp]。
	var rows: Array = [[&"skeleton_rat", 4.0, 3.0, 72.0, 1.0], [&"crypt_zombie", 12.0, 6.0, 40.0, 2.0], [&"charge_boar", 20.0, 10.0, 56.0, 3.0], [&"bone_archer", 10.0, 5.0, 40.0, 2.0], [&"blast_mushroom", 8.0, 20.0, 56.0, 2.0], [&"slime", 18.0, 5.0, 56.0, 2.0], [&"fire_mage", 14.0, 6.0, 40.0, 3.0], [&"lava_golem", 80.0, 12.0, 40.0, 6.0]]
	var waves: Array = [[1, 1.0, 1.0, 1.0], [6, 2.1, 1.6, 1.3], [12, 3.42, 2.32, 1.66]]
	for row: Array in rows:
		for wave: Array in waves:
			for danger: int in [0, 1, 5]:
				var sim: Sim = Sim.new(41, &"knight")
				var event: SimEvent = EnemyTestFixture.spawn(sim, Vector2(100, 100), row[0], wave[0], danger)
				eq(event.kind, SimEvent.Kind.SPAWNED)
				var e: EnemyState = sim.state.enemies[0]
				eq(e.enemy_type, row[0])
				near(e.radius, 8.0)
				near(e.max_hp, row[1] * wave[1] * (1.0 if danger == 0 else 1.15))
				near(e.hp, e.max_hp)
				near(e.damage, row[2] * wave[2] * (1.0 if danger == 0 else 1.10))
				near(e.xp, row[4] * wave[3])
				near(e.move_speed, row[3])
				eq(e.spawn_wave, wave[0])
				eq(e.danger_level, danger)
	eq(var_to_str(EnemyTable.ROWS), before)
	near(Balance.DANGER_ENEMY_HP_MULT, 1.15)
	near(Balance.DANGER_ENEMY_DAMAGE_MULT, 1.10)

func test_factory_instance_isolation() -> void:
	var a: EnemyState = EnemyFactory.build(&"slime", 1, Vector2(100, 100), 1, 0)
	var b: EnemyState = EnemyFactory.build(&"slime", 2, Vector2(100, 100), 1, 0)
	# 仅此纯工厂实例隔离测试写独立值；Sim集成始终由命令安排。
	a.hp = 1.0
	a.position = Vector2.ZERO
	near(b.hp, 18.0)
	eq(b.position, Vector2(100, 100))
	near(EnemyTable.ROWS[5]["child_xp"], 0.5)
	near(EnemyTable.ROWS[2]["dash_speed"], 12.0)

func test_command_ids_failure_atomicity_and_query_copy() -> void:
	var sim: Sim = Sim.new(42, &"knight")
	eq(sim.state.player.entity_id, 0)
	for i: int in 3:
		var event: SimEvent = EnemyTestFixture.spawn(sim, Vector2(100 + i * 30, 100))
		eq(event.entity_id, i + 1)
		eq(event.reason, "")
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.DESPAWN_ENEMY
	cmd.entity_id = 2
	var removed: SimEvent = sim.apply(cmd)[0]
	eq(removed.kind, SimEvent.Kind.DESPAWNED)
	eq(removed.entity_id, 2)
	var before: Array = EnemyTestFixture.snapshot(sim)
	for kind: int in [-99, Command.Kind.DESPAWN_ENEMY]:
		cmd.kind = kind
		cmd.entity_id = 999
		var event: SimEvent = sim.apply(cmd)[0]
		eq(event.kind, SimEvent.Kind.COMMAND_FAILED)
		ok(not event.reason.is_empty())
	for values: Array in [[&"missing", 1, 0], [&"skeleton_rat", 0, 0], [&"skeleton_rat", 1, -1], [&"skeleton_rat", 1, 6]]:
		eq(EnemyTestFixture.spawn(sim, Vector2.ZERO, values[0], values[1], values[2]).kind, SimEvent.Kind.COMMAND_FAILED)
	eq(sim.apply(null)[0].kind, SimEvent.Kind.COMMAND_FAILED)
	eq(EnemyTestFixture.snapshot(sim), before)
	ok(EnemyTestFixture.index_matches(sim), "failed command index unchanged")
	eq(EnemyTestFixture.spawn(sim, Vector2(-100, -100)).entity_id, 4, "failures consume no identity")
	eq(sim.state.enemies[2].position, Vector2(40, 40))
	var ids: Array[int] = sim.query_enemies(Vector2.ZERO, 2000)
	eq(ids, [1, 3, 4])
	ids.clear()
	eq(sim.query_enemies(Vector2.ZERO, 2000), [1, 3, 4])
	cmd.kind = Command.Kind.DESPAWN_ENEMY
	for id: int in [1, 3, 4]:
		cmd.entity_id = id
		eq(sim.apply(cmd)[0].kind, SimEvent.Kind.DESPAWNED)
	eq(sim.query_enemies(Vector2.ZERO, 2000), [])
	eq(EnemyTestFixture.spawn(sim, Vector2(100, 100)).entity_id, 5)

func test_index_cross_bucket_and_removal_after_motion() -> void:
	var sim: Sim = Sim.new(43, &"knight")
	EnemyTestFixture.spawn(sim, Vector2(63.9, 63.9))
	EnemyTestFixture.spawn(sim, Vector2(64, 64))
	for i: int in 90:
		sim.step(InputFrame.new())
	ok(EnemyTestFixture.index_matches(sim), "cross bucket final index exact")
	eq(sim.query_enemies(Vector2(64, 64), 1.0), [])
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.DESPAWN_ENEMY
	cmd.entity_id = 1
	sim.apply(cmd)
	ok(EnemyTestFixture.index_matches(sim), "removed identity absent from all buckets")
