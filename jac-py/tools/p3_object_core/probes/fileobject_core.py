class TestFileCore(unittest.TestCase):
    def test_str_print_value(self):
        self.assertEqual(str(42), '42')
        self.assertEqual(repr('x'), "'x'")

    def test_format_simple(self):
        self.assertEqual('{}'.format(1), '1')
