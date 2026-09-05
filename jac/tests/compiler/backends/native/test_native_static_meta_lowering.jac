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

import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT, unit_symbol }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     );


"""Compile a fixture in the native codespace; return the program and module."""
def compile_native(name: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(
            aot_mode=True,
            force_codespace='native',
            force_target_program=True,
            na_gc_mode='cycles'
        )
    );
    return (prog, ir, );
}


"""Compile a fixture in the server codespace; return its errors."""
def server_errors(name: str) -> list {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(force_codespace='server')
    );
    return [str(e) for e in prog.errors_had];
}


def diag_codes(entries: list) -> list {
    return [
        e.code.code
        for e in entries
        if e.code is not None
    ];
}


test "class-level tuple metadata lowers natively" {
    (prog, ir) = compile_native("static_tuple_meta.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for static tuple metadata";
}


test "class-level tuple metadata keeps the literal's layout" {
    (_prog, ir) = compile_native("static_tuple_meta.jac");
    text = str(ir.gen.llvm_ir);
    assert f'@"{unit_symbol(ir, "Access.PROVIDES")}" = global {{i8*}}*' in text , (
        "the widened `tuple` annotation did not narrow to the one-element "
        "tuple of str its constant declares; a scalar slot here would make "
        "every read of it garbage"
    );
    assert f'@"{unit_symbol(ir, "Stage.REQUIRES")}" = global {{}}*' in text , (
        "the empty tuple did not land on a zero-field struct"
    );
}


test "static tuple metadata draws no instance-layout warning" {
    (prog, _ir) = compile_native("static_tuple_meta.jac");
    codes = diag_codes(prog.warnings_had);
    assert "W5032" not in codes , (
        f"class-level field judged against the instance layout: {codes}"
    );
}


test "a defaulted static has does not order instance fields" {
    (prog, ir) = compile_native("static_meta_ordering.jac");
    codes = diag_codes(prog.errors_had);
    assert "E2004" not in codes , (
        f"class-level constant counted as a defaulted instance field: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for static-first archetype";
}


test "the static has ordering rule matches on the server lane" {
    errs = server_errors("static_meta_ordering.jac");
    assert not errs , f"server lane rejected a class-level constant: {errs}";
}


test "a TypeAlias glob lowers as a compile-time declaration" {
    (prog, ir) = compile_native("type_alias_glob.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the alias module";
}


test "a type-parameter glob lowers as a compile-time declaration" {
    (prog, ir) = compile_native("type_param_glob.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the type-param module";
    assert f'@"{unit_symbol(ir, "T")}"' not in str(ir.gen.llvm_ir) and '@"T"' not in str(ir.gen.llvm_ir) , (
        "the type variable was given storage instead of being erased"
    );
}


test "a widened tuple glob lowers from its constant" {
    (prog, ir) = compile_native("tuple_glob_meta.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the tuple glob";
    assert f'@"{unit_symbol(ir, "MOVE_EXEMPT")}" = global {{i8*, i8*}}*' in str(ir.gen.llvm_ir) , (
        "the glob did not take the two-element str layout its constant declares"
    );
}
