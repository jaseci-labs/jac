"""Tests for assignment-based type narrowing."""

def add_one(x: int) -> int {
    return x + 1;
}

def test_assignment_narrows_union(a: int | None) -> int {
    a = 90;
    return add_one(a);  # Ok

}

def test_multiple_reassignments(x: int | None) -> int {
    x = 1;
    x = 2;
    return add_one(x);  # Ok

}

def test_no_widen_list -> int {
    l: list[int] = [];
    for i in l {
        x: int = i;  # Ok
    }
    return 0;
}

obj Node {}
obj Token(Node) {}
obj Statement(Node) {}

def test_contextual_list_in_branch(flag: bool) {
    if flag {
        nodes: list[Node] = [Token()];
        statements: list[Statement] = [Statement()];
        nodes.extend(statements);
        nodes.append(Statement());
    }
}

def test_contextual_list_reassignment(flag: bool) {
    nodes: list[Node] = [];
    if flag {
        nodes = [Token()];
        nodes.extend([Statement()]);
    }
}
