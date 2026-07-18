# End-to-end tests for the list return tag (TAG_LIST_BIT | elem_tag) through the
# CPython ctypes loader, against the hand-written jac-bridge-list bridge. Proves a
# Vec<V> return marshals as a real Jac list[V] — a one-shot deep copy, not an
# opaque cursor — for V in {int, uint, str, bool}, that element order is preserved,
# that unicode and empty string elements round-trip byte-for-byte, that a
# full-range u64 element decodes unsigned, that an empty vector parses to an empty
# list, and that a fallible list return raises the bridge's error type.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _fixtures { list_so }


glob _SO = list_so(),
     _MOD = load_bridge(_SO),
     _Store = _MOD.Store,
     _StoreError = _MOD.StoreError;


# -- list[int]: signed values incl. a negative, order preserved -----------------
test "counts returns a real list of signed ints in order" {
    with _Store(3) as s {
        v = s.counts();
        assert isinstance(v, list);
        assert v == [0, 2, 4, -7];
    }
}

test "the marshaled list is an independent deep copy" {
    with _Store(2) as s {
        v = s.counts();
        v[0] = 999;
        # Mutating the returned list must not affect a fresh marshal.
        assert s.counts()[0] == 0;
    }
}

# -- list[int] with an unsigned high-bit element --------------------------------
test "big decodes u64::MAX as full unsigned range" {
    with _Store(1) as s {
        v = s.big();
        assert v == [0xFFFFFFFFFFFFFFFF, 0];
    }
}

# -- list[str]: length-prefixed values, unicode + empty -------------------------
test "labels round-trips unicode and empty string elements in order" {
    with _Store(1) as s {
        v = s.labels();
        assert v == ["héllo", "café", ""];
    }
}

# -- list[bool] -----------------------------------------------------------------
test "flags returns single-byte bool values" {
    with _Store(1) as s {
        v = s.flags();
        assert v == [True, False, True];
        assert v[0] is True;
        assert v[1] is False;
    }
}

# -- empty vector ---------------------------------------------------------------
test "none returns an empty list" {
    with _Store(5) as s {
        v = s.none();
        assert v == [];
        assert isinstance(v, list);
    }
}

# -- fallible list return -------------------------------------------------------
test "checked returns a list when seeded" {
    with _Store(4) as s {
        assert s.checked() == [0, 1, 2, 3];
    }
}

test "checked raises the bridge error when empty" {
    with _Store(0) as s {
        raised = False;
        try {
            s.checked();
        } except _StoreError as e {
            raised = True;
            assert "store is empty" in str(e);
        }
        assert raised;
    }
}
