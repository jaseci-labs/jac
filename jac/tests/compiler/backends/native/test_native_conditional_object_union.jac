"""A conditional expression over objects yields an object on both branches.

In `a.field if isinstance(a, T) else a`, with `a` taken from a list of a
union of archetypes, one branch is a declared class's struct pointer and the
other an untyped object pointer. The two met as a boxed `any`, and the
untyped one was tagged as a string, so every later `isinstance` on the
result was false. The kernel's ownership pass reads a `take` place exactly
that way and rejected `take(obj.field)` as "expected a local or an object
field". When the expression's own type is an object, the branches now meet
as the pointer they both are.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a conditional over a union of objects keeps the object on both branches" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "conditional_object_union.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-1]
        == "['ok:name', 'ok:name', 'ok:name', 'bad', 'bad']" , out;
}
