extends SceneTree

signal settled

const POOL: PackedScene = preload("res://view/battle/node_pool.tscn")
const FIXTURE: PackedScene = preload("res://tests/view/battle/fixtures/projectile.tscn")
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		print("RK008_FAIL " + message)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() == 2 and args[0] == "--negative":
			await _negative(args[1])
		else:
			_require(false, "invalid arguments")
		_finish("RK008_NEGATIVE")
		return
	var pool: NodePool = POOL.instantiate() as NodePool
	pool.configure(FIXTURE, 2)
	root.add_child(pool)
	var untouched: PooledView = pool.get_child(0) as PooledView
	var initial: Array[int] = _counters(untouched)
	await _wait_frames()
	_require(_counters(untouched) == initial, "initial root/child must not process")
	_require(not untouched.is_visible_in_tree() and not untouched.active, "initial visibility")
	var item: PooledView = pool.acquire()
	var before: Array[int] = _counters(item)
	await _wait_frames()
	var active: Array[int] = _counters(item)
	for i: int in active.size():
		_require(active[i] > before[i], "active root/child idle/physics growth")
	_require(item.is_visible_in_tree() and item.active, "active visibility")
	_require(pool.release(item), "release")
	var released: Array[int] = _counters(item)
	await _wait_frames()
	var inactive: Array[int] = _counters(item)
	_require(inactive == released, "released root/child must stop processing")
	_require(not item.is_visible_in_tree() and not item.active, "released visibility")
	_require(pool.acquire() == item, "same instance must be reused")
	await _wait_frames()
	var resumed: Array[int] = _counters(item)
	for i: int in resumed.size():
		_require(resumed[i] > inactive[i], "reacquired processing growth")
	_require(item.get("ready_count") == 1, "ready only once")
	_require(item.get("acquire_count") == 2, "acquire hook twice")
	_require(pool.release(item), "second release")
	_require(item.get("release_count") == 2, "release hook twice")
	_require(_counters(untouched) == initial, "unused instance stays stopped")
	print("RK008_COUNTS root_idle/root_physics/child_idle/child_physics active=%s released=%s inactive=%s resumed=%s ready=%s acquire=%s release=%s" % [active, released, inactive, resumed, item.get("ready_count"), item.get("acquire_count"), item.get("release_count")])
	pool.free()
	_finish("RK008_PROBE")


func _counters(item: PooledView) -> Array[int]:
	var child: Node = item.get_child(0)
	return [item.get("idle_count"), item.get("physics_count"), child.get("idle_count"), child.get("physics_count")]


func _wait_frames() -> void:
	for i: int in 8:
		await process_frame
	for i: int in 8:
		await physics_frame
	# 延迟信号在节点处理结束后发出，避免在 process_frame 的前半帧读取。
	_emit_settled.call_deferred()
	await settled


func _emit_settled() -> void:
	settled.emit()


func _negative(kind: String) -> void:
	var pool: NodePool = POOL.instantiate() as NodePool
	var retained: Node = null
	match kind:
		"null": pool.configure(null, 2)
		"zero": pool.configure(FIXTURE, 0)
		"negative": pool.configure(FIXTURE, -1)
		"empty": pool.configure(PackedScene.new(), 2)
		"wrong_root":
			var wrong: Node = Node.new()
			var scene: PackedScene = PackedScene.new()
			scene.pack(wrong)
			wrong.free()
			pool.configure(scene, 2)
		"bad_child", "canvas":
			var wrong: PooledView = PooledView.new()
			var child: Node = CanvasLayer.new() if kind == "canvas" else Node.new()
			wrong.add_child(child)
			child.owner = wrong
			if kind == "bad_child":
				child.process_mode = Node.PROCESS_MODE_ALWAYS
			var scene: PackedScene = PackedScene.new()
			scene.pack(wrong)
			wrong.free()
			pool.configure(scene, 2)
		"reconfigure":
			pool.configure(FIXTURE, 1)
			retained = pool.get_child(0)
			pool.configure(FIXTURE, 3)
		"in_tree":
			root.add_child(pool)
			pool.configure(FIXTURE, 1)
		_:
			_require(false, "unknown negative case")
	if kind == "reconfigure":
		_require(pool.get_capacity() == 1 and pool.get_child_count() == 1, "original configuration unchanged")
		_require(pool.get_child(0) == retained, "original instance unchanged")
	else:
		_require(pool.get_capacity() == 0 and pool.get_child_count() == 0, "invalid configuration must leave no children")
		# 合法配置仍可在拒绝非法输入之后成功，说明没有部分初始化。
		if kind != "in_tree":
			pool.configure(FIXTURE, 1)
			_require(pool.get_total_count() == 1, "valid configure after rejection")
	pool.free()


func _finish(prefix: String) -> void:
	print(prefix + (": failed" if _failed else ": passed"))
	quit(1 if _failed else 0)
