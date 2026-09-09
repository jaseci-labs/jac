"""Kernel scope controls inferred compiler dependencies without restricting libraries."""
import os;
import jaclang.compiler.native_scope as policy;

test "inferred compiler dependencies respect the active native scope" {
    compiler_root = os.path.dirname(policy.__file__);
    member = os.path.join(compiler_root, "frontend", "unitree.jac");
    outside = os.path.join(compiler_root, "placement", "placement_solver.jac");
    library = os.path.join(compiler_root, "..", "runtime", "osp_graph.jac");
    assert not policy.scope_lowering_active();
    assert policy.scope_allows_inferred_path(outside);
    checkout_root = os.path.join(
        compiler_root, "..", "..", "scope-checkout", "jaclang", "compiler"
    );
    checkout_entry = os.path.join(checkout_root, "jc_unit.jac");
    policy.activate_scope_lowering(checkout_entry);
    try {
        assert policy.scope_allows_inferred_path(member);
        assert not policy.scope_allows_inferred_path(outside);
        assert not policy.scope_allows_inferred_path(
            os.path.join(
                compiler_root, "frontend", "..", "placement", "placement_solver.jac"
            )
        );
        assert policy.scope_allows_inferred_path(library);
        assert policy.scope_allows_inferred_path(checkout_entry);
        assert not policy.scope_allows_inferred_path(
            os.path.join(checkout_root, "types", "type_evaluator.jac")
        );
    } finally {
        policy.deactivate_scope_lowering();
    }
    assert policy.scope_allows_inferred_path(outside);
}
