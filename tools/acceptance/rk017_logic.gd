extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var failed: bool = false
	var paths: Array[String] = ["res://tests/sim/combat/test_weapon_state.gd","res://tests/sim/combat/test_weapon_fire.gd"]
	if args.size() == 2:
		paths = [args[0]]
	for path: String in paths:
		var script: Script = load(path) as Script
		var methods: Array[String] = []
		if args.size() == 2:
			methods = [args[1]]
		else:
			for entry: Dictionary in script.get_script_method_list():
				if str(entry.name).begins_with("test_"):
					methods.append(entry.name)
			methods.sort()
		if methods.is_empty():
			failed = true
		for method: String in methods:
			print("RK017 RUN ",path,"::",method)
			var test: GdTest = script.new() as GdTest
			test.call(method)
			for failure: String in test.get_failures():
				print("RK017 FAIL ",failure)
				failed = true
	print("RK017_LOGIC: " + ("failed" if failed else "passed"))
	quit(1 if failed else 0)
