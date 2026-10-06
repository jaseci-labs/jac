"""Overrides declared in an importer, reached through base-typed references.

`RotatingNode` is laid out by its own module, which sees no subclass of it.
`ProfilerEntry` and `ProfilerSubEntry` override its methods here. A call
through a reference typed as `RotatingNode` -- in the base's own functions,
in its own `score` calling `self.weight()`, or here -- must run the
override, exactly as the Python backend does.
"""

import from xmod_override_base { RotatingNode, node_weight, node_label, tree_total }

obj ProfilerEntry(RotatingNode) {
    has callcount: int = 0;

    def weight -> int {
        return self.key * 100 + self.callcount;
    }

    def label -> str {
        return f"entry {self.key} calls={self.callcount}";
    }
}

obj ProfilerSubEntry(RotatingNode) {
    has recursive: int = 0;

    def weight -> int {
        return self.key + self.recursive;
    }

    def touch(n: int) {
        self.hits += n * 2;
    }
}

def local_weight(n: &RotatingNode) -> int {
    return n.weight();
}

with entry {
    nodes: list[RotatingNode] = [
        ProfilerEntry(key=5, callcount=2),
        ProfilerSubEntry(key=7, recursive=4),
        RotatingNode(key=9)
    ];
    for n in nodes {
        print(
            "node",
            node_weight(n),
            local_weight(n),
            n.weight(),
            node_label(n),
            n.score()
        );
    }
    print("total", tree_total(nodes));
    for n in nodes {
        print("hits", n.key, n.hits, isinstance(n, ProfilerEntry));
    }
}
