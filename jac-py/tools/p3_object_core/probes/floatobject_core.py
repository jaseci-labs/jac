class TestFloatCore(unittest.TestCase):
    def test_float_eq(self):
        self.assertEqual(1.5, 1.5)
        self.assertNotEqual(1.5, 2.0)

    def test_float_repr(self):
        self.assertEqual(repr(1.0), '1.0')
        self.assertEqual(repr(0.5), '0.5')
