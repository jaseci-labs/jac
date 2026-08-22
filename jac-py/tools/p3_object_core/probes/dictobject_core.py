class TestDictCore(unittest.TestCase):
    def test_dict_unhashable(self):
        with self.assertRaises(TypeError):
            hash({})

    def test_dict_equal(self):
        self.assertEqual({1: 2}, {1: 2})
        self.assertNotEqual({1: 2}, {2: 1})

    def test_key_collision(self):
        d = {}
        d[1] = 'a'
        d[1.0] = 'b'
        self.assertEqual(len(d), 1)
        self.assertEqual(d[True], 'b')

    def test_dict_repr(self):
        self.assertEqual(repr({}), '{}')
        self.assertEqual(repr({1: 2}), '{1: 2}')
