"""`isinstance` against an imported class with no vtable slot (issue #8201).

A class earns a vtable slot from facts its own module can see: it has a base,
something there subclasses it, or something there names it in an `isinstance`.
A flat archetype whose only `isinstance` lives in an importing module satisfies
none of the three, so it lays out without a slot -- and the cross-module fix in
#8061, which answers by comparing the operand's vtable pointer against each
candidate class, had nothing to compare. Sites naming such a class demoted.

Where a consumer subclassed one, the site did worse than demote: the subclass
carries a vtable, so the candidate set was non-empty and the check lowered,
read a plain instance's first field as if it were a vtable pointer, and
answered `False` for `isinstance(point, Point)`.

Identity for these sites now comes from the class name every instantiation
stamps into the allocation header, matched through the program-wide
`(class, ancestor)` table that `_register_imported_hierarchy` fills -- so the
answers below are what proves the identity reaches the right class rather than
merely existing.
"""

import contextlib;
import ctypes;
import io;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .jac fixture and return the JIT engine plus the compiled module.

`expect_demotions` frees the fixture that is supposed to refuse a site from the
clean-compile assertion, so a refusal that ever starts riding on the program
does not read as a broken fixture.
"""
def compile_native(
    fixture: str, expect_demotions: bool = False
) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    if not expect_demotions {
        assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    }
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""What a fixture's compile reported about seams, as the developer sees it.

Native seams are written to stderr as they are found rather than collected on
the program, so this captures the stream the same way a build would show it.
"""
def seam_report(fixture: str) -> str {
    buf = io.StringIO();
    prog = JacProgram();
    with contextlib.redirect_stderr(buf) {
        prog.compile(
            file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
        );
    }
    return buf.getvalue();
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

test "isinstance against a vtable-less imported class lowers natively" {
    seams = seam_report("xmod_isinstance_flat_main.jac");
    assert "isinstance" not in seams , f"a flat imported class did not lower: {seams}";
}

test "a flat imported class matches itself and nothing else" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_flat", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "a Point must match the imported Point";
    assert f(1) == 0 , "an unrelated imported class must not match Point";
    assert f(2) == 0 , "a same-module class must not match Point";
    assert f(3) == 0 , "an int must not match an imported archetype";
}

test "a same-module flat class still decides" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_local", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "a Local must match Local";
    assert f(1) == 0 , "an imported Point must not match a same-module Local";
}

test "a statically typed operand of a flat imported class matches" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_typed", ctypes.c_int64);
    assert f() == 1 , "a Point-typed local must match Point";
}

test "objects the defining module built carry the same identity" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_lib_built", ctypes.c_int64);
    assert f() == 1 , "a Point the library allocated must match Point here";
}

test "a consumer subclass and a plain instance both match the imported base" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_kid", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "MainKid must match its imported base Point";
    assert f(1) == 1 , "a plain Point must match Point once a subclass exists";
    assert f(2) == 1 , "a library-built Point must match Point too";
    assert f(3) == 0 , "an unrelated imported class must not match Point";
}

test "the consumer subclass does not swallow its imported base" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_kid_leaf", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "MainKid must match MainKid";
    assert f(1) == 0 , "a plain Point must not match the subclass MainKid";
}

test "an imported hierarchy still decides through its vtables" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_hier", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "LibKid must match its imported base LibBase";
    assert f(1) == 1 , "LibBase must match LibBase";
    assert f(2) == 0 , "an unrelated imported class must not match LibBase";
}

test "a tuple arm mixes a flat and a hierarchical imported class" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    f = get_func(eng, "chk_tuple_arm", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "the flat arm must answer for a Point";
    assert f(1) == 1 , "the hierarchical arm must answer for a LibKid";
    assert f(2) == 0 , "neither arm may answer for an unrelated class";
}

test "an ancestor chain that leaves the unit is continued, and the check answers" {
    # This test used to pin the refusal: `DeepKid` recorded `[DeepKid,
    # LibKid]` because nothing in this unit could see that `LibKid` has a
    # base, and answering from that short chain would have said `False` to
    # classes that genuinely derive from `LibBase`. `extended_mro` (#8320)
    # continues the recorded chain through `LibKid`'s own recorded chain
    # once the imported registry is merged, so the linearization is whole,
    # the check lowers, and the honest pin is the ANSWER, not the refusal.
    seams = seam_report("xmod_isinstance_deep_main.jac");
    assert "chk_deep" not in seams , (
        f"chk_deep refused again -- the linearization repair stopped "
        f"continuing the chain: {seams}"
    );
    (eng, _) = compile_native("xmod_isinstance_deep_main.jac");
    f = get_func(eng, "chk_deep", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "DeepKid must match LibBase through the continued chain";
    assert f(1) == 1 , "a plain LibKid must match LibBase too";
    assert f(2) == 0 , "an unrelated class must still not match LibBase";
}

test "a target whose chain was always whole is untouched by the repair" {
    (eng, _) = compile_native("xmod_isinstance_deep_main.jac");
    f = get_func(eng, "chk_flat", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "a target whose chain is whole must still lower and match";
    assert f(1) == 0 , "and must still reject an unrelated class";
}

test "an operand that could never hold the deep class still answers" {
    (eng, _) = compile_native("xmod_isinstance_deep_main.jac");
    f = get_func(eng, "chk_unrelated_operand", ctypes.c_int64);
    assert f() == 0 , (
        "a statically typed operand outside the subtree must decide, not refuse"
    );
}

test "an operand typed as the once-dropped ancestor answers correctly" {
    # The inverse of the old pin: a `LibBase`-typed operand used to look
    # unrelated to `DeepKid` precisely because `LibBase` was the link the
    # short chain dropped, and lowering it would have answered `False` for
    # a `DeepKid` flowing through that slot. With the chain continued, the
    # table holds (DeepKid, LibBase) and the answer is the true one.
    (eng, _) = compile_native("xmod_isinstance_deep_main.jac");
    f = get_func(eng, "chk_base_typed_operand", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1 , "a DeepKid behind a LibBase-typed slot must match";
    assert f(1) == 1 , "a LibKid behind the same slot must match too";
}
