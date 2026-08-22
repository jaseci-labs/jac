class TestUnicodeCore(unittest.TestCase):
    def test_str_len(self):
        self.assertEqual(len('abc'), 3)
        self.assertEqual(len(''), 0)

    def test_str_concat(self):
        self.assertEqual('a' + 'b', 'ab')
