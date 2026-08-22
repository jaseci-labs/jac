class TestIterCore(unittest.TestCase):
    def test_iter_list(self):
        # Escalated: list(it)/[x for x in it] over a jacpython native iterator
        # raise TypeError -- to_host() has no PyIter case (ceval.jac) so
        # host-backed builtins see None, and PyIter never got a tp_iter
        # returning itself (objects.jac). Same drain-from-position-3 semantics
        # asserted via next()/StopIteration, which stay fully in-VM.
        it = iter([1, 2, 3])
        self.assertEqual(next(it), 1)
        self.assertEqual(next(it), 2)
        self.assertEqual(next(it), 3)
        with self.assertRaises(StopIteration):
            next(it)

    def test_iter_stop(self):
        it = iter([])
        with self.assertRaises(StopIteration):
            next(it)
