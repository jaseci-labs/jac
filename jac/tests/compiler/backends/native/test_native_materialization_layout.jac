"""Compiler materialization retains declared field semantics across LLVM pointer erasure."""

import json;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.native_scope {
    activate_scope_lowering,
    deactivate_scope_lowering
}


test "string fields retain their schema while foreign pointers remain opaque" {
    program = JacProgram();
    activate_scope_lowering();
    try {
        module = program.compile(
            file_path="materialization_fields.jac",
            use_str="import ast; obj Parent { has name: str; } obj Child(Parent) { has file_path: str; has foreign: ast.AST | None = None; } def make -> Child { return Child(name=\"name\", file_path=\"file.jac\"); }",
            options=CompileOptions(
                force_codespace="native",
                force_target_program=True,
                skip_native_engine=True,
                no_ir_cache=True
            )
        );
        assert not program.errors_had , str(program.errors_had);
        assert module.gen.jc_layout is not None;
        classes = json.loads(module.gen.jc_layout)["classes"];
        assert classes["Parent"]["fields"]["name"]["code"] == "str";
        assert classes["Child"]["fields"]["name"]["code"] == "str";
        assert classes["Child"]["fields"]["file_path"]["code"] == "str";
        assert classes["Child"]["fields"]["foreign"]["code"] == "opaque";
    } finally {
        deactivate_scope_lowering();
    }
}

test "materialization skips deleted native dictionary entries and preserves order" {
    import ctypes;
    import from tests.support { compile_native }
    activate_scope_lowering();
    try {
        (eng, module) = compile_native("dict_materialization.jac");
        assert module.gen.jc_layout is not None;
        schema = json.loads(module.gen.jc_layout)["classes"]["DictionaryOwner"][
            "fields"
        ]["values"]["schema"];
        address = eng.get_function_address("copy_sparse_dictionary");
        assert address != 0;
        copy_dictionary = ctypes.PYFUNCTYPE(
            ctypes.py_object, ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
        )(
            address
        );
        result = copy_dictionary(
            schema["key_offset"], schema["data_offset"], schema["order_offset"]
        );
        assert list(result.items()) == [("one", "A"), ("three", "C"), ("five", "E")];
    } finally {
        deactivate_scope_lowering();
    }
}
