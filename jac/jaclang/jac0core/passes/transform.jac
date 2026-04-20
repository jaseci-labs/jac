"""Standardized transformation process and error interface."""
import time;
import from abc { ABC, abstractmethod }
import from threading { Event }
import from typing { Any, TYPE_CHECKING }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.diagnostics { DiagnosticInfo, Severity, E9001 }
import from jaclang.jac0core.log { logging }
import from jaclang.jac0core.unitree { UniNode }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

"""Alert interface."""
obj Alert {
    has msg: str,
        loc: CodeLocInfo,
        from_pass: type[Transform],
        code: DiagnosticInfo | None = None,
        related: list[tuple[str, CodeLocInfo]] = [],
        help_text: str | None = None;

    def postinit -> None;
    """Return string representation of alert."""
    def __str__ -> str;

    """Return string representation of alert."""
    def __repr__ -> str;

    """Return the alert as a single line log as opposed to the pretty print."""
    def as_log(*, colors: bool = False) -> str;

    """Pretty prints the Alert to show the alert with source location."""
    def pretty_print(*, colors: bool = False) -> str;
}

"""Base abstract class for all transforms (no UniNode constraint).

    Use this base class for transforms that don't operate on AST nodes,
    such as parser transforms that take string input and produce parse trees.
    """
obj BaseTransform[T_in, T_out](ABC) {
    has ir_in: T_in,
        prog: JacProgram,
        cancel_token: (Event | None) = None,
        errors_had: list[Alert] = [],
        warnings_had: list[Alert] = [],
        time_taken: float = 0.0,
        logger: Any by postinit,
        ir_out: T_out by postinit;

    """Initialize pass and run transformation."""
    def postinit -> None;

    """Transform with time tracking."""
    def timed_transform(ir_in: T_in) -> T_out;

    """Pre-transform hook."""
    def pre_transform -> None;

    """Post-transform hook."""
    def post_transform -> None;

    """Transform interface."""
    @abstractmethod
    def transform(ir_in: T_in) -> T_out;

    """Log info."""
    def log_info(msg: str) -> None;

    """Check if the pass has been canceled."""
    def is_canceled -> bool;
}

"""Abstract class for IR passes that operate on AST nodes.

    This class extends BaseTransform with UniNode-specific functionality
    like error/warning logging with source location tracking.
    """
obj Transform[T: UniNode, R: UniNode](BaseTransform[T, R]) {
    has cur_node: UniNode by postinit;

    """Initialize pass - set cur_node before parent postinit runs."""
    def postinit -> None;

    """Emit a structured diagnostic."""
    def emit(
        diag: DiagnosticInfo,
        node_override: (UniNode | None) = None,
        related: (list[tuple[str, UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: Any
    ) -> bool;

    """Check if a diagnostic code is suppressed."""
    def _is_suppressed(diag: DiagnosticInfo, loc: CodeLocInfo | None = None) -> bool;

    """Pass Error."""
    def ice(msg: str = 'Something went horribly wrong!') -> RuntimeError;
}
