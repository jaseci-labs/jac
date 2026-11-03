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
import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity, jac_command, native_outputs }

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
which gave `0` or `None` for keys that are present. A container whose
elements have another type, such as a `list[int]` bound to `list[float]`, is
refused too, while the pointer list an edge walk returns binds to a typed node
list. Python binds without a check, so the two backends differ only on the
refused lines."""
test "an any bound to a typed container passes a matching layout and refuses another" {
    source = str(
        Path(__file__).resolve().parent
            / "fixtures"
            / "any_bound_to_typed_container.jac"
    );
    outs = native_outputs(source, None, ["managed", "rc"]);
    assert outs["python"].splitlines()[-6:]
        == ["typed 7", "empty 4", "ints 3", "field 1", "floats 3", "walked 6"] , outs[
        "python"
    ];
    for (memory, out) in outs.items() {
        if memory == "python" {
            continue;
        }
        assert out.splitlines()[-6:]
            == [
                "typed 7",
                "empty 4",
                "ints TypeError",
                "field TypeError",
                "floats TypeError",
                "walked 6"
            ] , (memory, out);
    }
}

def _built(fixture: str, extra: list[str] | None = None) -> str {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            str(Path(__file__).resolve().parent / "fixtures" / fixture),
            "-o",
            out_bin
        )
            + list(extra or []),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , comp.stderr[-800:];
    return out_bin;
}

"""A refused bind releases the container it refused: the parsed dict is not
kept alive by the raise."""
test "a refused bind of an any container releases it" {
    out_bin = _built("any_bind_refused_leaks.jac", ["--debug"]);
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , proc.stderr[-400:];
    out = proc.stdout;
    assert out.split("\n")[0] == "10" , out[:200];
    assert "RC LIVE OBJECTS at exit" in out , out[-400:];
    leaks = [
        line
        for line in out.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , leaks;
}

"""A typed global bound from a borrowed `any` is checked like a local: the
mismatched layout raises at its initializer instead of storing null, and the
program stops there."""
test "a typed global bound from a mismatched any raises TypeError" {
    out_bin = _built("any_bind_refused_global.jac");
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode != 0 , proc.stdout;
    assert "a container held as `any` is not a dict_" in proc.stderr , proc.stderr;
    assert "reached" not in proc.stdout , proc.stdout;
}
