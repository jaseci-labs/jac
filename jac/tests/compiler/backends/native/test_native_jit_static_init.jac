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

from tests.support import compile_native, native_address

engine, fixture = compile_native(
    os.path.basename(sys.argv[1]), os.path.dirname(sys.argv[1])
)
addr = native_address(engine, sys.argv[2])
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
