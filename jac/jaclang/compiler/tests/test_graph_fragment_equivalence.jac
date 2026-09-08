"""Graph construction must compile and run on every backend."""
import from jaclang.compiler.tests.xbackend_equiv { run_with_both, run_py_fixture }

test "graph construction shares topology and fragment semantics" {
    assert run_py_fixture("osp_graph_fragment", "fragment_py")
        == {
            "root": 1,
            "nodes": 4,
            "edges": 4,
            "weight": 18,
            "tips": 1,
            "a_degree": 1,
            "b_degree": 1,
            "c_degree": 1,
            "nested_nodes": 3,
            "nested_edges": 2,
            "computed_nodes": 5,
            "computed_edges": 4,
            "branch_nodes": 3,
            "branch_edges": 2,
            "projected_value": 99,
            "projected_degree": 1
        };
    run_with_both(
        "osp_graph_fragment.jac",
        "fragment_py",
        "fragment_cl",
        "fragment_na",
        require=["na", "cl"],
        client_modules=True
    );
}
