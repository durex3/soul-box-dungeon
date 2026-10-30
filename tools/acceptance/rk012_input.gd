extends SceneTree

var _lab: PlayerMovementLab
var _collector: InputCollector = InputCollector.new()
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_lab = (load("res://app/dev/player_movement_lab.tscn") as PackedScene).instantiate() as PlayerMovementLab
	root.add_child(_lab)
	await process_frame
	_lab.driver.set_paused(true)
	_key(KEY_D, true)
	await _check(Vector2.RIGHT, "D")
	_key(KEY_W, true)
	await _check(Vector2(1, -1).normalized(), "diagonal")
	_key(KEY_A, true)
	await _check(Vector2.UP, "opposites cancel X")
	_key(KEY_W, false)
	await _check(Vector2.ZERO, "A+D cancel")
	_key(KEY_A, false)
	_key(KEY_D, false)
	await _check(Vector2.ZERO, "release")
	_axis(JOY_AXIS_LEFT_X, 0.1)
	await _check(Vector2.ZERO, "deadzone 0.1")
	_axis(JOY_AXIS_LEFT_X, 0.6)
	await _check(Vector2(0.5, 0), "remap 0.6 to 0.5")
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _check(Vector2.RIGHT, "full X")
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _check(Vector2(1, -1).normalized(), "joy diagonal")
	_axis(JOY_AXIS_LEFT_X, 0)
	_axis(JOY_AXIS_LEFT_Y, 0)
	_key(KEY_S, true)
	await _check(Vector2.DOWN, "back to keyboard")
	_lab.reset_run()
	var before: Vector2 = _lab.sim.state.player.position
	await create_timer(0.15).timeout
	_key(KEY_S, false)
	_lab.driver.set_paused(true)
	var p: Vector2 = _lab.sim.state.player.position
	if p.y <= before.y or _lab.player_view.position != p or _lab.steps <= 0:
		_failed = true
	print("RK012 chain steps=", _lab.steps, " state=", p, " view=", _lab.player_view.position)
	print("RK012 hand controller: synthetic InputEventJoypadMotion; no physical controller tested")
	await RenderingServer.frame_post_draw
	var path: String = "/private/tmp/rk012-movement.png"
	if root.get_texture().get_image().save_png(path) != OK:
		_failed = true
	print("RK012 screenshot ", path)
	print("RK012_INPUT: " + ("failed" if _failed else "passed"))
	_lab.queue_free()
	await process_frame
	quit(1 if _failed else 0)

func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _axis(axis: JoyAxis, strength: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = strength
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check(expected: Vector2, label: String) -> void:
	var actual: Vector2 = _collector.sample().move_direction
	_lab.reset_run()
	await create_timer(0.05).timeout
	_lab.driver.set_paused(true)
	var displacement: Vector2 = _lab.sim.state.player.position - Vector2(640, 360)
	var predicted: Vector2 = expected * (_lab.steps * Sim.DT * 64.0)
	if displacement.distance_to(predicted) > 0.01 or _lab.player_view.position != _lab.sim.state.player.position:
		_failed = true
		print("RK012 INPUT FAIL chain ", label, " displacement=", displacement, " expected=", predicted)
	if actual.distance_to(expected) > 0.001:
		_failed = true
		print("RK012 INPUT FAIL ", label, " expected=", expected, " actual=", actual)
	else:
		print("RK012 INPUT OK ", label, " ", actual)
