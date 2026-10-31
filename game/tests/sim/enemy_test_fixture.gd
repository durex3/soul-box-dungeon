class_name EnemyTestFixture
extends RefCounted
## 测试与验收的独立参考统计；生产代码不得引用本类。

## 通过正式命令创建敌人，返回真实命令事件。
static func spawn(sim: Sim, at: Vector2, type: StringName = &"skeleton_rat", wave: int = 1, danger: int = 0) -> SimEvent:
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SPAWN_ENEMY
	cmd.enemy_type = type
	cmd.position = at
	cmd.wave = wave
	cmd.danger_level = danger
	return sim.apply(cmd)[0]

## 固定20列10行，严格保留任务夹具坐标与数量。
static func standard(sim: Sim) -> void:
	for y: int in 10:
		for x: int in 20:
			spawn(sim, Vector2(64 + 24 * x, 64 + 24 * y))

## 独立全体遍历计算每只最近邻，索引不参与参考结果。
static func density(sim: Sim) -> Dictionary:
	var distances: Array[float] = []
	var below: int = 0
	for a: EnemyState in sim.state.enemies:
		var nearest: float = INF
		for b: EnemyState in sim.state.enemies:
			if a.entity_id != b.entity_id:
				nearest = minf(nearest, a.position.distance_to(b.position))
		distances.append(nearest)
		if nearest < 14.0:
			below += 1
	distances.sort()
	return {"min": distances[0] if not distances.is_empty() else 0.0, "p5": distances[maxi(0, ceili(distances.size() * 0.05) - 1)] if not distances.is_empty() else 0.0, "median": (distances[floori((distances.size() - 1) * 0.5)] + distances[floori(distances.size() * 0.5)]) * 0.5 if not distances.is_empty() else 0.0, "below14": below}

## 查询结果必须精确等于所有当前中心点的独立参考升序列表。
static func index_matches(sim: Sim) -> bool:
	for enemy: EnemyState in sim.state.enemies:
		for radius: float in [0.0, 23.0, 100.0]:
			var expected: Array[int] = []
			for other: EnemyState in sim.state.enemies:
				if other.position.distance_squared_to(enemy.position) <= radius * radius:
					expected.append(other.entity_id)
			if sim.query_enemies(enemy.position, radius) != expected:
				return false
	return sim.query_enemies(Vector2(640, 360), 2000.0).size() == sim.state.enemies.size()

## 所有逻辑圆保持有限且完整在场地中，身份严格升序。
static func valid(sim: Sim, expected_count: int = 0) -> bool:
	var last_id: int = 0
	for enemy: EnemyState in sim.state.enemies:
		if not enemy.position.is_finite() or not ArenaBounds.contains_circle(enemy.position, enemy.radius) or enemy.entity_id <= last_id:
			return false
		last_id = enemy.entity_id
	# 严格升序、正ID、count=N且末ID=N共同保证身份恰为1…N。
	return expected_count == 0 or (last_id == expected_count and sim.state.enemies.size() == expected_count)

## 逐属性保存纯值，避免误比较同一引用或漏掉hp等字段。
static func snapshot(sim: Sim) -> Array:
	var result: Array = [sim.state.player.entity_id, sim.state.player.position]
	for e: EnemyState in sim.state.enemies:
		result.append([e.entity_id, e.enemy_type, e.position, e.radius, e.max_hp, e.hp, e.damage, e.move_speed, e.xp, e.spawn_wave, e.danger_level])
	return result

## 四条随机流只读状态，不抽取随机数。
static func rng_states(sim: Sim) -> Array[int]:
	return [sim.rng.spawn.state, sim.rng.shop.state, sim.rng.loot.state, sim.rng.upgrade.state]
