class TestEnumCore(unittest.TestCase):
    def test_enumerate(self):
        self.assertEqual(list(enumerate(['a', 'b'])), [(0, 'a'), (1, 'b')])

    def test_enumerate_start(self):
        self.assertEqual(list(enumerate('ab', 1)), [(1, 'a'), (2, 'b')])

    def test_reversed(self):
        self.assertEqual(list(reversed([1, 2, 3])), [3, 2, 1])
