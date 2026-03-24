"""Test that @property resolves to return type on union types.

Mirrors the real bug in sym_tab_build_pass.impl.jac where:
    if isinstance(i, (uni.ListVal, uni.TupleVal)) {
        self._def_insert_unpacking(i, i.sym_tab);
    }
produces E1053 because `i.sym_tab` on the union `ListVal | TupleVal`
returns `<function sym_tab() -> UniScopeNode>` instead of `UniScopeNode`.

Uses unitree types directly to exercise the union property lookup path.
"""

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
