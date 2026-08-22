class TestObjectCore(unittest.TestCase):
    def test_object_identity(self):
        # Fresh-object identity cannot be diffed across interpreters by the
        # Layer-1 harness (each side constructs its own instances), so the
        # identity checks are asserted intra-expression.
        a = object()
        self.assertEqual(a is a, True)
        self.assertEqual(a is object(), False)

    def test_object_eq(self):
        a = object()
        self.assertTrue(a == a)
        self.assertFalse(a == object())
