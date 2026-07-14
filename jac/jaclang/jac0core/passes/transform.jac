import time;
import from abc { ABC, abstractmethod }
import from dataclasses { field }
import from threading { Event }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.diagnostics { DiagnosticInfo, Severity, E9001 }
import from jaclang.jac0core.log { logging }
import from jaclang.jac0core.unitree { UniNode }
import type from jaclang.jac0core.program { JacProgram }

obj Alert {
    has msg: str,
        loc: CodeLocInfo,
        from_pass: type[Transform],
        code: DiagnosticInfo | None = None,
        related: list[tuple[str, CodeLocInfo]] = [],
        help_text: str | None = None;

    def postinit -> None;
    def __str__ -> str;
    def __repr__ -> str;
    def as_log(*, colors: bool = False) -> str;
    def pretty_print(*, colors: bool = False) -> str;
}

obj BaseTransform[T_in, T_out](ABC) {
    has ir_in: T_in,
        prog: JacProgram,
        cancel_token: (Event | None) = None,
        errors_had: list[Alert] = [],
        warnings_had: list[Alert] = [],
        time_taken: float = 0.0,
        logger: any by postinit,
        ir_out: T_out by postinit;

    def postinit -> None;
    def timed_transform(ir_in: T_in) -> T_out;
    def pre_transform -> None;
    def post_transform -> None;
    @abstractmethod
    def transform(ir_in: T_in) -> T_out;

    def log_info(msg: str) -> None;
    def is_canceled -> bool;
}

obj Transform[T: UniNode, R: UniNode](BaseTransform[T, R]) {
    has cur_node: UniNode by postinit,
        _project_config: any = None,
        _cached_check_suppress_tokens: list[str] = field(default_factory=`list),
        _cached_check_suppress_codes: list[str] = field(default_factory=`list),
        _cached_inline_suppressions: dict[((str, int), list[str])] = field(
            default_factory=`dict
        );

    static has PROVIDES: tuple = (),
        REQUIRES: tuple = ();

    def postinit -> None;
    def emit(
        diag: DiagnosticInfo,
        node_override: (UniNode | None) = None,
        related: (list[tuple[str, UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: any
    ) -> bool;

    def _is_suppressed(diag: DiagnosticInfo, loc: CodeLocInfo | None = None) -> bool;
    def ice(msg: str = 'Something went horribly wrong!') -> RuntimeError;
}
