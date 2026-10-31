extends GdTest

func test_03_hold_release_short_press_and_toggle_parity() -> void:
	var sim: Sim = _sim()
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,1))).size(),1)
	sim.step(WeaponTestFixture.input(false))
	ok(not sim.state.player.weapon.firing)
	for i: int in 100:
		eq(sim.step(WeaponTestFixture.input()).size(),0)
	# 渲染帧内完整短按也可触发一次，下一步不得继续。
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(false,1))).size(),1)
	ok(not sim.state.player.weapon.firing)
	WeaponTestFixture.mode(sim, WeaponState.FireMode.TOGGLE)
	sim.step(WeaponTestFixture.input(false,2))
	ok(not sim.state.player.weapon.firing, "two presses from off net off")
	sim.step(WeaponTestFixture.input(false,1))
	ok(sim.state.player.weapon.firing)
	sim.step(WeaponTestFixture.input(false))
	ok(sim.state.player.weapon.firing, "release does not stop toggle")
	sim.step(WeaponTestFixture.input(false,1))
	ok(not sim.state.player.weapon.firing)
	WeaponTestFixture.equip(sim,0,&"")
	sim.step(WeaponTestFixture.input(false,1))
	ok(not sim.state.player.weapon.firing)
	WeaponTestFixture.equip(sim,0,&"knight_sword")
	eq(sim.step(InputFrame.new()).size(),0, "empty-slot presses never become phantom fire later")

func test_03_mode_change_stops_and_waits_for_fresh_press() -> void:
	var sim: Sim = _sim()
	sim.step(WeaponTestFixture.input(true,1))
	var cooldown: float = sim.state.player.weapon.cooldown_remaining
	eq(WeaponTestFixture.mode(sim,WeaponState.FireMode.TOGGLE)[0].kind,SimEvent.Kind.FIRE_MODE_CHANGED)
	near(sim.state.player.weapon.cooldown_remaining,cooldown)
	ok(not sim.state.player.weapon.firing and sim.state.player.weapon.release_required)
	for i: int in 100:
		eq(sim.step(WeaponTestFixture.input(true)).size(),0, "held without new edge remains locked")
	sim.step(WeaponTestFixture.input(false))
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,1))).size(),1)
	WeaponTestFixture.equip(sim,1,&"apprentice_fire_staff")
	sim.step(WeaponTestFixture.input(false,0,1))
	ok(sim.state.player.weapon.firing, "continuous state crosses slot change")
	WeaponTestFixture.mode(sim,WeaponState.FireMode.HOLD)
	ok(not sim.state.player.weapon.firing)

func test_04_fractional_cadence_frames_and_counts() -> void:
	for row: Array in [[&"knight_sword",0.0,16,37.5], [&"apprentice_fire_staff",0.0,20,30.0], [&"knight_sword",1.0,32,18.75], [&"apprentice_fire_staff",1.0,40,15.0], [&"goblin_smg",3.0,320,1.875]]:
		var sim: Sim = _sim(row[0])
		WeaponTestFixture.speed(sim,row[1])
		var frames: Array[int] = []
		for i: int in 600:
			var shots: Array[SimEvent] = WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,1 if i==0 else 0)))
			ok(shots.size()<=1)
			if not shots.is_empty():
				frames.append(i+1)
		eq(frames.size(),row[2], "600 step rate " + str(row[0]))
		for n: int in frames.size():
			eq(frames[n],1+ceili(n*row[3]-1e-9), "fractional cadence retains remainder")
		print("RK017 cadence ",row[0]," boost=",row[1]," shots=",frames.size()," first=",frames.slice(0,6))
	var long_run: Sim = _sim()
	var total: int = 0
	for i: int in 6000:
		total += WeaponTestFixture.fired(long_run.step(WeaponTestFixture.input(true))).size()
	eq(total,160, "long fractional rate never rounds to38 frames per shot")

func test_04_shared_cooldown_switch_and_reequip_preserve_time() -> void:
	var sim: Sim = _sim()
	WeaponTestFixture.equip(sim,1,&"apprentice_fire_staff")
	sim.step(WeaponTestFixture.input(true,1))
	var remaining: float = sim.state.player.weapon.cooldown_remaining
	WeaponTestFixture.equip(sim,1,&"apprentice_fire_staff")
	near(sim.state.player.weapon.cooldown_remaining,remaining,1e-12, "re-equipment preserves shared cooldown")
	for frame: int in range(2,39):
		var shots: Array[SimEvent] = WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,0,1)))
		eq(shots.size(),0, "switch cannot reset shared positive cooldown")
		near(sim.state.player.weapon.cooldown_remaining,remaining-(frame-1)*Sim.DT,1e-9)
	var next: Array[SimEvent] = WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,0,1)))
	eq(next.size(),1)
	eq(next[0].weapon_id,&"knight_sword")

func test_04_release_repress_and_stat_changes_preserve_positive_timer() -> void:
	var sim: Sim = _sim()
	sim.step(WeaponTestFixture.input(true,1))
	var remaining: float = sim.state.player.weapon.cooldown_remaining
	sim.step(WeaponTestFixture.input(false))
	ok(sim.state.player.weapon.cooldown_remaining>0.0, "release never clears positive timer")
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,1))).size(),0)
	remaining -= 2*Sim.DT
	WeaponTestFixture.equip(sim,0,&"apprentice_fire_staff")
	WeaponTestFixture.speed(sim,1.0)
	near(sim.state.player.weapon.cooldown_remaining,remaining,1e-12, "old cooldown not recalculated by new speed")
	for frame: int in range(4,39):
		eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true))).size(),0)
	var shots: Array[SimEvent] = WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true)))
	eq(shots.size(),1)
	near(shots[0].effective_shots_per_sec,4.0)
	near(shots[0].base_damage,12.0)
	near(sim.state.player.weapon.cooldown_remaining,0.25-Sim.DT*0.5,1e-9, "next interval uses new speed and prior remainder")

func test_04_idle_pause_ready_and_no_debt() -> void:
	var sim: Sim = _sim()
	sim.step(WeaponTestFixture.input(true,1))
	var before: Array = WeaponTestFixture.snapshot(sim)
	# 暂停的协议是不调用step；只读检查不能消耗冷却。
	for i: int in 100:
		eq(WeaponTestFixture.snapshot(sim),before)
	for i: int in 600:
		eq(WeaponTestFixture.fired(sim.step(InputFrame.new())).size(),0)
	near(sim.state.player.weapon.cooldown_remaining,0)
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,1))).size(),1)
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true))).size(),0, "idle never banks a burst")

func _sim(id: StringName = &"knight_sword") -> Sim:
	var sim: Sim = Sim.new(1710,&"knight")
	WeaponTestFixture.equip(sim,0,id)
	return sim

func test_04_ready_single_then_wait() -> void:
	var sim: Sim = _sim()
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true,1))).size(),1)
	eq(WeaponTestFixture.fired(sim.step(WeaponTestFixture.input(true))).size(),0,"positive cooldown prevents next-step fire")
