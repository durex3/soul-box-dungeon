class_name GdTest
extends RefCounted

var _failures: Array[String] = []


## 记录相等断言，失败后继续执行。
func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		_failures.append("eq expected=%s actual=%s msg=%s" % [expected, actual, msg])


## 记录绝对误差断言，失败后继续执行。
func near(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if not absf(actual - expected) <= eps:
		_failures.append("near expected=%s eps=%s actual=%s msg=%s" % [expected, eps, actual, msg])


## 记录布尔断言，失败后继续执行。
func ok(cond: bool, msg: String = "") -> void:
	if not cond:
		_failures.append("ok expected=true actual=%s msg=%s" % [cond, msg])


## 返回失败记录的副本，避免调用者修改内部状态。
func get_failures() -> Array[String]:
	return _failures.duplicate()
