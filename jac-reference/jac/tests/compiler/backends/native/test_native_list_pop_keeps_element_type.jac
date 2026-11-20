"""An element popped from a list keeps the type the list declares.

A list of lists (or of objects, strings or dicts) keeps its elements in
pointer slots, erased. Reads by index recover the declared pointee, but
`list.pop()` handed back the bare `i8*`, so a local bound from it without an
annotation took `i8*` as its type, and a subscript on it then called the
list's helpers with the wrong argument type: the function failed to lower
("Type of #1 arg mismatch") and was demoted to Python. The popped element now
has its pointee restored as reads by index do.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "elements popped from lists keep their own types" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "list_pop_keeps_element_type.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    lines = out.splitlines();
    assert lines[-2] == "85142" , out;
    assert lines[-1] == "[2, 2, 9, 3, 1, 1]" , out;
}
