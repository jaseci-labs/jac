"""Behavioral tests for TypeVar-function monomorphization on native.

Graduated from the unlowerable-type E5092 at declaration: a generic def is
a template that emits no code by itself; each callsite's checker-solved
types stamp a specialized private copy, memoized per solved-type key. The
same body lowers to different operations per instantiation.
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
    path = os.path.join(FIXTURES, f"_generics_{label}.na.jac");
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

test "mono: identity specializes at int, float, and str" {
    (eng, _) = compile_native("generics_mono.na.jac");
    fi = get_func(eng, "use_identity_int", ctypes.c_int64, ctypes.c_int64);
    assert fi(7) == 7;
    fs = get_func(eng, "use_identity_str_len", ctypes.c_int64, ctypes.c_char_p);
    assert fs(b"abcd") == 4;
    ff = get_func(eng, "use_identity_float", ctypes.c_double, ctypes.c_double);
    assert ff(2.5) == 2.5;
    fk = get_func(eng, "use_identity_kw", ctypes.c_int64, ctypes.c_int64);
    assert fk(9) == 9 , "keyword-supplied argument binds the type param";
}

test "mono: one body, different lowerings per instantiation" {
    (eng, _) = compile_native("generics_mono.na.jac");
    ti = get_func(eng, "use_tail_int", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert ti(3, 9) == 9 , "i64 element load at int";
    ts = get_func(
        eng, "use_tail_str_len", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert ts(b"ab", b"wxyz") == 4 , "pointer element load at str";
}

test "mono: container type params solve through list[T]" {
    (eng, _) = compile_native("generics_mono.na.jac");
    f = get_func(eng, "use_first", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(5, 9) == 5;
    g = get_func(
        eng, "use_first_str_len", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert g(b"hello", b"xy") == 5;
}

test "mono: an uncalled generic def emits no code and no error" {
    (eng, ir) = compile_native("generics_mono.na.jac");
    assert eng.get_function_address("never_called") == 0 , (
        "a generic template with no instantiations must not exist as a symbol"
    );
}

test "mono: generic generator specializes per element type" {
    # #7626 A3: the generator transform runs under the active substitution
    # with spec-keyed resume/drop symbols, so int and str instantiations
    # of one generic generator coexist.
    (eng, _) = compile_native("generics_generators.na.jac");
    f = get_func(eng, "sum_int_pairs", ctypes.c_int64);
    assert f() == 6 , "1+2+3 through pairs[int]";
    g = get_func(eng, "count_str_pairs", ctypes.c_int64);
    assert g() == 3 , "len('ab')+len('c') through pairs[str]";
}

test "mono: generic method on an archetype stamps per call site" {
    # #7626 A4: `def pick[T]` on an archetype registers as a method
    # template (no declaration-time unlowerable-type error); call sites
    # stamp self-prepended specializations.
    (eng, _) = compile_native("generics_methods.na.jac");
    f = get_func(eng, "pick_int", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 7 , "val>0 picks first";
    assert f(0) == 9 , "val==0 picks second";
    g = get_func(eng, "pick_str_len", ctypes.c_int64, ctypes.c_int64);
    assert g(1) == 2 , "picks 'xx'";
    assert g(0) == 3 , "picks 'yyy'";
}

test "iter flow: generator through a monomorphized Iterator[T] param" {
    # #7626 B4: JacIter is type-erased, so iterator values pass through
    # monomorphized signatures; the element type resolves per site.
    (eng, _) = compile_native("iter_generic.na.jac");
    f = get_func(eng, "use_take2", ctypes.c_int64);
    assert f() == 1 , "take2(gen_nums(5)) == [0, 1]";
}

test "iter flow: iterator stored in a container and drained later" {
    (eng, _) = compile_native("iter_generic.na.jac");
    f = get_func(eng, "stored_iter", ctypes.c_int64);
    assert f() == 3 , "0+1+2 through the stored iterator";
}

test "iter flow: lazy adapter over a passed-in iterator param" {
    (eng, _) = compile_native("iter_generic.na.jac");
    f = get_func(eng, "use_adapter", ctypes.c_int64);
    assert f() == 6 , "map(+1) over gen_nums(3): 1+2+3";
}

test "mono as-value: concrete Callable annotation stamps the template (#7626 A5)" {
    (eng, _) = compile_native("generics_as_value.na.jac");
    f = get_func(eng, "use_pick_int", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 7 , "pick2[int] through the closure value returns x";
    g = get_func(eng, "use_pick_str_len", ctypes.c_int64);
    assert g() == 3 , "pick2[str] picks 'abc'";
}

test "mono guardrail: a generic function used as a value stays rejected" {
    prog = compile_na_inline(
        "generic_as_value",
        "def pick[T](x: T) -> T {\n"
        "    return x;\n"
        "}\n"
        "def use_it(v: int) -> int {\n"
        "    f = pick;\n"
        "    return f(v);\n"
        "}\n"
    );
    assert has_error_code(prog, "E5092") , (
        f"expected E5092 for a generic fn used as a value, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}
