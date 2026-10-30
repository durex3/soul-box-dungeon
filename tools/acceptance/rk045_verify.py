"""Actual rendered masks, draw ordering, alpha isolation, nearest and pool acceptance."""
import argparse
import math
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from pngio import read_rgba

SIZES = (6, 8, 9, 10, 12, 16, 32)
PINK = (255, 46, 151, 255)
WHITE = (255, 255, 255, 255)
DARK = (42, 6, 20, 255)


def require(value, label):
    if not value:
        raise ValueError(label)


def run(arguments, marker='', graphical=False, expected_error=None):
    command = [os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')]
    command += ([] if graphical else ['--headless']) + ['--path', str(ROOT / 'game')] + arguments
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=45)
    print(result.stdout, end='', flush=True)
    errors = re.findall(r'^\s*(?:ERROR:|SCRIPT ERROR\b).*', result.stdout, re.M)
    require(result.returncode == 0, 'Godot nonzero exit')
    require([e.strip() for e in errors] == ([expected_error] if expected_error else []), 'unexpected engine errors')
    if marker:
        require(result.stdout.splitlines().count(marker) == 1, 'missing/duplicate marker ' + marker)


def reference(d, x, y):
    distance = math.hypot(x + 0.5 - d / 2, y + 0.5 - d / 2)
    if distance > d / 2:
        return (0, 0, 0, 0)
    if d >= 10:
        if distance > d / 2 - 1:
            return DARK
        if distance > d / 2 - 2:
            return WHITE
    elif distance > d / 2 - 1:
        return WHITE
    return PINK


def check_pixels(out):
    for d in SIZES:
        w, h, baseline = read_rgba(out / ('d%d_o0_a0_world.png' % d))
        require((w, h) == (160, 80), 'world dimensions')
        origin = (80 - d // 2, 40 - d // 2)
        for y in range(h):
            for x in range(w):
                local = (x - origin[0], y - origin[1])
                expected = reference(d, *local) if 0 <= local[0] < d and 0 <= local[1] < d else (0, 0, 0, 0)
                actual = baseline[y * w + x]
                require(actual == expected, 'mask/color/transparent d=%d at %s got=%s expected=%s' % (d, (x, y), actual, expected))
        colors = {p for p in baseline if p[3]}
        require(colors == ({PINK, WHITE, DARK} if d >= 10 else {PINK, WHITE}), '9/10 outer-ring threshold')
        for order in range(2):
            outside = []
            for alpha in range(4):
                stem = 'd%d_o%d_a%d' % (d, order, alpha)
                W, H, pixels = read_rgba(out / (stem + '_world.png'))
                require((W, H) == (w, h), 'world changed size')
                for index, pixel in enumerate(baseline):
                    if pixel[3]:
                        require(pixels[index] == pixel, 'coverage/alpha isolation ' + stem + ' index=' + str(index))
                outside.append(pixels[0])
                require((pixels[0][3] == 0) if alpha == 0 else (pixels[0][3] > 0), 'coverage outside bullet not rendered ' + stem)
                sw, sh, screen = read_rgba(out / (stem + '_screen.png'))
                require((sw, sh) == (640, 360), 'screen dimensions')
                for y in range(d):
                    for x in range(d):
                        a = (4 + origin[0] + x, 48 + origin[1] + y)
                        b = (156 + (origin[0] + x) * 3, 48 + (origin[1] + y) * 3)
                        color = screen[a[1] * sw + a[0]]
                        if reference(d, x, y)[3]:
                            require(color == reference(d, x, y), 'screen color ' + stem)
                        for dy in range(3):
                            require(screen[(b[1] + dy) * sw + b[0]:(b[1] + dy) * sw + b[0] + 3] == [color] * 3,
                                    'nearest 3x ' + stem)
            require(len(set(outside)) == 4, 'alpha changes not visible outside bullet')
        print('RK045 pixels passed d=%d origin=%s center=(80,40)' % (d, origin), flush=True)
    require(all(p[3] == 0 for p in read_rgba(out / 'returned_world.png')[2]), 'returned view still rendered')
    require(read_rgba(out / 'reborrow_world.png') == read_rgba(out / 'd6_o0_a0_world.png'),
            'reborrow/shrink 32 to 6 left stale pixels')
    print('RK045 full masks, opaque coverage, transparent corners, both orders, nearest and return/reborrow pixels passed', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=Path('/private/tmp/rk045-checks'))
    args = parser.parse_args()
    try:
        run(['--import'])
        out = args.output_dir.resolve()
        out.mkdir(parents=True, exist_ok=True)
        run(['-s', str(Path(__file__).with_name('rk045_probe.gd')), '--', str(out)], 'RK045_GRAPHICS: passed', True)
        check_pixels(out)
        for kind in ('5', '33', 'inactive'):
            error = 'ERROR: EnemyProjectileView.present: ' + ('inactive' if kind == 'inactive' else 'invalid diameter')
            run(['-s', str(Path(__file__).with_name('rk045_negative.gd')), '--', kind], 'RK045_NEGATIVE: passed', expected_error=error)
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print('RK045: failed: ' + str(exc), flush=True)
        return 1
    print('RK045: passed', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
