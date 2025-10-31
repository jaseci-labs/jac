"""Standardized transformation process and error interface."""

from __future__ import annotations

import time
from abc import ABC, abstractmethod
from threading import Event
from typing import Any, Dict, Generic, Optional, TYPE_CHECKING, Type, TypeVar

from jaclang.compiler.codeinfo import CodeLocInfo
from jaclang.compiler.errors.error_definitions import ErrorCode
from jaclang.compiler.unitree import UniNode
from jaclang.settings import settings
from jaclang.utils.helpers import ANSIColors, pretty_print_source_location
from jaclang.utils.log import logging

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram  # noqa: I300

T = TypeVar("T", bound=UniNode)
R = TypeVar("R", bound=UniNode)


class Alert:
    """Alert interface with centralized error codes."""

    def __init__(
        self,
        code: ErrorCode,
        loc: CodeLocInfo,
        from_pass: Type[Transform],
        args: Optional[Dict[str, Any]] = None,
    ) -> None:
        """Initialize alert.

        Args:
            code: The ErrorCode for this alert
            loc: Location information for the error
            from_pass: The transform pass that generated this alert
            args: Optional dictionary of arguments for error message formatting
        """
        self.code: ErrorCode = code
        self.loc: CodeLocInfo = loc
        self.from_pass: Type[Transform] = from_pass
        self.args: Dict[str, Any] = args if args else {}
        self.msg: str = code.format_message(**self.args)

    def __str__(self) -> str:
        """Return string representation of alert."""
        return (
            f"[{self.code.code}] {self.loc.mod_path}, line {self.loc.first_line},"
            f" col {self.loc.col_start}: {self.msg}"
        )

    def __repr__(self) -> str:
        """Return string representation of alert."""
        return self.as_log()

    def as_log(self, *, colors: bool = False) -> str:
        """Return the alert as a single line log as opposed to the pretty print."""
        file_path: str = self.loc.mod_path
        if file_path == "":
            return f"[{self.code.code}] {self.msg}"

        line: int = self.loc.first_line
        column: int = self.loc.col_start

        # Color coding based on error vs warning
        if colors:
            if self.code.is_warning():
                color = ANSIColors.YELLOW
            else:
                color = ANSIColors.RED
            msg = f"{color}{self.msg}{ANSIColors.END}"
        else:
            msg = self.msg

        return f"{file_path}:{line}:{column}: [{self.code.code}] {msg}"

    def pretty_print(self, *, colors: bool = False) -> str:
        """Pretty prints the Alert to show the alert with source location."""
        pretty_dump = pretty_print_source_location(
            self.loc.mod_path,
            self.loc.orig_src.code,
            self.loc.first_line,
            self.loc.pos_start,
            self.loc.pos_end,
            colors=colors,
        )
        if pretty_dump != "":
            pretty_dump = "\n" + pretty_dump
        return self.as_log(colors=colors) + pretty_dump


class Transform(ABC, Generic[T, R]):
    """Abstract class for IR passes."""

    def __init__(
        self, ir_in: T, prog: JacProgram, cancel_token: Event | None = None
    ) -> None:
        """Initialize pass."""
        self.logger = logging.getLogger(self.__class__.__name__)
        self.errors_had: list[Alert] = []
        self.warnings_had: list[Alert] = []
        self.cur_node: UniNode = ir_in  # tracks current node during traversal
        self.prog = prog
        self.time_taken = 0.0
        self.ir_in: T = ir_in
        self.cancel_token = cancel_token
        self.pre_transform()
        self.ir_out: R = self.timed_transform(ir_in=ir_in)
        self.post_transform()

    def timed_transform(
        self,
        ir_in: T,
    ) -> R:
        """Transform with time tracking."""
        start_time = time.time()
        ir_out = self.transform(ir_in=ir_in)
        self.time_taken = time.time() - start_time
        if settings.pass_timer:
            self.log_info(
                f"Time taken in {self.__class__.__name__}: {self.time_taken:.4f} seconds"
            )
        return ir_out

    def pre_transform(self) -> None:
        """Pre-transform hook."""
        pass

    def post_transform(self) -> None:
        """Post-transform hook."""
        pass

    @abstractmethod
    def transform(self, ir_in: T) -> R:
        """Transform interface."""
        pass

    def log_error(
        self,
        code: ErrorCode,
        node_override: Optional[UniNode] = None,
        **kwargs: object,
    ) -> None:
        """Log an error with centralized error codes.

        Args:
            code: The ErrorCode for this error
            node_override: Optional node to use for location instead of self.cur_node
            **kwargs: Arguments for error message template formatting
        """
        loc = self.cur_node.loc if not node_override else node_override.loc
        alrt = Alert(
            code,
            loc,
            self.__class__,
            args=kwargs if kwargs else None,
        )
        self.errors_had.append(alrt)
        self.prog.errors_had.append(alrt)

    def log_warning(
        self,
        code: ErrorCode,
        node_override: Optional[UniNode] = None,
        **kwargs: object,
    ) -> None:
        """Log a warning with centralized error codes.

        Args:
            code: The ErrorCode for this warning
            node_override: Optional node to use for location instead of self.cur_node
            **kwargs: Arguments for error message template formatting
        """
        loc = self.cur_node.loc if not node_override else node_override.loc
        alrt = Alert(
            code,
            loc,
            self.__class__,
            args=kwargs if kwargs else None,
        )
        self.warnings_had.append(alrt)
        self.prog.warnings_had.append(alrt)

    def log_info(self, msg: str) -> None:
        """Log info."""
        self.logger.info(msg)

    def is_canceled(self) -> bool:
        """Check if the pass has been canceled."""
        return self.cancel_token is not None and self.cancel_token.is_set()

    def ice(self, msg: str = "Something went horribly wrong!") -> RuntimeError:
        """Internal Compiler Error (ICE)."""
        self.log_error(
            ErrorCode.ICE_PASS_ERROR,
            pass_name=self.__class__.__name__,
            message=msg,
        )
        return RuntimeError(
            f"Internal Compiler Error: Pass {self.__class__.__name__} - {msg}"
        )
