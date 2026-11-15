"""`obj and items` is false when `items` is empty.

An object and a container are different kinds of pointer, and `and`/`or`
over the pair met as one bare pointer, whose truth is only whether it is
null: `if sig and outs(sig)` held for an empty list. The kernel's Python
generator guards a lambda's signature exactly that way and raised an
internal error on every parameterless `lambda { ... }`. A container met
with another kind of pointer now meets as a boxed value, which keeps its
tag, so truthiness reads its length and `isinstance` still sees what it is.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "and/or over an object and a container tests the container's length" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "bool_container_meet.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    lines = out.splitlines();
    assert lines[-2] == "pick 1 0 -1 fallback 7 -2" , out;
    assert lines[-1] == "list F T F dict F T or F T T str F T" , out;
}
