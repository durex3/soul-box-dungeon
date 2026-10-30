extends GdTest

const SCENES: Array[PackedScene] = [
	preload("res://tests/view/battle/fixtures/projectile.tscn"),
	preload("res://tests/view/battle/fixtures/number.tscn"),
	preload("res://tests/view/battle/fixtures/pickup.tscn"),
]
const POOL_SCENE: PackedScene = preload("res://view/battle/node_pool.tscn")


## 三种夹具同样预创建四个隐藏停用实例。
func test_initial_state() -> void:
	for scene: PackedScene in SCENES:
		var pool: NodePool = _pool(scene, 4)
		_counts(pool, 4, 0, 4)
		eq(_subtree_size(pool), 9)
		for item: PooledView in pool.get_children():
			ok(not item.active and not item.visible)
			eq(item.process_mode, Node.PROCESS_MODE_DISABLED)
			eq(item.get("acquire_count"), 0)
			eq(item.get("release_count"), 0)
		pool.free()


## 借满后不扩容；归还后以原身份复用。
func test_capacity_identity_and_reuse() -> void:
	for scene: PackedScene in SCENES:
		var pool: NodePool = _pool(scene, 4)
		var ids: Dictionary[int, bool] = {}
		var items: Array[PooledView] = []
		for i: int in 4:
			var item: PooledView = pool.acquire()
			ok(item != null)
			ok(not ids.has(item.get_instance_id()))
			ids[item.get_instance_id()] = true
			items.append(item)
		_counts(pool, 4, 4, 0)
		for i: int in 10:
			eq(pool.acquire(), null)
		eq(_subtree_size(pool), 9)
		ok(pool.release(items[0]))
		eq(pool.acquire(), items[0])
		_counts(pool, 4, 4, 0)
		pool.free()


## 每种场景一万轮借满归还，根实例和完整子树始终有界。
func test_ten_thousand_full_cycles() -> void:
	for scene: PackedScene in SCENES:
		var pool: NodePool = _pool(scene, 4)
		var initial_nodes: int = _subtree_size(pool)
		var initial_ids: Dictionary[int, bool] = {}
		for item: Node in pool.get_children():
			initial_ids[item.get_instance_id()] = true
		var seen: Dictionary[int, bool] = {}
		for cycle: int in 10000:
			var items: Array[PooledView] = []
			for i: int in 4:
				var item: PooledView = pool.acquire()
				ok(item != null)
				if item == null:
					continue
				ok(initial_ids.has(item.get_instance_id()))
				ok(not items.has(item))
				seen[item.get_instance_id()] = true
				items.append(item)
			_counts(pool, 4, 4, 0)
			eq(pool.acquire(), null)
			for item: PooledView in items:
				ok(pool.release(item))
			_counts(pool, 4, 0, 4)
			eq(_subtree_size(pool), initial_nodes)
		eq(seen.size(), 4)
		pool.free()


## 归还清理 payload，每次借还触发钩子并保持停用。
func test_release_state_and_hooks() -> void:
	for scene: PackedScene in SCENES:
		var pool: NodePool = _pool(scene, 1)
		var item: PooledView = pool.acquire()
		ok(item.active and item.visible)
		eq(item.process_mode, Node.PROCESS_MODE_INHERIT)
		item.set("payload", 42)
		ok(pool.release(item))
		ok(not item.active and not item.visible)
		eq(item.process_mode, Node.PROCESS_MODE_DISABLED)
		eq(item.get("payload"), 0)
		eq(item.get("release_count"), 1)
		eq(pool.acquire(), item)
		eq(item.get("payload"), 0)
		eq(item.get("acquire_count"), 2)
		ok(pool.release(item))
		eq(item.get("release_count"), 2)
		pool.free()


## 无效和跨池归还不会污染两个不同容量池的空闲列表。
func test_invalid_releases() -> void:
	var a: NodePool = _pool(SCENES[0], 1)
	var b: NodePool = _pool(SCENES[1], 3)
	var initial: PooledView = a.get_child(0) as PooledView
	ok(not a.release(null))
	ok(not a.release(initial))
	var other: PooledView = b.acquire()
	ok(not a.release(other))
	_counts(a, 1, 0, 1)
	_counts(b, 3, 1, 2)
	var item: PooledView = a.acquire()
	ok(not b.release(item))
	ok(a.release(item))
	ok(not a.release(item))
	_counts(a, 1, 0, 1)
	eq(a.acquire(), item)
	eq(a.acquire(), null)
	a.free()
	b.free()


func _pool(scene: PackedScene, capacity: int) -> NodePool:
	var pool: NodePool = POOL_SCENE.instantiate() as NodePool
	pool.configure(scene, capacity)
	return pool


func _counts(pool: NodePool, total: int, active: int, available: int) -> void:
	eq(pool.get_capacity(), total)
	eq(pool.get_total_count(), total)
	eq(pool.get_active_count(), active)
	eq(pool.get_available_count(), available)


func _subtree_size(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _subtree_size(child)
	return count
