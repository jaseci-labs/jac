"""Lazy iterator adapters yield boxed list elements typed by their layout.

A list whose elements are boxed (a tuple, an object) uses the erased `ptr`
list spec, so its runtime helpers traffic in `i8*`. The indexed for-loop casts
each element back to its static layout, but the iterator path reported the
list's storage type as the element type. `enumerate`, `zip`, `map` and
`filter` then built their tuples and callback arguments around an `i8*`, and
the loop body indexed the element as a string: `m[0]` of a `tuple[str, int]`
printed garbage and of a `tuple[int, int]` raised "string index out of range".

`iter_adapter_boxed_elems.jac` pins every adapter over tuple and object lists
against the Python backend under every memory profile, and
`iter_adapter_boxed_leaks.jac` repeats the shapes under an RC debug build,
whose live-object dump at exit must hold no leak.
"""

import from tests.support { assert_native_identity, jac_command }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "adapters over tuple and object lists agree with the Python backend" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "iter_adapter_boxed_elems.jac")
    );
    assert "enum 1 w1 10" in out , out[:400];
    assert "enum-int 2 2 14 16" in out , out[:400];
}

test "adapters over tuple lists leave no element alive" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "iter_adapter_boxed_leaks.jac"),
            "-o",
            out_bin,
            "--debug"
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"native build failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    assert "enum 1 w1 10" in proc.stdout , proc.stdout[:400];
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in proc.stdout.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , f"adapter elements leaked: {len(leaks)} e.g. {leaks[:3]}";
}
