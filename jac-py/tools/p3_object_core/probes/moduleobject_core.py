class TestModuleCore(unittest.TestCase):
    def test_builtin_module_name(self):
        import sys
        self.assertEqual(type(sys).__name__, 'module')

    def test_sys_has_version(self):
        import sys
        self.assertTrue(hasattr(sys, 'version'))
