"""Deliberately break required visual invariants; restore sources in finally."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from rk045_verify import run, check_pixels


def main():
    view = ROOT / 'game/view/battle/enemy_projectile_view.gd'
    lab = ROOT / 'game/app/dev/enemy_projectile_lab.gd'
    cases = [
        (view, 'diameter_px >= 10', 'diameter_px > 10', 'threshold', 'mask/color/transparent d=10'),
        (view, '#FF2E97', '#FF2E96', 'pink', 'mask/color/transparent d=6'),
        (view, 'z_index = BattleDrawOrder.ENEMY_PROJECTILES', 'z_index = BattleDrawOrder.ALLY_FX - 1',
         'draw_order', 'coverage/alpha isolation'),
        (lab, 'ally_fx.modulate.a = ALPHAS[alpha_index]',
         'ally_fx.modulate.a = ALPHAS[alpha_index]\n\tif bullet != null and bullet.active:\n\t\tbullet.modulate.a = ALPHAS[alpha_index]',
         'alpha_leak', 'coverage/alpha isolation'),
    ]
    for path, before, after, name, expected in cases:
        original = path.read_bytes()
        text = original.decode()
        if text.count(before) != 1:
            raise ValueError('Nonunique mutation target: ' + name)
        out = Path('/private/tmp/rk045-checks/faults') / name
        out.mkdir(parents=True, exist_ok=True)
        try:
            path.write_text(text.replace(before, after))
            run(['-s', str(Path(__file__).with_name('rk045_probe.gd')), '--', str(out)],
                'RK045_GRAPHICS: passed', True)
            try:
                check_pixels(out)
            except ValueError as exc:
                if expected not in str(exc):
                    raise
                print('RK045 fault caught: ' + name + ': ' + str(exc), flush=True)
            else:
                raise ValueError('Mutation escaped: ' + name)
        finally:
            path.write_bytes(original)
    print('RK045_FAULTS: passed; exact source bytes restored', flush=True)


if __name__ == '__main__':
    main()
