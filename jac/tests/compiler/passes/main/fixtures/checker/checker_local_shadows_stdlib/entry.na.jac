"""Imports `Node` and `make_node` from a sibling module named `ast`.

If the modresolver prefers stdlib `ast.pyi` over the local `ast.na.jac`,
both symbols resolve to Unknown and the body's `n.kind` access dissolves
into E1030 / E1001 cascade. Local-file priority keeps the types intact.
"""

import from ast { Node, make_node }

def:pub use_local_ast() -> int {
    n: Node = make_node(7);
    return n.kind;
}

with entry {}
