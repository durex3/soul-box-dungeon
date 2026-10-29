class_name UpgradeTable
extends RefCounted

const SCHEMA: Dictionary = {
	"id": TYPE_STRING_NAME,
	"name_cn": TYPE_STRING,
	"values": TYPE_ARRAY,
	"group": TYPE_STRING_NAME,
}

# GDD 9.3 节
const ROWS: Array[Dictionary] = [
	{ "id": &"max_hp", "name_cn": "生命上限", "values": [5.0, 10.0, 16.0, 25.0], "group": &"" },
	{ "id": &"hp_regen", "name_cn": "生命回复", "values": [1.0, 2.0, 3.0, 5.0], "group": &"" },
	{ "id": &"lifesteal", "name_cn": "吸血", "values": [0.01, 0.02, 0.03, 0.04], "group": &"" },
	{ "id": &"armor", "name_cn": "护甲", "values": [1.0, 2.0, 3.0, 4.0], "group": &"" },
	{ "id": &"dodge", "name_cn": "闪避", "values": [0.02, 0.04, 0.06, 0.08], "group": &"" },
	{ "id": &"damage", "name_cn": "伤害%", "values": [0.04, 0.07, 0.1, 0.14], "group": &"" },
	{ "id": &"melee_damage", "name_cn": "近战伤害%", "values": [0.07, 0.12, 0.18, 0.25], "group": &"typed_damage" },
	{ "id": &"ranged_damage", "name_cn": "远程伤害%", "values": [0.07, 0.12, 0.18, 0.25], "group": &"typed_damage" },
	{ "id": &"elemental_damage", "name_cn": "元素伤害%", "values": [0.07, 0.12, 0.18, 0.25], "group": &"typed_damage" },
	{ "id": &"attack_speed", "name_cn": "攻速%", "values": [0.04, 0.07, 0.1, 0.14], "group": &"" },
	{ "id": &"crit_chance", "name_cn": "暴击率", "values": [0.02, 0.04, 0.06, 0.08], "group": &"" },
	{ "id": &"area", "name_cn": "范围%", "values": [0.06, 0.1, 0.15, 0.2], "group": &"" },
	{ "id": &"move_speed", "name_cn": "移速%", "values": [0.02, 0.04, 0.06, 0.08], "group": &"" },
	{ "id": &"range", "name_cn": "射程%", "values": [0.06, 0.1, 0.15, 0.2], "group": &"" },
	{ "id": &"pickup_range", "name_cn": "拾取范围（格）", "values": [0.5, 1.0, 1.5, 2.0], "group": &"" },
	{ "id": &"luck", "name_cn": "幸运", "values": [4.0, 8.0, 12.0, 16.0], "group": &"" },
	{ "id": &"income", "name_cn": "收益", "values": [1.0, 2.0, 3.0, 5.0], "group": &"" },
	{ "id": &"max_energy", "name_cn": "能量上限", "values": [15.0, 25.0, 40.0, 60.0], "group": &"" },
]


## 返回本表的字段与业务错误，缺字段或类型错误的行不进入业务检查。
static func validate(rows: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = TableUtil.check_rows("UpgradeTable", rows, SCHEMA)
	for row: Dictionary in rows:
		if not TableUtil.has_valid_shape(row, SCHEMA):
			continue
		TableUtil.require_valid(errors, Balance.STAT_BASE.has(row.get("id")), "UpgradeTable", row, "id", "必须是已有属性")
		var values: Array = row.get("values")
		TableUtil.require_valid(errors, values.size() == 4, "UpgradeTable", row, "values", "必须恰有 4 档")
		var previous: float = 0.0
		for value: Variant in values:
			if not TableUtil.is_number(value):
				TableUtil.require_valid(errors, false, "UpgradeTable", row, "values", "每档必须是数字")
				continue
			TableUtil.require_valid(errors, value > 0 and value >= previous, "UpgradeTable", row, "values", "各档必须为正且非递减")
			previous = float(value)
		TableUtil.require_valid(errors, row.get("group") in [&"", &"typed_damage"], "UpgradeTable", row, "group", "非法分组")
	# 字段不完整时，无法可靠判定属性覆盖，避免重复诊断。
	for row: Dictionary in rows:
		if not TableUtil.has_valid_shape(row, SCHEMA):
			return errors
	for id: StringName in Balance.STAT_BASE:
		var count: int = 0
		for row: Dictionary in rows:
			if row.get("id") == id:
				count += 1
		if count != 1:
			errors.append("UpgradeTable %s: id 必须恰好出现一次" % id)
	return errors
