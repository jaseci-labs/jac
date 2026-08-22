class TestTypeVarCore(unittest.TestCase):
    def test_type_name(self):
        self.assertEqual(int.__name__, 'int')
        self.assertEqual(str.__name__, 'str')

    def test_type_identity(self):
        self.assertIs(type(1), int)
