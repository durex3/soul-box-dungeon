extends SceneTree

var _sim: Sim
var _driver: FixedStepDriver
var _steps: int = 0
var _input: InputFrame = InputFrame.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Engine.max_fps = int(args[0])
	_sim = Sim.new(1, &"knight", float(args[1]))
	_input.move_direction = Vector2.RIGHT
	_driver = FixedStepDriver.new()
	_driver.configure(_step)
	root.add_child(_driver)
	await create_timer(0.2).timeout
	_driver.reset()
	_sim = Sim.new(1, &"knight", float(args[1]))
	_steps = 0
	var start: int = Time.get_ticks_usec()
	await create_timer(1.0).timeout
	_driver.set_paused(true)
	var elapsed: float = (Time.get_ticks_usec() - start) / 1000000.0
	var distance: float = _sim.state.player.position.x - 640.0
	var speed: float = 64.0 * (1 + float(args[1]))
	print("RK012 timing fps=", args[0], " bonus=", args[1], " seconds=", elapsed, " steps=", _steps, " position=", _sim.state.player.position, " distance=", distance)
	if absf(distance - _steps * Sim.DT * speed) > 0.01 or absf(distance - speed) > 2.0:
		push_error("RK012 timing distance mismatch")
		quit(1)
		return
	print("RK012_DRIVER: passed")
	quit()

func _step() -> void:
	_sim.step(_input)
	_steps += 1
