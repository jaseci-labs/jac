"""A chunk view never grows, shrinks or reorders its parent's buffer.

`xs.chunks(n)` binds each chunk to a list view over the parent's elements,
so writes land in the parent. The Python backend's `JacListView` has no
append/extend/insert/pop/remove/clear/sort/reverse and no item deletion or
slicing; native code used to append through the view and reallocate the
parent's interior pointer. The fixture tries every such operation and
diffs the native output against the Python backend under the rc and nogc
profiles (and managed), including from a parallel `flow for` worker.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "chunk view mutations raise like the Python backend's JacListView" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "chunk_view_mutation.jac"
    );
    out = assert_native_identity(source, profiles=["rc", "nogc", "managed"]);
    assert "append: AttributeError: 'JacListView' object has no attribute 'append'"
        in out , out;
    assert "flow append: 'JacListView' object has no attribute 'append'" in out , out;
    assert "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]" in out , out;
    assert "[100, 101, 102, 103, 104, 105, 106, 107, 108, 109]" in out , out;
}

test "slice assignment into a chunk view raises like the Python backend" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "chunk_view_setslice.jac"
    );
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    assert "setslice: TypeError: '<' not supported between instances of 'slice' and 'int'"
        in out , out;
    assert "[0, 1, 2, 3, 4]" in out , out;
}
