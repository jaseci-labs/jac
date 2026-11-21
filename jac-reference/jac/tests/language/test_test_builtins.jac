"""Tests for the ambient test builtins: `testskip`, `testfail`, `testraises`.

These are declared in `jaclang/runtime/builtin.jac` (runtime behaviour) and
`jaclang/compiler/types/jac_builtins.pyi` (checker-visible signatures),
so they are usable inside any `test` block with no import. `skip` itself is a
Jac keyword (the walker skip statement), hence the `testskip` spelling.
"""

test "raises catches the expected exception" {
    with testraises(ValueError) {
        raise ValueError("boom");
    }
}

test "raises exposes the exception through .value" {
    with testraises(ValueError) as ei {
        raise ValueError("boom");
    }
    assert "boom" in str(ei.value);
}

test "raises accepts several exception types" {
    with testraises(KeyError, ValueError) {
        raise KeyError("k");
    }
}

test "raises honors a match pattern" {
    with testraises(RuntimeError, `match="no native parser") {
        raise RuntimeError("there is no native parser here");
    }
}

test "raises rejects a non-matching pattern" {
    caught = "";
    try {
        with testraises(RuntimeError, `match="expected text") {
            raise RuntimeError("entirely different");
        }
    } except AssertionError as e {
        caught = str(e);
    }
    assert "does not match" in caught;
}

test "raises fails when the block raises nothing" {
    caught = "";
    try {
        with testraises(ValueError) {}
    } except AssertionError as e {
        caught = str(e);
    }
    assert "DID NOT RAISE ValueError" in caught;
}

test "raises lets an unrelated exception propagate" {
    propagated = False;
    try {
        with testraises(ValueError) {
            raise KeyError("other");
        }
    } except KeyError {
        propagated = True;
    }
    assert propagated;
}

test "raises rejects non-exception arguments" {
    caught = False;
    bad_raises: any = testraises;
    try {
        bad_raises(int);
    } except TypeError {
        caught = True;
    }
    assert caught;
}

test "raises requires at least one exception type" {
    caught = False;
    try {
        testraises();
    } except TypeError {
        caught = True;
    }
    assert caught;
}

test "fail raises AssertionError carrying the reason" {
    caught = "";
    try {
        testfail("nope");
    } except AssertionError as e {
        caught = str(e);
    }
    assert caught == "nope";
}

test "fail has a default reason" {
    caught = "";
    try {
        testfail();
    } except AssertionError as e {
        caught = str(e);
    }
    assert caught == "explicit failure";
}

test "testskip raises SkipTest so the runner reports a skip" {
    import from unittest { SkipTest }
    caught = "";
    try {
        testskip("environment gate");
    } except SkipTest as e {
        caught = str(e);
    }
    assert caught == "environment gate";
}

test "testskip actually skips the rest of this block" {
    testskip("always skipped");
    assert False;
}
