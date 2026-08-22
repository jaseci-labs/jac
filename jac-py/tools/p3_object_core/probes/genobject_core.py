class TestGenCore(unittest.TestCase):
    def test_gen_yield(self):
        def g():
            yield 1
            yield 2
        self.assertEqual(list(g()), [1, 2])

    def test_gen_gi_running(self):
        def g():
            yield 1
        gen = g()
        self.assertFalse(gen.gi_running)
