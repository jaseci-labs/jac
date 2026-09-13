"""Native dependency cache keys include implementation annexes."""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.na_compile_pass { native_dep_cache_paths }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "editing an implementation invalidates its native dependency artifact" {
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "library.jac";
        annex = Path(directory) / "library.impl.jac";
        source.write_text("def value -> int;\n");
        annex.write_text("impl value -> int { return 1; }\n");
        options = CompileOptions(aot_mode=True, default_codespace="native");
        before = native_dep_cache_paths(os.path.realpath(str(source)), options);
        annex.write_text("impl value -> int { return 2; }\n");
        after = native_dep_cache_paths(os.path.realpath(str(source)), options);
        assert before != after;
    }
}

test "native dependency artifacts follow the running compiler identity" {
    import from unittest.mock { patch }
    import jaclang.compiler.driver.jir as jir;
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "library.jac";
        source.write_text("def value -> int { return 1; }\n");
        options = CompileOptions(aot_mode=True, default_codespace="native");
        with patch.object(jir, "running_compiler_digest", return_value="first") {
            first = native_dep_cache_paths(str(source), options);
            assert native_dep_cache_paths(str(source), options) == first;
        }
        with patch.object(jir, "running_compiler_digest", return_value="second") {
            assert native_dep_cache_paths(str(source), options) != first;
        }
    }
}

test "native imports link through a source directory alias at a different depth" {
    import ctypes;
    import from jaclang.compiler.driver.program { JacProgram }
    with tempfile.TemporaryDirectory() as directory {
        base = Path(directory).resolve();
        actual = base / "actual" / "nested" / "app";
        actual.mkdir(parents=True);
        alias = base / "alias";
        alias.symlink_to(actual, target_is_directory=True);
        (actual / "helper.jac").write_text("def value -> int { return 42; }\n");
        (actual / "main.jac").write_text(
            "import from .helper { value }\ndef answer -> int { return value(); }\n"
        );
        program = JacProgram();
        module = program.compile(
            str(alias / "main.jac"),
            options=CompileOptions(default_codespace="native", no_ir_cache=True)
        );
        assert not program.errors_had , [str(e) for e in program.errors_had];
        assert module is not None;
        engine = module.gen.native_engine;
        assert engine is not None;
        address = engine.get_function_address("answer");
        assert address != 0;
        call: any = ctypes.CFUNCTYPE(ctypes.c_int64)(address);
        assert call() == 42;
    }
}
