class_name StatBlock
extends RefCounted

# 来源与缓存均私有；被cap/floor遮住的原值必须保留，以便移除来源时重算。
var _sources: Dictionary = {}
var _values: Dictionary = {}

func _init() -> void:
	_recalculate()

## 完整校验后整体替换该效果实例，失败不会改动已有来源或有效值。
func set_modifier(source_id: StringName, mods: Dictionary) -> bool:
	if str(source_id).is_empty():
		return false
	for key: Variant in mods:
		if typeof(key) != TYPE_STRING_NAME:
			return false
		if not Balance.STAT_BASE.has(key) and key != &"max_hp_pct":
			return false
		var amount: Variant = mods[key]
		if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
			return false
		if not is_finite(float(amount)) or (key == &"max_hp_pct" and amount > 0):
			return false
	_sources[source_id] = mods.duplicate(true)
	_recalculate()
	return true

## 仅移除指定实例；不存在是正常失败，不产生错误。
func remove_modifier(source_id: StringName) -> bool:
	if not _sources.erase(source_id):
		return false
	_recalculate()
	return true

## 只允许查询18个基础属性；无效查询属于调用方程序错误。
func value(stat_id: StringName) -> float:
	if not _values.has(stat_id):
		push_error("StatBlock.value 未知属性: %s" % stat_id)
		return 0.0
	return _values[stat_id]

## 返回按STAT_BASE字段顺序排列的独立有效值副本。
func snapshot() -> Dictionary:
	return _values.duplicate(true)

func _recalculate() -> void:
	_values = Balance.STAT_BASE.duplicate(true)
	var names: Array[String] = []
	for source_id: StringName in _sources:
		names.append(str(source_id))
	names.sort()
	var health_factor: float = 1.0
	for source_name: String in names:
		var mods: Dictionary = _sources[StringName(source_name)]
		for stat_id: StringName in Balance.STAT_BASE:
			_values[stat_id] += float(mods.get(stat_id, 0.0))
		health_factor *= maxf(0.0, 1.0 + float(mods.get(&"max_hp_pct", 0.0)))
	_values[&"max_hp"] *= health_factor
	for stat_id: StringName in Balance.STAT_BASE:
		_values[stat_id] = maxf(float(Balance.STAT_FLOOR.get(stat_id, 0.0)), _values[stat_id])
		if Balance.STAT_CAP.has(stat_id):
			_values[stat_id] = minf(Balance.STAT_CAP[stat_id], _values[stat_id])
