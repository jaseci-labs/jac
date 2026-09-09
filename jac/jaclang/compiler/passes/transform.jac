import time;
import from jaclang.compiler.frontend.srcloc { CodeLocInfo, Span }
import from jaclang.compiler.frontend.diagnostics {
    DiagnosticInfo,
    E9001,
    LINT_ALIASES,
    Severity
}
import from jaclang.compiler.frontend.diagnostic_utils { resolve_diagnostic_tokens }
import from jaclang.compiler.frontend.unitree { Source, UniNode }

obj Alert {
    has msg: str,
        loc: Span,
        from_pass: type[Transform],
        code: DiagnosticInfo | None = None,
        related: list[tuple[str, Span]] = [],
        help_text: str | None = None,
        owner: str = '';

    def postinit -> None;
    def __str__ -> str;
    def __repr__ -> str;
    def as_log(*, colors: bool = False) -> str;
    def pretty_print(*, colors: bool = False) -> str;
}

obj DiagnosticPolicy {
    has suppress_codes: list[str] = [],
        suppress_categories: list[str] = [],
        lint_active: bool = False,
        lint_select: list[str] = [],
        lint_ignore: list[str] = [],
        _inline_cache: dict[(tuple[str, int], list[str])] = {};

    def is_suppressed(
        diag: DiagnosticInfo,
        loc: (CodeLocInfo | Span | None) = None,
        source: (Source | None) = None
    ) -> bool;

    def _inline_suppressed(
        diag: DiagnosticInfo, loc: (CodeLocInfo | Span), source: (Source | None) = None
    ) -> bool;
}

obj PassResult {
    has errors_had: list[Alert] = [],
        warnings_had: list[Alert] = [],
        time_taken: float = 0.0;
}

walker BaseTransform {
    has ir_in: UniNode,
        cancel_token: any = None,
        cancel_requested: bool = False,
        errors_had: list[Alert] = [],
        warnings_had: list[Alert] = [],
        time_taken: float = 0.0,
        ir_out: UniNode postinit,
        completed: (PassResult | None) = None;

    def postinit -> None;
    def timed_transform(ir_in: UniNode) -> UniNode {
        start_time = time.time();
        ir_out = self.transform(ir_in=ir_in);
        self.time_taken = time.time() - start_time;
        return ir_out;
    }

    def pre_transform -> None;
    def post_transform -> None;
    def transform(ir_in: UniNode) -> UniNode {
        return ir_in;
    }

    def log_info(msg: str) -> None;
    def is_canceled -> bool;
}

walker Transform(BaseTransform) {
    has cur_node: UniNode postinit,
        policy: (DiagnosticPolicy | None) = None;

    static has PROVIDES: tuple = (),
        REQUIRES: tuple = (),
        HOST_PASS: bool = False;

    def postinit -> None;
    def emit(
        diag: DiagnosticInfo,
        node_override: (UniNode | None) = None,
        related: (list[tuple[str, UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: object
    ) -> bool;

    def _is_suppressed(diag: DiagnosticInfo, loc: CodeLocInfo | None = None) -> bool;
    def ice(msg: str = 'Something went horribly wrong!') -> str;
}
