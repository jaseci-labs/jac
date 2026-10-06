import from jaclang.compiler.frontend.diagnostics { E9002 }

impl NativeLowering._require_trace_fn(
    type_name: str, participates: bool, has_trace: bool
) -> None {
    if self._gc_mode() != "cycles" {
        return;
    }
    if participates and not has_trace {
        self.emit(
            E9002,
            node_override=self.module,
            details=(
                f"type '{type_name}' has managed reference fields but no cycle "
                f"trace function; it cannot safely participate in cycle "
                f"collection (a cycle through it would leak). This is a native "
                f"code-generation invariant violation."
            )
        );
    }
}
