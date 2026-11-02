"""A function returning a tuple of C scalars returns it by value.

Every `return (a, b)` used to allocate a reference-counted tuple box that the
caller unpacked and freed at once, so a hot helper such as JacPython's
`dict_lookup(...) -> tuple[i64, ptr[PyObject]]` paid a malloc and a free per
call. A tuple whose elements are all C scalars (raw pointers lower to i64)
holds nothing to reference-count, so its function now returns the LLVM struct
in registers. The rule reads only the declared return type, so the importer of
a function, a method's vtable slot and a `Callable` naming the signature all
agree on it; a consumer that needs a tuple object boxes the value itself.

The fixture runs every consumer shape under each memory profile and must print
what the Python backend prints.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "tuple_return_byvalue.jac"
     );

test "scalar tuples returned by value agree with the Python backend" {
    out = assert_native_identity(FIXTURE, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert "destructured 3 9" in lines , out;
    assert "indexed 1 5 (1, 5)" in lines , out;
    assert "ptr and f64 True 2.5" in lines , out;
    assert "imported 5 2.5" in lines , out;
    assert "override 10 20 (10, 20)" in lines , out;
    assert "callable 405" in lines , out;
    assert "lambda 1810" in lines , out;
    assert "nested 91" in lines , out;
}
