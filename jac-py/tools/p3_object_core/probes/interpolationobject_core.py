class TestInterpolationCore(unittest.TestCase):
    def test_format_basic(self):
        self.assertEqual('{}'.format(1), '1')
        self.assertEqual('{}'.format(1 + 2), '3')

    def test_percent(self):
        self.assertEqual('%d' % 3, '3')
