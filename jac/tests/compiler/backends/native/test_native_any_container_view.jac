"""A typed container narrowed out of `any` to a container of `any` converts.

An `any` box records a container's heap kind, not its element storage, so a
`dict[str, int]` passed as `any` and narrowed to `dict[str, any]` used to be
read with its `i64` slots taken for boxed values: `json.dumps({"b": 1})`
printed `{"b": null}` natively and a nested `[1, 2]` came out as
`[1e-323, null]`. The unbox now reads the allocation header's type tag and
copies a typed container into the `any` family, boxing each element, and a
bare `isinstance(v, dict)` narrow keeps the value boxed instead of adopting
the default integer-keyed dict layout. The fixture covers a typed list and a
typed dict through `any`, a nested list inside an any-dict, pointer, float
and bool element families, a member narrow, a view taken in a loop, a
`json.dumps` / `json.loads` round trip, typed dicts crossing into `any` and
narrowing back to their own type without a copy, and a `dict[str, any]`
narrowed to `dict[str, str]`, all against the Python backend.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "typed containers narrowed from any to containers of any match Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "any_typed_container_view.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert lines[3] == "b=1,a=2" , out;
    assert lines[6] == "203" , out;
    assert '{"b": 1, "a": "x", "c": [1, 2]}' in lines , out;
    assert lines[-8] == "True" , out;
    # A typed dict through `any`: an any-subscript reads it, and the narrow
    # back to its own type is the same dict, so the write is shared.
    assert lines[-7] == "42" , out;
    assert lines[-6] == "83" , out;
    assert lines[-5] == "hiyo" , out;
    assert lines[-4] == "yo!" , out;
    # A dict[str, any] narrowed to dict[str, str] is copied, values unboxed.
    assert lines[-3] == "hiyo" , out;
    assert lines[-2] == "True" , out;
    # An `object`-narrowed dict rebuilt through `.items()`.
    assert lines[-1] == "2" , out;
}
