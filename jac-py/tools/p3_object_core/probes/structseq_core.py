class TestStructseqCore(unittest.TestCase):
    def test_tuple_fields(self):
        t = (0, 1, 2)
        self.assertEqual(t[0], 0)
        self.assertEqual(len(t), 3)

    def test_tuple_eq(self):
        self.assertEqual((1, 2), (1, 2))
