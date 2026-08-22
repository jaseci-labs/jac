class TestIntCore(unittest.TestCase):
    def test_int_hash(self):
        self.assertEqual(hash(1), hash(1.0))
        self.assertEqual(hash(1), hash(True))
        big = 10 ** 100
        self.assertEqual(hash(big), hash(big))

    def test_bigint_add(self):
        a = 10 ** 50
        self.assertEqual(a + a, 2 * a)

    def test_bigint_compare(self):
        self.assertLess(10 ** 50, 10 ** 50 + 1)
