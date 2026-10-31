class_name Sim
extends RefCounted

const DT: float = 1.0 / 60.0
const ID_HASH_MIX: int = 0x45d9f3b
const ID_HASH_MASK: int = 0xffffffff

# 外部只读约定。
var state: RunState = RunState.new()
var _next_entity_id: int = 1
var _enemy_index: SpatialHash = SpatialHash.new()
var _enemies_by_id: Dictionary = {}
var rng: RunRng

func _init(seed_value: int, character_id: StringName, initial_move_speed_bonus: float = 0.0) -> void:
	rng = RunRng.new(seed_value)
	state.player.character_id = character_id
	state.player.position = ArenaBounds.play_rect().get_center()
	state.player.move_speed_bonus = clampf(initial_move_speed_bonus, Balance.STAT_BASE[&"move_speed"], Balance.STAT_CAP[&"move_speed"])

## 固定步先更新玩家，再按ID追击和分离；运动暂不产生事件。
func step(input: InputFrame) -> Array[SimEvent]:
	var direction: Vector2 = input.move_direction.limit_length(1.0)
	var speed: float = PlayerConfig.BASE_MOVE_TILES_PER_SECOND * ArenaConfig.TILE_PX * (1.0 + state.player.move_speed_bonus)
	var next: Vector2 = state.player.position + direction * speed * DT
	state.player.position = ArenaBounds.clamp_position(next, state.player.radius)
	_move_enemies()
	var events: Array[SimEvent] = []
	return events

## 两次逻辑步之间处理出生/移除意图，事件表示对应状态改变已完成。
func apply(cmd: Command) -> Array[SimEvent]:
	if cmd == null:
		return [SimEvent.new(SimEvent.Kind.COMMAND_FAILED, -1, "空命令")]
	match cmd.kind:
		Command.Kind.SPAWN_ENEMY:
			var enemy: EnemyState = EnemyFactory.build(cmd.enemy_type, _next_entity_id, cmd.position, cmd.wave, cmd.danger_level)
			if enemy == null:
				return [SimEvent.new(SimEvent.Kind.COMMAND_FAILED, -1, "敌人类型、波次或危险等级无效")]
			_next_entity_id += 1
			state.enemies.append(enemy)
			_enemies_by_id[enemy.entity_id] = enemy
			_enemy_index.insert(enemy.entity_id, enemy.position)
			return [SimEvent.new(SimEvent.Kind.SPAWNED, enemy.entity_id)]
		Command.Kind.DESPAWN_ENEMY:
			if not _enemies_by_id.has(cmd.entity_id):
				return [SimEvent.new(SimEvent.Kind.COMMAND_FAILED, cmd.entity_id, "敌人不存在")]
			state.enemies.erase(_enemies_by_id[cmd.entity_id])
			_enemies_by_id.erase(cmd.entity_id)
			_enemy_index.remove(cmd.entity_id)
			return [SimEvent.new(SimEvent.Kind.DESPAWNED, cmd.entity_id)]
		_:
			return [SimEvent.new(SimEvent.Kind.COMMAND_FAILED, -1, "未知命令")]

## 只读查询敌人中心点，返回独立的升序ID列表，不包含玩家。
func query_enemies(center: Vector2, radius: float) -> Array[int]:
	return _enemy_index.query_circle(center, radius)

func _move_enemies() -> void:
	var maximum_radius: float = 0.0
	for enemy: EnemyState in state.enemies:
		enemy.position = ArenaBounds.clamp_position(enemy.position.move_toward(state.player.position, enemy.move_speed * DT), enemy.radius)
		_enemy_index.move(enemy.entity_id, enemy.position)
		maximum_radius = maxf(maximum_radius, enemy.radius)
	for iteration: int in EnemyConfig.SEPARATION_ITERATIONS:
		if iteration == 0 and _separate_coincident():
			continue
		for enemy: EnemyState in state.enemies:
			# 索引始终同步到最新坐标；候选和实体均升序，每对每轮只处理一次。
			for id: int in _enemy_index.query_circle(enemy.position, enemy.radius + maximum_radius):
				if id <= enemy.entity_id:
					continue
				var other: EnemyState = _enemies_by_id[id]
				var offset: Vector2 = other.position - enemy.position
				var distance: float = offset.length()
				var diameter: float = enemy.radius + other.radius
				if distance >= diameter:
					continue
				var direction: Vector2 = offset / distance if distance > 0.0 else _coincident_direction(enemy.entity_id, other.entity_id)
				var correction: Vector2 = direction * (diameter - distance) * 0.5
				enemy.position = ArenaBounds.clamp_position(enemy.position - correction, enemy.radius)
				other.position = ArenaBounds.clamp_position(other.position + correction, other.radius)
				_enemy_index.move(enemy.entity_id, enemy.position)
				_enemy_index.move(other.entity_id, other.position)

func _separate_coincident() -> bool:
	# 本轮完全同点的对先按同一快照累计修正，避免首对修正后其余对都退化到同一直线。
	# 该阶段占用一轮预算；仅用正式索引查询零距离候选，提交前不移动索引。
	var offsets: Dictionary = {}
	for enemy: EnemyState in state.enemies:
		for id: int in _enemy_index.query_circle(enemy.position, 0.0):
			if id <= enemy.entity_id:
				continue
			var other: EnemyState = _enemies_by_id[id]
			var correction: Vector2 = _coincident_direction(enemy.entity_id, id) * (enemy.radius + other.radius) * 0.5
			offsets[enemy.entity_id] = offsets.get(enemy.entity_id, Vector2.ZERO) - correction
			offsets[id] = offsets.get(id, Vector2.ZERO) + correction
	for enemy: EnemyState in state.enemies:
		if offsets.has(enemy.entity_id):
			enemy.position = ArenaBounds.clamp_position(enemy.position + offsets[enemy.entity_id], enemy.radius)
			_enemy_index.move(enemy.entity_id, enemy.position)
	return not offsets.is_empty()

func _coincident_direction(low_id: int, high_id: int) -> Vector2:
	# 有序ID对的确定性32位整数混合映射单位方向；不消耗任何随机子流。
	var mixed: int = ((low_id * 73856093) ^ (high_id * 19349663)) & ID_HASH_MASK
	mixed = ((mixed ^ (mixed >> 16)) * ID_HASH_MIX) & ID_HASH_MASK
	mixed = ((mixed ^ (mixed >> 16)) * ID_HASH_MIX) & ID_HASH_MASK
	mixed ^= mixed >> 16
	# 两个16位字段映射到有符号奇数分量再单位化，绝不会得到零向量。
	# 使用全部混合位，避免只看ID低三位时不同出生历史退化到同轴。
	return Vector2((mixed & 0xffff) * 2 - 65535, ((mixed >> 16) & 0xffff) * 2 - 65535).normalized()
