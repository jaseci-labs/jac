class TestBytearrayCore(unittest.TestCase):
    def test_bytearray_len(self):
        self.assertEqual(len(bytearray(b'abc')), 3)

    def test_bytearray_index(self):
        ba = bytearray(b'hi')
        self.assertEqual(ba[0], ord('h'))
        self.assertEqual(ba[-1], ord('i'))
