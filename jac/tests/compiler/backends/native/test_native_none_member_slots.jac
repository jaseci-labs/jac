"""A none-typed member of a tuple, list, dict or object is a real slot.

The member holds one null word with element kind NONE, so repr, equality,
indexing, unpacking and boxing into `any` all see `None` the way Python does,
and `tuple[int, None]` keeps a stable two-word layout.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "none-typed members print, compare, index and box as in Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "none_member_slots.jac"
    );
    out = assert_native_identity(source, profiles=["rc", "nogc"]);
    lines = out.splitlines();
    assert lines[0] == "(2, None) 2 None True True" , out;
    assert lines[-1] == "1 None 3" , out;
}
