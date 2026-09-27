"""An optional value renders as its payload's text, or as `None` when absent.

`print`, f-string interpolation and `str()` all route an optional through one
renderer. A scalar payload (bool, int, float) renders in a branch taken only
when the value is present, so the text built for it is never computed and
stranded when the value is absent -- the old form rendered the payload
unconditionally and selected between it and `"None"`, leaking one string per
absent value. A reference payload renders as itself when it is a string,
through its `__str__` when it is an object, and through the container
renderer when it is a list, dict, set or tuple; previously `print` refused
`str | None` and both `print` and f-strings refused `list[str] | None`. The
rendered text is always an owned string (a string payload is retained, the
headerless profile copies), so every caller releases it after use, and the
optional operand itself is released once rendered. Under `!r` the present
payload renders through its repr and an absent one as `None`; the optional is
not first rendered as text and then quoted.

`optional_text.jac` diffs every shape against the Python backend under each
memory profile; `optional_text_leaks.jac` repeats them and dumps the live
objects of an RC debug build, which must hold no leak.
"""

import from tests.support { assert_native_identity, jac_command }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "optional values render like CPython under every memory profile" {
    assert_native_identity(os.path.join(FIXTURES, "optional_text.jac"));
}

test "rendering optional values leaves no string alive" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "optional_text_leaks.jac"),
            "-o",
            out_bin,
            "--debug"
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in proc.stdout.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , f"optional text leaked: {len(leaks)} e.g. {leaks[:3]}";
}
