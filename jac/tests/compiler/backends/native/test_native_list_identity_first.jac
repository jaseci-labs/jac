"""List searches over elements with a user `__eq__` test identity first.

The value-equality scan for structural elements asked `__eq__` of every
element, so `xs.remove(xs[1])` with an `__eq__` that answers False found
nothing and raised "list.remove(x): x not in list" (test_native_borrow_inference
under rc). CPython's list.remove, index, count and `in` go through
PyObject_RichCompareBool, which takes an identical element as equal before
calling `__eq__`.
"""
import os;
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "an identical element matches without asking its __eq__" {
    out = assert_native_identity(
        str(Path(__file__).resolve().parent / "fixtures" / "list_identity_first.jac"),
        profiles=["rc", "managed"]
    );
    assert out.splitlines()[0] == "True 1 1" , out;
}
