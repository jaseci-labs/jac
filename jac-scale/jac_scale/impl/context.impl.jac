"""Initialize JScaleExecutionContext.

Storage backend is configured via environment variables (e.g., MONGODB_URI),
not per-context parameters.
"""

impl JScaleExecutionContext.init(self: JScaleExecutionContext) -> None {
    import from jac_scale.memory_hierarchy { ScaleTieredMemory, _process_cache }
    import from jaclang.jac0core.constructs {
        Anchor,
        NodeAnchor,
        PermissionDenied,
        Root
    }
    # ScaleTieredMemory gets storage config from environment variables
    self.mem = ScaleTieredMemory();
    self.reports: list[Any] = [];
    self.diagnostics: list[PermissionDenied] = [];
    self.custom: Any = MISSING;
    cached_root = _process_cache.get('system_root');
    if cached_root is not None {
        self.mem.__mem__[cached_root.id] = cached_root;
    }
    system_root_anchor: (Anchor | None) = self.mem.get(UUID(Con.SUPER_ROOT_UUID));
    if not isinstance(system_root_anchor, NodeAnchor) {
        system_root_anchor = Root().__jac__;
        system_root_anchor.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root_anchor);
    }
    _process_cache['system_root'] = system_root_anchor;
    self.system_root = system_root_anchor;
    # Default user_root and entry_node to system_root
    self.user_root = self.system_root;
    self.entry_node = self.system_root;
    self.call_state: ContextVar[CallState] = ContextVar('call_state');
}
