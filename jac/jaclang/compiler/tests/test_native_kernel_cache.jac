"""Fresh native builds bypass both layers of the runtime-unit cache."""

import from unittest.mock { patch }
import jaclang.compiler.backends.native.na_compile_pass as native;
import jaclang.compiler.backends.common.kernel_units as units;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

test "alternating kernel targets and compilers retain their own artifacts" {
    import tempfile;
    import from pathlib { Path }
    import jaclang.compiler.driver.jir as jir;
    with tempfile.TemporaryDirectory() as tmp, patch.object(
        units, "_units_dir", return_value=tmp
    ), patch.object(
        jir, "running_compiler_digest", return_value="compiler-a"
    ) as compiler {
        source = str(Path(tmp) / "unit.jac");
        Path(source).write_text("def f -> int { return 1; }\n");
        units.store_unit_artifact(source, "ll", "target-a", "first IR");
        units.store_unit_artifact(source, "ll", "target-b", "second IR");
        assert units.load_unit_artifact(source, "ll", "target-a") == "first IR";
        assert units.load_unit_artifact(source, "ll", "target-b") == "second IR";
        compiler.return_value = "compiler-b";
        assert units.load_unit_artifact(source, "ll", "target-a") is None;
        units.store_unit_artifact(source, "ll", "target-a", "new compiler IR");
        compiler.return_value = "compiler-a";
        assert units.load_unit_artifact(source, "ll", "target-a") == "first IR";
    }
}

test "kernel cache respects compiler identity and explicit fresh compilation" {
    cache: dict[str, str] = {};
    with patch.object(
        native, "native_compiler_fingerprint", return_value="first"
    ) as fingerprint, patch.object(
        units, "load_unit_artifact", return_value="disk IR"
    ) as load, patch.object(units, "store_unit_artifact") as store, patch.object(
        JacProgram, "compile"
    ) as compile {
        compile.return_value.gen.llvm_ir = "fresh IR";
        options = CompileOptions();
        assert native._compile_kernel_unit_ir("unit.jac", cache, options) == "disk IR";
        load.assert_called_once();
        assert native._compile_kernel_unit_ir("unit.jac", cache, options) == "disk IR";
        load.assert_called_once();
        compile.assert_not_called();
        fingerprint.return_value = "second";
        load.return_value = "second compiler IR";
        assert native._compile_kernel_unit_ir("unit.jac", cache, options)
            == "second compiler IR";
        assert load.call_count == 2;
        options.no_ir_cache = True;
        assert native._compile_kernel_unit_ir("unit.jac", cache, options) == "fresh IR";
        assert load.call_count == 2;
        compile.assert_called_once_with("unit.jac", options=options);
        store.assert_called_once_with("unit.jac", "ll", "second", "fresh IR");
    }
}
