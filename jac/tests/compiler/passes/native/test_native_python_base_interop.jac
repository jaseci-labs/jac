"""Python-base inheritance interop (epic #8201, blockers 4 and 5).

A jac class in a native unit may inherit from a class that stays
Python-side (the cross-module-trust design keeps bases like `Transform`
and `UniPass` out of the native closure). Three seams previously failed
there, coverage-verified against the compiler's own tree:

  1. `super.postinit();` -- E5092 "super.__post_init__", a hard abort of
     the whole module (`Transform.postinit`, chained by every pass).
  2. Stores to inherited fields -- E5092 "field assignment"
     (`UniPass.transform` assigning `self.ir_out`).
  3. Calls to inherited Python-resident methods -- E5092 on the call
     (`UniPass.traverse` calling `self.is_canceled()`).

All three reduce to one primitive: attribute access on a Python handle.
The native instance owns a Python *shadow* -- a real instance of a
synthesized subclass of the Python base -- and inherited members resolve
against it through libpython externs, the same interop path the sealed
parser's materializer already uses. The fixture runs in both lanes and
must agree: `Kid(label="kid")` chains postinit (count 0 -> 10, trace
"|base", extra 11), `poke()` stores 99 then bumps to 100.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.interop_bridge { _pyb_shadows }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     EXPECTED = 100 * 100000 + 100 * 10 + 11;

"""Compile a .jac fixture natively and return the JIT engine plus module."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
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

"""Run the fixture's function in the plain Python lane."""
def run_py_lane(fixture_stem: str, func_name: str) -> object {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(fixture_stem, None);
        sys.modules.pop("pyb_base_lib", None);
        sys.modules.pop("pyb_gen_base_lib", None);
        mod = importlib.import_module(fixture_stem);
        return getattr(mod, func_name)();
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
        sys.modules.pop(fixture_stem, None);
        sys.modules.pop("pyb_base_lib", None);
        sys.modules.pop("pyb_gen_base_lib", None);
    }
}

test "a native class over a Python-side base compiles with no seams" {
    (_eng, ir) = compile_native("pyb_native_main.jac");
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout was exported";
    for m in ["Kid.__post_init__", "Kid.poke", "Kid.read_back"] {
        assert m in layout.methods , (
            f"{m} was demoted instead of lowering: {sorted(layout.methods)}"
        );
    }
}

test "postinit chain, inherited store and inherited call match Python" {
    (eng, _) = compile_native("pyb_native_main.jac");
    get_func(eng, "jac_entry", None)();
    f = get_func(eng, "run_all", ctypes.c_int64);
    assert f() == EXPECTED , f"native lane produced {f()}, expected {EXPECTED}";
}

test "the Python lane and the native lane agree on the fixture" {
    (eng, _) = compile_native("pyb_native_main.jac");
    get_func(eng, "jac_entry", None)();
    native_val = get_func(eng, "run_all", ctypes.c_int64)();
    py_val = run_py_lane("pyb_native_main", "run_all");
    assert native_val == py_val , (
        f"lane divergence: native {native_val} vs python {py_val}"
    );
}

test "an inherited field store is visible on the Python shadow" {
    (eng, _) = compile_native("pyb_native_main.jac");
    get_func(eng, "jac_entry", None)();
    _pyb_shadows.clear();
    kept = get_func(eng, "keep_and_poke", ctypes.c_int64)();
    assert kept == 100 , f"keep_and_poke returned {kept}";
    assert len(_pyb_shadows) == 1 , (
        f"expected one live shadow, found {len(_pyb_shadows)}"
    );
    shadow = list(_pyb_shadows.values())[0];
    assert type(shadow).__name__ == "Kid" , type(shadow).__name__;
    assert any(c.__name__ == "PyBase" for c in type(shadow).__mro__) , (
        "shadow is not an instance of the Python base"
    );
    assert shadow.count == 100 , f"shadow.count is {shadow.count}";
    assert shadow.trace == "|base" , f"shadow.trace is {shadow.trace!r}";
    assert shadow.label == "kid" , f"shadow.label is {shadow.label!r}";
}

test "releasing the native owner drops its Python shadow" {
    (eng, _) = compile_native("pyb_native_main.jac");
    _pyb_shadows.clear();
    get_func(eng, "jac_entry", None)();
    transient = get_func(eng, "run_all", ctypes.c_int64)();
    assert transient == EXPECTED , f"run_all returned {transient}";
    assert len(_pyb_shadows) == 0 , (
        f"transient instances leaked {len(_pyb_shadows)} shadow(s)"
    );
}

test "a subscripted generic Python-side base still bridges" {
    # A subscripted base reference is an AtomTrailer carrying an IndexSlice
    # rather than a bare Name, and the bridge must unwrap it; before it did,
    # inherited stores and calls demoted silently. The shape was found on the
    # compiler's own pass chain, which spelled `Transform[Module, Module]`
    # until the chain went monomorphic; user code still writes it, which is
    # why the fixture keeps measuring it.
    (eng, ir) = compile_native("pyb_gen_base_main.jac");
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout was exported";
    assert "Kid.poke" in layout.methods , (
        f"Kid.poke was demoted instead of bridging: {sorted(layout.methods)}"
    );
    get_func(eng, "jac_entry", None)();
    native_val = get_func(eng, "run_all", ctypes.c_int64)();
    assert native_val == 100 , f"native lane produced {native_val}, expected 100";
    py_val = run_py_lane("pyb_gen_base_main", "run_all");
    assert native_val == py_val , (
        f"lane divergence: native {native_val} vs python {py_val}"
    );
}
