"""Kernel scope controls inferred compiler dependencies without restricting libraries."""
import os;
import jaclang.compiler.bootstrap.native_scope as policy;

test "inferred compiler dependencies respect the active native scope" {
    compiler_root = os.path.dirname(os.path.dirname(policy.__file__));
    member = os.path.join(compiler_root, "ir", "syntax", "nodes.jac");
    outside = os.path.join(compiler_root, "analysis", "placement", "solver.jac");
    library = os.path.join(compiler_root, "..", "runtime", "osp_graph.jac");
    assert not policy.scope_lowering_active();
    assert policy.scope_allows_inferred_path(outside);
    checkout_root = os.path.join(
        compiler_root, "..", "..", "scope-checkout", "jaclang", "compiler"
    );
    checkout_entry = os.path.join(checkout_root, "frontend", "kernel", "unit.jac");
    policy.activate_scope_lowering(checkout_entry);
    try {
        assert policy.scope_allows_inferred_path(member);
        assert not policy.scope_allows_inferred_path(outside);
        assert not policy.scope_allows_inferred_path(
            os.path.join(
                compiler_root, "frontend", "..", "analysis", "placement", "solver.jac"
            )
        );
        assert policy.scope_allows_inferred_path(library);
        assert policy.scope_allows_inferred_path(checkout_entry);
        assert not policy.scope_allows_inferred_path(
            os.path.join(checkout_root, "analysis", "types", "type_evaluator.jac")
        );
    } finally {
        policy.deactivate_scope_lowering();
    }
    assert policy.scope_allows_inferred_path(outside);
}

test "explicit native compilation applies in the bootstrap context" {
    import from unittest.mock { patch }
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.session.options { CompileOptions }
    import from jaclang.compiler.ir.enums { CodeContext }
    program = JacProgram();
    with patch.object(JacProgram, 'is_bootstrap', return_value=True) {
        module = program.compile(
            '/tmp/bootstrap-native-request.jac',
            use_str='def answer -> int { return 42; }',
            options=CompileOptions(
                symtab_ir_only=True,
                no_cgen=True,
                aot_mode=True,
                default_codespace='native',
                force_target_program=True
            )
        );
    }
    assert not program.errors_had;
    assert module.declares_codespace(CodeContext.NATIVE);
}
