class_name PlayerState
extends RefCounted

# 外部只读；仅Sim维护。
var entity_id: int = 0
var position: Vector2 = Vector2.ZERO
var radius: float = PlayerConfig.BODY_RADIUS
# 兼容调试界面的只读镜像；Sim仅从stats同步此值。
var move_speed_bonus: float = 0.0
var character_id: StringName = &"knight"
# 外部只能查询；生产表现层不得对容器set/remove来源。
var stats: StatBlock = StatBlock.new()
var weapon: WeaponState = WeaponState.new()
