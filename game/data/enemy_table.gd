class_name EnemyTable
extends RefCounted

const SCHEMA: Dictionary = {
	"id": TYPE_STRING_NAME,
	"name_cn": TYPE_STRING,
	"archetype": TYPE_STRING_NAME,
	"hp": TYPE_FLOAT,
	"damage": TYPE_FLOAT,
	"move_speed": TYPE_FLOAT,
	"dash_speed": TYPE_FLOAT,
	"xp": TYPE_FLOAT,
	"child_xp": TYPE_FLOAT,
	"first_wave": TYPE_INT,
}

# GDD 11.4 节
const ROWS: Array[Dictionary] = [
	{ "id": &"skeleton_rat", "name_cn": "骷髅鼠", "archetype": &"swarm", "hp": 4.0, "damage": 3.0, "move_speed": 4.5, "dash_speed": 0.0, "xp": 1.0, "child_xp": 0.0, "first_wave": 1 },
	{ "id": &"crypt_zombie", "name_cn": "墓穴僵尸", "archetype": &"melee", "hp": 12.0, "damage": 6.0, "move_speed": 2.5, "dash_speed": 0.0, "xp": 2.0, "child_xp": 0.0, "first_wave": 1 },
	{ "id": &"charge_boar", "name_cn": "冲锋野猪", "archetype": &"charger", "hp": 20.0, "damage": 10.0, "move_speed": 3.5, "dash_speed": 12.0, "xp": 3.0, "child_xp": 0.0, "first_wave": 2 },
	{ "id": &"bone_archer", "name_cn": "骨弓手", "archetype": &"shooter", "hp": 10.0, "damage": 5.0, "move_speed": 2.5, "dash_speed": 0.0, "xp": 2.0, "child_xp": 0.0, "first_wave": 3 },
	{ "id": &"blast_mushroom", "name_cn": "爆炸蘑菇", "archetype": &"bomber", "hp": 8.0, "damage": 20.0, "move_speed": 3.5, "dash_speed": 0.0, "xp": 2.0, "child_xp": 0.0, "first_wave": 4 },
	{ "id": &"slime", "name_cn": "史莱姆", "archetype": &"splitter", "hp": 18.0, "damage": 5.0, "move_speed": 3.5, "dash_speed": 0.0, "xp": 2.0, "child_xp": 0.5, "first_wave": 5 },
	{ "id": &"fire_mage", "name_cn": "火焰术士", "archetype": &"shooter", "hp": 14.0, "damage": 6.0, "move_speed": 2.5, "dash_speed": 0.0, "xp": 3.0, "child_xp": 0.0, "first_wave": 7 },
	{ "id": &"lava_golem", "name_cn": "熔岩傀儡", "archetype": &"tank", "hp": 80.0, "damage": 12.0, "move_speed": 2.5, "dash_speed": 0.0, "xp": 6.0, "child_xp": 0.0, "first_wave": 8 },
]


## 返回本表的字段与业务错误，缺字段或类型错误的行不进入业务检查。
static func validate(rows: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = TableUtil.check_rows("EnemyTable", rows, SCHEMA)
	for row: Dictionary in rows:
		if not TableUtil.has_valid_shape(row, SCHEMA):
			continue
		var archetype: StringName = row.get("archetype")
		TableUtil.require_valid(errors, archetype in Balance.ENEMY_ARCHETYPES, "EnemyTable", row, "archetype", "非法敌人类型")
		for field: String in ["hp", "damage", "xp"]:
			TableUtil.require_valid(errors, row.get(field) > 0, "EnemyTable", row, field, "必须大于 0")
		TableUtil.require_valid(errors, row.get("move_speed") >= 0, "EnemyTable", row, "move_speed", "不得为负")
		TableUtil.require_valid(errors, row.get("dash_speed") > 0 if archetype == &"charger" else row.get("dash_speed") == 0, "EnemyTable", row, "dash_speed", "仅 charger 大于 0，其余为 0")
		TableUtil.require_valid(errors, row.get("child_xp") > 0 if archetype == &"splitter" else row.get("child_xp") == 0, "EnemyTable", row, "child_xp", "仅 splitter 大于 0，其余为 0")
		TableUtil.require_valid(errors, row.get("first_wave") >= 1, "EnemyTable", row, "first_wave", "必须至少为 1")
	return errors
