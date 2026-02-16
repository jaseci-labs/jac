"""Standardized transformation process and error interface."""
import time;
import from abc { ABC, abstractmethod }
import from threading { Event }
import from typing { TYPE_CHECKING, Generic, TypeVar }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.log { logging }
import from jaclang.jac0core.unitree { UniNode }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

glob T_in = TypeVar('T_in'),
     T_out = TypeVar('T_out'),
     T = TypeVar('T', bound=UniNode),
     R = TypeVar('R', bound=UniNode);

"""Alert interface."""
class Alert {
    """Initialize alert."""
    def init(
        self: Alert, msg: str, loc: CodeLocInfo, from_pass: type[Transform]
    ) -> None;

    """Return string representation of alert."""
    def __str__(self: Alert) -> str;

    """Return string representation of alert."""
    def __repr__(self: Alert) -> str;

    """Return the alert as a single line log as opposed to the pretty print."""
    def as_log(self: Alert, *, colors: bool = False) -> str;

    """Pretty prints the Alert to show the alert with source location."""
    def pretty_print(self: Alert, *, colors: bool = False) -> str;
}

"""Base abstract class for all transforms (no UniNode constraint).

    Use this base class for transforms that don't operate on AST nodes,
    such as parser transforms that take string input and produce parse trees.
    """
class BaseTransform(ABC, Generic[(T_in, T_out)]) {
    """Initialize pass."""
    def init(
        self: BaseTransform,
        ir_in: T_in,
        prog: JacProgram,
        cancel_token: (Event | None) = None
    ) -> None;

    """Transform with time tracking."""
    def timed_transform(self: BaseTransform, ir_in: T_in) -> T_out;

    """Pre-transform hook."""
    def pre_transform(self: BaseTransform) -> None;

    """Post-transform hook."""
    def post_transform(self: BaseTransform) -> None;

    """Transform interface."""
    @abstractmethod
    def transform(self: BaseTransform, ir_in: T_in) -> T_out;

    """Log info."""
    def log_info(self: BaseTransform, msg: str) -> None;

    """Check if the pass has been canceled."""
    def is_canceled(self: BaseTransform) -> bool;
}

"""Abstract class for IR passes that operate on AST nodes.

    This class extends BaseTransform with UniNode-specific functionality
    like error/warning logging with source location tracking.
    """
class Transform(BaseTransform[(T, R)]) {
    """Initialize pass."""
    def init(
        self: Transform,
        ir_in: T,
        prog: JacProgram,
        cancel_token: (Event | None) = None
    ) -> None;

    """Pass Error."""
    def log_error(
        self: Transform, msg: str, node_override: (UniNode | None) = None
    ) -> None;

    """Pass Error."""
    def log_warning(
        self: Transform, msg: str, node_override: (UniNode | None) = None
    ) -> None;

    """Pass Error."""
    def ice(
        self: Transform, msg: str = 'Something went horribly wrong!'
    ) -> RuntimeError;
}
