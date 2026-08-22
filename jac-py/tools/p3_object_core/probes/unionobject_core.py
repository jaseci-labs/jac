class TestUnionCore(unittest.TestCase):
    def test_isinstance_int(self):
        self.assertTrue(isinstance(1, int))
        self.assertFalse(isinstance('a', int))

    def test_type_or_repr_fallback(self):
        self.assertEqual(type(1), int)
