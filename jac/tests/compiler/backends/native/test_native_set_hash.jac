"""Hash-table set semantics under mutation, across GC modes (#7871 C).

`set` shares the dict's hash core (FNV-1a str hash, ctrl fingerprints with
tombstone-aware probing, used-counting 75% rehash, insertion-order array), so
this mirrors the dict matrix: the JIT tests exercise each set operation
in-process, pinpointing the failing operation via per-function sentinels; the
GC-matrix tests AOT-compile the same fixture with `--memory rc`, `--memory managed`,
and `--memory nogc`, run the binary, and expect a clean exit (the fixture asserts
internally and prints OK).
"""

import ctypes;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     PROG = "set_hash_ops.jac";

test "set int add remove contains" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "add_remove_contains_int", ctypes.c_int64);
    assert f() == 2;
}

test "set str add remove contains" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "add_remove_contains_str", ctypes.c_int64);
    assert f() == 2;
}

test "set tombstone reuse after remove" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "tombstone_reuse", ctypes.c_int64);
    assert f() == 2;
}

test "set rehash cycle with removes mixed in" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "rehash_with_deletes", ctypes.c_int64);
    assert f() == 1;
}

test "set clear then contains and re-add" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "clear_then_reuse", ctypes.c_int64);
    assert f() == 1;
}

test "set iteration order preserved after removes" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "order_after_deletes", ctypes.c_char_p);
    assert f().decode("utf-8") == "one;three;four;five;";
}

test "set pop drains in LIFO order" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "pop_lifo", ctypes.c_int64);
    assert f() == 0;
}

test "set algebra correctness" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "algebra", ctypes.c_int64);
    assert f() == 1;
}

test "set in-place ops correctness" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "inplace_ops", ctypes.c_int64);
    assert f() == 1;
}

test "set f64 elements hash and compare" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "f64_elems", ctypes.c_int64);
    assert f() == 1;
}

def _run_fixture_with_gc(extra_flags: list[str], tag: str) {
    src = os.path.join(FIXTURES, PROG);
    out_bin = os.path.join(tempfile.mkdtemp(), f"set_hash_ops_{tag}.bin");
    cmd = [sys.executable, "-m", "jaclang", "build", "--native", src];
    cmd += extra_flags;
    cmd += ["-o", out_bin];
    comp = subprocess.run(cmd, capture_output=True, text=True, timeout=300);
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile ({tag}) failed: {combined[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"set ops failed under {tag}: {(
        proc.stderr or proc.stdout or '(empty)'
    )[-600:]}";
    assert proc.stdout.strip() == "OK set_hash_ops" , f"unexpected output under {tag}: {proc.stdout.strip()!r}";
}

test "set ops pass under --memory rc" {
    _run_fixture_with_gc(["--memory", "rc"], "rc");
}

test "set ops pass under --memory managed" {
    _run_fixture_with_gc(["--memory", "managed"], "cycles");
}

test "set ops pass under --memory nogc" {
    _run_fixture_with_gc(["--memory", "nogc"], "none");
}
