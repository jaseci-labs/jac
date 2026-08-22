class TestCellCore(unittest.TestCase):
    def test_nested_function(self):
        def outer(x):
            def inner():
                return x
            return inner
        self.assertEqual(outer(7)(), 7)

    def test_nested_add(self):
        def outer(a):
            def inner(b):
                return a + b
            return inner
        self.assertEqual(outer(2)(3), 5)
