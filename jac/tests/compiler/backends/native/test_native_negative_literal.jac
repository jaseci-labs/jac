"""A negated integer literal is a constant, so it narrows like any literal.

`-1` was lowered as a `neg` instruction on an i64 constant, and a C-layout
record field typed i32 with a `-1` default failed native lowering with
"silent narrowing 'i64 into i32'" (the posix fd pair record). The negation
of a literal now folds to a constant of the literal's type, and the Python
backend's C records take their declared constant defaults too.
"""

import from tests.support { assert_native_identity }

import from pathlib { Path }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "a sized record field defaults to a negative literal" {
    out = assert_native_identity(str(FIXTURES / "clib_negative_field_default.jac"));
    assert out.split("\n")[:3]
        == ["pair -1 -1", "narrow -128 -2 -9223372036854775807", "set 3 -3"] , out;
}
