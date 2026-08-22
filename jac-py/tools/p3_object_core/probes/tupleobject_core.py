class TestTupleCore(unittest.TestCase):
    def test_tuple_hash(self):
        self.assertEqual(hash((1, 2)), hash((1, 2)))
        self.assertNotEqual(hash((1,)), hash((1, 2)))

    def test_tuple_richcompare(self):
        self.assertEqual((1, 2), (1, 2))
        self.assertLess((1,), (1, 2))
        self.assertNotEqual((1, 2), (2, 1))

    def test_tuple_repr(self):
        self.assertEqual(repr((1,)), '(1,)')
        self.assertEqual(repr(()), '()')
