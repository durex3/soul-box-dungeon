"""RK-005 开工前的实测：Godot 算派生结果，和 Python 参考实现比对。
用法：python3 -I tools/acceptance/rk005_godot_ref.py tools/acceptance/rk005_godot_probe.gd"""
import subprocess, sys, tempfile, pathlib, shutil

M = (1 << 64) - 1


def signed(x):
    x &= M
    return x - (1 << 64) if x >> 63 else x


def mix(x):
    x = (x + 0x9E3779B97F4A7C15) & M
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & M
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & M
    return signed(x ^ (x >> 31))


def fnv(name):
    h = 0xCBF29CE484222325
    for b in name.encode("utf-8"):
        h = ((h ^ b) * 0x100000001B3) & M
    return h


ref = {}
for s in [0, 1, 12345, -1, 9223372036854775807]:
    for n in ["spawn", "shop", "loot", "upgrade"]:
        ref[(s, n)] = mix((s & M) ^ fnv(n))

d = pathlib.Path(tempfile.mkdtemp())
(d / "project.godot").write_text('config_version=5\n[application]\nconfig/name="p"\n')
shutil.copy(sys.argv[1], d / "probe.gd")
G = "/Applications/Godot.app/Contents/MacOS/Godot"
out = subprocess.run([G, "--headless", "--path", str(d), "-s", "res://probe.gd"],
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90).stdout
shutil.rmtree(d)
bad = 0
for line in out.splitlines():
    if line.startswith("DS "):
        _, s, n, v = line.split()
        if ref[(int(s), n)] != int(v):
            bad += 1
            print("MISMATCH", s, n, v, ref[(int(s), n)])
    elif line.startswith(("OVF", "RESEED", "SCRIPT ERROR", "ERROR")):
        print(line)
print("compared", sum(l.startswith("DS ") for l in out.splitlines()), "mismatch", bad)
for n in ["spawn", "shop", "loot", "upgrade"]:
    print("GOLD 12345", n, ref[(12345, n)])
