class_name EnemyFactory
extends RefCounted

## 复制表中基础值并计算出生属性；无效意图返回 null，不修改数据表。
static func build(enemy_type: StringName, entity_id: int, position: Vector2, wave: int, danger_level: int) -> EnemyState:
	if wave < 1 or danger_level < 0 or danger_level > 5:
		return null
	for row: Dictionary in EnemyTable.ROWS:
		if row["id"] != enemy_type:
			continue
		var enemy: EnemyState = EnemyState.new()
		enemy.entity_id = entity_id
		enemy.enemy_type = enemy_type
		enemy.position = ArenaBounds.clamp_position(position, enemy.radius)
		enemy.spawn_wave = wave
		enemy.danger_level = danger_level
		var hp_mult: float = Balance.DANGER_ENEMY_HP_MULT if danger_level > 0 else 1.0
		var damage_mult: float = Balance.DANGER_ENEMY_DAMAGE_MULT if danger_level > 0 else 1.0
		enemy.max_hp = row["hp"] * (1.0 + Balance.ENEMY_HP_GROWTH * (wave - 1)) * hp_mult
		enemy.hp = enemy.max_hp
		enemy.damage = row["damage"] * (1.0 + Balance.ENEMY_DAMAGE_GROWTH * (wave - 1)) * damage_mult
		enemy.xp = row["xp"] * (1.0 + Balance.ENEMY_XP_GROWTH * (wave - 1))
		enemy.move_speed = row["move_speed"] * ArenaConfig.TILE_PX
		return enemy
	return null
