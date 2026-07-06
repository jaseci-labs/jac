# End-to-end tests for async fn bridging (M6.3) through the CPython ctypes
# loader, against the hand-written jac-bridge-async bridge. Every AsyncCalc
# method is `async fn`; the #[bridge] macro emits a sync C shim that drives the
# future to completion on a module-owned Tokio runtime. The loader calls the
# exported C symbol exactly as it does for a sync bridge, so these assertions
# prove the async round-trip (real reactor + status/out-param marshaling) with no
# ABI change: a fallible async ctor, signed/str/Vec async returns, and a fallible
# async method that raises the bridge error type.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _fixtures { async_so }


glob _SO = async_so(),
     _MOD = load_bridge(_SO),
     _AsyncCalc = _MOD.AsyncCalc,
     _AsyncError = _MOD.AsyncError;


# -- async signed return (uses tokio::time::sleep -> proves a real reactor) -----
test "async seed round-trips a signed value" {
    with _AsyncCalc(6, "demo") as c {
        assert c.seed() == 6;
    }
    with _AsyncCalc(-7, "demo") as c {
        assert c.seed() == -7;
    }
}

# -- async String return -------------------------------------------------------
test "async label returns the text" {
    with _AsyncCalc(1, "hello") as c {
        assert c.label() == "hello";
    }
}

# -- fallible async int return -------------------------------------------------
test "async checked_div returns the quotient" {
    with _AsyncCalc(20, "demo") as c {
        assert c.checked_div(4) == 5;
        assert c.checked_div(-5) == -4;
    }
}

test "async checked_div by zero raises the bridge error" {
    with _AsyncCalc(20, "demo") as c {
        raised = False;
        try {
            c.checked_div(0);
        } except _AsyncError as e {
            raised = True;
            assert "divide by zero" in str(e);
        }
        assert raised;
    }
}

# -- async Vec<i64> return (M6 tail container composes with async) --------------
test "async counts returns an ordered list" {
    with _AsyncCalc(6, "demo") as c {
        assert list(c.counts(3)) == [6, 7, 8];
        assert list(c.counts(0)) == [];
    }
}

# -- fallible async ctor -------------------------------------------------------
test "async ctor raises on a zero seed" {
    raised = False;
    try {
        _AsyncCalc(0, "demo");
    } except _AsyncError as e {
        raised = True;
        assert "non-zero" in str(e);
    }
    assert raised;
}
