"""OSP target models must not reuse another codespace's archetype inventory."""
import from jaclang.compiler.analysis.binding.osp_model { prepare_osp_model }
import from jaclang.compiler.backends.common.artifact_store { artifact_scope }
import from jaclang.compiler.ir.enums { CodeContext }
import from jaclang.compiler.ir.schema { Archetype }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.session.session { JacProgram }

test "native and client OSP inventories remain independent in one module" {
    program = JacProgram();
    module = program.compile(
        use_str="node NativeNode {} node ClientNode {}",
        file_path="osp_target_models.jac",
        options=CompileOptions(no_cgen=True, no_ir_cache=True)
    );
    assert not program.errors_had;
    declarations = module.get_all_sub_nodes(Archetype);
    with artifact_scope(program.analysis.artifacts) {
        native_model = prepare_osp_model(module, [declarations[0]], CodeContext.NATIVE);
        client_model = prepare_osp_model(module, [declarations[1]]);
        assert set(native_model.tags) == {"NativeNode"};
        assert set(client_model.tags) == {"ClientNode"};
        assert prepare_osp_model(module, context=CodeContext.NATIVE) is native_model;
        assert prepare_osp_model(module) is client_model;
    }
}
