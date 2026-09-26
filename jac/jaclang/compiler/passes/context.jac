import from jaclang.compiler.frontend.srcloc { CodeLocInfo, Span }
import from jaclang.compiler.frontend.diagnostics {
    DiagnosticInfo,
    E9001,
    LINT_ALIASES,
    Severity
}
import from jaclang.compiler.frontend.diagnostic_utils { resolve_diagnostic_tokens }
import from jaclang.compiler.frontend.unitree { Module, Source, TreeWalker, UniNode }
import from jaclang.compiler.driver.compile_options { CancelToken }
import type from jaclang.compiler.driver.program { JacProgram }

obj Alert {
    has msg: str,
        loc: Span,
        from_pass: type,
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

glob INLINE_LOCKED_CODES: set[str] = {"E1144", "E2090", "E2091", "E2094"};

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

obj CompileContext {
    has current_node: UniNode,
        from_pass: type,
        pass_name: str,
        cancel_token: (CancelToken | None) = None,
        cancel_requested: bool = False,
        errors_had: list[Alert] = [],
        warnings_had: list[Alert] = [],
        time_taken: float = 0.0,
        nested_depth: int = 0,
        policy: (DiagnosticPolicy | None) = None,
        program: (JacProgram | None) = None;

    def emit(
        diag: DiagnosticInfo,
        node_override: (UniNode | None) = None,
        related: (list[tuple[str, UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: object
    ) -> bool;

    def _is_suppressed(diag: DiagnosticInfo, loc: CodeLocInfo | None = None) -> bool;
    def ice(msg: str = 'Something went horribly wrong!') -> str;
    def log_info(msg: str) -> None;
    def walk_subtree(nd: UniNode, walk: Walker) -> None;
    def enter_node(nd: UniNode) -> None;
    def exit_node(nd: UniNode) -> None;
    def is_canceled -> bool {
        return self.cancel_requested;
    }
}

walker CompilerPass {
    has ctx: CompileContext,
        module: Module;

    has prog: JacProgram { getter; }

    def release {}
}

type PassSchedule = list[type[CompilerPass]];

walker TreePass(CompilerPass, TreeWalker) {
    can enter_walk with UniNode entry {
        self.ctx.enter_node(here);
    }

    can exit_walk with UniNode exit {
        self.ctx.exit_node(here);
    }
}
