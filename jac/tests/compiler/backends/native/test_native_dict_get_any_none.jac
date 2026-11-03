"""`dict.get` on a dict of `any` is `None` when the stored value is `None`.

An `any` box already holds `None`, so `any | None` is the box itself. The get
emitter wrapped every non-pointer value type in an optional, so a key present
with a `None` value came back as a present optional and `value is not None`
held natively while Python said otherwise. The kernel read its request this way
and compiled the text "None" when a request carried no source.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "dict.get on a dict of any matches Python for None, missing and falsy values" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "dict_get_any_none.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert lines[0] == "source=none" , out;
    assert lines[1] == "source=none" , out;
    assert lines[3] == "path=set:p" , out;
    assert lines[8] == "count=falsy" , out;
    assert lines[9] == "missing=none" , out;
}
