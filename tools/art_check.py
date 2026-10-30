"""美术资源自动检查，对应 docs/style-bible.md 14.1 节。

用法：
  python3 tools/art_check.py                    检查 game/assets/sprites/ 下所有 PNG
  python3 tools/art_check.py 文件或目录 ...      只检查指定的文件或目录
  python3 tools/art_check.py --log 路径 ...     指定来源记录文件（默认 art/ai_log.csv）

输出里的 [1]-[6] 对应 14.1 节的检查项编号，退回时直接引用。
有任何一项不通过时，退出码为 1。
"""
import argparse
import csv
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_palettes import ally_colors, master_colors  # noqa: E402
from pngio import PngError, read_rgba  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DIR = os.path.join(ROOT, "game", "assets", "sprites")
DEFAULT_LOG = os.path.join(ROOT, "art", "ai_log.csv")

PREFIXES = ("chr", "enm", "bos", "box", "wpn", "rel", "pick", "vfx", "ui", "tile")
ALLY_PREFIXES = {"chr", "box", "wpn", "pick", "ui"}  # 14.1 节第 3 项
NAME_RE = re.compile(r"^(%s)_[a-z0-9]+(_[a-z0-9]+)*\.png$" % "|".join(PREFIXES))
FRAME_GAP = 1  # 13.3 节：精灵图之间留 1 像素间隙

# 4.1 节的单帧尺寸（宽, 高）
FRAME_SIZES = {
    "chr": [(32, 32)],
    "enm": [(s, s) for s in (16, 24, 32, 36, 48)],
    "bos": [(64, 64), (96, 96), (64, 80)],
    "box": [(s, s) for s in (6, 8, 10)],
    "pick": [(s, s) for s in (4, 6, 8, 16)],
    "rel": [(16, 16)],
}
# 9.3 节：角色动作的帧数
CHR_FRAMES = {"idle": {4}, "run": {8}, "skill": {4, 8}, "death": {8}}

LOG_NAME_FIELD = "资源文件名"
WHITE_WARN_RATIO = 0.10  # 14.3 节第 7 项的辅助提示，只提示不判定


def strip_frames(w, h, sizes):
    """在允许的单帧尺寸中找出能拼成该图的一种，返回 (帧宽, 帧数)；找不到返回 None。"""
    for fw, fh in sizes:
        if fh == h and (w + FRAME_GAP) % (fw + FRAME_GAP) == 0:
            return fw, (w + FRAME_GAP) // (fw + FRAME_GAP)
    return None


def is_greybox(path, resource_root=None):
    """Only resolved descendants of the real sprites/greybox directory qualify."""
    base = (Path(resource_root) if resource_root is not None else Path(DEFAULT_DIR)) / "greybox"
    try:
        Path(path).resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def check_size(prefix, stem, w, h, pixels, greybox=False):
    """第 1 项：尺寸和帧数。返回 (错误列表, 帧宽, 帧数)。"""
    action = stem.split("_")[-1] if stem.count("_") >= 2 else None
    if prefix in ("ui", "vfx"):
        return [], w, 1
    if prefix == "wpn":
        if action == "icon":
            ok = (w, h) == (20, 20)
            return ([] if ok else [f"主武器 UI 图标应为 20×20，实际 {w}×{h}"]), w, 1
        ok = w <= 16 and h <= 8
        return ([] if ok else [f"主武器手持图应在 16×8 以内，实际 {w}×{h}"]), w, 1
    if prefix == "tile":
        for step in (16, 16 + FRAME_GAP):
            if (w + (step - 16)) % step == 0 and (h + (step - 16)) % step == 0:
                return [], 16, 1
        return [f"地块图集的宽高应由 16×16 地块组成，实际 {w}×{h}"], 16, 1

    sizes = FRAME_SIZES[prefix]
    found = strip_frames(w, h, sizes)
    if found is None:
        allowed = "、".join(f"{a}×{b}" for a, b in sizes)
        return [f"尺寸 {w}×{h} 不符合 4.1 节（单帧应为 {allowed}，"
                f"多帧横向排列、帧间留 {FRAME_GAP} 像素透明间隙）"], w, 1
    fw, frames = found
    errors = []
    for i in range(1, frames):
        x = i * (fw + FRAME_GAP) - FRAME_GAP
        if any(pixels[y * w + x][3] != 0 for y in range(h)):
            errors.append(f"第 {i} 帧和第 {i + 1} 帧之间的间隙列（x={x}）不是全透明")
    if prefix == "chr":
        if action in CHR_FRAMES:
            allowed_frames = {2} if greybox and action in ("idle", "run") else CHR_FRAMES[action]
            if frames not in allowed_frames:
                want = " 或 ".join(str(n) for n in sorted(allowed_frames))
                errors.append(f"角色动作 {action} 应为 {want} 帧（9.3 节），实际 {frames} 帧")
        elif frames != 1:
            errors.append(f"动作名 {action} 不在 9.3 节的帧数表里（idle、run、skill、death），"
                          f"静态图只能有 1 帧，实际 {frames} 帧")
    return errors, fw, frames


def check_file(path, log_names, palettes, resource_root=None):
    name = os.path.basename(path)
    stem = name[:-4] if name.lower().endswith(".png") else name
    fails, warns = [], []

    if not NAME_RE.match(name):
        fails.append((5, "文件名应为\"前缀_名称_动作.png\"，全小写，前缀为 "
                         + "、".join(p + "_" for p in PREFIXES)))
    if name not in log_names:
        fails.append((6, f"art/ai_log.csv 里没有\"{name}\"的记录"))

    prefix = name.split("_", 1)[0]
    if prefix not in PREFIXES:
        return fails, warns  # 前缀不对时无法判断尺寸和色板，只报命名问题

    try:
        w, h, pixels = read_rgba(path)
    except (PngError, OSError, ValueError) as e:
        fails.append((1, f"无法读取：{e}"))
        return fails, warns

    size_errors, _, _ = check_size(prefix, stem, w, h, pixels, greybox=is_greybox(path, resource_root))
    fails += [(1, e) for e in size_errors]

    is_ally = prefix in ALLY_PREFIXES
    palette = palettes["ally" if is_ally else "master"]
    off_palette, semi, magenta, white, opaque = {}, 0, 0, 0, 0
    for r, g, b, a in pixels:
        if a == 0:
            continue
        if a != 255:
            semi += 1
        opaque += 1
        hexcode = "#%02X%02X%02X" % (r, g, b)
        if hexcode == "#FF2E97":
            magenta += 1
        if hexcode == "#FFFFFF":
            white += 1
        if hexcode not in palette:
            off_palette[hexcode] = off_palette.get(hexcode, 0) + 1

    if off_palette:
        top = sorted(off_palette.items(), key=lambda kv: -kv[1])[:5]
        sample = "、".join(f"{c}（{n} 个像素）" for c, n in top)
        more = f"，共 {len(off_palette)} 种" if len(off_palette) > 5 else ""
        which = "我方色板 soulbox_ally" if is_ally else "主色板 soulbox_master"
        fails.append((2, f"有颜色不在{which}内：{sample}{more}"))
    if is_ally and magenta:
        fails.append((3, f"我方资源出现敌弹品红 #FF2E97，共 {magenta} 个像素"))
    if semi:
        fails.append((4, f"有 {semi} 个半透明像素，只允许完全透明或完全不透明"))
    if is_ally and opaque and white / opaque > WHITE_WARN_RATIO:
        warns.append(f"纯白像素占 {white * 100 // opaque}%，人工检查时确认是否属于\"大面积纯白\"（14.3 节第 7 项）")
    return fails, warns


def load_log_names(path):
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None or LOG_NAME_FIELD not in reader.fieldnames:
            raise SystemExit(f"{path} 缺少\"{LOG_NAME_FIELD}\"列，表头见 docs/style-bible.md 13.4 节第 5 步")
        return {(row.get(LOG_NAME_FIELD) or "").strip() for row in reader}


def collect(targets):
    files = []
    for t in targets:
        if os.path.isdir(t):
            for dirpath, _, names in os.walk(t):
                files += [os.path.join(dirpath, n) for n in names if n.lower().endswith(".png")]
        elif os.path.isfile(t):
            files.append(t)
        else:
            print(f"找不到：{t}", file=sys.stderr)
    return sorted(files)


def main(argv=None):
    parser = argparse.ArgumentParser(description="美术资源自动检查（style-bible 14.1 节）")
    parser.add_argument("paths", nargs="*", default=[DEFAULT_DIR])
    parser.add_argument("--log", default=DEFAULT_LOG)
    args = parser.parse_args(argv)

    files = collect(args.paths)
    if not files:
        print("没有找到 PNG 文件")
        return 0
    log_names = load_log_names(args.log)
    palettes = {"master": set(master_colors()), "ally": set(ally_colors())}

    failed = 0
    for path in files:
        fails, warns = check_file(path, log_names, palettes)
        rel = os.path.relpath(path)
        print(f"{'不通过' if fails else '通过'}  {rel}")
        for item, msg in sorted(fails):
            print(f"    [{item}] {msg}")
        for msg in warns:
            print(f"    [提示] {msg}")
        failed += bool(fails)
    print(f"\n共 {len(files)} 个文件，通过 {len(files) - failed} 个，不通过 {failed} 个")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
