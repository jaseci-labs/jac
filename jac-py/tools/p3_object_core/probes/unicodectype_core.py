class TestUnicodectypeCore(unittest.TestCase):
    def test_str_isalpha(self):
        self.assertTrue('A'.isalpha())
        self.assertFalse('1'.isalpha())

    def test_str_isdigit_isspace(self):
        self.assertTrue('9'.isdigit())
        self.assertTrue(' '.isspace())
