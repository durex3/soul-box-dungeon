"""Run tool tests, layer checks, import and Godot tests from any directory."""
import argparse
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ERROR_LINE = re.compile(r'^\s*(?:SCRIPT ERROR\b|ERROR:)')
SUMMARY = re.compile(r'TESTS: ([0-9]+) passed, 0 failed')


def judge(step: int, returncode: int, output: str, timed_out: bool) -> list[str]:
    """Return all failure reasons; Godot's exit code alone is insufficient."""
    reasons = []
    if timed_out:
        reasons.append('超时，已结束子进程')
    if returncode != 0:
        reasons.append('退出码 %s' % returncode)
    if step in (3, 4):
        current = '(尚未进入测试方法)'
        for line in output.splitlines():
            if line.startswith('RUN '):
                current = line
            if ERROR_LINE.match(line):
                reasons.append('%s；最近测试：%s' % (line.strip(), current))
    if step == 4:
        lines = [line.strip() for line in output.splitlines() if line.strip()]
        match = SUMMARY.fullmatch(lines[-1]) if lines else None
        if match is None or int(match.group(1)) == 0:
            reasons.append('缺少有效的最后一行 TESTS: N passed, 0 failed（N > 0）')
    return reasons


def run_step(step: int, command: list[str], timeout: float) -> bool:
    """Merge stderr into stdout to preserve RUN/error ordering, including timeouts."""
    print('STEP %d: %s' % (step, ' '.join(command)), flush=True)
    timed_out = False
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout)
        code, output = result.returncode, result.stdout
    except subprocess.TimeoutExpired as exc:
        # subprocess.run kills and waits for the direct Godot child on timeout.
        timed_out = True
        code = -1
        output = exc.stdout or b''
        if isinstance(output, bytes):
            output = output.decode('utf-8', errors='replace')
    except OSError as exc:
        print('STEP %d FAIL: %s；请设置 GODOT_BIN 为 Godot 可执行文件路径' % (step, exc))
        return False
    print(output, end='' if output.endswith('\n') else '\n', flush=True)
    reasons = judge(step, code, output, timed_out)
    if reasons:
        print('STEP %d FAIL: %s' % (step, '\n'.join(reasons)), flush=True)
    return not reasons


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout', type=float, default=300, help='Godot 测试超时秒数（默认 300）')
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('--timeout 必须是有限正数')
    binary = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
    steps = [
        ([sys.executable, '-m', 'unittest', 'discover', '-s', 'tools'], 120),
        ([sys.executable, 'tools/lint_layers.py'], 120),
        ([binary, '--headless', '--path', 'game', '--import'], 120),
        ([binary, '--headless', '--path', 'game', '-s', 'res://tests/lib/run_tests.gd'], args.timeout),
    ]
    for step, (command, timeout) in enumerate(steps, 1):
        if step == 3 and shutil.which(binary) is None:
            print('STEP 3 FAIL: 找不到 Godot；请设置 GODOT_BIN 为 Godot 可执行文件路径')
            return 1
        if not run_step(step, command, timeout):
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
