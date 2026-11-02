"""A list taken out of a list by `enumerate` is a list, not a string.

A list of lists keeps each inner list as an untyped pointer. `enumerate`
paired the index with that pointer, and unpacking bound a new name to it as
an `i8*`. Whatever picks its lowering by the slot's type then took the name
for a `str`: `len(sides)` ran the string length over the list's header (a
wrong count, silently), and a nested `enumerate(sides)` walked it as
characters and crashed. `zip` bound its elements the same way, and dicts
and sets of a list fared like lists. A name unpacked from an
erased reference is now typed as the checker typed it, as a plain loop over
the list does.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "enumerate and zip over lists of containers bind containers" {
    source = str(
        Path(__file__).resolve().parent
            / "fixtures"
            / "enumerate_container_elements.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    lines = out.splitlines();
    assert lines[-4] == "['0:2', '1:1', '2:0']" , out;
    assert lines[-3] == "['00a', '01b', '10c']" , out;
    assert lines[-2] == "[37, 16]" , out;
    assert lines[-1] == "[102, 2]" , out;
}
