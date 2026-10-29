extends GdTest


## 验证real_data。
func test_real_data() -> void:
	var errors: PackedStringArray = SoulTable.validate(SoulTable.ROWS)
	eq(errors.size(), 0, "\n".join(errors))


## 验证row_count。
func test_row_count() -> void:
	eq(SoulTable.ROWS.size(), 12)


## 验证missing_fields_safe。
func test_missing_fields_safe() -> void:
	for field: String in SoulTable.SCHEMA:
		var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
		rows[0].erase(field)
		var errors: PackedStringArray = SoulTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证tags_empty。
func test_tags_empty() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["tags"] = []
	ok(not SoulTable.validate(rows).is_empty())


## 验证tags_too_many。
func test_tags_too_many() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["tags"] = [&"fire", &"frost", &"holy"]
	ok(not SoulTable.validate(rows).is_empty())


## 验证tags_duplicate。
func test_tags_duplicate() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["tags"] = [&"fire", &"fire"]
	ok(not SoulTable.validate(rows).is_empty())


## 验证tag_unknown。
func test_tag_unknown() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["tags"] = [&"unknown"]
	ok(not SoulTable.validate(rows).is_empty())


## 验证damage_positive。
func test_damage_positive() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["damage_t1"] = 0.0
	ok(not SoulTable.validate(rows).is_empty())


## 验证sustained_cooldown。
func test_sustained_cooldown() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["sustained"] = true
	ok(not SoulTable.validate(rows).is_empty())


## 验证cooldown_positive。
func test_cooldown_positive() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["cooldown"] = 0.0
	ok(not SoulTable.validate(rows).is_empty())


## 验证evolution_pair。
func test_evolution_pair() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["evolved_name_cn"] = ""
	ok(not SoulTable.validate(rows).is_empty())


## 验证unit。
func test_unit() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[0]["damage_unit"] = &"bad"
	ok(not SoulTable.validate(rows).is_empty())


## 验证sustained_zero。
func test_sustained_zero() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[4]["cooldown"] = 1.0
	ok(not SoulTable.validate(rows).is_empty())


## 验证no_orphan_evolved_name。
func test_no_orphan_evolved_name() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows[6]["evolved_name_cn"] = "孤立"
	ok(not SoulTable.validate(rows).is_empty())


## 验证wrong_types_safe。
func test_wrong_types_safe() -> void:
	for field: String in SoulTable.SCHEMA:
		var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
		rows[0][field] = null
		var errors: PackedStringArray = SoulTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证duplicate_ids。
func test_duplicate_ids() -> void:
	var rows: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	rows.append(rows[0].duplicate(true))
	ok(not SoulTable.validate(rows).is_empty())


## 验证spot_values。
func test_spot_values() -> void:
	near(SoulTable.ROWS[0].get("damage_t1"), 8.0)
	near(SoulTable.ROWS[0].get("cooldown"), 1.2)
