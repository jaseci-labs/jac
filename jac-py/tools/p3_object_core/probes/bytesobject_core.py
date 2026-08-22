class TestBytesCore(unittest.TestCase):
    def test_bytes_hash(self):
        # bytes hashes are seed-randomized; stability must be asserted
        # intra-expression for the Layer-1 replay to be interpreter-independent.
        self.assertEqual(hash(b'abc') == hash(b'abc'), True)
        self.assertEqual(hash(b'a') != hash(b'b'), True)

    def test_bytes_richcompare(self):
        self.assertEqual(b'abc', b'abc')
        self.assertLess(b'a', b'b')
        self.assertNotEqual(b'abc', b'abd')

    def test_bytes_repr(self):
        self.assertEqual(repr(b'abc'), "b'abc'")
        self.assertEqual(repr(b'\t'), "b'\\t'")
        self.assertEqual(repr(b"it's"), 'b"it\'s"')
