class_name Command
extends RefCounted

# 命令只携带意图，状态修改仍由 Sim.apply 处理。
enum Kind { SPAWN_ENEMY, DESPAWN_ENEMY, SET_STAT_MODIFIER, REMOVE_STAT_MODIFIER, SET_WEAPON_SLOT, SET_FIRE_MODE }
var kind: int = -1
var enemy_type: StringName = &""
var position: Vector2 = Vector2.ZERO
var wave: int = 1
var danger_level: int = 0
var entity_id: int = -1
var modifier_source: StringName = &""
var stat_mods: Dictionary = {}
var slot_index: int = 0
var weapon_id: StringName = &""
var fire_mode: int = 0
