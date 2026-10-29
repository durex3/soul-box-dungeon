class_name RelicTable
extends RefCounted

const SCHEMA: Dictionary = {
	"id": TYPE_STRING_NAME,
	"name_cn": TYPE_STRING,
	"quality": TYPE_STRING_NAME,
	"price": TYPE_INT,
	"unique": TYPE_BOOL,
	"mods": TYPE_DICTIONARY,
	"special": TYPE_STRING_NAME,
	"evolves_soul_id": TYPE_STRING_NAME,
	"effect_cn": TYPE_STRING,
}

# GDD 8.2、8.3 节
const ROWS: Array[Dictionary] = [
	{ "id": &"whetstone", "name_cn": "磨刀石", "quality": &"common", "price": 18, "unique": false, "mods": { &"damage": 0.05 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "伤害 +5%" },
	{ "id": &"feather_boots", "name_cn": "轻羽靴", "quality": &"common", "price": 15, "unique": false, "mods": { &"move_speed": 0.05, &"armor": -1.0 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "移速 +5%，护甲 -1" },
	{ "id": &"frenzy_potion", "name_cn": "狂热药剂", "quality": &"common", "price": 20, "unique": false, "mods": { &"attack_speed": 0.08, &"move_speed": -0.03 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "攻速 +8%，移速 -3%" },
	{ "id": &"vampire_fang", "name_cn": "吸血獠牙", "quality": &"rare", "price": 35, "unique": false, "mods": { &"lifesteal": 0.03 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "吸血 +3%" },
	{ "id": &"magnet", "name_cn": "磁石", "quality": &"rare", "price": 30, "unique": false, "mods": { &"pickup_range_pct": 0.4 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "拾取范围 +40%" },
	{ "id": &"piggy_bank", "name_cn": "存钱罐", "quality": &"rare", "price": 40, "unique": false, "mods": { &"income": 5.0, &"damage": -0.03 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "收益 +5，伤害 -3%" },
	{ "id": &"glass_cannon", "name_cn": "玻璃大炮", "quality": &"epic", "price": 70, "unique": false, "mods": { &"damage": 0.3, &"max_hp_pct": -0.25 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "伤害 +30%，生命上限 -25%" },
	{ "id": &"hound_collar", "name_cn": "猎犬项圈", "quality": &"epic", "price": 80, "unique": false, "mods": {  }, "special": &"crit_homing_shot", "evolves_soul_id": &"", "effect_cn": "暴击时发射一枚追踪弹" },
	{ "id": &"tuning_fork", "name_cn": "共鸣音叉", "quality": &"rare", "price": 35, "unique": false, "mods": { &"resonance_gain": 0.2, &"soul_damage": -0.04 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "共鸣获取 +20%，魂匣伤害 -4%" },
	{ "id": &"hunter_mark", "name_cn": "猎手印记", "quality": &"rare", "price": 35, "unique": false, "mods": { &"mark_multiplier": 0.1, &"mark_cap": -3.0 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "魂印倍率 +0.1，魂印上限 -3" },
	{ "id": &"echo_bell", "name_cn": "回响之铃", "quality": &"epic", "price": 75, "unique": false, "mods": {  }, "special": &"resonance_double_attack", "evolves_soul_id": &"", "effect_cn": "共鸣触发时，魂匣立即攻击的次数改为 2 次" },
	{ "id": &"time_hourglass", "name_cn": "时之沙漏", "quality": &"legendary", "price": 150, "unique": true, "mods": {  }, "special": &"revive_once", "evolves_soul_id": &"", "effect_cn": "生命首次归零时回到 50%（每局 1 次）" },
	{ "id": &"twin_heart", "name_cn": "双生之心", "quality": &"legendary", "price": 180, "unique": true, "mods": { &"soul_slots": 1.0 }, "special": &"", "evolves_soul_id": &"", "effect_cn": "魂匣栏位 +1" },
	{ "id": &"dragon_heart", "name_cn": "龙心", "quality": &"epic", "price": 80, "unique": true, "mods": { &"fire_damage": 0.1 }, "special": &"", "evolves_soul_id": &"fireball", "effect_cn": "火焰伤害 +10%" },
	{ "id": &"shadow_glove", "name_cn": "影之手套", "quality": &"epic", "price": 80, "unique": true, "mods": { &"soul_attack_speed": 0.06 }, "special": &"", "evolves_soul_id": &"knife", "effect_cn": "魂匣攻速 +6%" },
	{ "id": &"permafrost_core", "name_cn": "永冻核心", "quality": &"epic", "price": 80, "unique": true, "mods": { &"slow_effect": 0.1 }, "special": &"", "evolves_soul_id": &"icicle", "effect_cn": "减速效果 +10%" },
	{ "id": &"storm_eye", "name_cn": "风暴之眼", "quality": &"epic", "price": 80, "unique": true, "mods": { &"chain_count": 1.0 }, "special": &"", "evolves_soul_id": &"chain_lightning", "effect_cn": "雷电连锁数 +1" },
	{ "id": &"hades_pact", "name_cn": "冥王契约", "quality": &"epic", "price": 80, "unique": true, "mods": { &"undead_heal_cap": 2.0 }, "special": &"", "evolves_soul_id": &"bone_shield", "effect_cn": "亡灵击杀回复上限 +2 次/秒" },
	{ "id": &"angel_wing", "name_cn": "天使羽翼", "quality": &"epic", "price": 80, "unique": true, "mods": { &"move_speed": 0.05, &"hp_regen": 1.0 }, "special": &"", "evolves_soul_id": &"holy_light", "effect_cn": "移速 +5%，生命回复 +1" },
	{ "id": &"war_god_soul", "name_cn": "战神之魂", "quality": &"epic", "price": 80, "unique": true, "mods": { &"melee_damage": 0.1 }, "special": &"", "evolves_soul_id": &"greatsword", "effect_cn": "近战伤害 +10%" },
]


## 返回本表的字段与业务错误，缺字段或类型错误的行不进入业务检查。
static func validate(rows: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = TableUtil.check_rows("RelicTable", rows, SCHEMA)
	for row: Dictionary in rows:
		if not TableUtil.has_valid_shape(row, SCHEMA):
			continue
		var quality: StringName = row.get("quality")
		TableUtil.require_valid(errors, quality in Balance.QUALITIES, "RelicTable", row, "quality", "非法品质")
		if Balance.RELIC_PRICE_RANGE.has(quality):
			var limits: Array = Balance.RELIC_PRICE_RANGE.get(quality)
			TableUtil.require_valid(errors, row.get("price") >= limits[0] and row.get("price") <= limits[1], "RelicTable", row, "price", "超出品质允许范围")
		TableUtil.require_valid(errors, quality != &"legendary" or row.get("unique"), "RelicTable", row, "unique", "传说遗物必须唯一")
		var mods: Dictionary = row.get("mods")
		for key: Variant in mods:
			TableUtil.require_valid(errors, typeof(key) == TYPE_STRING_NAME and (Balance.STAT_BASE.has(key) or key in Balance.RELIC_EXTRA_MODS), "RelicTable", row, "mods", "非法属性 %s" % key)
			TableUtil.require_valid(errors, TableUtil.is_number(mods.get(key)) and mods.get(key) != 0, "RelicTable", row, "mods", "属性 %s 必须是非零数字" % key)
		TableUtil.require_valid(errors, not mods.is_empty() or row.get("special") != &"", "RelicTable", row, "mods/special", "不能同时为空")
		TableUtil.require_valid(errors, row.get("evolves_soul_id") == &"" or (quality == &"epic" and row.get("unique")), "RelicTable", row, "evolves_soul_id", "进化遗物必须为唯一史诗")
	return errors
