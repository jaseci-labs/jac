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

glob INLINE_LOCKED_CODES: set[str] = {
         "E1144",
         "E1146",
         "E2090",
         "E2091",
         "E2094",
         "E2099"
     };

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
    def is_canceled -> bool;
}

walker CompilerPass {
    static has contract: (PassContract | None) = None;
    has ctx: CompileContext,
        module: Module;

    has prog: JacProgram { getter; }

    def release;
}

type PassSchedule = list[type[CompilerPass]];

walker TreePass(CompilerPass, TreeWalker) {
    has _decl_bodies: list[ImplDef] = [];

    can enter_walk with UniNode entry;
    can exit_walk with UniNode exit;
    def walk_decl_body(decl: UniNode) -> None;
    def reached_by_syntax(nd: UniNode) -> bool;
}
