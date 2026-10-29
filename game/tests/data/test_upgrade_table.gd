extends GdTest


## 验证real_data。
func test_real_data() -> void:
	var errors: PackedStringArray = UpgradeTable.validate(UpgradeTable.ROWS)
	eq(errors.size(), 0, "\n".join(errors))


## 验证row_count。
func test_row_count() -> void:
	eq(UpgradeTable.ROWS.size(), 18)


## 验证missing_fields_safe。
func test_missing_fields_safe() -> void:
	for field: String in UpgradeTable.SCHEMA:
		var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
		rows[0].erase(field)
		var errors: PackedStringArray = UpgradeTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证id。
func test_id() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows[0]["id"] = &"bad"
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证values_count。
func test_values_count() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows[0]["values"] = [1, 2, 3]
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证values_type。
func test_values_type() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows[0]["values"] = [1, 2, "bad", 4]
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证values_positive。
func test_values_positive() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows[0]["values"] = [0, 1, 2, 3]
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证values_order。
func test_values_order() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows[0]["values"] = [4, 3, 2, 1]
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证group。
func test_group() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows[0]["group"] = &"bad"
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证coverage。
func test_coverage() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows.pop_back()
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证wrong_types_safe。
func test_wrong_types_safe() -> void:
	for field: String in UpgradeTable.SCHEMA:
		var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
		rows[0][field] = null
		var errors: PackedStringArray = UpgradeTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证duplicate_ids。
func test_duplicate_ids() -> void:
	var rows: Array[Dictionary] = UpgradeTable.ROWS.duplicate(true)
	rows.append(rows[0].duplicate(true))
	ok(not UpgradeTable.validate(rows).is_empty())


## 验证spot_values。
func test_spot_values() -> void:
	eq(UpgradeTable.ROWS[15].get("values"), [4.0, 8.0, 12.0, 16.0])
