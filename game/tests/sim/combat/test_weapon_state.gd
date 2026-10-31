extends GdTest

func test_01_empty_independence_equipment_clear_and_atomic_errors() -> void:
	var table_before: String = var_to_str(WeaponTable.ROWS)
	var sim: Sim = Sim.new(1701, &"knight")
	var other: Sim = Sim.new(1701, &"knight")
	var w: WeaponState = sim.state.player.weapon
	eq(w.slots, [&"", &""])
	eq(w.active_slot, 0)
	eq(w.aim_direction, Vector2.RIGHT)
	ok(not w.firing and w.cooldown_remaining == 0.0)
	eq(sim.step(InputFrame.new()).size(), 0)
	_check_command(WeaponTestFixture.equip(sim, 0, &"knight_sword"), SimEvent.Kind.WEAPON_EQUIPPED)
	_check_command(WeaponTestFixture.equip(sim, 1, &"knight_sword"), SimEvent.Kind.WEAPON_EQUIPPED)
	eq(other.state.player.weapon.slots, [&"", &""])
	EnemyTestFixture.spawn(sim, Vector2(100, 100))
	sim.step(WeaponTestFixture.input(true, 1))
	var before: Array = WeaponTestFixture.snapshot(sim)
	for request: Array in [[-1, &"knight_sword"], [2, &"knight_sword"], [0, &"missing"]]:
		var events: Array[SimEvent] = WeaponTestFixture.equip(sim, request[0], request[1])
		eq(events.size(), 1)
		eq(events[0].kind, SimEvent.Kind.COMMAND_FAILED)
		eq(WeaponTestFixture.snapshot(sim), before)
	for mode: int in [-1, 2]:
		eq(WeaponTestFixture.mode(sim, mode)[0].kind, SimEvent.Kind.COMMAND_FAILED)
		eq(WeaponTestFixture.snapshot(sim), before)
	var cooldown: float = w.cooldown_remaining
	WeaponTestFixture.equip(sim, 0, &"")
	eq(w.active_slot, 1)
	ok(w.firing, "firing survives automatic valid-slot selection")
	near(w.cooldown_remaining, cooldown)
	WeaponTestFixture.equip(sim, 1, &"")
	ok(not w.firing)
	near(w.cooldown_remaining, cooldown)
	eq(sim.step(WeaponTestFixture.input(true)).size(), 0)
	ok(not w.firing, "empty weapons cannot retain phantom continuous state")
	eq(EnemyTestFixture.spawn(sim, Vector2(200, 100)).entity_id, 2, "weapon events consume no enemy IDs")
	ok(EnemyTestFixture.index_matches(sim))
	eq(var_to_str(WeaponTable.ROWS), table_before)

func test_01_all_eight_table_values_and_event_snapshot() -> void:
	var references: Array = [[&"knight_sword",18.0,1.6], [&"great_hammer",32.0,0.9], [&"apprentice_fire_staff",12.0,2.0], [&"frost_staff",12.0,2.0], [&"old_revolver",10.0,3.0], [&"double_shotgun",6.0,1.0], [&"goblin_smg",5.0,8.0], [&"starlight_bow",40.0,0.8]]
	for row: Array in references:
		var sim: Sim = Sim.new(1702, &"knight")
		var streams: Array[int] = EnemyTestFixture.rng_states(sim)
		WeaponTestFixture.equip(sim, 0, row[0])
		WeaponTestFixture.speed(sim, 1.0)
		var shots: Array[SimEvent] = WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true, 1)))
		eq(shots.size(), 1)
		var shot: SimEvent = shots[0]
		eq(shot.entity_id, 0)
		eq(shot.weapon_id, row[0])
		eq(shot.slot_index, 0)
		near(shot.base_damage, row[1], 0.000001, "base damage excludes player damage/crit multipliers")
		near(shot.effective_shots_per_sec, row[2] * 2.0)
		var old: Array = WeaponTestFixture.event_snapshot(shots)
		WeaponTestFixture.equip(sim, 0, &"starlight_bow")
		WeaponTestFixture.speed(sim, 3.0)
		eq(WeaponTestFixture.event_snapshot(shots), old, "old event is a value snapshot")
		eq(EnemyTestFixture.rng_states(sim), streams)

func test_02_cardinal_diagonal_coincident_and_invalid_aim() -> void:
	var sim: Sim = Sim.new(1703, &"knight")
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1,1).normalized()]:
		var input: InputFrame = InputFrame.new()
		input.aim_valid = true
		input.aim_world = Vector2(640,360) + direction * 100
		sim.step(input)
		ok(sim.state.player.weapon.aim_direction.distance_to(direction) < 0.00001)
	var old: Vector2 = sim.state.player.weapon.aim_direction
	_input_aim(sim, Vector2(640,360), true)
	eq(sim.state.player.weapon.aim_direction, old, "coincident aim preserves last direction")
	_input_aim(sim, Vector2(NAN,0), true)
	_input_aim(sim, Vector2.ZERO, false)
	eq(sim.state.player.weapon.aim_direction, old)
	ok(old.is_finite() and old != Vector2.ZERO)

func test_02_move_then_aim_switch_then_fire_new_slot() -> void:
	var sim: Sim = Sim.new(1704, &"knight")
	WeaponTestFixture.equip(sim, 0, &"knight_sword")
	WeaponTestFixture.equip(sim, 1, &"apprentice_fire_staff")
	WeaponTestFixture.speed(sim, 1.0)
	var input: InputFrame = WeaponTestFixture.input(true, 1, 1)
	input.move_direction = Vector2.RIGHT
	input.aim_valid = true
	input.aim_world = Vector2(640,460)
	var events: Array[SimEvent] = sim.step(input)
	eq(events.size(), 2)
	eq(events[0].kind, SimEvent.Kind.WEAPON_CHANGED)
	eq(events[1].kind, SimEvent.Kind.WEAPON_FIRED)
	var origin: Vector2 = Vector2(640,360) + Vector2(64.0/60.0,0)
	for event: SimEvent in events:
		eq(event.weapon_id, &"apprentice_fire_staff")
		eq(event.slot_index, 1)
		eq(event.origin, origin)
		ok(event.direction.distance_to((input.aim_world-origin).normalized()) < 0.00001)
		near(event.base_damage, 12)
		near(event.effective_shots_per_sec, 4)
	# 净偶数切换和目标空槽均不产生虚假换槽事件。
	eq(sim.step(WeaponTestFixture.input(false,0,2)).size(), 0)
	WeaponTestFixture.equip(sim, 0, &"")
	eq(sim.step(WeaponTestFixture.input(false,0,-1)).size(), 0)
	eq(sim.state.player.weapon.active_slot, 1)

func test_05_replay_input_immutability_and_event_values() -> void:
	var a: Sim = Sim.new(1705, &"knight")
	var b: Sim = Sim.new(1705, &"knight")
	for sim: Sim in [a,b]:
		WeaponTestFixture.equip(sim, 0, &"knight_sword")
		WeaponTestFixture.equip(sim, 1, &"apprentice_fire_staff")
		WeaponTestFixture.mode(sim, WeaponState.FireMode.TOGGLE)
		EnemyTestFixture.spawn(sim, Vector2(100,100))
	var rng_before: Array[int] = EnemyTestFixture.rng_states(a)
	for i: int in 240:
		if i == 100:
			WeaponTestFixture.speed(a,1)
			WeaponTestFixture.speed(b,1)
		var frame: InputFrame = WeaponTestFixture.input(i%20<10, 1 if i%20==0 else 0, 1 if i%31==0 else 0)
		frame.move_direction = Vector2(0.5,0)
		frame.aim_valid = true
		frame.aim_world = Vector2(900,500)
		var before: Array = WeaponTestFixture.input_snapshot(frame)
		var first: Array[SimEvent] = a.step(frame)
		var second: Array[SimEvent] = b.step(frame)
		eq(WeaponTestFixture.input_snapshot(frame), before, "Sim never consumes shared input object")
		eq(WeaponTestFixture.event_snapshot(first), WeaponTestFixture.event_snapshot(second))
		eq(WeaponTestFixture.snapshot(a), WeaponTestFixture.snapshot(b))
		eq(EnemyTestFixture.rng_states(a), rng_before)
	ok(EnemyTestFixture.index_matches(a))

func _check_command(events: Array[SimEvent], kind: SimEvent.Kind) -> void:
	eq(events.size(),1)
	eq(events[0].kind,kind)
	eq(events[0].entity_id,0)

func _input_aim(sim: Sim, point: Vector2, valid: bool) -> void:
	var input: InputFrame = InputFrame.new()
	input.aim_world = point
	input.aim_valid = valid
	sim.step(input)
