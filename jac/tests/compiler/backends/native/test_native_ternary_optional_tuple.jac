"""A conditional expression whose sides are a tuple literal and `None`, typed
`tuple[...] | None`, lowers natively: the tuple is boxed and `None` becomes the
null of that boxed tuple, instead of the pair being erased to `any`, which
cannot hold a tuple by value (E5092, and the function sent to Python). The
fixture appends such conditionals to a list of optional tuples, stores them by
index and returns one, then reads every slot back; identity with the Python
backend also proves the native path was taken, and the thousand-element loop
shows a reference mishandled on either side."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a tuple-or-None conditional kept in optional-tuple lists agrees with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "ternary_optional_tuple.jac"
    );
    # The headerless (nogc) profile wants ownership written on values entering
    # an owning list, which is not what this tests.
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert lines[0] == "666 998001.0" , out;
    assert lines[1] == "1.0 2.0" , out;
    assert lines[2] == "5 35" , out;
    assert lines[3] == "True" , out;
    assert lines[4] == "4.0 0.5" , out;
}
