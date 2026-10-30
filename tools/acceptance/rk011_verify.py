"""Check ArenaView; --export-image [PATH] exports an actual graphical SubViewport."""
import argparse
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
ERROR_LINE = re.compile(r'^\s*(?:ERROR:|SCRIPT ERROR\b)', re.MULTILINE)


def run(arguments: list[str], headless: bool = True) -> str:
    """Merge streams, enforce 45 seconds, and reject engine errors even on exit 0."""
    command = [GODOT] + (['--headless'] if headless else [])
    command += ['--path', str(ROOT / 'game')] + arguments
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=45)
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b''
        print(output.decode(errors='replace') if isinstance(output, bytes) else output, flush=True)
        raise ValueError('Godot 超时（45 秒），子进程已结束') from exc
    print(result.stdout, end='' if result.stdout.endswith('\n') else '\n', flush=True)
    if result.returncode != 0 or ERROR_LINE.search(result.stdout):
        raise ValueError('Godot 失败，退出码 %d，见上方原始输出' % result.returncode)
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export-image', nargs='?', const='/private/tmp/rk011-arena.png',
                        metavar='PATH', help='使用图形渲染导出 PNG，默认 /private/tmp/rk011-arena.png')
    args = parser.parse_args()
    try:
        run(['--import'])
        command = ['-s', str(Path(__file__).with_name('rk011_probe.gd').resolve())]
        if args.export_image:
            path = Path(args.export_image).expanduser().resolve()
            command += ['--', '--export-image', str(path)]
        output = run(command, headless=not bool(args.export_image))
        if output.splitlines().count('RK011_PROBE: passed') != 1:
            raise ValueError('缺少唯一的探针通过标志')
        if args.export_image:
            if 'RK011_IMAGE ' not in output or 'RK011_SAMPLE ground' not in output:
                raise ValueError('缺少图片或取色输出')
            with path.open('rb') as stream:
                header = stream.read(24)
            if header[:8] != b'\x89PNG\r\n\x1a\n' or len(header) != 24:
                raise ValueError('不是有效的 PNG')
            if struct.unpack('>II', header[16:24]) != (1280, 720):
                raise ValueError('PNG 不是 1280×720')
    except (OSError, ValueError, struct.error) as exc:
        print('RK011: failed: %s；可用 GODOT_BIN 指定引擎路径' % exc, flush=True)
        return 1
    print('RK011: passed', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
