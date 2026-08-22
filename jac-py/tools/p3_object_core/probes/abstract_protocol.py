class TestProtocolCore(unittest.TestCase):
    def test_hash_neg1_sentinel(self):
        self.assertEqual(hash(-1), -2)
        self.assertNotEqual(hash((-1,)), -1)

    def test_hash_str_float_stable(self):
        # str hashes are seed-randomized, so stability must be asserted
        # intra-expression: the Layer-1 replay evaluates each argument on both
        # interpreters and diffs values, which can never match across seeds.
        self.assertEqual(hash('a') == hash('a'), True)
        self.assertEqual(hash(1.5), hash(1.5))
        self.assertEqual(hash(1.0), hash(1))
        self.assertEqual(hash(1.5), 1152921504606846977)

    def test_bool_int_equality(self):
        self.assertTrue(True == 1)
        self.assertTrue(1 == True)
        self.assertEqual(hash(1), hash(True))

    def test_cross_type_ordering(self):
        with self.assertRaises(TypeError):
            1 < 'a'
        with self.assertRaises(TypeError):
            (1, 2) < 'a'
