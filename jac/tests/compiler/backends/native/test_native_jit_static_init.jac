"""A JIT'd native unit runs its static initializers before its code is reached.

An AOT image gets this from the loader: `main` calls `jac_entry`, which walks
the import closure's `__jac_glob_init_<sym>` functions before running anything,
and a shared library gets the same walk out of `DT_INIT_ARRAY`. A JIT'd unit
has no loader, and `jac_entry` is only emitted for a module that has a `with
entry` block -- so a native *library* unit had no callable initializer at all.
Its imports' module-level tables stayed at their null placeholders and the
first read of one segfaulted the host process (#8228).

`keyword` is the sharp case: the bundled shim's `kwlist` is a `list[str]`
literal, which is not a compile-time constant the way an int or a float is, so
it is emitted as a null global plus a store inside the shim's initializer.
`iskeyword` is then a walk over that list, i.e. a dereference of null. Both
import spellings reach it, and both are pinned here.

The engine now runs the plan the first time it hands out a function address,
which is the JIT counterpart of the loader step. `jac_entry` is exempt: it
chains the same initializers itself, after the GC-mode and `argv` setup that
has to come first, and that order must not move.

Every execution here runs in a subprocess. A regression is a SIGSEGV, and a
SIGSEGV in-process would take the whole test run down with it instead of
failing one test.
"""

import os;
import subprocess;
import jaclang;
import from tests.support { TESTS_DIR, compiler_python_command }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _JIT_DRIVER = """
import ctypes
import os
import sys
import jaclang

assert os.path.realpath(jaclang.__file__) == os.path.realpath(sys.argv[3]), (
    "JIT subprocess selected a different compiler package", jaclang.__file__, sys.argv[3]
)

from jaclang.compiler.driver.compile_options import CompileOptions
from jaclang.compiler.driver.program import JacProgram

prog = JacProgram()
ir = prog.compile(
    file_path=sys.argv[1],
    options=CompileOptions(
        force_codespace='native',
        force_target_program=True,
        no_ir_cache=True,
    ),
)
if prog.errors_had:
    raise SystemExit('compile errors: %r' % [str(e) for e in prog.errors_had])
engine = ir.gen.native_engine
if engine is None:
    raise SystemExit('no native engine')
symbol = ir.gen.native_iface.symbol_of(sys.argv[2])
addr = engine.get_function_address(symbol or sys.argv[2])
if addr == 0:
    raise SystemExit('symbol absent from the JIT engine: %s' % sys.argv[2])
print(ctypes.CFUNCTYPE(ctypes.c_int64)(addr)())
""";


"""Compile a fixture natively and call one of its functions, out of process.

Put the loaded compiler's package root first: the test runner adds checkout
paths after loading jaclang, so copying sys.path alone can switch compilers.
"""
def _jit_call(fixture: str, symbol: str) -> tuple[(int, str, str)] {
    package = str(jaclang.__file__);
    proc = subprocess.run(
        compiler_python_command(
            _JIT_DRIVER, os.path.join(FIXTURES, fixture), symbol, package
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    return (proc.returncode, proc.stdout.strip(), proc.stderr);
}


"""Assert a fixture's `run` answers 1 rather than dying on a null table."""
def _assert_answers_one(fixture: str, spelling: str) {
    (code, out, err) = _jit_call(fixture, "run");
    assert code >= 0 , (
        f"the {spelling} spelling died on signal {-code}: a JIT'd unit handed "
        f"out `run` before its import closure's initializers ran, so "
        f"`kwlist` was still null when `iskeyword` walked it\n{err[-800:]}"
    );
    assert code == 0 , f"the {spelling} spelling failed to run: {err[-800:]}";
    assert out == "1" , (
        f"the {spelling} spelling answered {out!r}: `iskeyword('class')` is "
        f"True, so a 0 means the shim's table was read empty rather than "
        f"initialized"
    );
}


test "a from-imported shim's table is live when a JIT'd unit reads it" {
    _assert_answers_one("from_import_shimmed_stdlib.jac", "from-import");
}


test "a bare-imported shim's table is live when a JIT'd unit reads it" {
    _assert_answers_one("bare_import_shimmed_stdlib.jac", "bare import");
}


test "jac_entry is exempt so it keeps chaining the initializers itself" {
    import from jaclang.compiler.frontend.codeinfo { install_native_static_init }

    class _FakeEngine {
        def init(self: _FakeEngine) {
            self.static_init_symbols = [];
            self.static_init_chained = `set();
        }
    }
    engine = _FakeEngine();
    plan = ["__jac_glob_init_dep", "__jac_glob_init_unit"];
    install_native_static_init(engine, plan);
    assert "jac_entry" in engine.static_init_chained , (
        "`jac_entry` sets the GC mode and reads `argv` before it chains the "
        "initializers; pre-running them on the way to its address would move "
        "that setup after the code it configures"
    );
    assert engine.static_init_symbols == plan;
    install_native_static_init(None, plan);
}
