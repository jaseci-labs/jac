"""Implementation for treeprinter constructs."""

"""Initialize Symbol Tree Node."""
impl SymbolTree.init(
    self: SymbolTree,
    node_name: str,
    parent: (SymbolTree | None) = None,
    children: (list[SymbolTree] | None) = None
) -> None {
    self.parent = parent;
    self.kid = children if (children is not None) else [];
    self.name = node_name;
}

impl SymbolTree.parent.getter -> (SymbolTree | None) {
    return self.__parent;
}

impl SymbolTree.parent.setter(self: SymbolTree, parent_node: (SymbolTree | None)) {
    if parent_node {
        self.__parent = parent_node;
        parent_node.kid.append(self);
    }
}
