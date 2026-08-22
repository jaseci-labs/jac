class TestWeakrefCore(unittest.TestCase):
    def test_object_alive(self):
        import weakref
        class C:
            pass
        c = C()
        r = weakref.ref(c)
        # Referral keeps the target reachable and identity-faithful.
        self.assertEqual(r() is c, True)

    def test_object_identity(self):
        import weakref
        class C:
            pass
        a = C()
        r1 = weakref.ref(a)
        r2 = weakref.ref(a)
        # Two refs over one object share liveness; intra-expression so the
        # fresh instance never crosses the harness boundary.
        self.assertTrue(r1() is a and r2() is a)

    def test_object_dead_after_del(self):
        import weakref
        class C:
            pass
        o = C()
        r = weakref.ref(o)
        del o
        self.assertEqual(r() is None, True)

    def test_weakref_type_unsupported(self):
        import weakref
        with self.assertRaises(TypeError):
            weakref.ref([1, 2])
