"""End-to-end tests for native LLVM IR compilation (na {} / .na.jac).

Tests verify that .na.jac fixtures compile to LLVM IR, JIT-compile to
native machine code, and produce correct results when executed via ctypes.
"""

from __future__ import annotations

import ctypes
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"


def compile_native(fixture: str) -> tuple[object, object]:
    """Compile a .na.jac fixture and return the JIT engine."""
    from jaclang.pycore.program import JacProgram

    prog = JacProgram()
    ir = prog.compile(file_path=str(FIXTURES / fixture))
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else []
    assert not prog.errors_had, f"Compilation errors in {fixture}: {errors}"
    engine = ir.gen.native_engine
    assert engine is not None, f"No native engine produced for {fixture}"
    return engine, ir


def get_func(engine: object, name: str, restype: type, *argtypes: type) -> object:
    """Get a ctypes-callable function from the JIT engine."""
    addr = engine.get_function_address(name)  # type: ignore[attr-defined]
    assert addr != 0, f"Function '{name}' not found in JIT engine"
    functype = ctypes.CFUNCTYPE(restype, *argtypes)
    return functype(addr)


class TestNativeArithmeticExecution:
    """Verify native arithmetic produces correct results."""

    def test_add(self):
        engine, _ = compile_native("arithmetic.na.jac")
        add = get_func(engine, "add", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)
        assert add(3, 4) == 7
        assert add(-1, 1) == 0
        assert add(0, 0) == 0
        assert add(100, 200) == 300

    def test_multiply(self):
        engine, _ = compile_native("arithmetic.na.jac")
        mul = get_func(
            engine, "multiply", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
        )
        assert mul(5, 6) == 30
        assert mul(-3, 7) == -21
        assert mul(0, 999) == 0

    def test_negate(self):
        engine, _ = compile_native("arithmetic.na.jac")
        neg = get_func(engine, "negate", ctypes.c_int64, ctypes.c_int64)
        assert neg(5) == -5
        assert neg(-3) == 3
        assert neg(0) == 0

    def test_float_add(self):
        engine, _ = compile_native("arithmetic.na.jac")
        fadd = get_func(
            engine, "float_add", ctypes.c_double, ctypes.c_double, ctypes.c_double
        )
        assert abs(fadd(1.5, 2.5) - 4.0) < 1e-10
        assert abs(fadd(-1.0, 1.0)) < 1e-10


class TestNativeControlFlowExecution:
    """Verify control flow (if/else, while) works correctly."""

    def test_abs_val(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "abs_val", ctypes.c_int64, ctypes.c_int64)
        assert f(-5) == 5
        assert f(5) == 5
        assert f(0) == 0
        assert f(-100) == 100

    def test_max_val(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "max_val", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)
        assert f(3, 7) == 7
        assert f(10, 2) == 10
        assert f(5, 5) == 5

    def test_factorial(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "factorial", ctypes.c_int64, ctypes.c_int64)
        assert f(0) == 1
        assert f(1) == 1
        assert f(5) == 120
        assert f(10) == 3628800

    def test_sum_to_n(self):
        engine, _ = compile_native("control_flow.na.jac")
        f = get_func(engine, "sum_to_n", ctypes.c_int64, ctypes.c_int64)
        assert f(10) == 55
        assert f(100) == 5050
        assert f(0) == 0


class TestNativeRecursionExecution:
    """Verify recursive function calls work."""

    def test_fibonacci(self):
        engine, _ = compile_native("fibonacci.na.jac")
        fib = get_func(engine, "fib", ctypes.c_int64, ctypes.c_int64)
        assert fib(0) == 0
        assert fib(1) == 1
        assert fib(10) == 55
        assert fib(15) == 610


class TestNativeContextIsolation:
    """Verify na code is excluded from Python/JS codegen and vice versa."""

    def test_native_excluded_from_python(self):
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "mixed_contexts.jac"))
        # Python source should NOT contain native_add
        py_src = ir.gen.py
        assert "native_add" not in py_src
        # Python source should contain server_hello
        assert "server_hello" in py_src

    def test_native_ir_contains_function(self):
        engine, ir = compile_native("arithmetic.na.jac")
        # If we can get the function address, the IR was generated correctly
        addr = engine.get_function_address("add")
        assert addr != 0


class TestNativeLLVMIR:
    """Verify LLVM IR output structure."""

    def test_ir_has_function_definitions(self):
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        ir = prog.compile(str(FIXTURES / "arithmetic.na.jac"))
        assert ir.gen.llvm_ir is not None, "No LLVM IR generated"
        llvm_ir_str = str(ir.gen.llvm_ir)
        assert 'define i64 @"add"' in llvm_ir_str
        assert 'define i64 @"multiply"' in llvm_ir_str
        assert 'define i64 @"negate"' in llvm_ir_str
        assert 'define double @"float_add"' in llvm_ir_str
