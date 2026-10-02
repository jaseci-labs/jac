"""A base with fields and methods whose subclasses all live in an importer.

Nothing here subclasses `RotatingNode`. Its own functions still call its
methods through references typed as the base, and those calls must reach
the importer's overrides.
"""

obj RotatingNode {
    has key: int,
        hits: int = 0;

    def weight -> int {
        return self.key;
    }

    def label -> str {
        return f"node {self.key}";
    }

    def touch(n: int) {
        self.hits += n;
    }

    def score -> int {
        return self.weight() * 10 + self.hits;
    }
}

def node_weight(n: &RotatingNode) -> int {
    return n.weight();
}

def node_label(n: &RotatingNode) -> str {
    return n.label();
}

def tree_total(nodes: &list[RotatingNode]) -> int {
    total = 0;
    for n in nodes {
        n.touch(1);
        total += n.weight() + n.score();
    }
    return total;
}
