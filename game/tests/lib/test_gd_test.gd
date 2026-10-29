extends GdTest


## 相等值不记录失败。
func test_eq_pass() -> void:
	var subject: GdTest = GdTest.new()
	subject.eq(1, 1)
	eq(subject.get_failures().size(), 0)


## 不等值记录期望、实际值和上下文。
func test_eq_fail() -> void:
	var subject: GdTest = GdTest.new()
	subject.eq(1, 2, "context")
	eq(subject.get_failures().size(), 1)
	ok(subject.get_failures()[0].contains("eq expected=2 actual=1 msg=context"))


## near 接受误差边界，拒绝误差外值。
func test_near() -> void:
	var subject: GdTest = GdTest.new()
	subject.near(1.125, 1.0, 0.125)
	eq(subject.get_failures().size(), 0)
	subject.near(1.25, 1.0, 0.125, "outside")
	eq(subject.get_failures().size(), 1)
	ok(subject.get_failures()[0].contains("near expected="))
	ok(subject.get_failures()[0].contains("actual=1.25 msg=outside"))


## 连续失败不中断方法，ok 同样记录上下文。
func test_multiple_failures() -> void:
	var subject: GdTest = GdTest.new()
	subject.eq(1, 2)
	subject.ok(false, "second")
	subject.ok(true)
	eq(subject.get_failures().size(), 2)
	ok(subject.get_failures()[1].contains("ok expected=true actual=false msg=second"))


## 调用者取得的数组不会泄漏内部状态。
func test_failures_copy() -> void:
	var subject: GdTest = GdTest.new()
	subject.eq(1, 2)
	var failures: Array[String] = subject.get_failures()
	failures.clear()
	eq(subject.get_failures().size(), 1)
