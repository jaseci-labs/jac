"""Initialize JScaleExecutionContext.

Storage backend is configured via environment variables (e.g., MONGODB_URI),
not per-context parameters.
"""

impl JScaleExecutionContext.init(self: JScaleExecutionContext) -> None {
    import from jac_scale.memory_hierarchy { ScaleTieredMemory }
    import from jaclang.jac0core.constructs { Anchor, NodeAnchor, Root }
    # ScaleTieredMemory gets storage config from environment variables
    self.mem = ScaleTieredMemory();
    self.reports: list[Any] = [];
    self.custom: Any = MISSING;
    system_root_anchor: (Anchor | None) = self.mem.get(UUID(Con.SUPER_ROOT_UUID));
    if not isinstance(system_root_anchor, NodeAnchor) {
        system_root_anchor = Root().__jac__;
        system_root_anchor.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root_anchor);
    } else {
        # Clean up any stale edges from previous runs
        self._cleanup_stale_edges(system_root_anchor);
    }
    self.system_root = system_root_anchor;
    # Default user_root and entry_node to system_root
    self.user_root = self.system_root;
    self.entry_node = self.system_root;
    self.call_state: ContextVar[CallState] = ContextVar('call_state');
}

"""Remove stale edges that point to invalid anchors."""
impl JScaleExecutionContext._cleanup_stale_edges(
    self: JScaleExecutionContext, node_anchor: NodeAnchor
) -> None {
    if not node_anchor.edges {
        return;
    }
    valid_edges = [];
    found_stale = False;
    for edge in node_anchor.edges {
        try {
            # Access target.id from __dict__ to avoid triggering populate() during init
            # This prevents recursion when context is not fully initialized yet
            target_obj = edge.__dict__.get('target');
            if target_obj {
                target_id = target_obj.__dict__.get('id');
                if target_id and self.mem.has(target_id) {
                    valid_edges.append(edge);
                } else {
                    found_stale = True;
                }
            } else {
                found_stale = True;
            }
        } except (AttributeError, TypeError) {
            found_stale = True;
        }
    }
    if found_stale {
        node_anchor.edges = valid_edges;
    }
}
