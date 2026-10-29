#!/bin/zsh
# RK-003 验收：测试运行器和分层检查的故障注入。用法：zsh tools/acceptance/rk003_probe.sh <工作树路径>
W="$1"; cd "$W" || exit 2
LOG=/tmp/rk003-probe; rm -rf "$LOG"; mkdir -p "$LOG"

put() { mkdir -p "$(dirname "$1")"; printf '%b' "$2" > "$1"; }
clean() { for f in "$@"; do rm -f "$f" "$f.uid"; done; rmdir game/tests/sub 2>/dev/null; true; }
run() {
  local name="$1"; shift
  local s=$(date +%s)
  python3 tools/run_tests.py "$@" > "$LOG/$name.log" 2>&1; local rc=$?
  echo "== $name exit=$rc secs=$(( $(date +%s) - s ))"
  grep -E '^(STEP [0-9] FAIL|FAIL |LOAD FAIL|TESTS:|RUN .*probe|RUN .*nested|game/|.*SCRIPT ERROR|.*ERROR:|超时|退出码|缺少)' "$LOG/$name.log" | head -12
}

T=game/tests
H='extends GdTest\n\n\n'

# 1 断言失败
put $T/test_zz_probe_fail.gd "${H}func test_fail() -> void:\n\teq(1, 2, \"probe\")\n"
run 1_assert; clean $T/test_zz_probe_fail.gd

# 2 运行时报错 + 同文件正常方法
put $T/test_zz_probe_err.gd "${H}func test_a_error() -> void:\n\tvar a: Array = []\n\tvar v: Variant = a[5]\n\tok(v == null)\n\n\nfunc test_b_normal() -> void:\n\tok(true)\n"
run 2_runtime; clean $T/test_zz_probe_err.gd

# 3 死循环
put $T/test_zz_probe_loop.gd "${H}func test_loop() -> void:\n\twhile true:\n\t\tpass\n"
run 3_loop --timeout 20; clean $T/test_zz_probe_loop.gd
echo "-- headless godot left:"; pgrep -fl 'Godot.*headless' || echo none

# 4 解析错误
put $T/test_zz_probe_parse.gd "${H}func test_x() -> void\n\tok(true)\n"
run 4_parse; clean $T/test_zz_probe_parse.gd

# 5 sim 里 extends Node
put game/sim/probe_node.gd "extends Node\n"
run 5_layer; clean game/sim/probe_node.gd

# 额外样例
put $T/sub/test_zz_nested.gd "${H}func test_nested() -> void:\n\teq(\"a\", \"b\", \"nested\")\n"
run E1_nested_dir; clean $T/sub/test_zz_nested.gd

put $T/test_zz_probe_plain.gd "extends RefCounted\n\n\nfunc test_x() -> void:\n\tpass\n"
run E2_not_gdtest; clean $T/test_zz_probe_plain.gd

put $T/test_zz_probe_push.gd "${H}func test_push() -> void:\n\tpush_error(\"boom\")\n\tok(true)\n"
run E3_push_error; clean $T/test_zz_probe_push.gd

put game/sim/probe_time.gd "extends RefCounted\n\n\nfunc now() -> int:\n\treturn Time.get_ticks_msec()\n"
run E4_sim_time; clean game/sim/probe_time.gd

put game/data/probe_ref.gd "extends RefCounted\n\nconst P: String = \"res://sim/x.gd\"\n"
run E5_data_ref_sim; clean game/data/probe_ref.gd

put game/sim/probe_inline.gd "class_name ProbeInline extends Node2D\n"
run E6_inline_extends; clean game/sim/probe_inline.gd

GODOT_BIN=/nope/Godot python3 tools/run_tests.py > "$LOG/E7_no_godot.log" 2>&1
echo "== E7_no_godot exit=$?"; tail -1 "$LOG/E7_no_godot.log"

# 6 全部删掉后
run 6_clean
echo "-- git status:"; git status --short --untracked-files=all | grep -v '^?? game/.godot' || echo clean
