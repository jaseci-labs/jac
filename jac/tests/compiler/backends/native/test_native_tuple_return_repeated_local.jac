"""A local that fills two slots of a returned tuple is not released twice.

`return (ident, ident, name)` moved `ident` into both slots, so the tuple
owned two references while holding one; releasing the tuple freed the
object under the caller, and a later allocation reused its memory (an
assignment target turned into a block statement in the native compiler).
The first slot moves the local and every repeat takes its own reference.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a local repeated in a returned tuple outlives the tuple" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "tuple_return_repeated_local.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-1] == "x0 x99 x199 200" , out;
}
