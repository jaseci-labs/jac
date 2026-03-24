"""Test that @property resolves to return type on union types."""

import jaclang.jac0core.unitree as uni;

def use_scope(scope: uni.UniScopeNode) -> None {}

with entry {
    # Single type - property works (Path A)
    nodes: list[uni.ListVal] = [];
    for node in nodes {
        use_scope(node.sym_tab);
    }

    # Union type - property must also work (Path B)
    items: list[uni.AstSymbolNode] = [];
    for i in items {
        if isinstance(i, (uni.ListVal, uni.TupleVal)) {
            use_scope(i.sym_tab);
        }
    }
}
