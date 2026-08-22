"""`isinstance` against archetypes owned by an imported module (issue #8061).

Candidate vtables were enumerated from the classes the module being compiled
defines, and every vtable global was module-`private`, so a check against an
imported class found nothing to compare and the whole site demoted (E5092).
The candidate set now comes from the program-wide class hierarchy and an
imported class's vtable is referenced as an external symbol, so these sites
lower natively -- and the answers below are what proves the reference points
at the right vtable rather than merely existing.
"""

import contextlib;
import ctypes;
import io;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
import from jaclang.utils.precompile_bytecode { seal_native_artifacts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .jac fixture and return the JIT engine plus the compiled module."""
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

test "isinstance against an imported class lowers natively" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "xmod_isinstance_main.jac")),
        options=native_force_opts()
    );
    demoted = [
        d.pretty_print()
        for d in (prog.errors_had or [])
        if d.code is not None and d.code.code == "E5092"
    ];
    assert not demoted , f"cross-module isinstance did not lower: {demoted}";
    llvm_ir = str(ir.gen.llvm_ir);
    assert "Circle.__vtable" in llvm_ir , "the imported Circle vtable is not referenced at all";
}

test "imported base class matches through the imported MRO" {
    (eng, _) = compile_native("xmod_isinstance_main.jac");
    f = get_func(eng, "chk_base", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "Circle must match its imported base Shape";
    assert f(1) == 1 , "Square must match its imported base Shape";
    assert f(2) == 0 , "an unrelated imported hierarchy must not match Shape";
    assert f(3) == 0 , "an int must not match an imported archetype";
}

test "imported leaf class does not match a sibling" {
    (eng, _) = compile_native("xmod_isinstance_main.jac");
    f = get_func(eng, "chk_leaf", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "Circle must match Circle";
    assert f(1) == 0 , "Square must not match its sibling Circle";
}

test "statically typed operand of an imported class matches its base" {
    (eng, _) = compile_native("xmod_isinstance_main.jac");
    f = get_func(eng, "chk_typed", ctypes.c_int64);
    assert f() == 1 , "a Circle-typed local must match the imported base Shape";
}

test "objects built by the defining module carry the same vtable" {
    (eng, _) = compile_native("xmod_isinstance_main.jac");
    f = get_func(eng, "chk_lib_built", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "a Circle built inside the library must match Circle here";
    assert f(1) == 0 , "a Square built inside the library must not match Circle";
}

test "a sealed artifact resolves the cross-module vtable symbol" {
    # The vtable global is no longer `private`, so `seal_native_artifacts`'
    # in-house linker now sees it in the symbol table. The seal's load canary
    # dlopens the emitted library and calls into it, which is what proves the
    # reference resolved rather than merely assembling.
    tmp = tempfile.mkdtemp(prefix="jac_xmod_isinstance_seal_");
    buf = io.StringIO();
    try {
        with contextlib.redirect_stderr(buf) {
            arts = seal_native_artifacts(
                Path(FIXTURES), Path(tmp), modules=("xmod_isinstance_main.jac", )
            );
        }
        assert arts , f"the seal produced no artifact:\n{buf.getvalue()}";
        rec = arts["fixtures.xmod_isinstance_main"];
        lib = Path(tmp) / rec["lib"];
        assert lib.is_file() , f"no shared library at {lib}";
        assert "canary" in buf.getvalue().lower() , (
            f"the seal accepted an artifact without running the canary:\n{buf.getvalue()}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
