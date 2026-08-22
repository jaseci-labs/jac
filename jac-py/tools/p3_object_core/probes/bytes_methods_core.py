class TestBytesMethodsCore(unittest.TestCase):
    def test_bytes_upper_lower(self):
        self.assertEqual(b'Ab'.upper(), b'AB')
        self.assertEqual(b'Ab'.lower(), b'ab')

    def test_bytes_isdigit_isspace(self):
        self.assertTrue(b'12'.isdigit())
        self.assertTrue(b' \t'.isspace())
