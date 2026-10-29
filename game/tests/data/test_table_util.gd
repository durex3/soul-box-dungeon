extends GdTest

const SCHEMA: Dictionary = {"id": TYPE_STRING_NAME, "name_cn": TYPE_STRING, "value": TYPE_FLOAT, "count": TYPE_INT}
const ROW: Dictionary = {"id": &"sample", "name_cn": "示例", "value": 1.0, "count": 1}


## 每种结构错误均返回包含字段的唯一诊断。
func test_schema_errors() -> void:
	var cases: Array[Dictionary] = [
		{"field": "value", "value": "wrong"}, {"field": "extra", "value": 1},
		{"field": "count", "value": 1.5}, {"field": "id", "value": &"Bad-id"},
		{"field": "id", "value": &"valid\n"},
		{"field": "name_cn", "value": " "}, {"field": "id", "value": "sample"},
	]
	for case: Dictionary in cases:
		var row: Dictionary = ROW.duplicate(true)
		row[case.get("field")] = case.get("value")
		var errors: PackedStringArray = TableUtil.check_rows("ExampleTable", [row], SCHEMA)
		eq(errors.size(), 1)
		ok(errors[0].contains(str(case.get("field"))))


## 缺字段诊断使用 id；没有 id 时使用行号。
func test_diagnostic_context() -> void:
	var row: Dictionary = ROW.duplicate(true)
	row.erase("value")
	var errors: PackedStringArray = TableUtil.check_rows("ExampleTable", [row], SCHEMA)
	eq(errors.size(), 1)
	ok(errors[0].contains("ExampleTable sample"))
	ok(errors[0].contains("value"))
	row.erase("id")
	errors = TableUtil.check_rows("ExampleTable", [row], SCHEMA)
	ok(errors[0].contains("第 1 行"))


## 浮点字段接受整数，但布尔值不是数字。
func test_float_accepts_int() -> void:
	var row: Dictionary = ROW.duplicate(true)
	row["value"] = 1
	eq(TableUtil.check_rows("ExampleTable", [row], SCHEMA).size(), 0)
	row["value"] = true
	eq(TableUtil.check_rows("ExampleTable", [row], SCHEMA).size(), 1)


## 重复标识与空标识不能通过。
func test_duplicate_and_empty_id() -> void:
	var errors: PackedStringArray = TableUtil.check_rows("ExampleTable", [ROW, ROW], SCHEMA)
	eq(errors.size(), 1)
	ok(errors[0].contains("sample") and errors[0].contains("id"))
	var row: Dictionary = ROW.duplicate(true)
	row["id"] = &""
	eq(TableUtil.check_rows("ExampleTable", [row], SCHEMA).size(), 1)
