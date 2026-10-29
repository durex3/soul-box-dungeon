class_name SoulTable
extends RefCounted

const SCHEMA: Dictionary = {
	"id": TYPE_STRING_NAME,
	"name_cn": TYPE_STRING,
	"tags": TYPE_ARRAY,
	"damage_t1": TYPE_FLOAT,
	"damage_unit": TYPE_STRING_NAME,
	"cooldown": TYPE_FLOAT,
	"sustained": TYPE_BOOL,
	"evolve_relic_id": TYPE_STRING_NAME,
	"evolved_name_cn": TYPE_STRING,
}

# GDD 7.2 节
const ROWS: Array[Dictionary] = [
	{ "id": &"fireball", "name_cn": "火球匣", "tags": [&"fire"], "damage_t1": 8.0, "damage_unit": &"hit", "cooldown": 1.2, "sustained": false, "evolve_relic_id": &"dragon_heart", "evolved_name_cn": "陨星匣" },
	{ "id": &"knife", "name_cn": "飞刀匣", "tags": [&"mechanical"], "damage_t1": 5.0, "damage_unit": &"hit", "cooldown": 0.6, "sustained": false, "evolve_relic_id": &"shadow_glove", "evolved_name_cn": "千刃匣" },
	{ "id": &"icicle", "name_cn": "冰锥匣", "tags": [&"frost"], "damage_t1": 6.0, "damage_unit": &"hit", "cooldown": 1.0, "sustained": false, "evolve_relic_id": &"permafrost_core", "evolved_name_cn": "冰河匣" },
	{ "id": &"chain_lightning", "name_cn": "雷链匣", "tags": [&"lightning"], "damage_t1": 7.0, "damage_unit": &"hit", "cooldown": 1.4, "sustained": false, "evolve_relic_id": &"storm_eye", "evolved_name_cn": "天罚匣" },
	{ "id": &"bone_shield", "name_cn": "骨盾匣", "tags": [&"undead"], "damage_t1": 4.0, "damage_unit": &"hit", "cooldown": 0.0, "sustained": true, "evolve_relic_id": &"hades_pact", "evolved_name_cn": "骨龙匣" },
	{ "id": &"holy_light", "name_cn": "圣光匣", "tags": [&"holy"], "damage_t1": 6.0, "damage_unit": &"hit", "cooldown": 2.0, "sustained": false, "evolve_relic_id": &"angel_wing", "evolved_name_cn": "审判匣" },
	{ "id": &"gear", "name_cn": "齿轮匣", "tags": [&"mechanical"], "damage_t1": 5.0, "damage_unit": &"hit", "cooldown": 1.1, "sustained": false, "evolve_relic_id": &"", "evolved_name_cn": "" },
	{ "id": &"poison_flask", "name_cn": "毒瓶匣", "tags": [&"fire", &"undead"], "damage_t1": 3.0, "damage_unit": &"per_sec", "cooldown": 2.5, "sustained": false, "evolve_relic_id": &"", "evolved_name_cn": "" },
	{ "id": &"frost_ring", "name_cn": "霜环匣", "tags": [&"frost", &"holy"], "damage_t1": 4.0, "damage_unit": &"hit", "cooldown": 3.0, "sustained": false, "evolve_relic_id": &"", "evolved_name_cn": "" },
	{ "id": &"arc", "name_cn": "电弧匣", "tags": [&"lightning", &"mechanical"], "damage_t1": 5.0, "damage_unit": &"hit", "cooldown": 0.0, "sustained": true, "evolve_relic_id": &"", "evolved_name_cn": "" },
	{ "id": &"greatsword", "name_cn": "巨剑匣", "tags": [&"melee"], "damage_t1": 10.0, "damage_unit": &"hit", "cooldown": 1.5, "sustained": false, "evolve_relic_id": &"war_god_soul", "evolved_name_cn": "王者匣" },
	{ "id": &"scythe", "name_cn": "镰刀匣", "tags": [&"melee", &"undead"], "damage_t1": 9.0, "damage_unit": &"hit", "cooldown": 1.8, "sustained": false, "evolve_relic_id": &"", "evolved_name_cn": "" },
]


## 返回本表的字段与业务错误，缺字段或类型错误的行不进入业务检查。
static func validate(rows: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = TableUtil.check_rows("SoulTable", rows, SCHEMA)
	for row: Dictionary in rows:
		if not TableUtil.has_valid_shape(row, SCHEMA):
			continue
		var tags: Array = row.get("tags")
		var seen: Array = []
		TableUtil.require_valid(errors, tags.size() >= 1 and tags.size() <= 2, "SoulTable", row, "tags", "必须有 1-2 个标签")
		for tag: Variant in tags:
			TableUtil.require_valid(errors, typeof(tag) == TYPE_STRING_NAME and tag in Balance.TAGS and tag not in seen, "SoulTable", row, "tags", "标签不合法或重复")
			seen.append(tag)
		TableUtil.require_valid(errors, row.get("damage_t1") > 0, "SoulTable", row, "damage_t1", "必须大于 0")
		TableUtil.require_valid(errors, row.get("damage_unit") in [&"hit", &"per_sec"], "SoulTable", row, "damage_unit", "非法单位")
		TableUtil.require_valid(errors, row.get("cooldown") == 0 if row.get("sustained") else row.get("cooldown") > 0, "SoulTable", row, "cooldown", "必须符合 sustained 状态")
		TableUtil.require_valid(errors, (row.get("evolve_relic_id") != &"") == (row.get("evolved_name_cn") != ""), "SoulTable", row, "evolve_relic_id/evolved_name_cn", "必须同时填写或同时留空")
	return errors
