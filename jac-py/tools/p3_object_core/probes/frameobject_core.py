class TestFrameCore(unittest.TestCase):
    def test_function_code_name(self):
        def f():
            return 1
        self.assertEqual(f.__code__.co_name, 'f')

    def test_function_code_exists(self):
        def g():
            pass
        self.assertTrue(hasattr(g, '__code__'))
