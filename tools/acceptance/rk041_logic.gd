extends SceneTree
## 运行正式GdTest方法，亦供故意改坏的定点检查调用。

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var failed: bool = false
	if args.size() == 2:
		var script: Script = load(args[0]) as Script
		var test: GdTest = script.new() as GdTest
		test.call(args[1])
		for failure: String in test.get_failures():
			print("RK041 FAIL ", failure)
		failed = not test.get_failures().is_empty()
	else:
		var start: int = Time.get_ticks_usec()
		var sim: Sim = Sim.new(41, &"knight")
		EnemyTestFixture.standard(sim)
		var total: int = 0
		var maximum: int = 0
		for i: int in 600:
			var before: int = Time.get_ticks_usec()
			sim.step(InputFrame.new())
			var duration: int = Time.get_ticks_usec() - before
			total += duration
			maximum = maxi(maximum, duration)
			failed = failed or not EnemyTestFixture.valid(sim) or sim.state.enemies.size() != 200
		var stats: Dictionary = EnemyTestFixture.density(sim)
		print("RK041 metrics iterations=%d count=%d steps=600 min=%.6f p5=%.6f median=%.6f below14=%d mean_us=%.2f max_us=%d total_ms=%.2f" % [EnemyConfig.SEPARATION_ITERATIONS, sim.state.enemies.size(), stats.min, stats.p5, stats.median, stats.below14, total / 600.0, maximum, (Time.get_ticks_usec() - start) / 1000.0])
		failed = failed or stats.min < 8.0 or stats.below14 > 10 or not EnemyTestFixture.index_matches(sim)
		# 正式入口删除/重生，不依赖数组下标身份。
		var cmd: Command = Command.new()
		cmd.kind = Command.Kind.DESPAWN_ENEMY
		cmd.entity_id = 100
		failed = failed or sim.apply(cmd)[0].kind != SimEvent.Kind.DESPAWNED
		failed = failed or EnemyTestFixture.spawn(sim, sim.state.player.position).entity_id != 201
		failed = failed or not EnemyTestFixture.index_matches(sim)
		var coincident: Sim = Sim.new(42, &"knight")
		for i: int in 3:
			EnemyTestFixture.spawn(coincident, coincident.state.player.position)
		for i: int in 8:
			coincident.step(InputFrame.new())
		print("RK041 coincident ", EnemyTestFixture.density(coincident))
		failed = failed or EnemyTestFixture.density(coincident).min < 14.0 or not EnemyTestFixture.index_matches(coincident)
	print("RK041_LOGIC: " + ("failed" if failed else "passed"))
	quit(1 if failed else 0)
