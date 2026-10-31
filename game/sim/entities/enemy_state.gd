class_name EnemyState
extends RefCounted

# 外部只读；只由 Sim 的命令及逻辑步维护，不持有共享数据行。
var entity_id: int
var enemy_type: StringName
var position: Vector2
var radius: float = EnemyConfig.DEFAULT_RADIUS
var max_hp: float
var hp: float
var damage: float
var move_speed: float
var xp: float
var spawn_wave: int
var danger_level: int
