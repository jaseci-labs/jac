"""Compiler materialization retains declared field semantics across LLVM pointer erasure."""

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import json;
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.bootstrap.native_scope {
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
        layout = artifact_for(module).jc_layout;
        assert layout is not None;
        classes = json.loads(layout)["classes"];
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
    import os;
    import sys;
    import tempfile;
    import from tests.support { NATIVE_FIXTURES }
    import from jaclang.cli.commands.native_build { native_build }
    activate_scope_lowering();
    try {
        with tempfile.TemporaryDirectory() as directory {
            suffix = ".dylib" if sys.platform == "darwin" else ".so";
            output = os.path.join(directory, "dict_materialization" + suffix);
            source = os.path.join(NATIVE_FIXTURES, "dict_materialization.jac");
            assert native_build(source, output=output, lib=True) == 0;
            with open(output + ".layout.json") as layout_file {
                fields = json.load(layout_file)["classes"]["DictionaryOwner"]["fields"];
                schema = fields["values"]["schema"];
            }
            library = ctypes.PyDLL(output);
            copy_dictionary = library.copy_sparse_dictionary;
            copy_dictionary.restype = ctypes.py_object;
            copy_dictionary.argtypes = [ctypes.c_int64, ctypes.c_int64, ctypes.c_int64];
            result = copy_dictionary(
                schema["key_offset"], schema["data_offset"], schema["order_offset"]
            );
            assert list(result.items())
                == [("one", "A"), ("three", "C"), ("five", "E")];
            object_schema = fields["children"]["schema"];
            enqueue_dictionary = library.enqueue_sparse_dictionary;
            enqueue_dictionary.restype = ctypes.c_int64;
            enqueue_dictionary.argtypes = [
                ctypes.c_int64,
                ctypes.c_int64,
                ctypes.c_int64
            ];
            assert enqueue_dictionary(
                object_schema["key_offset"],
                object_schema["data_offset"],
                object_schema["order_offset"]
            )
                == 1;
        }
    } finally {
        deactivate_scope_lowering();
    }
}
