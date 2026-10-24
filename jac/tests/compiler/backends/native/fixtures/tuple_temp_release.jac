"""Index a tuple a call returns at once, millions of times.

`obj` returns a tuple holding a fresh object, `str` one holding a fresh
string; each step reads the int field and drops the tuple.
"""
import sys;

obj Node {
    has v: int = 0;
}

def pair(n: int) -> tuple[Node, int] {
    return (Node(v=n), n);
}

def label(n: int) -> tuple[str, int] {
    return (str(n), n * 2);
}

glob mode = sys.argv[1];
with entry {
    steps = int(sys.argv[2]);
    total = 0;
    if mode == "obj" {
        for i in range(steps) {
            total += pair(i)[1];
        }
    } else {
        for i in range(steps) {
            total += label(i)[1];
        }
    }
    print(total);
}
