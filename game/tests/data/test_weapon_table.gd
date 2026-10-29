extends GdTest


## 验证real_data。
func test_real_data() -> void:
	var errors: PackedStringArray = WeaponTable.validate(WeaponTable.ROWS)
	eq(errors.size(), 0, "\n".join(errors))


## 验证row_count。
func test_row_count() -> void:
	eq(WeaponTable.ROWS.size(), 8)


## 验证missing_fields_safe。
func test_missing_fields_safe() -> void:
	for field: String in WeaponTable.SCHEMA:
		var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
		rows[0].erase(field)
		var errors: PackedStringArray = WeaponTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证kind。
func test_kind() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[0]["kind"] = &"bad"
	ok(not WeaponTable.validate(rows).is_empty())


## 验证staff_tag。
func test_staff_tag() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[0]["tag"] = &"fire"
	ok(not WeaponTable.validate(rows).is_empty())


## 验证damage。
func test_damage() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[0]["damage"] = 0.0
	ok(not WeaponTable.validate(rows).is_empty())


## 验证rate。
func test_rate() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[0]["shots_per_sec"] = 0.0
	ok(not WeaponTable.validate(rows).is_empty())


## 验证pellets。
func test_pellets() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[0]["pellets"] = 0
	ok(not WeaponTable.validate(rows).is_empty())


## 验证energy。
func test_energy() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[0]["energy_cost"] = 1.0
	ok(not WeaponTable.validate(rows).is_empty())


## 验证resonance。
func test_resonance() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[0]["resonance_per_hit"] = -1.0
	ok(not WeaponTable.validate(rows).is_empty())


## 验证staff_requires_tag。
func test_staff_requires_tag() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[2]["tag"] = &""
	ok(not WeaponTable.validate(rows).is_empty())


## 验证staff_rejects_mechanical。
func test_staff_rejects_mechanical() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[2]["tag"] = &"mechanical"
	ok(not WeaponTable.validate(rows).is_empty())


## 验证energy_bounds。
func test_energy_bounds() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows[2]["energy_cost"] = 5.0
	ok(not WeaponTable.validate(rows).is_empty())


## 验证wrong_types_safe。
func test_wrong_types_safe() -> void:
	for field: String in WeaponTable.SCHEMA:
		var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
		rows[0][field] = null
		var errors: PackedStringArray = WeaponTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证duplicate_ids。
func test_duplicate_ids() -> void:
	var rows: Array[Dictionary] = WeaponTable.ROWS.duplicate(true)
	rows.append(rows[0].duplicate(true))
	ok(not WeaponTable.validate(rows).is_empty())


## 验证spot_values。
func test_spot_values() -> void:
	eq(WeaponTable.ROWS[7].get("pierce"), 3)
	near(WeaponTable.ROWS[1].get("damage"), 32.0)
	near(WeaponTable.ROWS[1].get("shots_per_sec"), 0.9)
	near(WeaponTable.ROWS[1].get("resonance_per_hit"), 7.0)
