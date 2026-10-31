class_name SimEvent
extends RefCounted

enum Kind { SPAWNED, DESPAWNED, COMMAND_FAILED, STATS_CHANGED, WEAPON_EQUIPPED, FIRE_MODE_CHANGED, WEAPON_CHANGED, WEAPON_FIRED }
var kind: Kind
var entity_id: int
var reason: String

var weapon_id: StringName = &""
var slot_index: int = -1
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var base_damage: float = 0.0
var effective_shots_per_sec: float = 0.0

func _init(event_kind: Kind, id: int = -1, failure_reason: String = "") -> void:
	kind = event_kind
	entity_id = id
	reason = failure_reason
