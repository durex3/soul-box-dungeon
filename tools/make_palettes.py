"""生成项目色板。色板的唯一来源是本文件里的 MASTER 列表。

用法：python3 tools/make_palettes.py
输出到 art/palette/：
  soulbox_master.gpl  全部颜色，用于敌人、Boss、地块、特效
  soulbox_ally.gpl    去掉敌弹专用色，用于角色、魂匣、主武器、拾取物、UI
  soulbox_master.hex / soulbox_ally.hex  每行一个色值，生成图片时传给 PixelLab 的 target_palette
改色板时只改 MASTER，然后重新运行本脚本，不要手改生成的文件。
"""
import os

# (色值, 名称, 分组)。分组只用于阅读，不影响生成结果。
MASTER = [
    # 暗部与中性色（暗部偏蓝紫）
    ("#0B0A12", "投影 / 最深", "中性"),
    ("#0B0E1F", "区域 3 地面", "中性"),
    ("#1A1426", "魂印描边", "中性"),
    ("#1C1B26", "区域 1 地面", "中性"),
    ("#231A17", "区域 2 地面", "中性"),
    ("#1A0A0A", "警示纹深色", "中性"),
    ("#2E2A3A", "赌徒墨黑 / 石头暗", "中性"),
    ("#3D3850", "石头中暗", "中性"),
    ("#575170", "石头中", "中性"),
    ("#7A7393", "石头亮", "中性"),
    ("#A39DB8", "石头高光", "中性"),
    ("#D8D8E0", "普通品质 / 浅灰", "中性"),
    ("#F0F0F0", "我方最亮 / 刃光", "中性"),
    ("#FFFFFF", "魂印白 / 敌弹白边", "中性"),
    # 骨头、皮革、木头
    ("#4A3B33", "褐暗", "暖色"),
    ("#6E5546", "皮革", "暖色"),
    ("#9C7B5E", "木头亮", "暖色"),
    ("#C9B79C", "骨头暗", "暖色"),
    ("#EDE3CC", "骨头亮", "暖色"),
    # 皮肤
    ("#8A5A44", "皮肤暗", "皮肤"),
    ("#C88A65", "皮肤", "皮肤"),
    ("#EBB894", "皮肤亮", "皮肤"),
    # 钢铁
    ("#3B4A5C", "钢暗", "钢铁"),
    ("#5B7FA6", "骑士钢蓝", "钢铁"),
    ("#8FA3B8", "钢中", "钢铁"),
    ("#B8C2CC", "近战钢", "钢铁"),
    # 黄铜
    ("#6B5530", "黄铜暗", "黄铜"),
    ("#A8823A", "商人金褐", "黄铜"),
    ("#C9A25E", "机械黄铜", "黄铜"),
    ("#E8CF8F", "黄铜亮", "黄铜"),
    # 火焰与熔岩
    ("#5C1A0E", "火焰最暗", "火焰"),
    ("#7A2412", "熔岩暗底", "火焰"),
    ("#9E3B2E", "狂战士锈红", "火焰"),
    ("#E0451F", "熔岩亮裂纹", "火焰"),
    ("#FF8A1F", "火焰", "火焰"),
    ("#FF9A2E", "传说品质", "火焰"),
    ("#FFC93C", "魂晶金", "火焰"),
    ("#FFE8A3", "神圣", "火焰"),
    # 敌方保留色（2.2 节）
    ("#FF3B30", "预警红", "保留"),
    ("#FF2E97", "敌弹品红", "保留"),
    ("#2A0614", "大弹外圈", "保留"),
    # 蓝与冰
    ("#1E3A5C", "深蓝", "蓝"),
    ("#2F5FA8", "蓝中", "蓝"),
    ("#4F7BFF", "雷电", "蓝"),
    ("#4A9CFF", "稀有品质", "蓝"),
    ("#8FD3FF", "我方地面效果描边", "蓝"),
    ("#A8EEFF", "冰霜", "蓝"),
    # 绿
    ("#1F3A2A", "绿暗", "绿"),
    ("#3A6B3F", "绿中", "绿"),
    ("#5BC85B", "精良品质", "绿"),
    ("#5FD38D", "亡灵", "绿"),
    ("#7A8C3A", "炼金师橄榄", "绿"),
    ("#1F5C5A", "青暗", "绿"),
    ("#3DF2C5", "能量", "绿"),
    # 紫
    ("#4B3B6B", "召唤师深紫", "紫"),
    ("#7A5BA8", "紫中", "紫"),
    ("#B05CFF", "史诗品质", "紫"),
    ("#B48CFF", "经验", "紫"),
    # 星界
    ("#2A2F5C", "星界蓝中", "星界"),
    ("#4A5590", "星界蓝亮", "星界"),
]

# 只能出现在敌方弹体上的颜色，我方色板不包含（2.2 节）
ENEMY_BULLET_ONLY = {"#FF2E97", "#2A0614"}


def _rgb(hexcode):
    return tuple(int(hexcode[i:i + 2], 16) for i in (1, 3, 5))


def master_colors():
    return [h.upper() for h, _, _ in MASTER]


def ally_colors():
    return [h for h in master_colors() if h not in ENEMY_BULLET_ONLY]


def _write_gpl(path, name, entries):
    lines = ["GIMP Palette", f"Name: {name}", "Columns: 8", "#"]
    for hexcode, label, _ in entries:
        r, g, b = _rgb(hexcode)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{label}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def _write_hex(path, entries):
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(h.upper() for h, _, _ in entries) + "\n")


def main():
    codes = master_colors()
    dupes = {c for c in codes if codes.count(c) > 1}
    if dupes:
        raise SystemExit(f"色板里有重复的颜色：{sorted(dupes)}")
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "art", "palette")
    os.makedirs(out, exist_ok=True)
    ally = [e for e in MASTER if e[0].upper() not in ENEMY_BULLET_ONLY]
    _write_gpl(os.path.join(out, "soulbox_master.gpl"), "soulbox_master", MASTER)
    _write_gpl(os.path.join(out, "soulbox_ally.gpl"), "soulbox_ally", ally)
    _write_hex(os.path.join(out, "soulbox_master.hex"), MASTER)
    _write_hex(os.path.join(out, "soulbox_ally.hex"), ally)
    print(f"主色板 {len(MASTER)} 色，我方色板 {len(ally)} 色，已写入 {out}")


if __name__ == "__main__":
    main()
