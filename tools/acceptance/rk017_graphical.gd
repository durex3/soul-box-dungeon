extends SceneTree
## 图形事件真实经过_input/GUI/_unhandled_input与正式driver，非实物设备试玩。

var lab: WeaponLab
var failed: bool = false
var out: String
var texts: Dictionary = {}
var coordinates: Array[Dictionary] = []
var original_cursor: Vector2i

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		print("RK017 GRAPH FAIL ",message)
		failed = true

func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _motion(point: Vector2, local: bool = true) -> void:
	root.warp_mouse(point if local else root.get_final_transform().affine_inverse()*point)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	root.push_input(event,local)

func _mouse(pressed: bool, point: Vector2 = Vector2(240,260), button: MouseButton = MOUSE_BUTTON_LEFT, local: bool = true) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event,local)

func _key(pressed: bool, echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.keycode = KEY_Q
	event.pressed = pressed
	event.echo = echo
	root.push_input(event,true)

func _click(key: String) -> void:
	await _settle()
	var point: Vector2 = lab.controls[key].get_global_rect().get_center()
	_motion(point)
	_mouse(true,point)
	_mouse(false,point)
	await _settle()

func _advance(count: int) -> void:
	# 在一个渲染帧内向原有driver注入一次delta，观察其真实补步采样。
	lab.set_paused(false)
	var remaining: int = count
	while remaining>0:
		var chunk: int = mini(14,remaining)
		lab.driver.reset()
		lab.driver._process((chunk+0.125)*Sim.DT)
		remaining -= chunk

func _case(mode: int) -> void:
	_mouse(false)
	lab.reset_run()
	lab.driver.set_process(false)
	lab.set_mode(mode)
	lab.set_paused(false)

func _cache() -> void:
	_case(WeaponState.FireMode.TOGGLE)
	_motion(Vector2(240,260))
	_mouse(true)
	_key(true)
	_key(true,true)
	_key(false)
	_mouse(true,Vector2(240,260),MOUSE_BUTTON_WHEEL_UP)
	_mouse(false,Vector2(240,260),MOUSE_BUTTON_WHEEL_UP)
	_mouse(true,Vector2(240,260),MOUSE_BUTTON_WHEEL_DOWN)
	await create_timer(0.08).timeout
	_check(lab.steps==0 and lab.sampled_edges.is_empty(),"no logical step retains queued edges")
	var draw_frame: int = Engine.get_frames_drawn()
	_advance(3)
	_check(Engine.get_frames_drawn()==draw_frame,"three logical samples in same rendered frame")
	_check(lab.sampled_edges==[Vector2i(1,1),Vector2i(0,0),Vector2i(0,0)],"edge cache consumed once")
	_check(lab.last_input.fire_held and lab.sim.state.player.weapon.firing and lab.sim.state.player.weapon.active_slot==1,"held/toggle and Q survive first sample only")
	print("RK017 cache render_frame=",draw_frame," samples=",lab.sampled_edges," steps=",lab.steps)
	_check(lab.controls.Identity.text.contains("apprentice_fire_staff") and lab.controls.Identity.text.contains("12.00") and lab.controls.Timing.text.contains("2.00 / 2.00"),"new-slot panel shows base damage/rate")
	await _settle()
	_audit()
	_check(root.get_texture().get_image().save_png(out.path_join("cache_staff_640.png"))==OK,"staff panel PNG")
	_mouse(false)
	_advance(1)
	_check(not lab.last_input.fire_held and lab.sim.state.player.weapon.firing,"release clears held but not toggle")
	_case(WeaponState.FireMode.TOGGLE)
	for i: int in 2:
		_mouse(true)
		_mouse(false)
	_advance(1)
	_check(lab.last_input.fire_presses==2 and not lab.sim.state.player.weapon.firing and lab.fired_frames.is_empty(),"two full short clicks net toggle off")
	_case(WeaponState.FireMode.HOLD)
	_mouse(true)
	_mouse(false)
	_advance(1)
	_check(lab.last_input.fire_presses==1 and lab.counts[0]==1 and not lab.sim.state.player.weapon.firing,"full HOLD short press retained")
	_case(WeaponState.FireMode.HOLD)
	_key(true)
	_key(false)
	_key(true)
	_key(false)
	_advance(1)
	_check(lab.last_input.switch_steps==2 and lab.sim.state.player.weapon.active_slot==0 and lab.last_events.is_empty(),"two switches return original without event")
	_mouse(true,Vector2(240,260),MOUSE_BUTTON_WHEEL_DOWN)
	_mouse(false,Vector2(240,260),MOUSE_BUTTON_WHEEL_DOWN)
	_advance(1)
	_check(lab.last_input.switch_steps==-1 and lab.sim.state.player.weapon.active_slot==1,"wheel previous is one edge, never held")

func _gui_and_lifecycle() -> void:
	_case(WeaponState.FireMode.HOLD)
	await _click("Toggle")
	_advance(1)
	_check(lab.sim.state.player.weapon.fire_mode==WeaponState.FireMode.TOGGLE and lab.counts==[0,0] and lab.last_input.fire_presses==0,"mode GUI hit without firing")
	var gui: Vector2 = lab.controls.Speed.get_global_rect().get_center()
	_motion(gui)
	_mouse(true,gui,MOUSE_BUTTON_WHEEL_UP)
	_mouse(false,gui,MOUSE_BUTTON_WHEEL_UP)
	_advance(1)
	_check(lab.last_input.switch_steps==0,"GUI wheel never switches weapon")
	_motion(Vector2(240,260))
	_mouse(true)
	_advance(1)
	_check(lab.sim.state.player.weapon.firing and lab.counts[0]==1,"world click starts toggle")
	await _click("Speed")
	_advance(1)
	_check(lab.last_input.fire_presses==0 and not lab.last_input.fire_held and lab.sim.state.player.weapon.firing,"GUI release not sticky and GUI press not toggle")
	_check(lab.sim.state.player.stats.value(&"attack_speed")==1.0 and lab.sim.state.player.weapon.effective_shots_per_sec==3.2,"attack-speed GUI uses command")
	await _click("Pause")
	var before: Array = WeaponTestFixture.snapshot(lab.sim)
	var before_steps: int = lab.steps
	lab.driver._process(0.2)
	await create_timer(0.08).timeout
	_check(lab.paused and lab.steps==before_steps and WeaponTestFixture.snapshot(lab.sim)==before,"paused real driver never consumes cooldown")
	await _click("Step")
	_check(lab.paused and lab.steps==before_steps+1,"GUI single step exactly one")
	lab.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not lab.sim.state.player.weapon.firing,"focus out command stops continuous fire")
	lab.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_advance(2)
	_check(lab.last_input.fire_presses==0 and not lab.last_input.fire_held and not lab.sim.state.player.weapon.firing,"focus in never resumes physical held state")
	await _click("Reset")
	_check(lab.steps==0 and lab.counts==[0,0] and not lab.sim.state.player.weapon.firing,"GUI rebuild fresh run and input reset")
	_case(WeaponState.FireMode.HOLD)
	_mouse(true)
	_advance(1)
	_motion(gui)
	_mouse(false,gui)
	_advance(1)
	_check(not lab.last_input.fire_held and not lab.sim.state.player.weapon.firing,"HOLD release over GUI stops")
	_mouse(true)
	lab.collector.reset()
	_advance(1)
	_check(not lab.last_input.fire_held and lab.last_input.fire_presses==0,"reset while physically held never polls a synthetic press")
	_mouse(false)
	_mouse(true)
	_advance(1)
	_check(lab.last_input.fire_presses==1,"fresh press after reset accepted")
	_mouse(false)

func _wait_steps(count: int) -> void:
	var target: int = lab.steps+count
	while lab.steps<target:
		await process_frame

func _live_driver() -> void:
	_case(WeaponState.FireMode.HOLD)
	_motion(Vector2(240,260))
	_mouse(true)
	lab.driver.set_process(true)
	await _wait_steps(12)
	_check(lab.counts[0]==1,"live HOLD driver first shot")
	_key(true)
	_key(false)
	await _wait_steps(48)
	_check(lab.sim.state.player.weapon.active_slot==1 and lab.counts[1]>=1,"live Q switch while held fires new slot")
	_check(lab.fired_frames.size()>=2 and lab.fired_frames[1]==39,"live shared cooldown event frame")
	_mouse(false)
	await _wait_steps(2)
	_check(not lab.sim.state.player.weapon.firing,"live release stops HOLD")
	print("RK017 live HOLD steps=",lab.steps," counts=",lab.counts," shot_frames=",lab.fired_frames)
	lab.driver.set_process(false)
	_case(WeaponState.FireMode.TOGGLE)
	_mouse(true)
	_mouse(false)
	lab.driver.set_process(true)
	await _wait_steps(60)
	_check(lab.counts[0]>=2 and lab.sim.state.player.weapon.firing,"live toggle short click continues")
	_mouse(true)
	_mouse(false)
	await _wait_steps(2)
	_check(not lab.sim.state.player.weapon.firing,"live second click stops toggle")
	print("RK017 live TOGGLE steps=",lab.steps," counts=",lab.counts," shot_frames=",lab.fired_frames)
	lab.driver.set_process(false)
	lab.set_paused(true)

func _audit() -> void:
	for control: Control in lab.controls.values():
		var font: Font = control.get_theme_font("font")
		_check(font is FontFile and font.resource_path=="res://assets/fonts/fusion-pixel-12px-zh_hans.woff2" and not font.allow_system_fallback,"project font "+control.name)
		_check(control.get_theme_font_size("font_size")==12,"font size "+control.name)
		texts[control.text] = true
		for c: String in control.text:
			if c.unicode_at(0)>=32:
				_check(font.has_char(c.unicode_at(0)),"missing glyph "+c)
		_check(root.get_visible_rect().encloses(control.get_global_rect()),"viewport "+control.name)
		if control is Label:
			_check(control.get_line_count()*control.get_line_height()<=control.size.y+0.01,"label clipping "+control.name)
		else:
			_check(font.get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+control.get_theme_stylebox("normal").get_minimum_size().x<=control.size.x,"button clipping "+control.name)
		for other: Control in lab.controls.values():
			if other!=control:
				_check(not control.get_global_rect().intersects(other.get_global_rect()),"overlap "+control.name+"/"+other.name)
	_check(lab.player_view.position==lab.sim.state.player.position and lab.player_view.rotation==0.0,"player exact position without aim rotation")

func _coordinates_and_screens() -> void:
	for sizes: Array in [[Vector2i(640,360),Vector2i(640,360)],[Vector2i(1280,720),Vector2i(1280,720)],[Vector2i(640,360),Vector2i(1280,720)]]:
		root.content_scale_size = sizes[0]
		root.size = sizes[1]
		_case(WeaponState.FireMode.HOLD)
		lab.camera.position = Vector2(800,450)
		lab.camera.force_update_scroll()
		await _settle()
		var local: Vector2 = Vector2(sizes[0])*0.7
		var native_point: Vector2 = root.get_final_transform()*local
		var inverse: Transform2D = lab.get_global_transform_with_canvas().affine_inverse()
		var expected: Vector2 = inverse*local
		_motion(native_point,false)
		await process_frame
		_mouse(true,native_point,MOUSE_BUTTON_LEFT,false)
		_advance(1)
		_check(root.get_mouse_position().distance_to(local)<0.01,"native window to logical mouse transform")
		_check(lab.last_input.aim_valid and lab.last_input.aim_world.distance_to(expected)<0.01,"world-coordinate input")
		var shots: Array[SimEvent] = WeaponTestFixture.fired(lab.last_events)
		_check(shots.size()==1,"world click immediate HOLD shot")
		if not shots.is_empty():
			_check(shots[0].origin==lab.sim.state.player.position and shots[0].direction.distance_to((expected-shots[0].origin).normalized())<0.00001,"event world origin/direction")
			var record: Dictionary = {"logical":str(sizes[0]),"window":str(sizes[1]),"viewport_mouse":str(root.get_mouse_position()),"native_event":str(native_point),"canvas_inverse":str(inverse),"aim_world":str(lab.last_input.aim_world),"origin":str(shots[0].origin),"direction":str(shots[0].direction)}
			coordinates.append(record)
			print("RK017 coordinates ",JSON.stringify(record))
		await RenderingServer.frame_post_draw
		_audit()
		var name: String = "hold_%d_window%d" % [sizes[0].x,sizes[1].x]
		_check(root.get_texture().get_image().save_png(out.path_join(name+".png"))==OK,"actual HOLD PNG")
		_mouse(false,native_point,MOUSE_BUTTON_LEFT,false)
		await _click("Toggle")
		_motion(native_point,false)
		await process_frame
		_mouse(true,native_point,MOUSE_BUTTON_LEFT,false)
		_mouse(false,native_point,MOUSE_BUTTON_LEFT,false)
		_advance(45)
		_check(lab.sim.state.player.weapon.firing and lab.counts[0]>1,"toggle continues after release")
		await RenderingServer.frame_post_draw
		_audit()
		_check(root.get_texture().get_image().save_png(out.path_join("toggle_%d_window%d.png" % [sizes[0].x,sizes[1].x]))==OK,"actual TOGGLE PNG")

func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	original_cursor = DisplayServer.mouse_get_position()
	root.size = Vector2i(640,360)
	root.content_scale_size = root.size
	root.grab_focus()
	await create_timer(0.2).timeout
	lab = (load("res://app/dev/weapon_lab.tscn") as PackedScene).instantiate() as WeaponLab
	root.add_child(lab)
	lab.driver.set_process(false)
	await _settle()
	_case(WeaponState.FireMode.HOLD)
	_motion(Vector2(480,260))
	await process_frame
	_mouse(true,Vector2(480,260))
	_advance(1)
	await RenderingServer.frame_post_draw
	_audit()
	_check(root.get_texture().get_image().save_png(out.path_join("default_hold_640.png"))==OK,"default camera HOLD PNG")
	await _cache()
	if not "--cache" in OS.get_cmdline_user_args():
		await _gui_and_lifecycle()
		await _live_driver()
		await _coordinates_and_screens()
	var file: FileAccess = FileAccess.open(out.path_join("graphical.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"texts":texts.keys(),"coordinates":coordinates,"synthetic_input":true,"failed":failed},"\t")+"\n")
	file.close()
	DisplayServer.warp_mouse(original_cursor)
	lab.queue_free()
	await process_frame
	print("RK017_GRAPHICAL: "+("failed" if failed else "passed"))
	quit(1 if failed else 0)
