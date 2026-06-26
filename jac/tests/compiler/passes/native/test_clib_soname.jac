"""Regression test: `jac nacompile` records the real versioned soname in
DT_NEEDED for a bare clib import.

A bare logical clib import (`import from z { ... }`) used to emit the
unversioned `libz.so` into DT_NEEDED. That bare name only exists with the
library's `-dev` package installed; on a stock host only the runtime soname
`libz.so.N` is present, so the produced binary failed to load
(`error while loading shared libraries: libz.so: cannot open shared object`).
nacompile now resolves a bare soname to the library's real soname, exactly as
libc/libm are recorded as `libc.so.6` / `libm.so.6`.

ELF/Linux only (DT_NEEDED + `readelf` are ELF-specific); skipped elsewhere.
"""
import os;
import re;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");


test "nacompile records a versioned soname (not bare lib.so) in DT_NEEDED" {
    import pytest;
    if sys.platform != "linux" {
        pytest.skip("DT_NEEDED soname resolution is ELF/Linux-specific");
    }
    if not __import__("shutil").which("readelf") {
        pytest.skip("readelf not available");
    }
    src = os.path.join(FIXTURES, "clib_soname.na.jac");
    out = os.path.join(tempfile.mkdtemp(prefix="jac_soname_"), "clib_soname");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src, "-o", out],
        capture_output=True,
        text=True,
        timeout=400
    );
    assert comp.returncode == 0 , (
        f"nacompile failed: exit={comp.returncode}\n{comp.stderr[-600:]}"
    );
    assert os.path.exists(out) , "binary not produced";
    dyn = subprocess.run(
        ["readelf", "-d", out], capture_output=True, text=True, timeout=60
    );
    needed = re.findall(r"\(NEEDED\)[^\[]*\[([^\]]+)\]", dyn.stdout);
    libz = [
        n
        for n in needed
        if n.startswith("libz.so")
    ];
    assert libz , f"libz not in DT_NEEDED: {needed}";
    # The recorded soname must be versioned (libz.so.N), not the bare dev name.
    assert all(re.match(r"libz\.so\.\d", n) for n in libz) , (
        f"expected a versioned libz soname, got {libz} (bare lib.so regressed)"
    );
}
