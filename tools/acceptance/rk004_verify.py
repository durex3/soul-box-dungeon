"""RK-004 验收：在独立工作树里重做自检 2-4 步并跑探针。用法：python3 -I tools/acceptance/rk004_verify.py <工作树>"""
import shutil
import subprocess
import sys
from pathlib import Path

W = Path(sys.argv[1])
G = "/Applications/Godot.app/Contents/MacOS/Godot"


def run(cmd, timeout=300):
    try:
        p = subprocess.run(cmd, cwd=W, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        return "TIMEOUT", (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")


def errs(out):
    return [l for l in out.splitlines() if "ERROR" in l]


def edit(path, old, new):
    p = W / path
    s = p.read_text(encoding="utf-8")
    assert s.count(old) == 1, (path, old)
    p.write_text(s.replace(old, new), encoding="utf-8")


soul = "game/data/soul_table.gd"
relic = "game/data/relic_table.gd"
orig_soul = (W / soul).read_text(encoding="utf-8")
orig_relic = (W / relic).read_text(encoding="utf-8")

print("== baseline run_tests")
code, out = run([sys.executable, "tools/run_tests.py"], 600)
print("exit", code, "|", out.strip().splitlines()[-1])

print("== step2 remove fireball cooldown")
edit(soul, '"damage_unit": &"hit", "cooldown": 1.2, "sustained": false, "evolve_relic_id": &"dragon_heart"',
     '"damage_unit": &"hit", "sustained": false, "evolve_relic_id": &"dragon_heart"')
code, out = run([sys.executable, "tools/run_tests.py"], 600)
print("exit", code)
print("\n".join([l for l in out.splitlines() if "FAIL" in l or "cooldown" in l][:6]))

print("== step3 boot with broken data")
code, out = run([G, "--headless", "--path", "game", "--quit-after", "10"], 120)
print("exit", code)
print("\n".join(errs(out)[:4]))
(W / soul).write_text(orig_soul, encoding="utf-8")
code, out = run([G, "--headless", "--path", "game", "--quit-after", "10"], 120)
print("restored boot exit", code, "errors", len(errs(out)))

print("== step4 dragon_heart -> knife")
edit(relic, '"evolves_soul_id": &"fireball"', '"evolves_soul_id": &"knife"')
(W / "game/zz_vc.gd").write_text(
    "extends SceneTree\nfunc _init() -> void:\n\tfor e: String in DataCheck.validate_all():\n\t\tprint(\"V \", e)\n\tquit(0)\n",
    encoding="utf-8")
code, out = run([G, "--headless", "--path", "game", "-s", "res://zz_vc.gd"], 120)
print("exit", code)
print("\n".join(l for l in out.splitlines() if l.startswith("V ")))
(W / relic).write_text(orig_relic, encoding="utf-8")

print("== probe (unlisted breakages)")
shutil.copy(Path(__file__).resolve().parent / "rk004_probe.gd", W / "game/zz_vc.gd")
code, out = run([G, "--headless", "--path", "game", "-s", "res://zz_vc.gd"], 120)
print("exit", code)
print("\n".join(l for l in out.splitlines() if l.startswith(("CAUGHT", "MISSED", "PROBE", "SCRIPT ERROR", "ERROR"))))
for f in ("game/zz_vc.gd", "game/zz_vc.gd.uid"):
    (W / f).unlink(missing_ok=True)
code, out = run(["git", "status", "--short"])
print("== git status:", out.strip() or "clean")
