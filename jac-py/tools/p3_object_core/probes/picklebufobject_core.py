class TestPicklebufCore(unittest.TestCase):
    def test_bytes_roundtrip(self):
        self.assertEqual(bytes(b'abc'), b'abc')

    def test_bytearray_bytes(self):
        self.assertEqual(bytes(bytearray(b'xy')), b'xy')
