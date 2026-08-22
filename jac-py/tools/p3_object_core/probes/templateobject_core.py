class TestTemplateCore(unittest.TestCase):
    def test_str_format(self):
        self.assertEqual('{}-{}'.format(1, 2), '1-2')

    def test_percent(self):
        self.assertEqual('%s-%d' % ('a', 1), 'a-1')
