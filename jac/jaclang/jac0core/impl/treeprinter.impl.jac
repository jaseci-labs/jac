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
