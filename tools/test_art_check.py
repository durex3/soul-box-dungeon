"""art_check.py 的测试。用法：python3 -m unittest discover -s tools"""
import csv
import os
import shutil
import sys
import tempfile
import unittest
import zlib
import struct

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_check  # noqa: E402
from make_palettes import ally_colors, master_colors  # noqa: E402
from pngio import PngError, read_rgba, write_rgba  # noqa: E402

STEEL = (0x5B, 0x7F, 0xA6, 255)   # 两套色板都有
MAGENTA = (0xFF, 0x2E, 0x97, 255)  # 只在主色板
CLEAR = (0, 0, 0, 0)


def frames(fw, fh, n, color=STEEL, gap_color=CLEAR):
    """生成 n 帧横向排列的精灵图，帧间留 1 像素间隙。"""
    w = n * fw + (n - 1)
    px = []
    for y in range(fh):
        for x in range(w):
            px.append(gap_color if x % (fw + 1) == fw else color)
    return w, fh, px


class ArtCheckTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.log = os.path.join(self.dir, "ai_log.csv")
        self.logged = []
        self.palettes = {"master": set(master_colors()), "ally": set(ally_colors())}

    def tearDown(self):
        shutil.rmtree(self.dir)

    def make(self, name, w, h, px, log=True):
        path = os.path.join(self.dir, name)
        write_rgba(path, w, h, px)
        if log:
            self.logged.append(name)
        return path

    def check(self, path):
        fails, warns = art_check.check_file(path, set(self.logged), self.palettes)
        return sorted({item for item, _ in fails}), warns

    def test_good_run_animation_passes(self):
        path = self.make("chr_knight_run.png", *frames(32, 32, 8))
        self.assertEqual(self.check(path)[0], [])

    def test_wrong_frame_count(self):
        path = self.make("chr_knight_run.png", *frames(32, 32, 6))
        self.assertEqual(self.check(path)[0], [1])

    def test_wrong_size(self):
        path = self.make("enm_skullrat_idle.png", *frames(20, 20, 1))
        self.assertEqual(self.check(path)[0], [1])

    def test_gap_not_transparent(self):
        path = self.make("enm_skullrat_idle.png", *frames(16, 16, 4, gap_color=STEEL))
        self.assertEqual(self.check(path)[0], [1])

    def test_off_palette(self):
        path = self.make("enm_skullrat_idle.png", *frames(16, 16, 1, color=(1, 2, 3, 255)))
        self.assertEqual(self.check(path)[0], [2])

    def test_magenta_allowed_for_enemy(self):
        path = self.make("enm_archer_shot.png", *frames(16, 16, 1, color=MAGENTA))
        self.assertEqual(self.check(path)[0], [])

    def test_magenta_rejected_for_ally(self):
        # 我方色板不含品红，所以同时触发第 2 项和第 3 项
        path = self.make("box_fireball_t1.png", *frames(8, 8, 1, color=MAGENTA))
        self.assertEqual(self.check(path)[0], [2, 3])

    def test_semi_transparent(self):
        path = self.make("enm_skullrat_idle.png", *frames(16, 16, 1, color=(0x5B, 0x7F, 0xA6, 128)))
        self.assertEqual(self.check(path)[0], [4])

    def test_bad_name(self):
        path = self.make("Knight-Run.png", *frames(32, 32, 1))
        self.assertIn(5, self.check(path)[0])

    def test_missing_log(self):
        path = self.make("chr_knight_idle.png", *frames(32, 32, 4), log=False)
        self.assertEqual(self.check(path)[0], [6])

    def test_white_warning_only(self):
        path = self.make("ui_panel_frame.png", *frames(20, 20, 1, color=(255, 255, 255, 255)))
        fails, warns = self.check(path)
        self.assertEqual(fails, [])
        self.assertEqual(len(warns), 1)

    def test_tile_sheet(self):
        path = self.make("tile_crypt_floor.png", 64, 32, [STEEL] * (64 * 32))
        self.assertEqual(self.check(path)[0], [])

    def test_main_exit_code_and_log_file(self):
        good = self.make("chr_knight_idle.png", *frames(32, 32, 4))
        bad = self.make("chr_knight_run.png", *frames(32, 32, 6))
        with open(self.log, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["资源文件名", "原始文件名", "接口名"])
            for n in self.logged:
                writer.writerow([n, "raw.png", "create-character-v3"])
        self.assertEqual(art_check.main([good, "--log", self.log]), 0)
        self.assertEqual(art_check.main([good, bad, "--log", self.log]), 1)


class GreyboxArtCheckTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.temp.name, "sprites")
        self.palettes = {"master": set(master_colors()), "ally": set(ally_colors())}

    def tearDown(self):
        self.temp.cleanup()

    def check(self, folder, action="idle", count=2, color=STEEL, logged=True):
        name = "chr_knight_" + action + ".png"
        path = os.path.join(self.root, folder, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_rgba(path, *frames(32, 32, count, color))
        errors, _ = art_check.check_file(path, {name} if logged else set(), self.palettes,
                                        resource_root=self.root)
        return {item for item, _ in errors}

    def test_greybox_requires_two_frames(self):
        for action in ("idle", "run"):
            self.assertEqual(self.check("greybox/rk073", action), set())
            for count in (1, 3, 4, 8):
                with self.subTest(action=action, count=count):
                    self.assertIn(1, self.check("greybox/rk073", action, count))

    def test_formal_rules_unchanged(self):
        for action, count in (("idle", 4), ("run", 8)):
            self.assertIn(1, self.check("formal", action, 2))
            self.assertEqual(self.check("formal", action, count), set())
        self.assertIn(1, self.check("greybox/rk073", "skill", 2))
        self.assertEqual(self.check("greybox/rk073", "skill", 4), set())

    def test_exact_resolved_directory(self):
        for folder in ("greybox-copy", "not-greybox", "greybox/../formal", "greyboxes/rk073"):
            with self.subTest(folder=folder):
                self.assertIn(1, self.check(folder))
        self.assertEqual(self.check("greybox/unused/../rk073"), set())
        outside = os.path.join(self.temp.name, "outside")
        os.makedirs(outside)
        os.makedirs(os.path.join(self.root, "greybox"), exist_ok=True)
        os.symlink(outside, os.path.join(self.root, "greybox", "escape"))
        self.assertIn(1, self.check("greybox/escape"))

    def test_other_checks_remain_strict(self):
        self.assertIn(4, self.check("greybox", color=(91,127,166,128)))
        self.assertTrue({2,3}.issubset(self.check("greybox", color=MAGENTA)))
        self.assertIn(2, self.check("greybox", color=(1,2,3,255)))
        self.assertIn(6, self.check("greybox", logged=False))


class PngIoTest(unittest.TestCase):
    def test_roundtrip(self):
        d = tempfile.mkdtemp()
        try:
            path = os.path.join(d, "a.png")
            px = [(i, 255 - i, 7, 255 if i % 2 else 0) for i in range(12)]
            write_rgba(path, 4, 3, px)
            self.assertEqual(read_rgba(path), (4, 3, px))
        finally:
            shutil.rmtree(d)

    def test_indexed_png_with_trns(self):
        # 手工构造 2 位索引色 PNG（Aseprite 和很多工具会导出索引色）
        d = tempfile.mkdtemp()
        try:
            def chunk(t, b):
                return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xFFFFFFFF)
            plte = bytes([0, 0, 0, 0x5B, 0x7F, 0xA6, 255, 255, 255])
            row = bytes([0, 0b00011000])  # 过滤类型 0，像素索引 0,1,2,0
            data = (b"\x89PNG\r\n\x1a\n"
                    + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 1, 2, 3, 0, 0, 0))
                    + chunk(b"PLTE", plte) + chunk(b"tRNS", bytes([0]))
                    + chunk(b"IDAT", zlib.compress(row)) + chunk(b"IEND", b""))
            path = os.path.join(d, "i.png")
            with open(path, "wb") as f:
                f.write(data)
            w, h, px = read_rgba(path)
            self.assertEqual(px, [(0, 0, 0, 0), (0x5B, 0x7F, 0xA6, 255), (255, 255, 255, 255), (0, 0, 0, 0)])
        finally:
            shutil.rmtree(d)

    def test_rejects_non_png(self):
        d = tempfile.mkdtemp()
        try:
            path = os.path.join(d, "x.png")
            with open(path, "wb") as f:
                f.write(b"not a png")
            with self.assertRaises(PngError):
                read_rgba(path)
        finally:
            shutil.rmtree(d)


class GreyboxBoxTest(unittest.TestCase):
    def test_box12_exact_greybox_only(self):
        from pathlib import Path
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'sprites'
            palettes={'ally':set(ally_colors()),'master':set(master_colors())}
            for folder, allowed in [('greybox/rk074',True),('formal',False),('greybox-copy',False),
                                    ('greybox/../formal',False),('greybox/nested/../rk074',True)]:
                path=root/folder/'box_fireball_t4.png';path.parent.mkdir(parents=True,exist_ok=True)
                write_rgba(path,12,12,[STEEL]*144)
                errors,_=art_check.check_file(path,{path.name},palettes,resource_root=root)
                self.assertEqual(bool(errors),not allowed,folder)
            for size in (6,8,10):
                self.assertEqual(art_check.check_size('box','box_fireball_t1',size,size,[STEEL]*(size*size))[0],[])
            path=root/'greybox/rk074/box_fireball_t4.png'
            for color, expected in [((91,127,166,128),4),(MAGENTA,3),((1,2,3,255),2)]:
                write_rgba(path,12,12,[color]*144)
                errors,_=art_check.check_file(path,{path.name},palettes,resource_root=root)
                self.assertIn(expected,{item for item,_ in errors})
            write_rgba(path,12,12,[STEEL]*144)
            errors,_=art_check.check_file(path,set(),palettes,resource_root=root)
            self.assertIn(6,{item for item,_ in errors})


if __name__ == "__main__":
    unittest.main()
