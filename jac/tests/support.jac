"""Shared path anchor for the test suite.

Tests must not assume the editable-install layout (`jaclang.__file__` sitting
next to the repo `tests/`): under the single `jac` binary, jaclang lives in the
sealed runtime cache, not beside the tests. This module resolves the repo root
from its OWN location inside `tests/`, so every test imports one stable anchor
instead of re-deriving it with a `Path(__file__).resolve().parents` walk.

Imported as `from tests.support`, which resolves identically under the single
`jac` binary and a source checkout (same mechanism as `tests.fixtures_list`).
"""

import ctypes;

import from pathlib { Path }

# `tests/`: the directory holding this file.
glob TESTS_DIR: str = str(Path(__file__).resolve().parent),
     # Repo root (the `jac/` dir): the parent of `tests/`.
     JAC_ROOT: str = str(Path(__file__).resolve().parent.parent);

"""CompileOptions that force a fixture into the native codespace.

The retired .na.jac marker used to do this from the filename; tests that
compile a fixture and expect a JIT engine now state the mandate explicitly.
Forced placement keeps lowering failures loud (no server demotion), exactly
like the old suffix.
"""
def native_force_opts -> any {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    return CompileOptions(force_codespace='native', force_target_program=True);
}


class JacStrABI(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}

def native_str_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    # descriptor-ABI JIT getter shared by native tests: a c_char_p
    # spelling means a Jac str (the by-value {root, data, len}
    # descriptor); LLVM decomposes the by-value param into three scalar
    # slots, so str args pass as (root, data, len) built via
    # jac_str_new, and str returns read back as a two-pointer pair with
    # the payload NUL-bounded at data
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    real_res: any = JacStrABI if restype == ctypes.c_char_p else restype;
    str_slots: list = [];
    real_args: list = [];
    for a in argtypes {
        if a == ctypes.c_char_p {
            str_slots.append(True);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_int64);
        } else {
            str_slots.append(False);
            real_args.append(a);
        }
    }
    raw = ctypes.CFUNCTYPE(real_res, *real_args)(addr);
    sn_addr = 0;
    for sn in ("jac_str_new", "__jac_str_new") {
        try {
            sn_addr = eng.get_function_address(sn);
        } except Exception {
            sn_addr = 0;
        }
        if sn_addr {
            break;
        }
    }
    mkstr = (
        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(sn_addr)
            if sn_addr
            else None
    );
    def _call(*args: any) -> any {
        c_args: list = [];
        _keep: list = [];
        for (a, is_str) in zip(args, str_slots) {
            if is_str {
                b = a.encode("utf-8") if isinstance(a, str) else a;
                if mkstr is not None {
                    p = mkstr(b, len(b));
                } else {
                    _buf = ctypes.create_string_buffer(b);
                    _keep.append(_buf);
                    p = ctypes.cast(_buf, ctypes.c_void_p).value;
                }
                c_args.append(p);
                c_args.append(p);
                c_args.append(len(b));
            } else {
                c_args.append(a);
            }
        }
        r = raw(*c_args);
        if real_res is JacStrABI {
            if not r.data {
                return b"";
            }
            return ctypes.string_at(r.data);
        }
        return r;
    }
    return _call;
}


"""Fetch an object's persisted state by id from a compiled Jac program.

Runs under the system context (no user root), so access checks always pass.
Previously lived in `tests/conftest.py`, which existed only for pytest.
"""
def get_object(filename: str, id: str, main: bool = True) -> dict[(str, any)] {
    import from jaclang.cli.commands.cli_helpers { proc_file }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    (base, mod, mach) = proc_file(filename);
    try {
        Jac.jac_import(
            target=mod, base_path=base, override_name=("__main__" if main else None)
        );
        found = Jac.get_object(id);
        if not found {
            raise ValueError(f"Object with id {id} not found.");
        }
        return found.__jac__.__getstate__();
    } finally {
        mach.close();
    }
}


# The native pass fixtures directory: the default corpus for `compile_native`.
glob NATIVE_FIXTURES: str = str(
         Path(__file__).resolve().parent
             / "compiler"
             / "backends"
             / "native"
             / "fixtures"
     );

"""Compile a .jac fixture into the native codespace and return (engine, module).

`fixture_dir` defaults to the native pass fixtures directory, which is where
all but one caller looks; pass it explicitly for a fixture that lives
elsewhere. The engine is NOT cached across calls -- a JIT engine owns the
module's mutable globals, so handing the same one to two tests would let the
first test's writes reach the second. Tests that want a fixture compiled once
should assert against it once, in a single test.
"""
def compile_native(fixture: str, fixture_dir: str = "") -> tuple {
    import from jaclang.compiler.driver.program { JacProgram }
    base = fixture_dir or NATIVE_FIXTURES;
    prog = JacProgram();
    ir = prog.compile(file_path=str(Path(base) / fixture), options=native_force_opts());
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from a JIT engine."""
def get_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: any, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

"""Memory profiles a native test can build under.

`nogc` is the headerless endpoint (zero-RC enforcement, no runtime, the
RC-free IR scan on); `rc` and `managed` are the reference-counted runtimes
without and with the cycle collector. The CLI spelling of each profile lives
here and nowhere else in the test tree, so a flag rename is a one-line
change.
"""
glob NATIVE_MEMORY_PROFILES: list[str] = ["nogc", "rc", "managed"];

def native_memory_flags(memory: str) -> list[str] {
    if memory == "nogc" {
        return ["--enforce-nogc", "--gc", "none", "--assert-no-rc"];
    }
    if memory == "rc" {
        return ["--gc", "rc"];
    }
    if memory == "managed" {
        return ["--gc", "cycles"];
    }
    raise ValueError(f"unknown native memory profile: {memory}");
}

"""Build `src` into the native binary `out_bin` through the CLI.

Runs the compiler in a subprocess exactly as a developer would, under the
given memory profile, and asserts the build succeeded. Returns the build's
combined stdout/stderr so a caller can grep a build-time line (rc-stats,
assert-no-rc) without a second compile.
"""
def native_build(
    src: str,
    out_bin: str,
    memory: str = "managed",
    extra: list[str] | None = None,
    timeout: int = 300
) -> str {
    import os;
    import subprocess;
    import sys;
    assert os.path.exists(src) , f"fixture missing: {src}";
    cmd = (
        [sys.executable, "-m", "jaclang", "nacompile", src]
        + native_memory_flags(memory)
        + list(extra or [])
        + ["-o", out_bin]
    );
    comp = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout);
    assert comp.returncode == 0 , (
        f"native build ({memory}) failed for {os.path.basename(src)}:"
        f" exit={comp.returncode}\n"
        f"stdout: {comp.stdout[-800:] if comp.stdout else '(empty)'}\n"
        f"stderr: {comp.stderr[-800:] if comp.stderr else '(empty)'}"
    );
    assert os.path.exists(out_bin) , f"binary not produced at {out_bin}";
    return (comp.stdout or "") + (comp.stderr or "");
}

"""Run a built native binary and return its stdout; assert a clean exit."""
def native_run(
    out_bin: str,
    args: list[str] | None = None,
    timeout: int = 120,
    env: dict[str, str] | None = None
) -> str {
    import os;
    import subprocess;
    run_env = dict(os.environ);
    if env {
        run_env.update(env);
    }
    proc = subprocess.run(
        [out_bin] + list(args or []),
        capture_output=True,
        text=True,
        timeout=timeout,
        env=run_env
    );
    assert proc.returncode == 0 , (
        f"{os.path.basename(out_bin)} exited {proc.returncode}"
        f" (a segfault or abort here is a codegen regression)\n"
        f"stdout: {proc.stdout[-400:] if proc.stdout else '(empty)'}\n"
        f"stderr: {proc.stderr[-400:] if proc.stderr else '(empty)'}"
    );
    return proc.stdout;
}

"""Run `src` on the Python backend through the CLI and return its stdout."""
def python_run(src: str, args: list[str] | None = None, timeout: int = 120) -> str {
    import os;
    import subprocess;
    import sys;
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", src] + list(args or []),
        capture_output=True,
        text=True,
        timeout=timeout
    );
    assert proc.returncode == 0 , (
        f"jac run failed for {os.path.basename(src)}: exit={proc.returncode}\n"
        f"stderr: {proc.stderr[-800:] if proc.stderr else '(empty)'}"
    );
    return proc.stdout;
}

"""Build and run `src` under every memory profile and on the Python backend.

Returns {profile: stdout}. The identity contract of the ownership design is
that these agree byte for byte: annotations erase, and a headerless build
must behave exactly like the managed ones. A caller asserts that agreement
with `assert_native_identity`.
"""
def native_outputs(
    src: str, args: list[str] | None = None, profiles: list[str] | None = None
) -> dict[str, str] {
    import os;
    import tempfile;
    outs: dict[str, str] = {};
    with tempfile.TemporaryDirectory() as tmp {
        for memory in (profiles or NATIVE_MEMORY_PROFILES) {
            out_bin = os.path.join(tmp, f"{Path(src).stem}.{memory}");
            native_build(src, out_bin, memory=memory);
            outs[memory] = native_run(out_bin, args);
        }
    }
    outs["python"] = python_run(src, args);
    return outs;
}

"""Assert every backend produced the same stdout for `src`; return that stdout."""
def assert_native_identity(
    src: str, args: list[str] | None = None, profiles: list[str] | None = None
) -> str {
    outs = native_outputs(src, args, profiles);
    reference = outs["python"];
    for (memory, out) in outs.items() {
        assert out == reference , (
            f"{Path(src).name}: {memory} output differs from the Python backend\n"
            f"--- {memory} ---\n{out}\n--- python ---\n{reference}"
        );
    }
    return reference;
}
