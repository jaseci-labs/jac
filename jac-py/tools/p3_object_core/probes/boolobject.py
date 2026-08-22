class TestBoolCore(unittest.TestCase):
    def test_bool_int_equality(self):
        self.assertTrue(True == 1)
        self.assertTrue(1 == True)
        self.assertEqual(hash(1), hash(True))
