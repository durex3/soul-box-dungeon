class_name PooledView
extends Node2D

# 只读约定：使用方通过所属池借还，不直接改状态或销毁节点。
var active: bool = false


func _init() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


## 每次借出都执行申请钩子，不依赖 ready 再次触发。
func activate() -> void:
	active = true
	_on_pool_acquire()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


## 先停止整个继承子树，再清理自定义表现状态。
func deactivate() -> void:
	active = false
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	_on_pool_release()
	# 保证归还完成时仍然停用；钩子不能重新激活对象。
	active = false
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


## 子类可在此准备本次表现状态。
func _on_pool_acquire() -> void:
	pass


## 子类在此清理 payload、Tween 或外部信号等独立活动。
func _on_pool_release() -> void:
	pass
