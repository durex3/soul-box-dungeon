class_name WeaponTable
extends RefCounted

const SCHEMA: Dictionary = {
	"id": TYPE_STRING_NAME,
	"name_cn": TYPE_STRING,
	"kind": TYPE_STRING_NAME,
	"tag": TYPE_STRING_NAME,
	"damage": TYPE_FLOAT,
	"shots_per_sec": TYPE_FLOAT,
	"pellets": TYPE_INT,
	"spread_deg": TYPE_FLOAT,
	"pierce": TYPE_INT,
	"arc_deg": TYPE_FLOAT,
	"energy_cost": TYPE_FLOAT,
	"resonance_per_hit": TYPE_FLOAT,
}

# GDD 6.1、6.3 节
const ROWS: Array[Dictionary] = [
	{ "id": &"knight_sword", "name_cn": "骑士剑", "kind": &"melee", "tag": &"", "damage": 18.0, "shots_per_sec": 1.6, "pellets": 1, "spread_deg": 0.0, "pierce": 0, "arc_deg": 120.0, "energy_cost": 0.0, "resonance_per_hit": 0.0 },
	{ "id": &"great_hammer", "name_cn": "巨锤", "kind": &"melee", "tag": &"", "damage": 32.0, "shots_per_sec": 0.9, "pellets": 1, "spread_deg": 0.0, "pierce": 0, "arc_deg": 120.0, "energy_cost": 0.0, "resonance_per_hit": 7.0 },
	{ "id": &"apprentice_fire_staff", "name_cn": "学徒火杖", "kind": &"staff", "tag": &"fire", "damage": 12.0, "shots_per_sec": 2.0, "pellets": 1, "spread_deg": 0.0, "pierce": 0, "arc_deg": 0.0, "energy_cost": 3.0, "resonance_per_hit": 0.0 },
	{ "id": &"frost_staff", "name_cn": "寒冰法杖", "kind": &"staff", "tag": &"frost", "damage": 12.0, "shots_per_sec": 2.0, "pellets": 1, "spread_deg": 0.0, "pierce": 0, "arc_deg": 0.0, "energy_cost": 3.0, "resonance_per_hit": 0.0 },
	{ "id": &"old_revolver", "name_cn": "旧式左轮", "kind": &"pistol", "tag": &"", "damage": 10.0, "shots_per_sec": 3.0, "pellets": 1, "spread_deg": 0.0, "pierce": 0, "arc_deg": 0.0, "energy_cost": 1.0, "resonance_per_hit": 0.0 },
	{ "id": &"double_shotgun", "name_cn": "双管猎枪", "kind": &"shotgun", "tag": &"", "damage": 6.0, "shots_per_sec": 1.0, "pellets": 5, "spread_deg": 30.0, "pierce": 0, "arc_deg": 0.0, "energy_cost": 4.0, "resonance_per_hit": 0.0 },
	{ "id": &"goblin_smg", "name_cn": "地精冲锋枪", "kind": &"rifle", "tag": &"", "damage": 5.0, "shots_per_sec": 8.0, "pellets": 1, "spread_deg": 0.0, "pierce": 0, "arc_deg": 0.0, "energy_cost": 1.0, "resonance_per_hit": 0.0 },
	{ "id": &"starlight_bow", "name_cn": "星辉长弓", "kind": &"sniper", "tag": &"", "damage": 40.0, "shots_per_sec": 0.8, "pellets": 1, "spread_deg": 0.0, "pierce": 3, "arc_deg": 0.0, "energy_cost": 7.0, "resonance_per_hit": 0.0 },
]


## 返回本表的字段与业务错误，缺字段或类型错误的行不进入业务检查。
static func validate(rows: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = TableUtil.check_rows("WeaponTable", rows, SCHEMA)
	for row: Dictionary in rows:
		if not TableUtil.has_valid_shape(row, SCHEMA):
			continue
		var kind: StringName = row.get("kind")
		TableUtil.require_valid(errors, kind in Balance.WEAPON_KINDS, "WeaponTable", row, "kind", "非法武器类型")
		TableUtil.require_valid(errors, row.get("tag") in [&"fire", &"frost", &"lightning", &"undead", &"holy"] if kind == &"staff" else row.get("tag") == &"", "WeaponTable", row, "tag", "必须符合武器类型")
		for field: String in ["damage", "shots_per_sec"]:
			TableUtil.require_valid(errors, row.get(field) > 0, "WeaponTable", row, field, "必须大于 0")
		TableUtil.require_valid(errors, row.get("pellets") >= 1, "WeaponTable", row, "pellets", "必须至少为 1")
		if Balance.WEAPON_ENERGY_RANGE.has(kind):
			var limits: Array = Balance.WEAPON_ENERGY_RANGE.get(kind)
			TableUtil.require_valid(errors, row.get("energy_cost") >= limits[0] and row.get("energy_cost") <= limits[1], "WeaponTable", row, "energy_cost", "超出类型允许范围")
		TableUtil.require_valid(errors, row.get("resonance_per_hit") >= 0, "WeaponTable", row, "resonance_per_hit", "不得为负")
	return errors
