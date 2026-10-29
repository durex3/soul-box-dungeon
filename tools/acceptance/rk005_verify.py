"""RK-005 验收。用法：python3 -I tools/acceptance/rk005_verify.py <工作树>"""
import pathlib, re, subprocess, sys

W = pathlib.Path(sys.argv[1])
M = (1 << 64) - 1


def signed(x):
    x &= M
    return x - (1 << 64) if x >> 63 else x


def derive(seed, name):
    h = 0xCBF29CE484222325
    for b in name.encode("utf-8"):
        h = ((h ^ b) * 0x100000001B3) & M
    x = (h ^ (seed & M)) & M
    x = (x + 0x9E3779B97F4A7C15) & M
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & M
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & M
    return signed(x ^ (x >> 31))


def run(*args, timeout=600):
    p = subprocess.run(args, cwd=W, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, timeout=timeout)
    return p.returncode, p.stdout


def tests():
    rc, out = run("python3", "tools/run_tests.py")
    last = [l for l in out.splitlines() if l.strip()][-1:] or [""]
    fails = [l for l in out.splitlines() if "FAIL" in l or "错误" in l or "禁止" in l or "只能" in l]
    return rc, last[0], fails[:4]


# 1. 参考值：Codex 测试里写死的值 + 我另选的种子
test_src = (W / "game/tests/sim/core/test_run_rng.gd").read_text(encoding="utf-8")
print("== 1 reference vectors in Codex tests")
for seed, name, val in re.findall(r'derive_seed\((-?\d+), &"([^"]*)"\), (-?\d+)\)', test_src):
    ok = derive(int(seed), name) == int(val)
    print(" ", "ok " if ok else "BAD", seed, repr(name), val)
for name, val in [("spawn", 7640713538129709433), ("shop", 5310988902323854553),
                  ("loot", -244990251510703615), ("upgrade", 49347111058617004)]:
    print(" ", "ok " if derive(12345, name) == val else "BAD", 12345, name)

# 我另选的种子：写一个临时测试让 Godot 算，和 Python 对比
extra = [(7, "spawn"), (-123456789, "shop"), (2026102900, "loot"), (-2, "upgrade"),
         (1 << 40, "spawn"), (-(1 << 62), "loot")]
probe = W / "game/tests/sim/core/test_zz_pm_probe.gd"
lines = ["extends GdTest", "", "", "func test_pm_vectors() -> void:"]
for s, n in extra:
    lines.append('\teq(RunRng.derive_seed(%d, &"%s"), %d)' % (s, n, derive(s, n)))
probe.write_text("\n".join(lines) + "\n", encoding="utf-8")
rc, last, fails = tests()
print("== 1b PM extra seeds via Godot: exit", rc, "|", last)
probe.unlink()
for p in W.glob("game/tests/sim/core/test_zz_pm_probe.gd*"):
    p.unlink()

# 2. MIX_ADD 改 1
rng = W / "game/sim/core/run_rng.gd"
orig = rng.read_text(encoding="utf-8")
rng.write_text(orig.replace("-7046029254386353131", "-7046029254386353130", 1), encoding="utf-8")
rc, last, fails = tests()
print("== 2 MIX_ADD+1: exit", rc, "|", last)
rng.write_text(orig, encoding="utf-8")

# 3. core 下新建生成器
bad = W / "game/sim/core/pm_bad.gd"
bad.write_text("extends RefCounted\n\nvar r: RandomNumberGenerator = RandomNumberGenerator.new()\n",
               encoding="utf-8")
rc, last, fails = tests()
print("== 3 new RNG in core: exit", rc, "|", fails[:2])
bad.unlink()

# 4. _init 里 spawn.randomize()
rng.write_text(orig.replace("\tspawn = RandomNumberGenerator.new()\n",
                            "\tspawn = RandomNumberGenerator.new()\n\tspawn.randomize()\n", 1),
               encoding="utf-8")
rc, last, fails = tests()
print("== 4 spawn.randomize(): exit", rc, "|", fails[:2])
rng.write_text(orig, encoding="utf-8")

# 5. 说明里没列的违规写法，直接调 lint
sys.path.insert(0, str(W / "tools"))
import lint_layers  # noqa: E402
cases = {
    "class_ref_new": "var C = RandomNumberGenerator\nvar r = C.new()",
    "tab_spaces": "var r = RandomNumberGenerator\t.new()",
    "randomize_tab": "spawn.randomize\t()",
    "nested_path": None,  # 子目录里的 run_rng.gd
    "global_seed": "seed(42)",
    "rand_from_seed": "rand_from_seed(1)",
}
print("== 5 extra violations (True = blocked)")
import tempfile, shutil  # noqa: E402
for key, src in cases.items():
    d = pathlib.Path(tempfile.mkdtemp())
    rel = "sim/core/x/run_rng.gd" if key == "nested_path" else "sim/core/probe.gd"
    f = d / rel
    f.parent.mkdir(parents=True)
    f.write_text("extends RefCounted\n" + (src or "var r = RandomNumberGenerator.new()") + "\n",
                 encoding="utf-8")
    print(" ", key, bool(lint_layers.lint(d)))
    shutil.rmtree(d)

rc, out = run("git", "status", "--short")
print("== git status:", out.strip() or "clean")
