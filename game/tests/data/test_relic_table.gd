extends GdTest


## 验证real_data。
func test_real_data() -> void:
	var errors: PackedStringArray = RelicTable.validate(RelicTable.ROWS)
	eq(errors.size(), 0, "\n".join(errors))


## 验证row_count。
func test_row_count() -> void:
	eq(RelicTable.ROWS.size(), 20)


## 验证missing_fields_safe。
func test_missing_fields_safe() -> void:
	for field: String in RelicTable.SCHEMA:
		var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
		rows[0].erase(field)
		var errors: PackedStringArray = RelicTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证quality。
func test_quality() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[0]["quality"] = &"bad"
	ok(not RelicTable.validate(rows).is_empty())


## 验证price。
func test_price() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[0]["price"] = 0
	ok(not RelicTable.validate(rows).is_empty())


## 验证mod_key。
func test_mod_key() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[0]["mods"] = {&"unknown": 1}
	ok(not RelicTable.validate(rows).is_empty())


## 验证mod_type。
func test_mod_type() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[0]["mods"] = {&"damage": "bad"}
	ok(not RelicTable.validate(rows).is_empty())


## 验证mod_zero。
func test_mod_zero() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[0]["mods"] = {&"damage": 0}
	ok(not RelicTable.validate(rows).is_empty())


## 验证mod_string_key。
func test_mod_string_key() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[0]["mods"] = {"damage": 1}
	ok(not RelicTable.validate(rows).is_empty())


## 验证effect_required。
func test_effect_required() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[0]["mods"] = {}
	ok(not RelicTable.validate(rows).is_empty())


## 验证legendary_unique。
func test_legendary_unique() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[11]["unique"] = false
	ok(not RelicTable.validate(rows).is_empty())


## 验证evolution_unique。
func test_evolution_unique() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[13]["unique"] = false
	ok(not RelicTable.validate(rows).is_empty())


## 验证evolution_epic。
func test_evolution_epic() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows[13]["quality"] = &"rare"
	rows[13]["price"] = 35
	ok(not RelicTable.validate(rows).is_empty())


## 验证wrong_types_safe。
func test_wrong_types_safe() -> void:
	for field: String in RelicTable.SCHEMA:
		var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
		rows[0][field] = null
		var errors: PackedStringArray = RelicTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证duplicate_ids。
func test_duplicate_ids() -> void:
	var rows: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	rows.append(rows[0].duplicate(true))
	ok(not RelicTable.validate(rows).is_empty())


## 验证spot_values。
func test_spot_values() -> void:
	var mods: Dictionary = RelicTable.ROWS[6].get("mods")
	near(mods.get(&"max_hp_pct"), -0.25)
