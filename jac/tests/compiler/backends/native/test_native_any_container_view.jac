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
and bool element families, a member narrow, a view taken in a loop, and a
`json.dumps` / `json.loads` round trip, all against the Python backend.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity, native_outputs }

test "typed containers narrowed from any to containers of any match Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "any_typed_container_view.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert lines[3] == "b=1,a=2" , out;
    assert lines[6] == "203" , out;
    assert '{"b": 1, "a": "x", "c": [1, 2]}' in lines , out;
    assert lines[-1] == "True" , out;
}

"""The other direction: an `any` holding a container bound to a typed
container. A container whose header names the target's own layout passes
through, and an empty one is rebuilt with the target's layout. Any other
container, such as the `dict[str, any]` that `json.loads` returns, raises
`TypeError` natively instead of being read with the target's slot layout,
which gave `0` or `None` for keys that are present. Python binds without a
check, so the two backends differ only on the refused lines."""
test "an any bound to a typed container passes a matching layout and refuses another" {
    source = str(
        Path(__file__).resolve().parent
            / "fixtures"
            / "any_bound_to_typed_container.jac"
    );
    outs = native_outputs(source, None, ["managed", "rc"]);
    assert outs["python"].splitlines()[-4:]
        == ["typed 7", "empty 4", "ints 3", "field 1"] , outs["python"];
    for (memory, out) in outs.items() {
        if memory == "python" {
            continue;
        }
        assert out.splitlines()[-4:]
            == ["typed 7", "empty 4", "ints TypeError", "field TypeError"] , (
            memory,
            out
        );
    }
}
