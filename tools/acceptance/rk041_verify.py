"""RK041 actual Sim/Driver, graphical observation and deliberate faults; stdlib."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('/private/tmp/rk041-checks')
BINARY = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
ERROR = re.compile(r'^\s*(?:SCRIPT ERROR\b|ERROR:)', re.M)
HERE = Path(__file__).resolve().parent


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
        if (result.returncode != 1 or failure not in result.stdout
                or result.stdout.splitlines().count('RK041_LOGIC: failed') != 1
                or 'RK041_LOGIC: passed' in result.stdout):
            raise RuntimeError('Fault escaped: ' + label + '\n' + result.stdout)
        print('RK041 caught ' + label + ': ' + failure, flush=True)
    elif result.returncode or (marker and result.stdout.splitlines().count(marker) != 1):
        raise RuntimeError(result.stdout)
    if marker and not failure:
        print(result.stdout, end='', flush=True)


def logic(label='logic', test=None, failure=None):
    args = ['--headless', '-s', str(HERE / 'rk041_logic.gd')]
    if test:
        args += ['--', 'res://tests/sim/' + test[0] + '.gd', test[1]]
    run(label, args, 'RK041_LOGIC: passed', failure)


def fault(label, path, before, after, test, failure):
    original = path.read_bytes()
    try:
        if original.count(before.encode()) != 1:
            raise RuntimeError('Fault anchor not unique: ' + label)
        path.write_bytes(original.replace(before.encode(), after.encode()))
        logic(label, test, failure)
    finally:
        path.write_bytes(original)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    run('import', ['--headless', '--import'])
    logic()
    sim = ROOT / 'game/sim/core/sim.gd'
    factory = ROOT / 'game/sim/entities/enemy_factory.gd'
    fault('wave', factory, 'Balance.ENEMY_HP_GROWTH * (wave - 1)',
          'Balance.ENEMY_HP_GROWTH * wave',
          ('test_enemy_state', 'test_eight_species_wave_danger_and_table_unchanged'), 'near expected=')
    config = ROOT / 'game/data/enemy_config.gd'
    fault('no_separation', config, 'SEPARATION_ITERATIONS: int = 8',
          'SEPARATION_ITERATIONS: int = 0',
          ('test_enemy_crowd', 'test_standard_200_density_600_steps'), '200 density minimum >=8')
    fault('stale_index', sim, '_enemy_index.move(other.entity_id, other.position)',
          '_enemy_index.has(other.entity_id)',
          ('test_enemy_state', 'test_index_cross_bucket_and_removal_after_motion'), 'cross bucket final index exact')
    fault('coincident', sim, 'return Vector2((mixed & 0xffff) * 2 - 65535, ((mixed >> 16) & 0xffff) * 2 - 65535).normalized()', 'return Vector2.ZERO',
          ('test_enemy_motion', 'test_three_coincident_resolve_non_collinear_deterministically'), 'three coincident resolve')
    logic('restored')
    run('graphical', ['-s', str(HERE / 'rk041_graphical.gd'), '--', str(OUT)],
        'RK041_GRAPHICAL: passed')
    print('RK041: passed')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as exc:
        print('RK041: failed: ' + str(exc))
        sys.exit(1)
