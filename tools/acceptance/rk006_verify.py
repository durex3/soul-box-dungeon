"""Verify the production fixed-step driver at real 30/60 fps (about 20 seconds)."""
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
ERROR_LINE = re.compile(r'^\s*(?:ERROR:|SCRIPT ERROR\b)', re.MULTILINE)


def run(arguments: list[str]) -> str:
    """Run one bounded Godot child, keeping raw merged output for diagnosis."""
    command = [GODOT, '--headless', '--path', str(ROOT / 'game')] + arguments
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=45, cwd=ROOT)
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b''
        print(output.decode(errors='replace') if isinstance(output, bytes) else output, flush=True)
        raise ValueError('Godot 超时（45 秒），子进程已结束') from exc
    print(result.stdout, end='' if result.stdout.endswith('\n') else '\n', flush=True)
    if result.returncode != 0 or ERROR_LINE.search(result.stdout):
        raise ValueError('Godot 运行失败，退出码 %d；请查看上方原始输出' % result.returncode)
    return result.stdout


def read_result(output: str, cap: int) -> dict:
    """Reject missing, malformed, non-finite or physically invalid measurements."""
    lines = [line.removeprefix('RK006_RESULT ') for line in output.splitlines()
             if line.startswith('RK006_RESULT ')]
    if len(lines) != 1:
        raise ValueError('缺少唯一的 RK006_RESULT 输出')
    result = json.loads(lines[0])
    if not isinstance(result, dict):
        raise ValueError('探针输出不是对象')
    for key in ('cap', 'seconds', 'render_frames', 'steps', 'distance'):
        value = result.get(key)
        if type(value) not in (int, float) or not math.isfinite(value):
            raise ValueError('缺少或非有限数字字段：' + key)
    if result['cap'] != cap or result['seconds'] < 10.0:
        raise ValueError('限帧值或实际运行时长错误')
    if result['render_frames'] <= 0 or result['steps'] <= 0:
        raise ValueError('没有实际处理帧或逻辑步')
    fps = result['render_frames'] / result['seconds']
    if abs(fps / cap - 1.0) > 0.15:
        raise ValueError('实际帧率 %.6f 不在 %d 的 ±15%% 内' % (fps, cap))
    if abs(result['distance'] / 640.0 - 1.0) > 0.01:
        raise ValueError('距离 %.9f 不在 640 的 ±1%% 内' % result['distance'])
    return result


def main() -> int:
    try:
        run(['--import'])
        results = []
        for cap in (30, 60):
            output = run(['-s', str(Path(__file__).with_name('rk006_probe.gd').resolve()), '--', str(cap)])
            results.append(read_result(output, cap))
        difference = abs(results[0]['distance'] - results[1]['distance']) / results[1]['distance']
        print('RK006 distance difference: %.9f' % difference, flush=True)
        if difference > 0.01:
            raise ValueError('两次距离相差超过 1%')
    except (OSError, ValueError, TypeError, OverflowError) as exc:
        print('RK006: failed: %s；可用 GODOT_BIN 指定引擎路径' % exc, flush=True)
        return 1
    print('RK006: passed', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
