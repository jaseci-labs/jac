class TestMethodCore(unittest.TestCase):
    def test_bound_method_call(self):
        class C:
            def f(self):
                return 42

        c = C()
        self.assertEqual(c.f(), 42)
        self.assertTrue(c.f.__self__ is c)

    def test_unbound_class_access(self):
        # Python 3.14 removed __self__ on unbound method descriptors.
        lst = []
        with self.assertRaises(AttributeError):
            list.append.__self__
        # The unbound form must mutate the real native list (not a to_host copy).
        list.append(lst, 1)
        self.assertEqual(lst, [1])

    def test_builtin_method_repr(self):
        # Method/builtin reprs embed addresses, so membership is asserted
        # intra-expression (Layer-1 diffs argument values across interpreters).
        self.assertEqual("built-in method append" in repr([].append), True)
        self.assertEqual("built-in function" in repr(len), True)

    def test_method_identity(self):
        self.assertIs(list.append, list.append)
        # Bound methods don't survive to_host round-tripping, so identity
        # between a bound and an unbound access is asserted intra-expression.
        a = []
        self.assertEqual(a.append == list.append, False)
