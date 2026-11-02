"""An optional object read into a module global keeps its own reference.

A module global of type `T | None` is a tagged `{tag, payload}` pair, and the
global store path only did reference counting for pointer and string globals,
so `kept = holder.grid` at module level stored the payload without a retain
(and an overwrite of the global never released the old one). Clearing or
replacing `holder.grid` then freed the object `kept` still pointed at, and the
next read returned freed memory. The fixture keeps the old object alive
through a module global, a function local, a list element, another object's
field and a global assigned from a function, and also restores and
self-assigns the field; every managed profile has to print what Python does.
"""

import from pathlib { Path }
import from tests.support { assert_native_identity }

test "overwriting an optional field leaves other references to the old object alive" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "optional_field_overwrite.jac"
    );
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    assert "global after clear [5, 6, 7]" in out , out;
    assert "kept [5, 6, 7]" in out , out;
}
