"""`bytes(...)` and `bytearray(...)` lower natively over ranges and tuples.

The native constructors took a count, a buffer or a list of ints, so
`bytes(range(256))` was refused (E5092) and its function sent to Python.
They now drain any other iterable through the list path first, as `set`
does; a native build refuses any demoted function, so identity with the
Python backend under every memory profile also proves the native path was
taken.
"""
import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity, jac_command }

test "native bytes and bytearray over ranges and tuples agree with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "bytes_from_iterable.jac"
    );
    out = assert_native_identity(source);
    lines = out.splitlines();
    assert lines[0] == "[256, 255, 3, 250, 254, 4, 9]" , out;
    assert lines[1] == "[3, 255]" , out;
}

test "a bytes or bytearray conversion that raises ValueError releases what it allocated" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "bytes_from_iterable_leaks.jac"
    );
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", source, "-o", out_bin, "--debug"),
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
    assert proc.stdout.split("\n")[0] == "-150" , proc.stdout[-400:];
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in proc.stdout.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , f"conversion temporaries leaked: {len(leaks)} e.g. {leaks[:3]}";
}
