import unittest
from run_tests import judge


class JudgeTests(unittest.TestCase):
    def test_success(self):
        self.assertEqual(judge(4, 0, 'RUN x::test_a\nTESTS: 2 passed, 0 failed\n\n', False), [])
        self.assertEqual(judge(3, 0, 'import complete', False), [])

    def test_returncode(self):
        for step in range(1, 5):
            with self.subTest(step=step):
                self.assertTrue(judge(step, 1, 'TESTS: 1 passed, 0 failed', False))

    def test_timeout(self):
        self.assertTrue(judge(4, 0, 'TESTS: 1 passed, 0 failed', True))

    def test_error_lines(self):
        for step in (3, 4):
            for error in ('SCRIPT ERROR: bad', 'ERROR: bad', '  ERROR: bad', '\tSCRIPT ERROR: bad'):
                with self.subTest(step=step, error=error):
                    self.assertTrue(judge(step, 0, error + '\nTESTS: 1 passed, 0 failed', False))

    def test_middle_error_is_not_error(self):
        self.assertEqual(judge(4, 0, 'NO ERROR: x\nTESTS: 1 passed, 0 failed', False), [])

    def test_error_context(self):
        reasons = judge(4, 0, 'RUN a::test_first\nRUN b::test_second\nSCRIPT ERROR: bad\nTESTS: 2 passed, 0 failed', False)
        self.assertIn('RUN b::test_second', reasons[0])
        self.assertNotIn('test_first', reasons[0])

    def test_invalid_summary(self):
        for output in ('', 'TESTS: 0 passed, 0 failed', 'TESTS: 1 passed, 1 failed',
                       'TESTS: 1 passed, 0 failed\ntrailing output', 'prefix TESTS: 1 passed, 0 failed'):
            with self.subTest(output=output):
                self.assertTrue(judge(4, 0, output, False))

    def test_import_needs_no_summary(self):
        self.assertEqual(judge(3, 0, '', False), [])
