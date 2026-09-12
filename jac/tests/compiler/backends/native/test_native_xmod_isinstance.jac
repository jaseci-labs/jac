"""`isinstance` against archetypes owned by an imported module (issue #8061).

Candidate vtables were enumerated from the classes the module being compiled
defines, and every vtable global was module-`private`, so a check against an
imported class found nothing to compare and the whole site demoted (E5092).
The candidate set now comes from the program-wide class hierarchy and an
imported class's vtable is referenced as an external symbol, so these sites
lower natively -- and the answers below are what proves the reference points
at the right vtable rather than merely existing.
"""

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

import from jaclang.compiler.session.session { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

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
    llvm_ir = str(artifact_for(ir).llvm_ir);
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
