class TestMemoryCore(unittest.TestCase):
    def test_bytes_len(self):
        self.assertEqual(len(b'abc'), 3)

    def test_bytes_index(self):
        self.assertEqual(b'ab'[0], 97)
