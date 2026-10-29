extends GdTest


## 真实数据及 Balance 通过全部校验。
func test_validate_all() -> void:
	var errors: PackedStringArray = DataCheck.validate_all()
	eq(errors.size(), 0, "\n".join(errors))


## 不存在的遗物与魂匣引用均会报错。
func test_missing_references() -> void:
	var souls: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	souls[0]["evolve_relic_id"] = &"missing"
	ok(not DataCheck.check_refs(souls, RelicTable.ROWS, EnemyTable.ROWS, WaveTable.ROWS).is_empty())
	var relics: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	relics[13]["evolves_soul_id"] = &"missing"
	ok(not DataCheck.check_refs(SoulTable.ROWS, relics, EnemyTable.ROWS, WaveTable.ROWS).is_empty())


## 错配配方两边都给出未指回诊断。
func test_bidirectional_references() -> void:
	var relics: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	relics[13]["evolves_soul_id"] = &"knife"
	var errors: PackedStringArray = DataCheck.check_refs(SoulTable.ROWS, relics, EnemyTable.ROWS, WaveTable.ROWS)
	eq(errors.size(), 2)
	ok(errors[0].contains("SoulTable fireball"))
	ok(errors[1].contains("RelicTable dragon_heart"))


## 敌人首波不能超出原型范围。
func test_enemy_wave_limit() -> void:
	var enemies: Array[Dictionary] = EnemyTable.ROWS.duplicate(true)
	enemies[0]["first_wave"] = 13
	var errors: PackedStringArray = DataCheck.check_refs(SoulTable.ROWS, RelicTable.ROWS, enemies, WaveTable.ROWS)
	eq(errors.size(), 1)
	ok(errors[0].contains("EnemyTable skeleton_rat") and errors[0].contains("first_wave"))


## 空引用和缺字段输入不会造成脚本错误。
func test_empty_and_missing_refs() -> void:
	eq(DataCheck.check_refs([{}], [{}], [{}], []).size(), 0)
	eq(DataCheck.check_refs([{ "id": &"x", "evolve_relic_id": &"" }], [], [], []).size(), 0)
