class_name SpatialHash
extends RefCounted

const CELL_SIZE: float = 64.0
var _positions: Dictionary = {}
var _buckets: Dictionary = {}

## 插入新中心点；重复ID不覆盖原记录。
func insert(entity_id: int, position: Vector2) -> bool:
	if _positions.has(entity_id):
		return false
	_positions[entity_id] = position
	_add(entity_id, _cell(position))
	return true

## 移除中心点，并清理不再使用的桶。
func remove(entity_id: int) -> bool:
	if not _positions.has(entity_id):
		return false
	_drop(entity_id, _cell(_positions[entity_id]))
	_positions.erase(entity_id)
	return true

## 更新已存在的中心点；跨格时迁移桶记录。
func move(entity_id: int, position: Vector2) -> bool:
	if not _positions.has(entity_id):
		return false
	var old_cell: Vector2i = _cell(_positions[entity_id])
	var new_cell: Vector2i = _cell(position)
	if old_cell != new_cell:
		_drop(entity_id, old_cell)
		_add(entity_id, new_cell)
	_positions[entity_id] = position
	return true

## 返回圆内（含边界）中心点的有符号ID升序副本，负半径返回空数组。
func query_circle(center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	if radius < 0.0:
		return result
	var extent: Vector2 = Vector2(radius, radius)
	var low: Vector2i = _cell(center - extent)
	var high: Vector2i = _cell(center + extent)
	var squared: float = radius * radius
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var key: Vector2i = Vector2i(x, y)
			if not _buckets.has(key):
				continue
			var bucket: Array[int] = _buckets[key]
			for entity_id: int in bucket:
				var position: Vector2 = _positions[entity_id]
				if position.distance_squared_to(center) <= squared:
					result.append(entity_id)
	result.sort()
	return result

## 检查ID是否存在，不修改索引。
func has(entity_id: int) -> bool:
	return _positions.has(entity_id)

## 返回中心点数量。
func size() -> int:
	return _positions.size()

## 清空索引，允许重复调用并重新插入。
func clear() -> void:
	_positions.clear()
	_buckets.clear()

func _cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func _add(entity_id: int, cell: Vector2i) -> void:
	var bucket: Array[int] = _buckets.get(cell, [] as Array[int])
	bucket.append(entity_id)
	_buckets[cell] = bucket

func _drop(entity_id: int, cell: Vector2i) -> void:
	var bucket: Array[int] = _buckets[cell]
	bucket.erase(entity_id)
	if bucket.is_empty():
		_buckets.erase(cell)
