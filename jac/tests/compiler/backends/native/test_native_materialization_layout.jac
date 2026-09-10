"""Compiler materialization retains declared field semantics across LLVM pointer erasure."""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.codeinfo {
    set_native_unit_compile,
    reset_native_unit_compile
}


test "string fields retain their schema while foreign pointers remain opaque" {
    program = JacProgram();
    previous = set_native_unit_compile(True);
    try {
        module = program.compile(
            file_path="materialization_fields.jac",
            use_str="import ast; obj Parent { has name: str; } obj Child(Parent) { has file_path: str; has foreign: ast.AST | None = None; } def make -> Child { return Child(name=\"name\", file_path=\"file.jac\"); }",
            options=CompileOptions(
                force_codespace="native",
                skip_native_engine=True,
                no_ir_cache=True,
                native_unit=True
            )
        );
        assert not program.errors_had , str(program.errors_had);
        assert module.gen.native_iface is not None;
        classes = module.gen.native_iface.classes;
        assert classes["Parent"].fields["name"].code == "str";
        assert classes["Child"].fields["name"].code == "str";
        assert classes["Child"].fields["file_path"].code == "str";
        assert classes["Child"].fields["foreign"].code == "opaque";
    } finally {
        reset_native_unit_compile(previous);
    }
}
