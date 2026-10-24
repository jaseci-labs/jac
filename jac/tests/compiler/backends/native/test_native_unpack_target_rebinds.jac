"""A `for` whose tuple target rebinds a name the function already holds with
another type (`for (side, sign) in ...` after `for (name, side) in ...`)
gets a slot of its own natively, as a plain loop target does, instead of
the native backend failing with "cannot store i8* to double*" and sending
the function to Python. Identity with the Python backend also proves the
native path was taken."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "names rebound to another type by a loop or an assignment agree with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "unpack_target_rebinds.jac"
    );
    # The headerless (nogc) profile refuses a tuple holding a string in a
    # list literal outright (E1406), so it is left out.
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert lines[0] == "[-2.5, 3.0]" , out;
    assert lines[1] == "25" , out;
    assert lines[2] == "18.5" , out;
    assert lines[3] == "6 6" , out;
    assert lines[4] == "5 -1" , out;
    # A string reassigned on one path keeps its one slot: only a change of
    # kind (int, float, reference) rebinds.
    assert lines[5] == "MAIN INTER" , out;
}
