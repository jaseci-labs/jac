impl JScaleExecutionContext.init(self: JScaleExecutionContext) -> None {
    import os;
    import from jaclang.jac0core.constructs {
        Anchor,
        NodeAnchor,
        PermissionDenied,
        Root
    }
    import from jaclang.jac0core.runtime { JacRuntime }
    import from jaclang.runtimelib.session {
        Session,
        conninfo_from_url,
        promotions_for
    }
    import from jaclang.scale.persistence.pg { scale_db_url }

    base = JacRuntime.get_base_path_dir();
    target = JacRuntime.get_full_target_path();
    url = scale_db_url();
    if url and not os.environ.get('JAC_DB_URL') {
        import from jaclang.runtimelib.store { PgStore }
        store = PgStore(conninfo=conninfo_from_url(url));
        store.ensure_schema(promotions_for(base));
        self.mem = Session(store=store, base_path=base, target_path=target);
    } else {
        self.mem = Session(base_path=base, target_path=target);
    }
    self.reports: list[any] = [];
    self.diagnostics: list[PermissionDenied] = [];
    self.pending_effects = [];
    self.read_versions = {};
    self.custom: any = MISSING;
    system_root_anchor: (Anchor | None) = self.mem.get(UUID(Con.SUPER_ROOT_UUID));
    if not isinstance(system_root_anchor, NodeAnchor) {
        system_root_anchor = Root().__jac__;
        system_root_anchor.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root_anchor);
    }
    self.system_root = system_root_anchor;

    self.user_root = self.system_root;
    self.entry_node = self.system_root;
    self.call_state: ContextVar[CallState] = ContextVar('call_state');
}
