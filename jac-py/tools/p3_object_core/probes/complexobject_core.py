class TestComplexCore(unittest.TestCase):
    def test_complex_eq(self):
        self.assertEqual(1+0j, 1+0j)
        self.assertEqual(1+2j, complex(1, 2))

    def test_complex_real_imag(self):
        c = 3+4j
        self.assertEqual(c.real, 3.0)
        self.assertEqual(c.imag, 4.0)
