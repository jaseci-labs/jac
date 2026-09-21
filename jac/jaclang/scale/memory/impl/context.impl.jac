impl JScaleExecutionContext.init(
    self: JScaleExecutionContext,
    base_path_dir: str | None = None,
    full_target_path: str | None = None
) -> None {
    import os;
    import from jaclang.runtime.constructs { PermissionDenied }
    import from jaclang.runtime.runtime { JacRuntime }
    import from jaclang.server.session { Session, conninfo_from_url, promotions_for }
    import from jaclang.server.shared_store { scale_db_url }

    base = base_path_dir
        if base_path_dir is not None
        else JacRuntime.get_base_path_dir();
    target = full_target_path
        if full_target_path is not None
        else JacRuntime.get_full_target_path();
    self.base_path_dir = base;
    self.full_target_path = target;
    url = scale_db_url() or "";
    if url and not os.environ.get('JAC_DB_URL') {
        import from jaclang.data.store { PgStore }
        store = PgStore(
            conninfo=conninfo_from_url(url),
            promotions=promotions_for(base),
            auto_schema=True
        );
        self.mem = Session(store=store, base_path=base, target_path=target);
    } else {
        self.mem = Session(base_path=base, target_path=target);
    }
    self.reports: list[any] = [];
    self.diagnostics: list[PermissionDenied] = [];
    self.pending_effects = [];
    self.read_versions = {};
    self.custom: any = MISSING;
    self.call_state: ContextVar[CallState] = ContextVar('call_state');
}
