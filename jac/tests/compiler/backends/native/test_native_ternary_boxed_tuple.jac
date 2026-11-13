"""A conditional expression whose sides are both tuples of one type, one a
function's result (a boxed tuple) and one a literal (a tuple value), lowers
natively: the literal is boxed to meet the other side, instead of the pair
being taken for an `any` and the function sent to Python. Identity with the
Python backend also proves the native path was taken; the loop builds a
thousand of them, so a reference mishandled on either side shows."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a tuple literal beside a returned tuple in a conditional agrees with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "ternary_boxed_tuple.jac"
    );
    # The headerless (nogc) profile wants ownership written on the
    # fixture's tuple-returning functions, which is not what this tests.
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert lines[0] == "4.0 1.5" , out;
    assert lines[1] == "15 9" , out;
}
