class_name WaveTable
extends RefCounted

const SCHEMA: Dictionary = {
	"id": TYPE_STRING_NAME,
	"name_cn": TYPE_STRING,
	"zone": TYPE_INT,
	"first_wave": TYPE_INT,
	"last_wave": TYPE_INT,
	"duration_start": TYPE_FLOAT,
	"duration_end": TYPE_FLOAT,
	"spawn_rate_start": TYPE_FLOAT,
	"spawn_rate_end": TYPE_FLOAT,
	"elites_start": TYPE_INT,
	"elites_end": TYPE_INT,
}

# GDD 11.3 节
const ROWS: Array[Dictionary] = [
	{ "id": &"zone_1", "name_cn": "遗忘墓穴", "zone": 1, "first_wave": 1, "last_wave": 6, "duration_start": 30.0, "duration_end": 50.0, "spawn_rate_start": 2.0, "spawn_rate_end": 4.0, "elites_start": 0, "elites_end": 1 },
	{ "id": &"zone_2", "name_cn": "熔岩工坊", "zone": 2, "first_wave": 7, "last_wave": 12, "duration_start": 50.0, "duration_end": 65.0, "spawn_rate_start": 5.0, "spawn_rate_end": 8.0, "elites_start": 1, "elites_end": 2 },
]


## 返回本表的字段与业务错误，缺字段或类型错误的行不进入业务检查。
static func validate(rows: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = TableUtil.check_rows("WaveTable", rows, SCHEMA)
	var expected_wave: int = 1
	for row: Dictionary in rows:
		if not TableUtil.has_valid_shape(row, SCHEMA):
			expected_wave = row.get("last_wave") + 1 if typeof(row.get("last_wave")) == TYPE_INT else -1
			continue
		TableUtil.require_valid(errors, row.get("first_wave") <= row.get("last_wave"), "WaveTable", row, "first_wave/last_wave", "波次范围倒置")
		for prefix: String in ["duration", "spawn_rate", "elites"]:
			var start: Variant = row.get(prefix + "_start")
			var end: Variant = row.get(prefix + "_end")
			TableUtil.require_valid(errors, start >= 0 and end >= 0 if prefix == "elites" else start > 0 and end > 0, "WaveTable", row, prefix, "时长速率须为正，精英数不得为负")
			TableUtil.require_valid(errors, start <= end, "WaveTable", row, prefix, "start 不得大于 end")
		TableUtil.require_valid(errors, expected_wave < 0 or row.get("first_wave") == expected_wave, "WaveTable", row, "first_wave", "波段须从 1 开始且连续有序")
		expected_wave = row.get("last_wave") + 1
	return errors
