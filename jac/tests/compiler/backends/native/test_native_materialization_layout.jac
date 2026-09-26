"""Compiler materialization retains declared field semantics across LLVM pointer erasure."""

import json;
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
            use_str="import ast; obj Parent { has name: str; } obj Child(Parent) { has file_path: str; has foreign: ast.AST | None = None; has tags: set[str] = set(); } def make -> Child { return Child(name=\"name\", file_path=\"file.jac\"); }",
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
        tags = classes["Child"].fields["tags"];
        assert tags.code == "natset";
        assert tags.schema is not None;
        assert tags.schema.to_dict()["code"] == "set";
        assert tags.schema.to_dict()["element"] == {"code": "str"};
    } finally {
        reset_native_unit_compile(previous);
    }
}

test "materialization skips deleted native hash entries and preserves dictionary order" {
    import ctypes;
    import os;
    import sys;
    import tempfile;
    import from tests.support { NATIVE_FIXTURES }
    import from jaclang.cli.commands.native_build { native_build }
    previous = set_native_unit_compile(True);
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
            set_schema = fields["names"]["schema"];
            copy_set = library.copy_sparse_set;
            copy_set.restype = ctypes.py_object;
            copy_set.argtypes = [ctypes.c_int64, ctypes.c_int64];
            copied = copy_set(set_schema["key_offset"], set_schema["order_offset"]);
            assert isinstance(copied, set);
            assert copied == {"one", "three", "four"};
        }
    } finally {
        reset_native_unit_compile(previous);
    }
}
