"""Compiler materialization retains declared field semantics across LLVM pointer erasure."""

import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { compile_native_ir, write_case }

glob FIELDS_SRC: str = "import ast; obj Parent { has name: str; } obj Child(Parent) { has file_path: str; has foreign: ast.AST | None = None; has tags: set[str] = set(); } def make -> Child { return Child(name=\"name\", file_path=\"file.jac\"); }";


test "string fields retain their schema while foreign pointers remain opaque" {
    fx = compile_native_ir(
        write_case(FIELDS_SRC, "materialization_fields.jac"),
        "",
        CompileOptions(force_codespace="native", native_unit=True)
    );
    iface = fx.iface();
    assert iface is not None;
    classes = iface.classes;
    assert classes["Parent"].fields["name"].code == "str";
    assert classes["Child"].fields["name"].code == "str";
    assert classes["Child"].fields["file_path"].code == "str";
    assert classes["Child"].fields["foreign"].code == "opaque";
    tags = classes["Child"].fields["tags"];
    assert tags.code == "natset";
    assert tags.schema is not None;
    assert tags.schema.to_dict()["code"] == "set";
    assert tags.schema.to_dict()["element"] == {"code": "str"};
}
