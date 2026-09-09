"""Hash-table dict semantics under mutation, across GC modes.

The JIT tests exercise each dict operation in-process (default compile
options), pinpointing the failing operation via per-function sentinels.
The GC-matrix tests AOT-compile the same fixture with `--memory rc`,
`--memory managed`, `--memory nogc`, and headerless `--memory nogc`
(the mode whose dict drop path must walk ctrl-occupied slots instead of
densely freeing uninitialized key slots), then run the binary and expect
a clean exit: the fixture asserts internally and prints OK.
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
     PROG = "dict_hash_ops.jac";

test "dict str-key del and pop" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "del_pop_str_keys", ctypes.c_int64);
    assert f() == 1;
}

test "dict tombstone reuse after delete" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "tombstone_reuse", ctypes.c_int64);
    assert f() == 2;
}

test "dict rehash cycle with deletes mixed in" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "rehash_with_deletes", ctypes.c_int64);
    assert f() == 1;
}

test "dict clear then contains and reinsert" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "clear_then_reuse", ctypes.c_int64);
    assert f() == 1;
}

test "dict iteration order preserved after deletes" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "order_after_deletes", ctypes.c_char_p);
    assert f().decode("utf-8") == "one;three;four;five;";
}

test "dict popitem returns last pair with str keys" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "popitem_last_str", ctypes.c_char_p);
    assert f().decode("utf-8") == "gamma=C";
}

test "dict popitem drains in LIFO order" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "popitem_drain", ctypes.c_int64);
    assert f() == 0;
}

test "dict f64 keys hash and compare" {
    (eng, _) = compile_native(PROG);
    f = get_func(eng, "f64_keys", ctypes.c_int64);
    assert f() == 1;
}

def _run_fixture_with_gc(extra_flags: list[str], tag: str) {
    src = os.path.join(FIXTURES, PROG);
    out_bin = os.path.join(tempfile.mkdtemp(), f"dict_hash_ops_{tag}.bin");
    cmd = [sys.executable, "-m", "jaclang", "build", "--native", src];
    cmd += extra_flags;
    cmd += ["-o", out_bin];
    comp = subprocess.run(cmd, capture_output=True, text=True, timeout=300);
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile ({tag}) failed: {combined[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"dict ops failed under {tag}: {(
        proc.stderr or proc.stdout or '(empty)'
    )[-600:]}";
    assert proc.stdout.strip() == "OK dict_hash_ops" , f"unexpected output under {tag}: {proc.stdout.strip()!r}";
}

test "dict ops pass under --memory rc" {
    _run_fixture_with_gc(["--memory", "rc"], "rc");
}

test "dict ops pass under --memory managed" {
    _run_fixture_with_gc(["--memory", "managed"], "cycles");
}

test "dict ops pass under --memory nogc" {
    _run_fixture_with_gc(["--memory", "nogc"], "none");
}

test "dict ops pass under headerless --memory nogc" {
    # Dedicated ownership-dialect fixture: the scope-exit drop must walk
    # ctrl-occupied slots only (a dense keys[0..len) drop frees garbage from
    # uninitialized slots), and popitem must survive the pop freeing the
    # dict's stored key.
    src = os.path.join(FIXTURES, "nogc", "dict_hash_nogc.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "dict_hash_nogc.bin");
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "build",
            "--native",
            src,
            "--memory",
            "nogc",
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=300
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile (nogc_enforced) failed: {combined[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"dict ops crashed under nogc_enforced: {(
        proc.stderr or proc.stdout or '(empty)'
    )[-600:]}";
    out = proc.stdout.strip().split("\n");
    assert out == ["2", "w", "0", "y", "21", "p2", "q2", "1", "done"] , f"nogc dict output mismatch: {out}";
}
