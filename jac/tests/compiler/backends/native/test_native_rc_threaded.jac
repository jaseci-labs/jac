"""Refcount updates are plain until the program starts a thread, atomic after.

A `lock`-prefixed RMW on every retain/release dominated RC-heavy code, but
`flow`, parallel `flow for` and C-imported `pthread_create` can put several
threads on one object. Retain, release and the alloc-id counter therefore test
the process-wide `__jac_rc_threaded` byte: 0 takes a plain load/add/store, 1
takes the atomic RMW. Every thread spawn stores 1 before `pthread_create`, and
nothing stores 0. These pin that shape and run the threaded fixture: with the
flag store removed, 9 of 10 runs freed the shared string early and printed a
string that reused its block.

Native code a host loads is entered from threads the native code did not
start (a Python process calls in from any thread), so the host side marks it
threaded when it loads it: a shared library's `__jac_shared_init` and a JIT
engine set the flag before any of the code runs. Only a standalone executable,
whose threads all come from its own spawn sites, starts on the plain path.

A plain store, unlike an atomic RMW, is deleted by LLVM when it writes through
a `readonly` argument. Retaining a borrowed object writes its count header, so
borrowed parameters carry `readonly` only in builds without refcounts; with it,
a view that stored a borrowed list lost its retain and freed the list early.
"""

import ctypes;
import os;
import re;
import subprocess;
import tempfile;
import from concurrent.futures { ThreadPoolExecutor }
import from jaclang.compiler.backends.native.link_glue {
    GlueSpec,
    RC_THREADED_SYMBOL,
    entry_preamble_ir
}
import from tests.support {
    compile_native,
    compile_native_ir,
    get_func,
    jac_command,
    TESTS_DIR
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "rc_threaded.jac"
     ),
     EXPECTED = "7780\n26400000\nshared-4950\nend\n",
     MARK_RE = re.compile(r'store atomic i8 1, \S+ @"?__jac_rc_threaded"?'),
     SPAWN_RE = re.compile(r'call i32 @"?pthread_create"?\(');

def _compile_ir(gc_mode: str, path: str = FIXTURE) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=path, options=CompileOptions(aot_mode=True, na_gc_mode=gc_mode)
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(ir.gen.llvm_ir);
}

def _mark_precedes_spawn(text: str) -> bool {
    mark = MARK_RE.search(text);
    if mark is None {
        return False;
    }
    call = SPAWN_RE.search(text);
    if call is None {
        return False;
    }
    return mark.start() < call.start();
}

test "retain, release and alloc ids branch on the threaded flag" {
    text = _compile_ir("rc");
    assert re.search(r'@"?__jac_rc_threaded"? = weak global i8 0', text) , "no shared threaded flag";
    for tag in ("rc.r", "rc.rel", "aid") {
        assert f"{tag}.mt.flag" in text , f"{tag}: update not gated on the flag";
        assert f"{tag}.st.new" in text , f"{tag}: no plain update path";
        assert f"{tag}.mt.old" in text , f"{tag}: no atomic update path";
    }
}

test "flow spawns set the flag before pthread_create" {
    assert _mark_precedes_spawn(_compile_ir("rc")) , "flag must be set before the first spawn";
}

test "sequential builds never set the flag" {
    text = _compile_ir("cycles");
    assert SPAWN_RE.search(text) is None , "cycles build must stay sequential";
    assert MARK_RE.search(text) is None , "no spawn, so RC must stay on the plain path";
}

test "a C-imported pthread_create sets the flag before the call" {
    text = str(compile_native_ir("rc_threaded_ffi.jac").gen.llvm_ir);
    assert _mark_precedes_spawn(text) , "C-imported spawn must switch RC to atomic first";
}

test "single-threaded RC churn computes correctly" {
    (eng, _) = compile_native("rc_threaded.jac");
    f = get_func(eng, "rc_churn", ctypes.c_int64, ctypes.c_int64);
    assert f(500) == 2 * (500 + 1390);
    assert f(1) == 4;
    assert f(0) == 0;
}

test "borrowed parameters are readonly only when nothing writes their refcount" {
    view = os.path.join(
        TESTS_DIR,
        "compiler",
        "backends",
        "native",
        "fixtures",
        "nogc_identity",
        "view_cursor.jac"
    );
    for (gc_mode, readonly) in (("cycles", False), ("rc", False), ("none", True)) {
        sig = [
            ln
            for ln in _compile_ir(gc_mode, view).splitlines()
            if ln.startswith("define") and re.search(r'\.walk"?\(', ln)
        ];
        assert len(sig) == 1 , f"{gc_mode}: walk not found";
        assert "noalias" in sig[0] , f"{gc_mode}: {sig[0]}";
        assert ("readonly" in sig[0]) == readonly , f"{gc_mode}: {sig[0]}";
    }
}

test "shared string survives concurrent retain/release from flow tasks" {
    with tempfile.TemporaryDirectory() as tmp {
        for mode in ("rc", "managed") {
            out_bin = os.path.join(tmp, f"rct_{mode}");
            res = subprocess.run(
                jac_command("build", "--native", FIXTURE)
                    + ["--memory", mode, "-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            for _ in range(5) {
                ran = subprocess.run([out_bin], capture_output=True, text=True);
                assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
                assert ran.stdout == EXPECTED , f"{mode}: {ran.stdout}";
            }
        }
    }
}

test "a shared library's init switches refcounts to atomic before the host calls in" {
    shared = entry_preamble_ir(GlueSpec(units=[], shared=True));
    init = shared[shared.index("define void @__jac_shared_init"):];
    assert f"store atomic i8 1, ptr @{RC_THREADED_SYMBOL}" in init , "shared init must mark RC threaded";
    exe = entry_preamble_ir(GlueSpec(units=[], shared=False));
    assert RC_THREADED_SYMBOL not in exe , "an executable starts on the plain path";
}

test "a JIT engine starts with atomic refcounts" {
    (eng, _) = compile_native("rc_host_threads.jac");
    address = int(eng.get_global_value_address(RC_THREADED_SYMBOL));
    assert address , "no threaded flag in the JIT module";
    assert ctypes.c_uint8.from_address(address).value == 1 , "host-loaded code must start atomic";
}

test "Python threads calling in at once keep a shared string alive" {
    (eng, _) = compile_native("rc_host_threads.jac");
    hammer = get_func(eng, "hammer", ctypes.c_int64, ctypes.c_int64);
    churn = get_func(eng, "churn", ctypes.c_int64, ctypes.c_int64);
    intact = get_func(eng, "shared_intact", ctypes.c_int64);
    # ctypes releases the GIL around each call, so the four calls run at once.
    for _ in range(3) {
        with ThreadPoolExecutor(max_workers=4) as pool {
            results = list(pool.map(hammer, [200000, 200000, 200000, 200000]));
        }
        assert results == [3600000, 3600000, 3600000, 3600000];
        assert churn(20000) == 20000;
        assert intact() == 1 , "shared string was freed or overwritten";
    }
}
