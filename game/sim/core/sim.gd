class_name Sim
extends RefCounted

const DT: float = 1.0 / 60.0

# 外部只读约定。
var state: RunState = RunState.new()
var rng: RunRng

func _init(seed_value: int, character_id: StringName, initial_move_speed_bonus: float = 0.0) -> void:
	rng = RunRng.new(seed_value)
	state.player.character_id = character_id
	state.player.position = ArenaBounds.play_rect().get_center()
	state.player.move_speed_bonus = clampf(initial_move_speed_bonus, Balance.STAT_BASE[&"move_speed"], Balance.STAT_CAP[&"move_speed"])

## 推进一个固定逻辑步，仅更新玩家中心点；暂不产生事件。
func step(input: InputFrame) -> Array[SimEvent]:
	var direction: Vector2 = input.move_direction.limit_length(1.0)
	var speed: float = PlayerConfig.BASE_MOVE_TILES_PER_SECOND * ArenaConfig.TILE_PX * (1.0 + state.player.move_speed_bonus)
	var next: Vector2 = state.player.position + direction * speed * DT
	state.player.position = ArenaBounds.clamp_position(next, state.player.radius)
	var events: Array[SimEvent] = []
	return events
