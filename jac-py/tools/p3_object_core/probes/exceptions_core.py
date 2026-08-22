class TestExcCore(unittest.TestCase):
    def test_isinstance_exc(self):
        e = ValueError('x')
        self.assertTrue(isinstance(e, ValueError))
        self.assertTrue(isinstance(e, Exception))
        self.assertFalse(isinstance(e, TypeError))

    def test_str_exc(self):
        self.assertEqual(str(ValueError('hello')), 'hello')
        self.assertEqual(str(ValueError()), '')

    def test_repr_exc(self):
        self.assertEqual(repr(ValueError('x')), "ValueError('x')")
        self.assertEqual(repr(ValueError()), 'ValueError()')
        self.assertEqual(repr(ValueError("it's")), 'ValueError("it\'s")')
