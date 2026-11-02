import from jaclang.compiler.driver.dependency_graph { dependency_groups }

test "dependency groups preserve cycles and omit unreachable nodes" {
    edges = {
        "root": ["left", "right"],
        "left": ["base", "right"],
        "right": ["left"],
        "base": [],
        "unused": ["missing"]
    };
    assert dependency_groups(edges, ["root"])
        == [["base"], ["left", "right"], ["root"]];
    assert dependency_groups({"self": ["self"]}, ["self"]) == [["self"]];
}

test "deep dependency chains do not depend on the interpreter recursion limit" {
    edges: dict[str, list[str]] = {};
    for i in range(2000) {
        edges[str(i)] = [str(i + 1)];
    }
    groups = dependency_groups(edges, ["0"]);
    assert len(groups) == 2001;
    assert groups[0] == ["2000"];
    assert groups[-1] == ["0"];
}
