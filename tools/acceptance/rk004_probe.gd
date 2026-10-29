extends SceneTree


func _show(name: String, errors: PackedStringArray) -> void:
	print("%s %s | %s" % ["CAUGHT" if not errors.is_empty() else "MISSED", name, " ; ".join(errors)])


func _init() -> void:
	var r: Array[Dictionary]
	r = WeaponTable.ROWS.duplicate(true); r[0]["kind"] = &"laser"; _show("weapon kind laser", WeaponTable.validate(r))
	r = WeaponTable.ROWS.duplicate(true); r[2]["tag"] = &"mechanical"; _show("staff tag mechanical", WeaponTable.validate(r))
	r = WeaponTable.ROWS.duplicate(true); r[6]["energy_cost"] = 3.0; _show("smg energy 3", WeaponTable.validate(r))
	r = WeaponTable.ROWS.duplicate(true); r[0]["pellets"] = 1.5; _show("pellets float", WeaponTable.validate(r))
	r = SoulTable.ROWS.duplicate(true); r[0]["tags"] = ["fire"]; _show("tag as String", SoulTable.validate(r))
	r = SoulTable.ROWS.duplicate(true); r[0]["id"] = "fireball"; _show("id as String", SoulTable.validate(r))
	r = SoulTable.ROWS.duplicate(true); r[1]["id"] = &"Knife"; _show("id uppercase", SoulTable.validate(r))
	r = SoulTable.ROWS.duplicate(true); r[6]["evolved_name_cn"] = "齿轮王"; _show("name without relic", SoulTable.validate(r))
	r = SoulTable.ROWS.duplicate(true); r[0]["damage_unit"] = &"tick"; _show("damage_unit tick", SoulTable.validate(r))
	r = SoulTable.ROWS.duplicate(true); r.append(r[0].duplicate(true)); _show("dup soul row", SoulTable.validate(r))
	r = RelicTable.ROWS.duplicate(true); r[0]["mods"] = {&"damge": 0.05}; _show("mod key typo", RelicTable.validate(r))
	r = RelicTable.ROWS.duplicate(true); r[11]["unique"] = false; _show("legendary not unique", RelicTable.validate(r))
	r = RelicTable.ROWS.duplicate(true); r[0]["price"] = 25; _show("common price 25", RelicTable.validate(r))
	r = RelicTable.ROWS.duplicate(true); r[13]["quality"] = &"rare"; r[13]["price"] = 35; _show("evo relic rare", RelicTable.validate(r))
	r = RelicTable.ROWS.duplicate(true); r[0]["mods"] = {&"damage": true}; _show("mod value bool", RelicTable.validate(r))
	r = EnemyTable.ROWS.duplicate(true); r[0]["hp"] = -1.0; _show("enemy hp -1", EnemyTable.validate(r))
	r = EnemyTable.ROWS.duplicate(true); r[1]["dash_speed"] = 5.0; _show("zombie dash", EnemyTable.validate(r))
	r = EnemyTable.ROWS.duplicate(true); r[0]["first_wave"] = 0; _show("first_wave 0", EnemyTable.validate(r))
	r = WaveTable.ROWS.duplicate(true); r[1]["first_wave"] = 8; _show("wave gap", WaveTable.validate(r))
	r = WaveTable.ROWS.duplicate(true); r[1]["first_wave"] = 6; _show("wave overlap", WaveTable.validate(r))
	r = WaveTable.ROWS.duplicate(true); r.reverse(); _show("wave reversed", WaveTable.validate(r))
	r = WaveTable.ROWS.duplicate(true); r[0]["elites_end"] = -1; _show("elites -1", WaveTable.validate(r))
	r = WaveTable.ROWS.duplicate(true); r[0].erase("last_wave"); _show("wave missing last_wave", WaveTable.validate(r))
	r = UpgradeTable.ROWS.duplicate(true); r[0]["values"] = [5.0, 10.0, 16.0]; _show("3 values", UpgradeTable.validate(r))
	r = UpgradeTable.ROWS.duplicate(true); r[0]["values"] = [5.0, 4.0, 16.0, 25.0]; _show("values decreasing", UpgradeTable.validate(r))
	r = UpgradeTable.ROWS.duplicate(true); r.remove_at(15); _show("luck row removed", UpgradeTable.validate(r))
	r = UpgradeTable.ROWS.duplicate(true); r[0]["values"] = [5.0, "10", 16.0, 25.0]; _show("value string", UpgradeTable.validate(r))
	var s: Array[Dictionary] = SoulTable.ROWS.duplicate(true)
	var rl: Array[Dictionary] = RelicTable.ROWS.duplicate(true)
	s[0].erase("id"); _show("soul without id refs", DataCheck.check_refs(s, rl, EnemyTable.ROWS, WaveTable.ROWS))
	var w: Array[Dictionary] = WaveTable.ROWS.duplicate(true)
	w.remove_at(1); _show("enemy beyond waves", DataCheck.check_refs(SoulTable.ROWS, RelicTable.ROWS, EnemyTable.ROWS, w))
	_show("empty waves", DataCheck.check_refs(SoulTable.ROWS, RelicTable.ROWS, EnemyTable.ROWS, [] as Array[Dictionary]))
	print("PROBE DONE")
	quit(0)
