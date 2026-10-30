class_name PlayerMovementLab
extends Node2D

var sim: Sim
var steps: int = 0
var player_view: PlayerView
var driver: FixedStepDriver
var _collector: InputCollector = InputCollector.new()
var _status: Label

func _ready() -> void:
	if not OS.is_debug_build():
		return
	add_child(ArenaView.new())
	player_view = (load("res://view/battle/player_view.tscn") as PackedScene).instantiate() as PlayerView
	add_child(player_view)
	var camera: Camera2D = Camera2D.new()
	camera.position = ArenaBounds.play_rect().get_center()
	add_child(camera)
	var overlay: CanvasLayer = CanvasLayer.new()
	add_child(overlay)
	var box: VBoxContainer = VBoxContainer.new()
	box.theme = preload("res://app/dev/debug_ui_theme.tres")
	box.position = Vector2(8, 8)
	overlay.add_child(box)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	box.add_child(_status)
	var hint: Label = Label.new()
	hint.text = "WASD / 左摇杆 · 固定镜头移动检查"
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)
	for bonus: float in [0.0, 0.5]:
		var button: Button = Button.new()
		button.text = "重建：+%d%%" % int(bonus * 100)
		button.pressed.connect(reset_run.bind(bonus))
		box.add_child(button)
	driver = FixedStepDriver.new()
	driver.configure(_step)
	reset_run()
	add_child(driver)

## 重建模拟并清空驱动余数；不通过表现层直接改状态。
func reset_run(bonus: float = 0.0) -> void:
	sim = Sim.new(20261030, &"knight", bonus)
	steps = 0
	driver.reset()
	_sync()

func _step() -> void:
	sim.step(_collector.sample())
	steps += 1
	_sync()

func _sync() -> void:
	player_view.sync(sim.state.player)
	_status.text = "位置 %s  步数 %d  加成 %.2f" % [sim.state.player.position, steps, sim.state.player.move_speed_bonus]
