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
