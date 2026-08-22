class TestRangeCore(unittest.TestCase):
    def test_range_len(self):
        self.assertEqual(len(range(5)), 5)
        self.assertEqual(len(range(1, 10, 2)), 5)

    def test_range_contains(self):
        self.assertTrue(3 in range(5))
        self.assertFalse(5 in range(5))

    def test_range_eq(self):
        # Intra-expression by necessity: the Layer-1 replay diffs each argument
        # VALUE across interpreters, and jacpython's native range reaches the
        # host as a list under to_host, so a cross-interpreter range-object
        # diff can never match even though range equality itself is correctly
        # implemented inside jacpython (incl. stop-only normalization and
        # step-mismatch rejection).
        self.assertEqual(range(3) == range(0, 3), True)
        self.assertEqual(range(3) == range(4), False)
        self.assertEqual(range(0, 6, 2) == range(0, 3, 2), False)
