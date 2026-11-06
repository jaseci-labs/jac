"""A generator, iterator or range boxed into `any` iterates like Python.

MIR boxes a typed iterator into `any` through an adapter that boxes each
element, and the runtime's `any` iteration takes a boxed iterator as its own
iterator and walks a boxed range. Before that, the boxed iterator reached
the `any` path as an opaque object and iterating it raised
`'iterator' object is not iterable`.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "generators, iterators and ranges passed as any iterate like Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "any_boxed_iterables.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert "sum 30" in out , out;
    assert "strs ['X', 'Y'] []" in out , out;
}
