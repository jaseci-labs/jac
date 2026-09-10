"""Kernel scope controls inferred compiler dependencies without restricting libraries."""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.frontend.codeinfo {
    native_unit_compile_active,
    set_native_unit_compile,
    reset_native_unit_compile
}
import jaclang.compiler.native_scope as policy;

test "inferred compiler dependencies respect the active native scope" {
    compiler_root = os.path.dirname(policy.__file__);
    member = os.path.join(compiler_root, "frontend", "unitree.jac");
    outside = os.path.join(compiler_root, "placement", "placement_solver.jac");
    library = os.path.join(compiler_root, "..", "runtime", "osp_graph.jac");
    assert not native_unit_compile_active();
    assert policy.scope_allows_inferred_path(outside);
    checkout = tempfile.TemporaryDirectory();
    checkout_root = os.path.join(checkout.name, "jaclang", "compiler");
    Path(checkout_root).mkdir(parents=True);
    Path(os.path.join(checkout.name, "jaclang", "jac.toml")).write_text("");
    checkout_entry = os.path.join(checkout_root, "jc_unit.jac");
    previous = set_native_unit_compile(True);
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
        reset_native_unit_compile(previous);
        checkout.cleanup();
    }
    assert policy.scope_allows_inferred_path(outside);
}
