extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _find_tests(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		_load_fail(path)
		return files
	for child: String in dir.get_directories():
		files.append_array(_find_tests(path.path_join(child)))
	for file: String in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(path.path_join(file))
	files.sort()
	return files


func _load_fail(path: String) -> void:
	print("LOAD FAIL %s" % path)
	_failed += 1


func _run() -> void:
	for path: String in _find_tests("res://tests"):
		_run_file(path)
	if _passed + _failed == 0:
		print("FAIL no test methods found")
		_failed += 1
	print("TESTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run_file(path: String) -> void:
	var script: Script = load(path) as Script
	if script == null or not script.can_instantiate():
		_load_fail(path)
		return
	var methods: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = str(method["name"])
		if method_name.begins_with("test_"):
			methods.append(method_name)
	methods.sort()
	for method: String in methods:
		_run_method(script, path, method)


func _run_method(script: Script, path: String, method: String) -> void:
	print("RUN %s::%s" % [path, method])
	# 在独立函数中实例化，构造方法出错不会中止外层的退出逻辑。
	var test: GdTest = _create_test(script)
	if test == null:
		_load_fail(path)
		return
	# call() 的脚本错误会返回到此处；Python 包装器另行扫描错误输出。
	test.call(method)
	var failures: Array[String] = test.get_failures()
	if failures.is_empty():
		_passed += 1
	else:
		_failed += 1
		for failure: String in failures:
			print("FAIL %s::%s %s" % [path, method, failure])


func _create_test(script: Script) -> GdTest:
	var instance: Variant = script.new()
	if instance is GdTest:
		return instance as GdTest
	if instance is Node:
		instance.free()
	return null
