class TestTypeCore(unittest.TestCase):
    def test_type_repr(self):
        class C:
            pass
        self.assertEqual(repr(C), "<class '__main__.C'>")
        self.assertEqual(repr(int), "<class 'int'>")

    def test_type_identity(self):
        self.assertTrue(int is int)
        self.assertTrue(int == int)
        self.assertFalse(int == float)

    def test_isinstance_basics(self):
        self.assertTrue(isinstance(1, int))
        class C:
            pass
        c = C()
        self.assertTrue(isinstance(c, C))
        self.assertFalse(isinstance(c, int))
