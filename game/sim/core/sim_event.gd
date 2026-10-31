class_name SimEvent
extends RefCounted

enum Kind { SPAWNED, DESPAWNED, COMMAND_FAILED, STATS_CHANGED }
var kind: Kind
var entity_id: int
var reason: String

func _init(event_kind: Kind, id: int = -1, failure_reason: String = "") -> void:
	kind = event_kind
	entity_id = id
	reason = failure_reason
