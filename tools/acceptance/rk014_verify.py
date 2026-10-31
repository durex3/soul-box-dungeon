"""RK014 numerical acceptance and restored deliberate faults, Python stdlib only."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('/private/tmp/rk014-checks')
PROBE = Path(__file__).resolve().with_name('rk014_probe.gd')
BINARY = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
ERROR = re.compile(r'^\s*(?:SCRIPT ERROR\b|ERROR:)', re.M)
QUERY_ERRORS = ['ERROR: StatBlock.value 未知属性: max_hp_pct',
                'ERROR: StatBlock.value 未知属性: unknown']


def run(label, args, marker=None, expected_failure=None, query=False):
    try:
        result = subprocess.run([BINARY, '--headless', '--path', str(ROOT / 'game')] + args,
                                cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=45)
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b''
        if isinstance(output, bytes):
            output = output.decode(errors='replace')
        (OUT / (label + '.log')).write_text(output)
        raise RuntimeError(label + ' timeout (45s):\n' + output) from exc
    (OUT / (label + '.log')).write_text(result.stdout)
    errors = [line.strip() for line in result.stdout.splitlines() if ERROR.match(line)]
    if (query and errors != QUERY_ERRORS) or (not query and errors):
        raise RuntimeError(result.stdout)
    if expected_failure:
        if (result.returncode != 1 or expected_failure not in result.stdout
                or result.stdout.splitlines().count('RK014_PROBE: failed') != 1
                or 'RK014_PROBE: passed' in result.stdout):
            raise RuntimeError('Fault escaped: ' + label + '\n' + result.stdout)
        print('RK014 caught ' + label + ': ' + expected_failure, flush=True)
    elif result.returncode or (marker and result.stdout.splitlines().count(marker) != 1):
        raise RuntimeError(result.stdout)
    elif marker:
        print(result.stdout, end='', flush=True)


def probe(label='positive', test=None):
    args = ['-s', str(PROBE)]
    if test:
        args += ['--', '--test', 'res://tests/sim/combat/' + test[0] + '.gd', test[1]]
    run(label, args, 'RK014_PROBE: passed')


def fault(label, replacements, test, failure):
    originals = {path: path.read_bytes() for path in replacements}
    try:
        for path, edits in replacements.items():
            text = originals[path].decode()
            for before, after in edits:
                if text.count(before) != 1:
                    raise RuntimeError('Fault anchor not unique: ' + label + ': ' + before)
                text = text.replace(before, after)
            path.write_text(text)
        args = ['-s', str(PROBE), '--', '--test',
                'res://tests/sim/combat/' + test[0] + '.gd', test[1]]
        run(label, args, expected_failure=failure)
    finally:
        for path, original in originals.items():
            path.write_bytes(original)
            if path.read_bytes() != original:
                raise RuntimeError('Restoration failed: ' + str(path))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    run('import', ['--import'])
    probe()
    run('invalid_query', ['-s', str(PROBE), '--', '--query'],
        'RK014_QUERY: passed', query=True)
    block = ROOT / 'game/sim/combat/stat_block.gd'
    sim = ROOT / 'game/sim/core/sim.gd'
    fault('additive_health', {block: [
        ('health_factor *= maxf(0.0, 1.0 + float(mods.get(&"max_hp_pct", 0.0)))',
         'health_factor += float(mods.get(&"max_hp_pct", 0.0))')]},
        ('test_stat_block', 'test_03_glass_from_relic_table_fixed_health_and_removal'),
        'two glass health')
    floor = '_values[stat_id] = maxf(float(Balance.STAT_FLOOR.get(stat_id, 0.0)), _values[stat_id])'
    fault('no_health_floor', {block: [(floor,
        '_values[stat_id] = _values[stat_id] if stat_id == &"max_hp" else maxf(float(Balance.STAT_FLOOR.get(stat_id, 0.0)), _values[stat_id])')]},
        ('test_stat_block', 'test_03_health_floor_and_nonnegative_factors_recover_raw_sources'),
        'ten glass minimum health')
    # Deliberately wrong: add the change in raw totals to the already-clamped cache.
    # This loses the portion hidden by a previous cap/floor and also breaks removal.
    fault('incremental_clamped_cache', {block: [
        ('var _values: Dictionary = {}',
         'var _values: Dictionary = {}\nvar _bad_previous_totals: Dictionary = {}'),
        ('\t_values = Balance.STAT_BASE.duplicate(true)',
         '\tvar previous_effective: Dictionary = Balance.STAT_BASE.duplicate(true) if _values.is_empty() else _values.duplicate(true)\n\t_values = Balance.STAT_BASE.duplicate(true)'),
        ('\t\t' + floor,
         '\t\tvar raw_total: float = _values[stat_id]\n\t\t_values[stat_id] = previous_effective[stat_id] + raw_total - float(_bad_previous_totals.get(stat_id, Balance.STAT_BASE[stat_id]))\n\t\t_bad_previous_totals[stat_id] = raw_total\n\t\t' + floor)]},
        ('test_stat_block', 'test_04_raw_sum_then_clamp_and_source_restoration'),
        'raw sum 0.8+0.8-0.9')
    fault('stale_speed_mirror', {sim: [
        ('(1.0 + state.player.stats.value(&"move_speed"))',
         '(1.0 + state.player.move_speed_bonus)'),
        ('\t\t\t_sync_player_stats()\n\t\t\treturn [SimEvent.new(SimEvent.Kind.STATS_CHANGED',
         '\t\t\tpass # deliberately omit command mirror sync\n\t\t\treturn [SimEvent.new(SimEvent.Kind.STATS_CHANGED')]},
        ('test_stat_sim', 'test_06_movement_initial_command_replace_remove_half_and_diagonal'),
        'command modifier distance')
    probe('restored')
    print('RK014: passed')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as exc:
        print('RK014: failed: ' + str(exc))
        sys.exit(1)
