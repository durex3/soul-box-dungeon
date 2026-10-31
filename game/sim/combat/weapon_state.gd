class_name WeaponState
extends RefCounted

enum FireMode { HOLD, TOGGLE }
# 外部只读；两槽共享一个冷却，不持有数据表行引用。
var slots: Array[StringName] = [&"", &""]
var active_slot: int = 0
var fire_mode: FireMode = FireMode.HOLD
var firing: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
var cooldown_remaining: float = 0.0
var release_required: bool = false
var fire_was_held: bool = false
# 只读面板数据，Sim在装备/切槽/属性变化及逻辑步更新。
var base_damage: float = 0.0
var base_shots_per_sec: float = 0.0
var effective_shots_per_sec: float = 0.0
