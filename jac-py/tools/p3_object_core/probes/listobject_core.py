class TestListCore(unittest.TestCase):
    def test_list_richcompare(self):
        self.assertEqual([1, 2], [1, 2])
        self.assertLess([1], [1, 2])
        self.assertNotEqual([1, 2], [2, 1])

    def test_list_repr(self):
        self.assertEqual(repr([]), '[]')
        self.assertEqual(repr([1, 2]), '[1, 2]')

    def test_list_sort(self):
        xs = [3, 1, 2]
        xs.sort()
        self.assertEqual(xs, [1, 2, 3])

    def test_list_sort_key_reverse_stable(self):
        # reverse flips the comparison but not the tie-break: stable in both
        # directions (CPython guarantees this).
        ps = [(1, 'b'), (0, 'x'), (1, 'a')]
        ps.sort(key=lambda p: p[0], reverse=True)
        self.assertEqual(ps, [(1, 'b'), (1, 'a'), (0, 'x')])
