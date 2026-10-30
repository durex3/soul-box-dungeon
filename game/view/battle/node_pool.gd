class_name NodePool
extends Node

var _configured: bool = false
var _capacity: int = 0
var _available: Array[PooledView] = []
var _active: Dictionary[PooledView, bool] = {}


## 入树前一次性预创建全部实例；失败时释放临时实例并保持原配置。
func configure(scene: PackedScene, capacity: int) -> void:
	if _configured or is_inside_tree() or scene == null or capacity <= 0 or not scene.can_instantiate():
		push_error("NodePool.configure: invalid configuration")
		return
	var prepared: Array[PooledView] = []
	for i: int in capacity:
		var node: Node = scene.instantiate()
		if not node is PooledView or not _inherits_processing(node):
			if is_instance_valid(node):
				node.free()
			for item: PooledView in prepared:
				item.free()
			push_error("NodePool.configure: invalid configuration")
			return
		var item: PooledView = node as PooledView
		# 场景保存的可见性不能覆盖入池初始停用要求，不触发借还钩子。
		item.hide()
		item.process_mode = Node.PROCESS_MODE_DISABLED
		prepared.append(item)
	_capacity = capacity
	_available = prepared
	_configured = true
	for item: PooledView in _available:
		add_child(item)


## 借出一个空闲实例，满池时安静返回 null，不扩容或抢占。
func acquire() -> PooledView:
	if _available.is_empty():
		return null
	var item: PooledView = _available.pop_back()
	_active[item] = true
	item.activate()
	return item


## 仅归还本池当前活跃的有效实例，无效归还不改变状态。
func release(item: PooledView) -> bool:
	if not is_instance_valid(item) or not _active.has(item):
		return false
	_active.erase(item)
	item.deactivate()
	_available.append(item)
	return true


## 返回成功配置的硬容量，未配置时为零。
func get_capacity() -> int:
	return _capacity


## 返回本池创建的场景根实例总数，不含子节点。
func get_total_count() -> int:
	return _active.size() + _available.size()


## 返回当前借出的实例数。
func get_active_count() -> int:
	return _active.size()


## 返回当前可申请的实例数。
func get_available_count() -> int:
	return _available.size()


func _inherits_processing(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CanvasLayer or child.process_mode != Node.PROCESS_MODE_INHERIT:
			return false
		if not _inherits_processing(child):
			return false
	return true
