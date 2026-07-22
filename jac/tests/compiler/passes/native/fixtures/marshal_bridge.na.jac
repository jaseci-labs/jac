"""Test fixture for marshal bridge identity, cycle, and container coverage."""

obj Child {
    has val: int;
}

obj Pair {
    has left: Child,
        right: Child;
}

obj Node {
    has val: int,
        nxt: (Node | None) = None;
}

def make_shared -> Pair {
    c = Child(val=7);
    return Pair(left=c, right=c);
}

def make_cycle -> Node {
    a = Node(val=1);
    b = Node(val=2);
    a.nxt = b;
    b.nxt = a;
    return a;
}

def make_child -> Child {
    return Child(val=5);
}

def child_val(c: Child) -> int {
    return c.val;
}

def make_list(n: int) -> list[int] {
    result: list[int] = [];
    i = 0;
    while i < n {
        result.append(i * 2);
        i = i + 1;
    }
    return result;
}

def sum_list(xs: list[int]) -> int {
    total = 0;
    for x in xs {
        total = total + x;
    }
    return total;
}

def make_strlist -> list[str] {
    return ["x", "yy"];
}

def make_map -> dict[int, int] {
    return {1: 10, 2: 20};
}

def make_strmap -> dict[str, int] {
    return {"a": 1, "b": 2};
}

def make_set -> set[int] {
    return {1, 2, 3};
}

with entry {
    x = 0;
}
