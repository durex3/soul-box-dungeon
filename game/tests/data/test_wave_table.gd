extends GdTest


## 验证real_data。
func test_real_data() -> void:
	var errors: PackedStringArray = WaveTable.validate(WaveTable.ROWS)
	eq(errors.size(), 0, "\n".join(errors))


## 验证row_count。
func test_row_count() -> void:
	eq(WaveTable.ROWS.size(), 2)


## 验证missing_fields_safe。
func test_missing_fields_safe() -> void:
	for field: String in WaveTable.SCHEMA:
		var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
		rows[0].erase(field)
		var errors: PackedStringArray = WaveTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证wave_order。
func test_wave_order() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["last_wave"] = 0
	ok(not WaveTable.validate(rows).is_empty())


## 验证duration。
func test_duration() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["duration_start"] = 0.0
	ok(not WaveTable.validate(rows).is_empty())


## 验证rate。
func test_rate() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["spawn_rate_start"] = 0.0
	ok(not WaveTable.validate(rows).is_empty())


## 验证elite。
func test_elite() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["elites_start"] = -1
	ok(not WaveTable.validate(rows).is_empty())


## 验证duration_order。
func test_duration_order() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["duration_start"] = 60.0
	ok(not WaveTable.validate(rows).is_empty())


## 验证rate_order。
func test_rate_order() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["spawn_rate_start"] = 5.0
	ok(not WaveTable.validate(rows).is_empty())


## 验证elite_order。
func test_elite_order() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["elites_start"] = 2
	ok(not WaveTable.validate(rows).is_empty())


## 验证starts_at_one。
func test_starts_at_one() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["first_wave"] = 2
	ok(not WaveTable.validate(rows).is_empty())


## 验证gap。
func test_gap() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[1]["first_wave"] = 8
	ok(not WaveTable.validate(rows).is_empty())


## 验证overlap。
func test_overlap() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[1]["first_wave"] = 6
	ok(not WaveTable.validate(rows).is_empty())


## 验证out_of_order。
func test_out_of_order() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows.reverse()
	ok(not WaveTable.validate(rows).is_empty())


## 验证end_duration。
func test_end_duration() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["duration_end"] = 0.0
	ok(not WaveTable.validate(rows).is_empty())


## 验证end_rate。
func test_end_rate() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["spawn_rate_end"] = 0.0
	ok(not WaveTable.validate(rows).is_empty())


## 验证end_elites。
func test_end_elites() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows[0]["elites_end"] = -1
	ok(not WaveTable.validate(rows).is_empty())


## 验证wrong_types_safe。
func test_wrong_types_safe() -> void:
	for field: String in WaveTable.SCHEMA:
		var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
		rows[0][field] = null
		var errors: PackedStringArray = WaveTable.validate(rows)
		eq(errors.size(), 1, field + "\n".join(errors))


## 验证duplicate_ids。
func test_duplicate_ids() -> void:
	var rows: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	rows.append(rows[0].duplicate(true))
	ok(not WaveTable.validate(rows).is_empty())


## 验证spot_values。
func test_spot_values() -> void:
	eq(WaveTable.ROWS[1].get("elites_start"), 1)
	eq(WaveTable.ROWS[1].get("elites_end"), 2)
