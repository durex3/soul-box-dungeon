class_name WeaponTestFixture
extends RefCounted

## 正式装备命令，不直接改只读WeaponState。
static func equip(sim: Sim, slot: int, id: StringName) -> Array[SimEvent]:
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SET_WEAPON_SLOT
	cmd.slot_index = slot
	cmd.weapon_id = id
	return sim.apply(cmd)

## 正式射击模式命令。
static func mode(sim: Sim, value: int) -> Array[SimEvent]:
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SET_FIRE_MODE
	cmd.fire_mode = value
	return sim.apply(cmd)

## 正式RK014属性命令。
static func speed(sim: Sim, value: float) -> Array[SimEvent]:
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SET_STAT_MODIFIER
	cmd.modifier_source = &"weapon_test_speed"
	cmd.stat_mods = {&"attack_speed": value, &"damage": 9.0, &"melee_damage": 3.0, &"crit_chance": 1.0}
	return sim.apply(cmd)

## 仅构建输入意图，每次返回独立实例。
static func input(held: bool = false, presses: int = 0, switches: int = 0) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.fire_held = held
	frame.fire_presses = presses
	frame.switch_steps = switches
	return frame

## 保留事件序列中的真实开火快照。
static func fired(events: Array[SimEvent]) -> Array[SimEvent]:
	var shots: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.WEAPON_FIRED:
			shots.append(event)
	return shots

## 逐字段纯值快照，捕获失败命令及重放中的任何状态改变。
static func snapshot(sim: Sim) -> Array:
	var w: WeaponState = sim.state.player.weapon
	return [w.slots.duplicate(), w.active_slot, w.fire_mode, w.firing, w.aim_direction, w.cooldown_remaining, w.release_required, w.fire_was_held, w.base_damage, w.base_shots_per_sec, w.effective_shots_per_sec, sim.state.player.stats.snapshot(), EnemyTestFixture.snapshot(sim), EnemyTestFixture.rng_states(sim)]

## 输入对象自身不应被模拟消费或重写。
static func input_snapshot(frame: InputFrame) -> Array:
	return [frame.move_direction, frame.aim_world, frame.aim_valid, frame.fire_held, frame.fire_presses, frame.switch_steps]

## 事件只比较标量和Vector2快照，不比较引用身份。
static func event_snapshot(events: Array[SimEvent]) -> Array:
	var result: Array = []
	for e: SimEvent in events:
		result.append([e.kind, e.entity_id, e.reason, e.weapon_id, e.slot_index, e.origin, e.direction, e.base_damage, e.effective_shots_per_sec])
	return result
