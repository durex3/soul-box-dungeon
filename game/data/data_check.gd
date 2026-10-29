class_name DataCheck
extends RefCounted


## 验证全部真实数据和 Balance，再检查双向引用。
static func validate_all() -> PackedStringArray:
	var errors: PackedStringArray = []
	errors.append_array(SoulTable.validate(SoulTable.ROWS))
	errors.append_array(WeaponTable.validate(WeaponTable.ROWS))
	errors.append_array(RelicTable.validate(RelicTable.ROWS))
	errors.append_array(EnemyTable.validate(EnemyTable.ROWS))
	errors.append_array(WaveTable.validate(WaveTable.ROWS))
	errors.append_array(UpgradeTable.validate(UpgradeTable.ROWS))
	for field: StringName in Balance.STAT_CAP:
		if not Balance.STAT_BASE.has(field):
			errors.append("Balance STAT_CAP: 未知字段 %s" % field)
	for field: StringName in Balance.STAT_FLOOR:
		if not Balance.STAT_BASE.has(field):
			errors.append("Balance STAT_FLOOR: 未知字段 %s" % field)
	for field: StringName in Balance.RELIC_EXTRA_MODS:
		if Balance.STAT_BASE.has(field):
			errors.append("Balance RELIC_EXTRA_MODS: 重复字段 %s" % field)
	var total: float = 0.0
	for probability: float in Balance.UPGRADE_QUALITY_BASE:
		total += probability
	if absf(total - 1.0) > 0.0001:
		errors.append("Balance UPGRADE_QUALITY_BASE: 概率和必须为 1")
	errors.append_array(check_refs(SoulTable.ROWS, RelicTable.ROWS, EnemyTable.ROWS, WaveTable.ROWS))
	return errors


## 安全检查双向进化配方及敌人首次出现波次，空引用不参与检查。
static func check_refs(souls: Array[Dictionary], relics: Array[Dictionary], enemies: Array[Dictionary], waves: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = []
	_check_links(souls, relics, "SoulTable", "evolve_relic_id", "evolves_soul_id", errors)
	_check_links(relics, souls, "RelicTable", "evolves_soul_id", "evolve_relic_id", errors)
	var last_wave: int = 0
	if not waves.is_empty() and typeof(waves[-1].get("last_wave")) == TYPE_INT:
		last_wave = waves[-1].get("last_wave")
	for row: Dictionary in enemies:
		if typeof(row.get("first_wave")) == TYPE_INT and row.get("first_wave") > last_wave:
			errors.append("EnemyTable %s: first_wave 超出波次表 last_wave" % row.get("id", "未知行"))
	return errors


static func _check_links(source: Array[Dictionary], targets: Array[Dictionary], table: String, field: String, back_field: String, errors: PackedStringArray) -> void:
	for i: int in source.size():
		var row: Dictionary = source[i]
		var reference: Variant = row.get(field, &"")
		if reference == &"":
			continue
		var found: bool = false
		for target: Dictionary in targets:
			if target.has("id") and target.get("id") == reference:
				found = true
				if not row.has("id") or target.get(back_field) != row.get("id"):
					errors.append("%s %s: %s %s 的 %s 未指回" % [table, row.get("id", "第 %d 行" % (i + 1)), field, reference, back_field])
				break
		if not found:
			errors.append("%s %s: %s 引用不存在的 id %s" % [table, row.get("id", "第 %d 行" % (i + 1)), field, reference])
