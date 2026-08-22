class TestCallCore(unittest.TestCase):
    def test_call_args(self):
        def f(a, b):
            return a + b
        self.assertEqual(f(1, 2), 3)

    def test_call_kwargs(self):
        def f(a, b=0):
            return a + b
        self.assertEqual(f(1, b=4), 5)
