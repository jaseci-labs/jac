class TestCapsuleCore(unittest.TestCase):
    def test_sys_modules(self):
        import sys
        self.assertTrue(hasattr(sys, 'modules'))
        # assertIn isn't a Layer-1 check form; fold membership intra-expression.
        self.assertEqual('sys' in sys.modules, True)

    def test_builtin_type(self):
        self.assertEqual(type(len).__name__, 'builtin_function_or_method')
