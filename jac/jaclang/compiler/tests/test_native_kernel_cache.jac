"""Fresh native builds bypass both layers of the runtime-unit cache."""

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from unittest.mock { patch }
import jaclang.compiler.backends.native.na_compile_pass as native;
import jaclang.compiler.backends.common.kernel_units as units;
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.session.session { JacProgram }

test "kernel cache respects compiler identity and explicit fresh compilation" {
    cache: dict[str, str] = {};
    import from jaclang.compiler.ir.schema { Module }
    fixture_program = JacProgram();
    output = Module.make_stub(inject_name='cached_kernel');
    fixture_program.analysis.artifacts.output(output).llvm_ir = 'fresh IR';
    with patch.object(
        native, "native_compiler_fingerprint", return_value="first"
    ) as fingerprint, patch.object(
        units, "load_unit_artifact", return_value="disk IR"
    ) as load, patch.object(units, "store_unit_artifact") as store, patch.object(
        JacProgram, "compile", return_value=output
    ) as compile {
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


test "runtime kernel metadata belongs to the requesting compilation session" {
    import from jaclang.compiler.backends.native.na_ir_gen_pass {
        _load_native_osp_kernel_module
    }
    first = JacProgram();
    second = JacProgram();
    a = _load_native_osp_kernel_module(first);
    again = _load_native_osp_kernel_module(first);
    b = _load_native_osp_kernel_module(second);
    assert a is again;
    assert a is not b;
    assert a.mutation_permit is not b.mutation_permit;
    assert not first.errors_had , [str(error) for error in first.errors_had];
    assert not second.errors_had , [str(error) for error in second.errors_had];
    first.release_compile_closure(collect=False);
    assert second.analysis.has_module(b);
}
