extends SceneTree

const DRIVER_SCENE: PackedScene = preload("res://view/battle/fixed_step_driver.tscn")
const SPEED: float = 64.0
const DURATION: float = 10.0

var _cap: int = 0
var _started_usec: int = 0
var _render_frames: int = 0
var _steps: int = 0
var _distance: float = 0.0
var _finished: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_valid_int() or int(args[0]) <= 0:
		push_error("rk006_probe 需要正整数限帧参数")
		quit(1)
		return
	_cap = int(args[0])
	Engine.max_fps = _cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# 先让实际限帧稳定，避免首个 delta 含引擎启动开销。
	await process_frame
	await process_frame
	_begin.call_deferred()


func _begin() -> void:
	var driver: FixedStepDriver = DRIVER_SCENE.instantiate() as FixedStepDriver
	driver.configure(_step)
	process_frame.connect(_before_frame)
	_started_usec = Time.get_ticks_usec()
	root.add_child(driver)


func _step() -> void:
	_distance += SPEED * Sim.DT
	_steps += 1


func _before_frame() -> void:
	# process_frame 信号先于节点 _process，延迟读取以包含这一帧的驱动结果。
	_after_frame.call_deferred()


func _after_frame() -> void:
	if _finished:
		return
	_render_frames += 1
	var elapsed: float = (Time.get_ticks_usec() - _started_usec) / 1000000.0
	if elapsed < DURATION:
		return
	_finished = true
	print("RK006_RESULT " + JSON.stringify({
		"cap": _cap, "seconds": elapsed, "render_frames": _render_frames,
		"steps": _steps, "distance": _distance,
	}))
	quit(0)
