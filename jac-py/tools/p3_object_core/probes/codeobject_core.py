class TestCodeCore(unittest.TestCase):
    def test_code_flags_generator(self):
        # Fold to bool: raw co_flags ints carry aux bits (OPTIMIZED|NEWLOCALS|
        # NOFREE) that legitimately differ between compilers, so the flag test
        # must be intra-expression, not a cross-interpreter int diff.
        def g():
            yield 1
        self.assertEqual(g.__code__.co_flags & 0x20 != 0, True)

    def test_code_argcount(self):
        def f(a, b, c=1):
            return a
        self.assertEqual(f.__code__.co_argcount, 3)
