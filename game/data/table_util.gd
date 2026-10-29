class_name TableUtil
extends RefCounted


## 仅检验字段是否齐全且类型兼容，供各表安全地进入本表检查。
static func has_valid_shape(row: Dictionary, schema: Dictionary) -> bool:
	if row.size() != schema.size():
		return false
	for field: String in schema:
		if not row.has(field) or not _matches_type(row.get(field), schema.get(field)):
			return false
	return true


static func _matches_type(value: Variant, type: int) -> bool:
	return is_number(value) if type == TYPE_FLOAT else typeof(value) == type


## 检查字段、类型、标识、重名与显示名；坏数据也只返回诊断。
static func check_rows(table: String, rows: Array[Dictionary], schema: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary = {}
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\A[a-z0-9_]+\\z")
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var label: String = "%s %s" % [table, row.get("id", "第 %d 行" % (i + 1))]
		for field: String in schema:
			if not row.has(field):
				errors.append("%s: 缺少字段 %s" % [label, field])
			elif not _matches_type(row.get(field), schema.get(field)):
				errors.append("%s: 字段 %s 类型错误" % [label, field])
		for field: Variant in row:
			if not schema.has(field):
				errors.append("%s: 未知字段 %s" % [label, field])
		if typeof(row.get("id")) == TYPE_STRING_NAME:
			var id: StringName = row.get("id")
			if pattern.search(str(id)) == null:
				errors.append("%s: id 格式错误" % label)
			if seen.has(id):
				errors.append("%s: id 重复" % label)
			seen[id] = true
		if typeof(row.get("name_cn")) == TYPE_STRING and str(row.get("name_cn")).strip_edges().is_empty():
			errors.append("%s: name_cn 为空" % label)
	return errors


## 添加带表名、行 id 和字段的业务诊断。
static func require_valid(errors: PackedStringArray, condition: bool, table: String, row: Dictionary, field: String, rule: String) -> void:
	if not condition:
		errors.append("%s %s: %s %s" % [table, row.get("id", "未知行"), field, rule])


## 数值必须是有限的整数或浮点数，布尔值不算数值。
static func is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))
