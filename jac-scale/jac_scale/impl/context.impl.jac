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
    import from jaclang.jac0core.runtime { plugin_manager, JacRuntimeInterface }
    # Phase-2 seal: JScaleExecutionContext.init overrides core
    # ExecutionContext.postinit (where the seal otherwise fires), so trigger
    # it here too. Idempotent, so the first request seals and the rest no-op.
    # The plugin set is fully loaded at request time, so devirtualization is
    # safe (jac-scale's multi-impl hooks stay on the dynamic dispatcher).
    plugin_manager.seal(JacRuntimeInterface);
    # ScaleTieredMemory gets storage config from environment variables
    self.mem = ScaleTieredMemory();
    self.reports: list[any] = [];
    self.diagnostics: list[PermissionDenied] = [];
    self.pending_effects = [];
    self.read_versions = {};
    self.custom: any = MISSING;
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
