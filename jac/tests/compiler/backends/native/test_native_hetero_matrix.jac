"""Heterogeneous container matrix: jacval storage, ownership, reclamation.

Mixed-element containers lower to tagged jacval storage (`List.jacval`,
`Dict.<k>.jacval`); elements are self-describing and retain/release/trace/
drop route through the tag inside the container helpers, so no call site
carries hetero-store ownership special cases.

Coverage:
  - JIT read-back correctness for list and dict mixed elements
    (store/load/overwrite/append/pop/clear/iteration/repr).
  - IR-shape gate: the hetero fixtures build jacval containers and contain
    ZERO `ptr.toint` coercions -- the only emitter that ever `ptrtoint`'d an
    RC pointer into an integer container slot. Boxing uses the tagged
    `jv.p2i` path, whose payload the container releases through the tag.
  - Full-reclamation churn under gc rc and cycles via the glibc
    `mallinfo2().uordblks` in-use probe (container death, slot overwrite,
    and clear() all release), and under headerless `--memory nogc
    --memory nogc` via the stamped jacval elem-drop slot.
  - AOT runs of the self-checking fixture across --memory rc / cycles / none.
"""

import ctypes;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support {
    TESTS_DIR,
    native_address,
    native_force_opts,
    native_str_func
}
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     PROG = "hetero_matrix.jac";


def _opts(gc_mode: str | None = None, enforce: bool = False) -> any {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    if gc_mode is None {
        return native_force_opts();
    }
    return CompileOptions(
        force_codespace='native', na_gc_mode=gc_mode, nogc_enforce_all=enforce
    );
}


def _compile(fixture: str, options: any | None = None) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)),
        options=(options if options is not None else native_force_opts())
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine for {fixture}";
    return (eng, ir);
}


def _get(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}


def _get_s(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    # descriptor-ABI variant of _get: a c_char_p spelling means a Jac
    # `str` (the by-value {root, data, len} descriptor at the native ABI);
    # delegates to the shared tests.support harness.
    return native_str_func(eng, name, restype, *argtypes);
}


test "hetero list read-back: str, int, float slots" {
    (eng, _) = _compile(PROG);
    rs = _get_s(eng, "hl_read_str", ctypes.c_char_p, ctypes.c_char_p);
    ri = _get(eng, "hl_read_int", ctypes.c_int64);
    rf = _get(eng, "hl_read_float", ctypes.c_double);
    assert rs(b"in").decode("utf-8") == "in!";
    assert ri() == 42;
    assert rf() == 2.5;
}

test "hetero list slot overwrite and append/pop" {
    (eng, _) = _compile(PROG);
    ow = _get_s(eng, "hl_overwrite", ctypes.c_char_p, ctypes.c_char_p);
    ap = _get(eng, "hl_append_pop", ctypes.c_int64);
    ann = _get_s(eng, "hl_annotated", ctypes.c_char_p, ctypes.c_char_p);
    assert ow(b"ow").decode("utf-8") == "ow-two";
    assert ap() == 6;
    assert ann(b"q").decode("utf-8") == "q?" , repr(ann(b"q"));
}

test "hetero list iteration dispatches isinstance by tag" {
    (eng, _) = _compile(PROG);
    it = _get(eng, "hl_iter_int_total", ctypes.c_int64);
    assert it() == 13;
}

test "hetero list and dict repr render mixed elements" {
    (eng, _) = _compile(PROG);
    lr = _get_s(eng, "hl_repr", ctypes.c_char_p);
    dr = _get_s(eng, "hd_repr", ctypes.c_char_p);
    assert lr().decode("utf-8") == "[1, 'two', 3.5, True]";
    assert dr().decode("utf-8") == "{'a': 1, 'b': 'two'}";
}

test "hetero dict read-back, overwrite, pop, clear" {
    (eng, _) = _compile(PROG);
    rs = _get_s(eng, "hd_read_str", ctypes.c_char_p);
    ri = _get(eng, "hd_read_int", ctypes.c_int64);
    ow = _get_s(eng, "hd_overwrite", ctypes.c_char_p, ctypes.c_char_p);
    pl = _get_s(eng, "hd_pop_len", ctypes.c_int64, ctypes.c_char_p);
    cl = _get_s(eng, "hd_clear_len", ctypes.c_int64, ctypes.c_char_p);
    assert rs().decode("utf-8") == "bee";
    assert ri() == 42;
    assert ow(b"dv").decode("utf-8") == "dv-second";
    assert pl(b"z") == 5;
    assert cl(b"z") == 0;
}

test "IR shape: hetero containers are jacval; no ptrtoint into integer slots" {
    for fixture in [PROG, "hetero_list_str.jac"] {
        (_, ir) = _compile(fixture);
        text = str(ir.gen.llvm_ir);
        assert "List.jacval" in text , f"{fixture}: hetero list did not lower to List.jacval";
        assert "ptr.toint" not in text , (
            f"{fixture}: an RC pointer was ptrtoint'd into an integer "
            f"container slot (the deleted List.i64 boxing path is back)"
        );
    }
    (_, ir2) = _compile(PROG);
    text2 = str(ir2.gen.llvm_ir);
    assert "Dict.ptr.jacval" in text2 , "hetero dict did not lower to Dict.<k>.jacval";
}


"""Return a callable reading glibc `mallinfo2().uordblks`, or None if unavailable."""
def _inuse_probe -> (object | None) {
    if not sys.platform.startswith("linux") {
        return None;
    }
    try {
        libc = ctypes.CDLL("libc.so.6");
        _fields = [
            (n, ctypes.c_size_t)
            for n in (
                "arena",
                "ordblks",
                "smblks",
                "hblks",
                "hblkhd",
                "usmblks",
                "fsmblks",
                "uordblks",
                "fordblks",
                "keepcost"
            )
        ];
        _MI = type("Mallinfo2", (ctypes.Structure, ), {"_fields_": _fields});
        libc.mallinfo2.restype = _MI;
    } except (OSError, AttributeError) {
        return None;
    }
    return lambda { int(libc.mallinfo2().uordblks); };
}


"""Warm `fn`, baseline in-use bytes, run a long churn window, return growth."""
def _churn_growth(fn: any, inuse: any, arg: int = 2000, iters: int = 40) -> int {
    for _ in range(3) {
        fn(arg);
    }
    base = inuse();
    for _ in range(iters) {
        fn(arg);
    }
    return inuse() - base;
}


def _assert_reclaims_all(fixture: str, fnames: list[str], options: object) {
    inuse = _inuse_probe();
    if inuse is None {
        return;
    }
    (eng, _) = _compile(fixture, options);
    for fname in fnames {
        fn = _get(eng, fname, ctypes.c_int64, ctypes.c_int64);
        growth = _churn_growth(fn, inuse);
        assert growth < 256 * 1024 , (
            f"{fixture}:{fname}: in-use heap grew {growth} B across the churn "
            f"window -- hetero container elements are not being reclaimed"
        );
    }
}


test "hetero death/overwrite/clear reclaim all elements under gc rc" {
    _assert_reclaims_all(
        PROG,
        [
            "hl_churn",
            "hd_churn",
            "hl_overwrite_churn",
            "hd_overwrite_churn",
            "hd_clear_churn"
        ],
        _opts("rc")
    );
}

test "hetero death/overwrite/clear reclaim all elements under gc cycles" {
    _assert_reclaims_all(
        PROG,
        [
            "hl_churn",
            "hd_churn",
            "hl_overwrite_churn",
            "hd_overwrite_churn",
            "hd_clear_churn"
        ],
        _opts("cycles")
    );
}

test "hetero death reclaims elements under headerless gc none (stamped drops)" {
    _assert_reclaims_all(
        "nogc/hetero_nogc.jac",
        ["list_churn", "dict_churn"],
        _opts("none", enforce=True)
    );
}


def _run_fixture_with_gc(extra_flags: list[str], tag: str) {
    src = os.path.join(FIXTURES, PROG);
    out_bin = os.path.join(tempfile.mkdtemp(), f"hetero_matrix_{tag}.bin");
    cmd = [sys.executable, "-m", "jaclang", "build", "--native", src];
    cmd += extra_flags;
    cmd += ["-o", out_bin];
    comp = subprocess.run(cmd, capture_output=True, text=True, timeout=300);
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile ({tag}) failed: {combined[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"hetero matrix failed under {tag}: {(
        proc.stderr or proc.stdout or '(empty)'
    )[-600:]}";
    assert proc.stdout.strip() == "OK hetero_matrix" , f"unexpected output under {tag}: {proc.stdout.strip()!r}";
}

test "hetero matrix passes under --memory rc (AOT)" {
    _run_fixture_with_gc(["--memory", "rc"], "rc");
}

test "hetero matrix passes under --memory managed (AOT)" {
    _run_fixture_with_gc(["--memory", "managed"], "cycles");
}

test "hetero matrix passes under --memory nogc (AOT)" {
    _run_fixture_with_gc(["--memory", "nogc"], "none");
}

test "hetero nogc fixture passes under headerless --memory nogc (AOT)" {
    src = os.path.join(FIXTURES, "nogc", "hetero_nogc.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "hetero_nogc.bin");
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
    assert proc.returncode == 0 , f"hetero nogc crashed: {(
        proc.stderr or proc.stdout or '(empty)'
    )[-600:]}";
    out = proc.stdout.strip().split("\n");
    assert out == ["1200", "1200", "done"] , f"hetero nogc output mismatch: {out}";
}

test "mixed dict keys and mixed set elements are stable diagnostics" {
    import tempfile as _tf;
    for (src_text, fn_name, label) in [
        (
            "def bad_keys -> int { d: dict = {1: \"a\", \"b\": 2}; return len(d); }",
            "bad_keys",
            "dict-mixed-keys"
        ),
        (
            "def bad_set -> int { s: set = {1, \"a\"}; return len(s); }",
            "bad_set",
            "set-mixed-elems"
        )
    ] {
        with _tf.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tf {
            tf.write(src_text);
            path = tf.name;
        }
        try {
            prog = JacProgram();
            ir = prog.compile(file_path=path, options=native_force_opts());
            assert not prog.errors_had , (
                f"{label}: the refusal is owned by {fn_name}(), which must "
                f"demote to a seam, got: {[str(e) for e in prog.errors_had]}"
            );
            assert ir.gen.native_layout is not None , (
                f"{label}: whole-module native compile aborted"
            );
            assert fn_name not in ir.gen.native_layout.functions , (
                f"{label}: the refused container must demote its function "
                f"out of the native layout, never lower silently"
            );
        } finally {
            os.unlink(path);
        }
    }
}
