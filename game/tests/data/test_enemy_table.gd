extends GdTest


## 验证real_data。
func test_real_data() -> void:
	var errors: PackedStringArray = EnemyTable.validate(EnemyTable.ROWS)
	eq(errors.size(), 0, "\n".join(errors))


## 验证row_count。
func test_row_count() -> void:
	eq(EnemyTable.ROWS.size(), 8)


## 验证missing_fields_safe。
func test_missing_fields_safe() -> void:
	for field: String in EnemyTable.SCHEMA:
		var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
		rows[0].erase(field)
		var errors: PackedStringArray = EnemyTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证archetype。
func test_archetype() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["archetype"] = &"bad"
	ok(not EnemyTable.validate(rows).is_empty())


## 验证hp。
func test_hp() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["hp"] = 0.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证damage。
func test_damage() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["damage"] = 0.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证xp。
func test_xp() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["xp"] = 0.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证speed。
func test_speed() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["move_speed"] = -1.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证dash_only_charger。
func test_dash_only_charger() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["dash_speed"] = 1.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证children_only_splitter。
func test_children_only_splitter() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["child_xp"] = 1.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证first_wave。
func test_first_wave() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[0]["first_wave"] = 0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证charger_requires_dash。
func test_charger_requires_dash() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[2]["dash_speed"] = 0.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证splitter_requires_child_xp。
func test_splitter_requires_child_xp() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows[5]["child_xp"] = 0.0
	ok(not EnemyTable.validate(rows).is_empty())


## 验证wrong_types_safe。
func test_wrong_types_safe() -> void:
	for field: String in EnemyTable.SCHEMA:
		var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
		rows[0][field] = null
		var errors: PackedStringArray = EnemyTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证duplicate_ids。
func test_duplicate_ids() -> void:
	var rows: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	rows.append(rows[0].duplicate(true))
	ok(not EnemyTable.validate(rows).is_empty())


## 验证spot_values。
func test_spot_values() -> void:
	near(EnemyTable.ROWS[7].get("hp"), 80.0)
