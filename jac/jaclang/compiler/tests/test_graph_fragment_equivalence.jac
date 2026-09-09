"""Graph construction must compile and run on every backend."""
import from jaclang.compiler.tests.xbackend_equiv {
    run_with_both,
    run_py_fixture,
    run_js_module_fixture
}

test "client module fixtures run through symlinked directories" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    with TemporaryDirectory() as directory {
        base = Path(directory).resolve();
        actual = base / "actual";
        actual.mkdir();
        alias = base / "alias";
        alias.symlink_to(actual, target_is_directory=True);
        (actual / "jac.toml").write_text(
            '[placement.pins]\n"fixture.result" = "client"\n'
        );
        (actual / "fixture.jac").write_text(
            'def result -> dict[str, int] { return {"value": 42}; }'
        );
        assert run_js_module_fixture(str(alias / "fixture.jac"), "result")
            == {"value": 42};
    }
}

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
