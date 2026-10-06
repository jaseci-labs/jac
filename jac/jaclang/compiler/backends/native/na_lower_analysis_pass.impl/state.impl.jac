impl NativeLowering.emit(
    diag: DiagnosticInfo,
    node_override: (uni.UniNode | None) = None,
    related: (list[tuple[str, uni.UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: any
) -> bool {
    saved = self.ctx.policy;
    self.ctx.policy = None;
    try {
        return self.ctx.emit(
            diag,
            node_override=node_override,
            related=related,
            help_text=help_text,
            **kwargs
        );
    } finally {
        self.ctx.policy = saved;
    }
}
