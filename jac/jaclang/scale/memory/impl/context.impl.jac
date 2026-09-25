impl JScaleExecutionContext.init(self: JScaleExecutionContext) -> None {
    import os;

    base = JacRuntime.get_base_path_dir();
    target = JacRuntime.get_full_target_path();
    url = scale_db_url() or "";
    if url and not os.environ.get('JAC_DB_URL') {
        import from jaclang.data.store { PgStore }
        store = PgStore(
            conninfo=conninfo_from_url(url),
            promotions=promotions_for(base),
            auto_schema=True
        );
        self.mem = Session(_store=store, base_path=base, target_path=target);
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
