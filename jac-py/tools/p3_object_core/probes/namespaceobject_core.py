class TestNamespaceCore(unittest.TestCase):
    def test_simple_attrs(self):
        class NS:
            pass
        ns = NS()
        ns.a = 1
        ns.b = 2
        self.assertEqual(ns.a, 1)
        self.assertEqual(ns.b, 2)

    def test_attr_missing(self):
        class NS:
            pass
        ns = NS()
        self.assertFalse(hasattr(ns, 'x'))
