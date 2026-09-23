"""Rendering a float natively releases the text buffers it builds.

`__jac_float_repr` prints the shortest round-tripping `%e` form into a scratch
string, reads the exponent back out of it, and for a value in fixed notation
re-renders it with `%f`. The fixed path allocated a second string for that and
abandoned the scratch one under the managed and plain-rc profiles (only the
headerless profile freed it), so every `print` or `str()` of a float such as
`1.5` stranded one string. The fixed rendering now reuses the scratch buffer,
which already has the capacity it needs.

The callers of the repr leaked the same way: an f-string interpolating a float
passed the repr to `snprintf` and never released it, and `str.format` never
released the text it rendered for an int or float argument, nor the
intermediate string of each substitution before the last. Both now release
them once the result is built.

`float_text_values.jac` pins the rendered text against the Python backend
under every memory profile; `float_print_leaks.jac` repeats the shapes and
dumps the live objects of an RC debug build, which must hold no leak.
"""

import from tests.support { assert_native_identity, jac_command }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "floats render like CPython under every memory profile" {
    assert_native_identity(os.path.join(FIXTURES, "float_text_values.jac"));
}

test "printing and formatting floats leaves no string alive" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "float_print_leaks.jac"),
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
    lines = proc.stdout.split("\n");
    assert lines[0] == "1.5" , proc.stdout[:200];
    assert lines[1] == "100.0 -2.5 3.0" , proc.stdout[:200];
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in lines
        if "<- LEAK" in line
    ];
    assert not leaks , f"float text leaked: {len(leaks)} e.g. {leaks[:3]}";
}
