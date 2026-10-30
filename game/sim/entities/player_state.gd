class_name PlayerState
extends RefCounted

# 外部只读；仅Sim维护。
var position: Vector2 = Vector2.ZERO
var radius: float = PlayerConfig.BODY_RADIUS
var move_speed_bonus: float = 0.0
var character_id: StringName = &"knight"
