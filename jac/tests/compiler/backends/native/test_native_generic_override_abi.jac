"""An override reached through a generic base's vtable slot keeps the slot's ABI.

A generic base declares `emit_add(...) -> (V | None)`, which lowers with `V`
erased to a nullable pointer; a `str` subclass's override lowers
`(str | None)` as an optional struct. A virtual call typed by the base read
the struct's presence tag as the pointer, so `dispatch` returned the address
1. Each vtable slot now has the signature of the class that introduced it,
and an override that lowers differently is entered through an adapter.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "an override called through a generic base's slot returns its value" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "generic_dispatch_return.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[:2] == ["reset", '("task-title " + x)'] , out;
}
