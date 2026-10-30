class_name EnemyProjectileLab
extends Control

const SIZES: Array[int] = [6, 8, 9, 10, 12, 16, 32]
const ALPHAS: Array[float] = [0.0, 0.6, 0.8, 1.0]
var viewport: SubViewport
var world: Node2D
var pool: NodePool
var bullet: EnemyProjectileView
var ally_fx: EnemyProjectilePressure
var controls: Dictionary = {}
var size_index: int = 0
var alpha_index: int = 0
var paused: bool = false
var reversed_order: bool = false
var _status: Label

func _ready() -> void:
	if not OS.is_debug_build():
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(160, 80)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	world = Node2D.new()
	viewport.add_child(world)
	pool = NodePool.new()
	pool.configure(load("res://view/battle/enemy_projectile_view.tscn"), 1)
	world.add_child(pool)
	ally_fx = EnemyProjectilePressure.new()
	world.add_child(ally_fx)
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1C1B26")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for factor: int in [1, 3]:
		var screen: TextureRect = TextureRect.new()
		screen.texture = viewport.get_texture()
		screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		screen.position = Vector2(4 if factor == 1 else 156, 48)
		screen.size = Vector2(160, 80) * factor
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(screen)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(4, 4)
	add_child(row)
	for key: String in ["Size", "Alpha", "Cover", "Order", "Borrow", "Return", "Pause"]:
		var button: Button = Button.new()
		button.add_theme_font_size_override("font_size", 11)
		controls[key] = button
		row.add_child(button)
	(controls["Size"] as Button).pressed.connect(func() -> void:
		size_index = (size_index + 1) % SIZES.size()
		_present())
	(controls["Alpha"] as Button).pressed.connect(func() -> void:
		alpha_index = (alpha_index + 1) % ALPHAS.size()
		_refresh())
	(controls["Cover"] as Button).pressed.connect(func() -> void:
		ally_fx.full_cover = not ally_fx.full_cover
		_refresh())
	(controls["Order"] as Button).pressed.connect(func() -> void:
		reversed_order = not reversed_order
		world.move_child(ally_fx, 0 if reversed_order else world.get_child_count() - 1)
		_refresh())
	(controls["Borrow"] as Button).pressed.connect(_borrow)
	(controls["Return"] as Button).pressed.connect(_release)
	(controls["Pause"] as Button).pressed.connect(func() -> void:
		paused = not paused
		_refresh())
	_status = Label.new()
	_status.position = Vector2(8, 300)
	_status.add_theme_font_size_override("font_size", 12)
	add_child(_status)
	_borrow()

func _borrow() -> void:
	var item: EnemyProjectileView = pool.acquire() as EnemyProjectileView
	if item != null:
		bullet = item
		_present()
	else:
		_refresh()
		_status.text += " · 满池返回null"

func _release() -> void:
	if bullet != null:
		pool.release(bullet)
	_refresh()

func _present() -> void:
	if bullet != null and bullet.active:
		bullet.present(45, Vector2(80.3, 40.4), SIZES[size_index])
	_refresh()

func _refresh() -> void:
	# 仅改变独立我方组；敌弹池保持兄弟关系及原生世界Canvas。
	ally_fx.modulate.a = ALPHAS[alpha_index]
	ally_fx.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if paused else SubViewport.UPDATE_ALWAYS
	(controls["Size"] as Button).text = "直径 %d" % SIZES[size_index]
	(controls["Alpha"] as Button).text = "我方 %.1f" % ALPHAS[alpha_index]
	(controls["Cover"] as Button).text = "满覆盖 " + ("开" if ally_fx.full_cover else "关")
	(controls["Order"] as Button).text = "添加序 " + ("我方先" if reversed_order else "敌弹先")
	(controls["Borrow"] as Button).text = "借出/重借"
	(controls["Return"] as Button).text = "归还"
	(controls["Pause"] as Button).text = "持续绘制" if paused else "暂停绘制"
	_status.text = "1×（左） / 3× nearest（右）\n池容量 %d · 活跃 %d · 空闲 %d\n静态验收：不模拟弹道、寿命或自动回收" % [pool.get_capacity(), pool.get_active_count(), pool.get_available_count()]
