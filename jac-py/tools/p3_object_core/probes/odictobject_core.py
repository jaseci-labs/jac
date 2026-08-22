class TestOdictCore(unittest.TestCase):
    def test_dict_order(self):
        d = {}
        d['a'] = 1
        d['b'] = 2
        self.assertEqual(list(d.keys()), ['a', 'b'])

    def test_dict_eq(self):
        self.assertEqual({'a': 1}, {'a': 1})
