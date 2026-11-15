"""A break whose loop ends an `if` or `else` body has no edge in the statement
graph, so the code after the loop looks unreachable from it. A copy in such a
function must not move: the source is read again after the loop."""

obj Node {
    has v: int = 0;
}

def in_if(flag: bool) -> int {
    a = Node(v=7);
    if flag {
        while True {
            b = a;
            break;
        }
    }
    return a.v;
}

def in_for(flag: bool, xs: list[int]) -> int {
    a = Node(v=8);
    if flag {
        for x in xs {
            b = a;
            break;
        }
    }
    return a.v;
}

def in_else(flag: bool) -> int {
    a = Node(v=9);
    if flag {
        a.v = 1;
    } else {
        while True {
            b = a;
            break;
        }
    }
    return a.v;
}

def before_loops(flag: bool) -> int {
    a = Node(v=5);
    b = a;
    if flag {
        while True {
            break;
        }
    } else {
        while True {
            break;
        }
    }
    return a.v + b.v;
}

with entry {
    print(in_if(True), in_if(False), in_for(True, [1, 2]), in_else(False));
    print(before_loops(True), before_loops(False));
}
