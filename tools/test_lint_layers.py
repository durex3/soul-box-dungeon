from pathlib import Path
import tempfile
import unittest
from lint_layers import lint


class LayerTests(unittest.TestCase):
    def check(self, source, layer='sim', extras=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / layer / 'sample.gd'
            path.parent.mkdir(parents=True)
            path.write_text(source)
            for name, body in (extras or {}).items():
                other = root / name
                other.parent.mkdir(parents=True, exist_ok=True)
                other.write_text(body)
            return lint(root)

    def test_inheritance_whitelist(self):
        for base in ('Node', 'CharacterBody2D', 'Object', 'Resource', 'Unknown', '"res://view/a.gd"', '"res://sim/../view/a.gd"'):
            with self.subTest(base=base):
                self.assertTrue(self.check('extends ' + base))
        for source in ('extends RefCounted', '# extends Node\n', 'static func f() -> void: pass',
                       'extends "res://sim/core/base.gd"', "extends 'res://data/base.gd'"):
            with self.subTest(source=source):
                self.assertFalse(self.check(source))
        self.assertFalse(self.check('extends Base', extras={'data/base.gd': 'class_name Base\nextends RefCounted'}))
        self.assertTrue(self.check('extends ViewBase', extras={'view/base.gd': 'class_name ViewBase'}))

    def test_forbidden_sim_tokens(self):
        bad = ['Input.is_action_pressed("a")', 'Time.get_ticks_msec()', 'OS.get_name()',
               'FileAccess.open("x", 1)', 'get_tree()', 'signal changed',
               'changed.emit()', 'changed.connect(f)', 'emit_signal("changed")',
               'randf()', 'randi()', 'randf_range(0, 1)', 'randi_range(0, 1)', 'randomize()', 'rng.randomize()']
        for expression in bad:
            with self.subTest(expression=expression):
                self.assertTrue(self.check(expression))
                self.assertFalse(self.check('# ' + expression))
                self.assertFalse(self.check('var text: String = ' + repr(expression)))
        for good in ('rng.randf()', 'rng.randi()', 'rng.randf_range(0,1)', 'rng.randi_range(0,1)',
                     'RandomNumberGenerator.randf()', 'rng. randf()',
                     'my_randf()', 'my_get_tree()', 'InputMap.action_add_event("x", event)',
                     'SomeFileAccess.open()', 'var signal_name: String = "x"'):
            with self.subTest(good=good):
                self.assertFalse(self.check(good))

    def test_layer_paths(self):
        for layer, forbidden in [('sim', ('view', 'app')), ('data', ('sim', 'view', 'app'))]:
            for target in forbidden:
                with self.subTest(layer=layer, target=target):
                    self.assertTrue(self.check('load("res://%s/a.gd")' % target, layer))
                    self.assertFalse(self.check('# res://%s/a.gd' % target, layer))
            self.assertFalse(self.check('load("res://data/a.gd")', layer))
        self.assertFalse(self.check('load("res://sim/a.gd")'))

    def test_hash_in_strings_and_line_numbers(self):
        errors = self.check('var s: String = "#" # ignored\n\nInput.foo()')
        self.assertEqual(len(errors), 1)
        self.assertIn(':3:', errors[0])
        self.assertTrue(self.check('var p: String = "#res://view/a.gd"'))
        self.assertFalse(self.check('var s: String = "escaped \\" # Input.foo()"'))
        self.assertFalse(self.check('var s: String = """\nInput.foo()\n# comment in string\n"""'))

    def test_only_sim_and_data(self):
        self.assertFalse(self.check('extends Node\nInput.foo()', 'view'))
        self.assertFalse(self.check('extends Node\nInput.foo()', 'app'))
        self.assertFalse(self.check('extends Node\nInput.foo()', 'tests'))
        self.assertFalse(self.check('extends RefCounted\n# Input.foo()'))


    def test_rng_creation_path_exception(self):
        source = 'var r: RandomNumberGenerator = RandomNumberGenerator.new()'
        errors = self.check(source)
        self.assertEqual(len(errors), 1)
        self.assertIn(':1: 随机数生成器只能在 RunRng 里创建', errors[0])
        self.assertFalse(self.check('', extras={'sim/core/run_rng.gd': source}))
        self.assertTrue(self.check('class_name RunRng\n' + source))
        self.assertTrue(self.check('', extras={'sim/other/run_rng.gd': source}))
        self.assertTrue(self.check('', extras={'sim/core/run_rng_copy.gd': source}))
        self.assertFalse(self.check('# ' + source))
        self.assertFalse(self.check('var text: String = "RandomNumberGenerator.new()"'))
        self.assertFalse(self.check(source, 'data'))

    def test_rng_whitespace_and_word_boundaries(self):
        self.assertTrue(self.check('RandomNumberGenerator . new ( )'))
        self.assertTrue(self.check('RandomNumberGenerator.\nnew()'))
        self.assertTrue(self.check('rng. randomize ( )'))
        self.assertTrue(self.check('randomize ()'))
        self.assertFalse(self.check('OtherRandomNumberGenerator.new()'))
        self.assertFalse(self.check('rng.my_randomize()'))
        self.assertFalse(self.check('var text: String = "rng.randomize()"'))

    def test_randomize_has_no_path_exception(self):
        for source in ('randomize()', 'rng.randomize()'):
            with self.subTest(source=source):
                self.assertTrue(self.check('', extras={'sim/core/run_rng.gd': source}))
                self.assertFalse(self.check(source, 'data'))
                self.assertFalse(self.check('# ' + source))

    def test_global_random_entries(self):
        for name in ('seed', 'rand_from_seed', 'randfn', 'randf', 'randi', 'randf_range', 'randi_range'):
            with self.subTest(name=name):
                errors = self.check(name + '(42)')
                self.assertEqual(len(errors), 1)
                self.assertIn('禁止使用全局随机函数', errors[0])
                for gap in ('', ' ', '\t', '\n', ' \t\n '):
                    self.assertTrue(self.check(name + gap + '(42)'))
                    self.assertFalse(self.check('rng.' + gap + name + '(42)'))
        for source in ('rng.randfn(0.0, 1.0)', 'rng.seed = 42', 'my_seed()',
                       'my_rand_from_seed()', 'my_randfn()'):
            with self.subTest(source=source):
                self.assertFalse(self.check(source))

    def test_array_random_methods(self):
        for method in ('shuffle', 'pick_random'):
            for before in ('', ' ', '\t', '\n'):
                for after in ('', ' ', '\t', '\n'):
                    with self.subTest(method=method, before=before, after=after):
                        errors = self.check('items' + before + '.' + after + method + ' ()')
                        self.assertEqual(len(errors), 1)
                        self.assertIn('禁止数组随机方法', errors[0])
        for source in ('items.my_shuffle()', 'items.my_pick_random()', 'items.shuffle_extra()',
                       'items.pick_random_extra()', 'shuffle_helper()', 'items.shuffle_count'):
            with self.subTest(source=source):
                self.assertFalse(self.check(source))

    def test_rng_class_alias_assignments(self):
        for prefix in ('var C =', 'var C :=', 'const C =', 'C =',
                       'var C: Variant =', 'const C: Variant =', 'var factory: Variant ='):
            for gap in (' ', '\t', '\n', ' # comment\n\t'):
                with self.subTest(prefix=prefix, gap=gap):
                    source = prefix + gap + 'RandomNumberGenerator'
                    errors = self.check(source)
                    self.assertEqual(len(errors), 1)
                    self.assertIn('禁止生成器类别名赋值', errors[0])
        for source in ('var C = RandomNumberGenerator\nvar rng = C.new()',
                       'const Factory := RandomNumberGenerator\nFactory.new()'):
            with self.subTest(source=source):
                self.assertTrue(any('类别名' in error for error in self.check(source)))
        for source in ('var rng: RandomNumberGenerator', 'var rng: RandomNumberGenerator = null',
                       'var C = OtherRandomNumberGenerator', 'if C == RandomNumberGenerator: pass',
                       'if C != RandomNumberGenerator: pass'):
            with self.subTest(source=source):
                self.assertFalse(self.check(source))

    def test_random_rule_exact_path_exception(self):
        privileged = 'sim/core/run_rng.gd'
        allowed = 'var C = RandomNumberGenerator\nvar r: RandomNumberGenerator = RandomNumberGenerator.new()'
        self.assertFalse(self.check('', extras={privileged: allowed}))
        for path in ('sim/other/run_rng.gd', 'sim/core/run_rng_copy.gd',
                     'sim/core/nested/run_rng.gd'):
            with self.subTest(path=path):
                errors = self.check('', extras={path: allowed})
                self.assertEqual(len(errors), 2)
        self.assertEqual(len(self.check('class_name RunRng\n' + allowed)), 2)
        for source in ('seed(42)', 'rand_from_seed(1)', 'randfn(0.0, 1.0)',
                       'items.shuffle()', 'items.pick_random()', 'randomize()', 'rng.randomize()'):
            with self.subTest(source=source):
                self.assertTrue(self.check('', extras={privileged: source}))

    def test_new_random_rules_ignore_comments_and_strings(self):
        for source in ('seed(42)', 'rand_from_seed(1)', 'randfn(0.0, 1.0)',
                       'items.shuffle()', 'items.pick_random()', 'var C = RandomNumberGenerator'):
            for wrap in ('# %s', 'var text: String = "%s"', "var text: String = '%s'",
                         'var text: String = """\n%s\n"""', "var text: String = '''\n%s\n'''"):
                with self.subTest(source=source, wrap=wrap):
                    self.assertFalse(self.check(wrap % source))
        for source, line in (('\n\nrandfn(0.0, 1.0)', 3),
                             ('\nvar text: String = "# safe"; items.pick_random()', 2),
                             ('\n\nvar C = # comment\n\tRandomNumberGenerator', 3)):
            with self.subTest(source=source):
                errors = self.check(source)
                self.assertEqual(len(errors), 1)
                self.assertIn(':%d:' % line, errors[0])
        self.assertFalse(self.check('var rng: RandomNumberGenerator\nvar text: String = "randfn()"'))

    def test_new_random_rules_only_apply_to_sim(self):
        source = '\n'.join(('seed(42)', 'rand_from_seed(1)', 'randfn(0.0, 1.0)',
                            'items.shuffle()', 'items.pick_random()', 'var C = RandomNumberGenerator'))
        for layer in ('data', 'view', 'app', 'tests'):
            with self.subTest(layer=layer):
                self.assertFalse(self.check(source, layer))
