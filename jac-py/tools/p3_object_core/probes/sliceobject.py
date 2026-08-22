class TestSliceCore(unittest.TestCase):
    def test_slice_indices_positive(self):
        self.assertEqual(list(range(10)[2:8:2]), [2, 4, 6])

    def test_slice_indices_negative_step(self):
        self.assertEqual(list(range(10)[8:2:-2]), [8, 6, 4])

    def test_slice_empty(self):
        self.assertEqual(list(range(5)[10:20]), [])
