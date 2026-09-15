import from tests.compiler.fixtures.osp_execution { run }

def select(items: list, filter_type: type) -> list {
    return items[?:filter_type];
}

def chained(items: list) -> list {
    return items[?:int][?:int];
}

test "object spatial execution preserves traversal and edge semantics" {
    assert run()
        == (
            6,
            ["enter:top", "enter:a", "enter:b", "exit:b", "exit:a", "exit:top", "done"],
            2,
            1,
            2,
            2,
            1
        );
}

test "type filters preserve order and chained filtering" {
    assert select([1, "x", 2, "y"], str) == ["x", "y"];
    assert chained([1, "x", 2]) == [1, 2];
}
