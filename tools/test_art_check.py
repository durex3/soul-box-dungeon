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


if __name__ == "__main__":
    unittest.main()
