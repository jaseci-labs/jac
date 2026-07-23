"""Detach a copy of the shared super root so contexts never share one anchor."""
def _independent_super_root(template: any) -> any {
    import from jaclang.jac0core.constructs { NodeAnchor }
    import from jaclang.runtimelib.serializer { Serializer }
    if not isinstance(template, NodeAnchor) {
        return None;
    }
    copy = Serializer.deserialize(Serializer.serialize(template, include_type=True));
    return copy if isinstance(copy, NodeAnchor) else None;
}

impl JScaleExecutionContext.init(self: JScaleExecutionContext) -> None {
    import from jaclang.scale.memory.memory_hierarchy {
        ScaleTieredMemory,
        _process_cache,
        _publish_super_root_template
    }
    import from jaclang.jac0core.constructs { NodeAnchor, PermissionDenied, Root }

    self.mem = ScaleTieredMemory();
    self.reports: list[any] = [];
    self.diagnostics: list[PermissionDenied] = [];
    self.pending_effects = [];
    self.read_versions = {};
    self.custom: any = MISSING;

    # Per-request super root copy; a shared mutable anchor corrupts CAS tracking.
    system_root_anchor = _independent_super_root(_process_cache.get('system_root'));
    if system_root_anchor is not None {
        self.mem.__mem__[system_root_anchor.id] = system_root_anchor;
    } else {
        fetched = self.mem.get(UUID(Con.SUPER_ROOT_UUID));
        if isinstance(fetched, NodeAnchor) {
            system_root_anchor = fetched;
        } else {
            system_root_anchor = Root().__jac__;
            system_root_anchor.id = UUID(Con.SUPER_ROOT_UUID);
            self.mem.put(system_root_anchor);
        }
        # Warm template is a detached snapshot, never this request's live anchor.
        _publish_super_root_template(_independent_super_root(system_root_anchor));
    }

    self.system_root = system_root_anchor;
    self.user_root = self.system_root;
    self.entry_node = self.system_root;
    self.call_state: ContextVar[CallState] = ContextVar('call_state');
}
