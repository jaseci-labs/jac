class TestClassCore(unittest.TestCase):
    def test_bound_method_attrs(self):
        class C:
            def m(self):
                return 1
        c = C()
        # Intra-expression identity: assertIs(c.m.__self__, c) compares objects
        # across interpreters under the Layer-1 replay harness, which never matches.
        self.assertEqual(c.m.__self__ is c, True)
        self.assertEqual(c.m.__func__.__name__, 'm')

    def test_bound_method_call(self):
        class C:
            def m(self, x):
                return x + 1
        self.assertEqual(C().m(2), 3)
