class TestSetCore(unittest.TestCase):
    def test_set_eq(self):
        self.assertEqual({1, 2, 3}, {3, 2, 1})
        self.assertNotEqual({1, 2}, {1, 3})

    def test_frozenset_hash(self):
        self.assertEqual(hash(frozenset({1, 2})), hash(frozenset({2, 1})))
        self.assertEqual(hash(frozenset()), hash(frozenset()))

    def test_set_unhashable(self):
        with self.assertRaises(TypeError):
            hash({1})
