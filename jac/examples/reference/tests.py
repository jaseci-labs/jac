import unittest


class TestCases(unittest.TestCase):
    def test_test1(self):
        self.assertAlmostEqual(4.99999, 4.99999)

    def test_test2(self):
        self.assertEqual(5, 5)

    def test_test3(self):
        self.assertIn("e", "qwerty")


if __name__ == "__main__":
    unittest.main()
