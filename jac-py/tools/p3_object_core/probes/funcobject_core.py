class TestFuncCore(unittest.TestCase):
    def test_func_name(self):
        def foo():
            pass
        self.assertEqual(foo.__name__, 'foo')

    def test_func_defaults(self):
        def f(a=1, b=2):
            return a + b
        self.assertEqual(f.__defaults__, (1, 2))
        self.assertEqual(f(), 3)

    def test_func_call(self):
        def g(x):
            return x * 2
        self.assertEqual(g(4), 8)
