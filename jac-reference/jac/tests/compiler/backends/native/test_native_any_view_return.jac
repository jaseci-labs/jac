"""A container converted out of `any` and returned outlives the function.

Unboxing an `any` that holds a `list[Box]` into a `list[any]` copies the list
with every element boxed. The copy was parked in a hidden local and released
when the function returned, while the function returned it as its result: the
caller read freed memory, and the next allocation reused it (the returned
list reported the length of an unrelated 200-element list). When the box being
unboxed is owned, the copy now takes over its ownership and the original list
is released; a borrowed box keeps the parked copy.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a list converted out of any and returned is still the caller's" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "any_view_return.jac");
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-1] == "3 200 3" , out;
}
