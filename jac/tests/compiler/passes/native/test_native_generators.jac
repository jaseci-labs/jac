"""Behavioral tests for generator functions (yield) on native.

Graduated from the YieldExpr hard reject in the capability gate: a `def`
containing `yield` lowers to a JacIter creation function plus a private
resume state machine. Consumers exercise the existing iterator surface:
for-loops, first-class next(), independent instances, early break (frame
drop), and composition through the lazy adapters.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_gen_{label}.na.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code);
    return prog;
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

test "generator: for-loop drives a while/yield state machine" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(eng, "total_of", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 10 , "0+1+2+3+4";
    assert f(0) == 0 , "empty generator yields nothing";
    assert f(1) == 0 , "single yield of 0";
}

test "generator: early break abandons the stream safely" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(eng, "early_break", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(10, 3) == 3 , "sees 0,1,2 then breaks";
}

test "generator: first-class next() advances a stored instance" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(eng, "manual_next", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 1 , "a=0, b=1 -> 0*10+1";
}

test "generator: independent instances do not share frames" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(eng, "two_streams", ctypes.c_int64, ctypes.c_int64);
    # sum over a,b in [0..2]^2 of a*b = (0+1+2)^2 = 9.
    assert f(3) == 9;
}

test "generator: yield inside a for-over-range resumes mid-loop" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(eng, "total_for_yield", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 12 , "0+2+4+6";
}

test "generator: plain return stops iteration early" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(
        eng, "total_stop_early", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(10, 4) == 6 , "0+1+2+3 then return";
}

test "generator: str parameter is retained by the frame across yields" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(eng, "echo_len", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"abcd") == 12 , "len('abcd') * 3";
}

test "generator: composes under the lazy map adapter" {
    (eng, _) = compile_native("generators.na.jac");
    f = get_func(eng, "doubled_total", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 12 , "2*(0+1+2+3)";
}

test "generator guardrail: yield inside try is a structured error" {
    prog = compile_na_inline(
        "yield_in_try",
        "def g(n: int) -> Iterator[int] {\n"
        "    try {\n"
        "        yield n;\n"
        "    } except Exception as e {\n"
        "        return;\n"
        "    }\n"
        "}\n"
    );
    assert has_error_code(prog, "E5092") , (
        f"expected E5092 for yield inside try, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}
