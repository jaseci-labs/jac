"""Initialize JScaleExecutionContext."""

impl JScaleExecutionContext.init(
    self: JScaleExecutionContext,
    session: (str | None) = None,
    <>root: (str | None) = None
) -> None {
    import from jac_scale.memory_hierarchy { ScaleTieredMemory }
    import from jaclang.pycore.constructs { Anchor, NodeAnchor, Root }
    # Pass session to ScaleTieredMemory for proper storage isolation
    self.mem = ScaleTieredMemory(session=session);
    self.reports: list[Any] = [];
    self.custom: Any = MISSING;
    system_root_anchor: (Anchor | None) = self.mem.get(UUID(Con.SUPER_ROOT_UUID));
    if not isinstance(system_root_anchor, NodeAnchor) {
        system_root_anchor = Root().__jac__;
        system_root_anchor.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root_anchor);
    }
    self.system_root = system_root_anchor;
    self.entry_node = self.root_state=self._get_anchor(<>root)
    if <>root
    else self.system_root;
}
