"""`copy.copy` and `copy.deepcopy` lower natively, answering what CPython answers.

`import copy` (and `import from copy { copy, deepcopy }`) is a supported native
stdlib import whose two functions are backend intrinsics: the argument's static
type picks the lowering. Scalars, strings, bytes and tuples of immutables come
back as they are; list, dict and set copies are the containers' own `.copy()`;
an obj/class archetype is copied by a per-class function (allocate, copy the
body, retain every reference field exactly as the class's release function
releases it) chosen at run time by the instance's class name, so a subclass
behind a base-typed variable copies as itself. `deepcopy` threads a memo keyed
by source address through per-type functions, so shared references and cycles
come back shared and cyclic.

The fixtures print what they observe and the native binaries' output is diffed
against the Python backend, which runs the real `copy` module, under both the
managed (cycle-collecting) and the plain-rc memory profiles.
`copy_options_shape.jac` mirrors the compiler's `CompileOptions` and copies it
the way the driver does. `copy_leaks.jac` repeats every shape of copy and then
dumps the live objects of an RC debug build, which must be empty. The last
tests pin the refusals: a node archetype (its graph anchor would be shared or
duplicated), a deep copy through an `any` field, and a subclass defined in a
module the copying unit does not import, which raises `TypeError` at run time
rather than copying the wrong class.
"""

import from tests.support { assert_native_identity, jac_command, python_run }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     PROFILES: list[str] = ["managed", "rc"];

def _build(
    fixture: str, extra: list[str] | None = None
) -> tuple[subprocess.CompletedProcess, str] {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", os.path.join(FIXTURES, fixture), "-o", out_bin)
            + list(extra or []),
        capture_output=True,
        text=True,
        timeout=900
    );
    return (comp, out_bin);
}

def _refusal(fixture: str) -> str {
    (comp, out_bin) = _build(fixture);
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , f"{fixture} lowered instead of being refused: {combined[-600:]}";
    return combined;
}

test "native copy.copy of archetypes, containers and atomics answers like CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "copy_shallow.jac"), profiles=PROFILES
    );
}

test "native copy.deepcopy keeps shared references and cycles like CPython" {
    assert_native_identity(os.path.join(FIXTURES, "copy_deep.jac"), profiles=PROFILES);
}

test "native copy.copy of a CompileOptions-shaped obj answers like CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "copy_options_shape.jac"), profiles=PROFILES
    );
}

test "native copies are all released" {
    (comp, out_bin) = _build("copy_leaks.jac", ["--debug"]);
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    out = proc.stdout;
    assert out.split("\n")[0] == "470" , f"wrong result: {out[:200]}";
    assert "RC LIVE OBJECTS at exit" in out , f"no live-object dump: {out[-400:]}";
    leaks = [
        line
        for line in out.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , f"copies leaked: {leaks}";
}

test "copy of a node archetype is refused naming it" {
    combined = _refusal("copy_refused_node.jac");
    assert "copy.copy of `Station`, a node archetype" in combined , combined[-800:];
}

test "deepcopy through an any field is refused naming the field" {
    combined = _refusal("copy_refused_any.jac");
    assert "copy.deepcopy of `Slot`, whose field `payload`" in combined , combined[-800:];
}

test "a subclass from a module the copying unit does not import raises TypeError" {
    src = os.path.join(FIXTURES, "copy_xmod_main.jac");
    py_lines = python_run(src).strip().split("\n");
    assert py_lines == ["MainDerived(2, x)", "MainDerived(2, x)"] , py_lines;
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.stdout.strip().split("\n")[0] == py_lines[0] , proc.stdout;
    assert proc.returncode != 0 , f"unseen subclass copied silently: {proc.stdout}";
    assert "no copy for the runtime class of a 'LibBase' value"
        in (proc.stdout + proc.stderr) , proc.stderr[-400:];
}
