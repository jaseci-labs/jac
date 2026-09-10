import os;
import subprocess;
import sys;
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _JIT_DRIVER = """
import ctypes
import sys

from jaclang.compiler.driver.compile_options import CompileOptions
from jaclang.compiler.driver.program import JacProgram

prog = JacProgram()
ir = prog.compile(
    file_path=sys.argv[1],
    options=CompileOptions(
        force_codespace='native',
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

The child gets this process's `sys.path` verbatim so it resolves the same
jaclang the test is exercising, rather than whatever an installed one would be.
"""
def _jit_call(fixture: str, symbol: str) -> tuple[(int, str, str)] {
    source = "import sys\nsys.path[:] = " + repr(sys.path) + "\n" + _JIT_DRIVER;
    proc = subprocess.run(
        [sys.executable, "-c", source, os.path.join(FIXTURES, fixture), symbol],
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
