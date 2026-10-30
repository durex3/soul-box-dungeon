"""Required movement mutations, restored byte-for-byte after each run."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    sim = ROOT / 'game/sim/core/sim.gd'
    collector = ROOT / 'game/view/battle/input_collector.gd'
    cases = [
        (sim, 'input.move_direction.limit_length(1.0)', 'input.move_direction',
         'test_diagonal_and_analog_magnitude', False),
        (sim, 'direction * speed * DT', 'direction * speed',
         'test_axis_distance_and_bonus', False),
        (sim, 'ArenaBounds.clamp_position(next, state.player.radius)', 'next',
         'test_walls_corners_and_leave_wall', False),
        (collector, 'frame.move_direction = Input.get_vector',
         'frame.move_direction = Input.get_vector', 'remap 0.6 to 0.5', True),
    ]
    for path, before, after, expected, graphical in cases:
        original = path.read_bytes()
        text = original.decode()
        if graphical:
            before = ', 0.2)'
            after = ', 0.2).normalized()'
        if text.count(before) != 1:
            raise ValueError('Nonunique mutation target')
        try:
            path.write_text(text.replace(before, after))
            command = [os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')]
            command += ([] if graphical else ['--headless']) + ['--path', str(ROOT / 'game'), '-s']
            command += [str(Path(__file__).with_name('rk012_input.gd'))] if graphical else ['res://tests/lib/run_tests.gd']
            result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=45)
            matches = [line for line in result.stdout.splitlines() if 'FAIL' in line and expected in line]
            if result.returncode != 1 or not matches:
                print(result.stdout)
                raise ValueError('Mutation escaped: ' + expected)
            print('RK012 mutation caught: ' + matches[0], flush=True)
        finally:
            path.write_bytes(original)
    print('RK012_FAULTS: passed; exact bytes restored', flush=True)


if __name__ == '__main__':
    main()
