"""Fresh native builds bypass both layers of the runtime-unit cache."""

import from unittest.mock { patch }
import jaclang.compiler.backends.native.na_compile_pass as native;
import jaclang.compiler.backends.common.kernel_units as units;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

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
