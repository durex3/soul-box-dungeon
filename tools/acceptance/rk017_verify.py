"""RK017 formal Sim/Driver, graphical input, rates and fault checks (stdlib)."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = Path('/private/tmp/rk017-checks')
BINARY = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
ERROR = re.compile(r'^\s*(?:SCRIPT ERROR\b|ERROR:)', re.M)
sys.path.insert(0, str(ROOT / 'tools'))
from pngio import read_rgba



def run(label, args, marker=None, failure=None):
    try:
        result = subprocess.run([BINARY, '--path', str(ROOT / 'game')] + args,
                                cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=45)
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b''
        if isinstance(output, bytes):
            output = output.decode(errors='replace')
        (OUT / (label + '.log')).write_text(output)
        raise RuntimeError(label + ' timeout (45s):\n' + output) from exc
    (OUT / (label + '.log')).write_text(result.stdout)
    if ERROR.search(result.stdout):
        raise RuntimeError(result.stdout)
    if failure:
        failed_marker = marker.replace(': passed', ': failed')
        if (result.returncode != 1 or failure not in result.stdout
                or result.stdout.splitlines().count(failed_marker) != 1
                or marker in result.stdout):
            raise RuntimeError('Fault escaped: ' + label + '\n' + result.stdout)
        print('RK017 caught ' + label + ': ' + failure, flush=True)
    elif result.returncode or (marker and result.stdout.splitlines().count(marker) != 1):
        raise RuntimeError(result.stdout)
    elif marker:
        print(result.stdout, end='', flush=True)


def logic(label='logic', test=None, failure=None):
    args = ['--headless', '-s', str(HERE / 'rk017_logic.gd')]
    if test:
        args += ['--', 'res://tests/sim/combat/' + test[0] + '.gd', test[1]]
    run(label, args, 'RK017_LOGIC: passed', failure)


def graphical(label='graphical', cache=False, failure=None):
    args = ['-s', str(HERE / 'rk017_graphical.gd'), '--', str(OUT)]
    if cache:
        args += ['--cache']
    run(label, args, 'RK017_GRAPHICAL: passed', failure)
    if not cache and not failure:
        for name in ('hold_640_window640', 'toggle_640_window640',
                     'hold_1280_window1280', 'toggle_1280_window1280',
                     'hold_640_window1280', 'toggle_640_window1280'):
            width, height, pixels = read_rgba(OUT / (name + '.png'))
            counts = Counter(pixels)
            if (counts[(118, 158, 181, 255)] == 0 or
                    counts[(143, 189, 211, 255)] == 0 or
                    counts[(206, 229, 236, 255)] == 0):
                raise RuntimeError('Actual aim line/crosshair/event marker missing: ' + name)
        print('RK017 actual PNG aim/crosshair/event pixels present', flush=True)


def fault(label, path, before, after, test, failure, cache=False):
    original = path.read_bytes()
    try:
        if original.count(before.encode()) != 1:
            raise RuntimeError('Fault anchor not unique: ' + label)
        path.write_bytes(original.replace(before.encode(), after.encode()))
        if cache:
            graphical(label, True, failure)
        else:
            logic(label, test, failure)
    finally:
        path.write_bytes(original)
        if path.read_bytes() != original:
            raise RuntimeError('Restoration failed: ' + str(path))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    run('import', ['--headless', '--import'])
    logic()
    graphical()
    for fps in (30, 60):
        run('rate_' + str(fps), ['--headless', '--max-fps', str(fps), '-s',
                                str(HERE / 'rk017_rate.gd'), '--', str(OUT), str(fps)],
            'RK017_RATE: passed')
    first = json.loads((OUT / 'rate_30.json').read_text())
    second = json.loads((OUT / 'rate_60.json').read_text())
    if (first['steps'] != 600 or second['steps'] != 600 or not first['events']
            or first['events'] != second['events'] or first['player'] != second['player']):
        raise RuntimeError('30/60fps pre-generated logical input replay mismatch')
    print('RK017 rate equality: 600 logical steps; identical event frames and snapshots', flush=True)
    sim = ROOT / 'game/sim/core/sim.gd'
    timer = 'weapon.cooldown_remaining += 1.0 / event.effective_shots_per_sec'
    fault('no_cooldown', sim, timer, 'weapon.cooldown_remaining += 0.0',
          ('test_weapon_fire', 'test_04_ready_single_then_wait'),
          'positive cooldown prevents next-step fire')
    fault('switch_resets_timer', sim, 'weapon.active_slot = next_slot',
          'weapon.active_slot = next_slot\n\t\t\tweapon.cooldown_remaining = 0.0',
          ('test_weapon_fire', 'test_04_shared_cooldown_switch_and_reequip_preserve_time'),
          'switch cannot reset shared positive cooldown')
    fault('discard_remainder', sim, timer,
          'weapon.cooldown_remaining = 1.0 / event.effective_shots_per_sec',
          ('test_weapon_fire', 'test_04_fractional_cadence_frames_and_counts'),
          'fractional cadence retains remainder')
    collector = ROOT / 'game/view/battle/input_collector.gd'
    fault('repeat_press_edge', collector,
          '\t\t_fire_presses = 0\n\t\t_switch_steps = 0',
          '\t\tpass # deliberately retain cached press\n\t\t_switch_steps = 0',
          None, 'edge cache consumed once', cache=True)
    logic('restored_logic')
    graphical('restored_graphical')
    print('RK017: passed')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.TimeoutExpired, OSError, ValueError) as exc:
        print('RK017: failed: ' + str(exc))
        sys.exit(1)
