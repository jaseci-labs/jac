"""Local module deliberately named `ast` to shadow Python's stdlib.

The type checker's modresolver must prefer this local file over
`vendor/typeshed/stdlib/ast.pyi` when resolving `import from ast`
from `entry.na.jac` in the same directory.
"""

obj:pub Node {
    has kind: int = 0;
}

def:pub make_node(kind: int) -> Node {
    n = Node();
    n.kind = kind;
    return n;
}
