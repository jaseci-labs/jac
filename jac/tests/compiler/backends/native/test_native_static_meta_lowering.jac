"""Class-level metadata and type aliases lower on the native pathway.

Every `Transform` subclass in the compiler carries `static has
PROVIDES/REQUIRES: tuple`, and several passes reach for a module-level
`TypeAlias` glob or a constant tuple glob. Each of those shapes used to
refuse the native codespace, which put the whole pass tree out of reach of
a native compile, so each gets a case here.

Two separate mistakes are pinned. The first is a lowering gap: a widened
`tuple` annotation carries no arity, so the layout has to come from the
constant the declaration is initialized with, and a `TypeAlias` glob is a
compile-time declaration that must never be given a layout at all. The
second is a classification mistake shared with the server lane: `static
has` is class-level, so it takes no part in the instance dataclass field
order and none of the instance layout rules.
"""

import ctypes;
import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support {
    JAC_ROOT,
    KernelFixture,
    compile_native,
    diagnostics_text,
    error_codes,
    get_func,
    kernel_compile_file,
    names_global,
    native_str_func,
    unit_symbol,
    warning_codes
}

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     );


"""Compile a fixture in the native codespace through the kernel; return the
result and, when it compiled, what it made of the fixture."""
def compile_meta(name: str) -> tuple[any, (KernelFixture | None)] {
    path = os.path.realpath(os.path.join(FIXTURES, name));
    result = kernel_compile_file(
        path,
        CompileOptions(
            aot_mode=True,
            force_codespace='native',
            na_gc_mode='cycles',
            no_ir_cache=True,
            skip_native_engine=True
        ),
        ["mir"]
    );
    if not result.ok() {
        return (result, None);
    }
    return (result, KernelFixture(path=path, result=result, unit=result.unit(path)));
}


"""Compile a fixture in the server codespace through the kernel."""
def server_result(name: str) -> any {
    return kernel_compile_file(
        os.path.join(FIXTURES, name), CompileOptions(force_codespace='server')
    );
}


test "class-level tuple metadata lowers natively" {
    (result, fx) = compile_meta("static_tuple_meta.jac");
    assert fx is not None , diagnostics_text(result);
    assert fx.llvm_ir() , "no native IR for static tuple metadata";
    assert not fx.demoted() , str(fx.demoted());
}


test "class-level tuple metadata keeps the literal's layout" {
    (eng, _fx) = compile_native(os.path.join(FIXTURES, "static_tuple_meta.jac"));
    provided = native_str_func(eng, "first_provided", ctypes.c_char_p)();
    assert provided == b"access-checks" , (
        "the widened `tuple` annotation did not narrow to the one-element "
        f"tuple of str its constant declares: read {provided!r}"
    );
    assert get_func(eng, "run", ctypes.c_int64)() == 2 + len("access-checks");
}


test "static tuple metadata draws no instance-layout warning" {
    (result, _fx) = compile_meta("static_tuple_meta.jac");
    codes = warning_codes(result);
    assert "W5032" not in codes , (
        f"class-level field judged against the instance layout: {codes}"
    );
}


test "a defaulted static has does not order instance fields" {
    (result, fx) = compile_meta("static_meta_ordering.jac");
    assert "E2004" not in error_codes(result) , (
        f"class-level constant counted as a defaulted instance field: "
        f"{diagnostics_text(result)}"
    );
    assert fx is not None , diagnostics_text(result);
    assert fx.llvm_ir() , "no native IR for static-first archetype";
}


test "the static has ordering rule matches on the server lane" {
    result = server_result("static_meta_ordering.jac");
    assert result.ok() , (
        f"server lane rejected a class-level constant: {diagnostics_text(result)}"
    );
}


test "a TypeAlias glob lowers as a compile-time declaration" {
    (result, fx) = compile_meta("type_alias_glob.jac");
    assert fx is not None , diagnostics_text(result);
    assert fx.llvm_ir() , "no native IR for the alias module";
}


test "a type-parameter glob lowers as a compile-time declaration" {
    (result, fx) = compile_meta("type_param_glob.jac");
    assert fx is not None , diagnostics_text(result);
    text = fx.llvm_ir();
    assert text , "no native IR for the type-param module";
    assert not names_global(text, unit_symbol(fx, "T")) and '@"T"' not in text , (
        "the type variable was given storage instead of being erased"
    );
}


test "a widened tuple glob lowers from its constant" {
    (eng, _fx) = compile_native(os.path.join(FIXTURES, "tuple_glob_meta.jac"));
    exempt = native_str_func(eng, "is_exempt", ctypes.c_bool, ctypes.c_char_p);
    assert exempt("len") is True and exempt("id") is True , (
        "the glob did not take the two-element str layout its constant declares"
    );
    assert exempt("print") is False;
    assert get_func(eng, "run", ctypes.c_int64)() == 1;
}
