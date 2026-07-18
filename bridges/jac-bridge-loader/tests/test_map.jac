# End-to-end tests for the map return tag (TAG_MAP_BIT | value_tag) through the
# CPython ctypes loader, against the hand-written jac-bridge-map bridge. Proves a
# HashMap<String, V> return marshals as a real Jac dict[str, V] — a one-shot deep
# copy, not an opaque cursor — for V in {int, uint, str, bool}, that unicode keys
# and string values round-trip byte-for-byte, that a full-range u64 value decodes
# unsigned, that an empty map parses to an empty dict, and that a fallible map
# return raises the bridge's error type.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _fixtures { map_so }


glob _SO = map_so(),
     _MOD = load_bridge(_SO),
     _Store = _MOD.Store,
     _StoreError = _MOD.StoreError;


# -- dict[str, int]: signed values incl. a negative -----------------------------
test "counts returns a real dict of signed ints" {
    with _Store(3) as s {
        m = s.counts();
        assert isinstance(m, dict);
        assert m == {"k0": 0, "k1": 2, "k2": 4, "neg": -7};
    }
}

test "the marshaled dict is an independent deep copy" {
    with _Store(2) as s {
        m = s.counts();
        m["k0"] = 999;
        # Mutating the returned dict must not affect a fresh marshal.
        assert s.counts()["k0"] == 0;
    }
}

# -- dict[str, int] with an unsigned high-bit value -----------------------------
test "big decodes u64::MAX as full unsigned range" {
    with _Store(1) as s {
        m = s.big();
        assert m["max"] == 0xFFFFFFFFFFFFFFFF;
        assert m["zero"] == 0;
    }
}

# -- dict[str, str]: length-prefixed values, unicode keys -----------------------
test "labels round-trips unicode keys and string values" {
    with _Store(1) as s {
        m = s.labels();
        assert m == {"greeting": "héllo", "naïve": "café", "empty": ""};
    }
}

# -- dict[str, bool] ------------------------------------------------------------
test "flags returns single-byte bool values" {
    with _Store(1) as s {
        m = s.flags();
        assert m == {"on": True, "off": False};
        assert m["on"] is True;
        assert m["off"] is False;
    }
}

# -- empty map ------------------------------------------------------------------
test "none returns an empty dict" {
    with _Store(5) as s {
        m = s.none();
        assert m == {};
        assert isinstance(m, dict);
    }
}

# -- fallible map return --------------------------------------------------------
test "checked returns a dict when seeded" {
    with _Store(4) as s {
        assert s.checked() == {"n": 4};
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
