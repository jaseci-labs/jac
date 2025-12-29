"""Standardized transformation process and error interface."""

from __future__ import annotations

import time
from abc import ABC, abstractmethod
from threading import Event
from typing import TYPE_CHECKING, Generic, TypeVar

from jaclang.pycore.codeinfo import CodeLocInfo
from jaclang.pycore.log import logging
from jaclang.pycore.unitree import UniNode

if TYPE_CHECKING:
    from jaclang.pycore.program import JacProgram

# Type variables for transforms - T_in/T_out are unconstrained for base transforms
T_in = TypeVar("T_in")
T_out = TypeVar("T_out")

# Type variables for AST transforms - constrained to UniNode
T = TypeVar("T", bound=UniNode)
R = TypeVar("R", bound=UniNode)


class Alert:
    """Alert interface."""

    def __init__(self, msg: str, loc: CodeLocInfo, from_pass: type[Transform]) -> None:
        """Initialize alert."""
        self.msg = msg
        self.loc: CodeLocInfo = loc
        self.from_pass: type[Transform] = from_pass

    def __str__(self) -> str:
        """Return string representation of alert."""
        return f"{self.loc.mod_path}, line {self.loc.first_line}, col {self.loc.col_start}: {self.msg}"

    def __repr__(self) -> str:
        """Return string representation of alert."""
        return self.as_log()

    def as_log(self, *, colors: bool = False) -> str:
        """Return the alert as a single line log as opposed to the pretty print."""
        from jaclang.pycore.helpers import ANSIColors

        file_path: str = self.loc.mod_path
        if file_path == "":
            return self.msg  # There are error messages without file references.

        line: int = self.loc.first_line
        column: int = self.loc.col_start

        # TODO: Set if the alert is error or warning and color accordingly.
        msg = self.msg if not colors else f"{ANSIColors.RED}{self.msg}{ANSIColors.END}"
        return f"{file_path}:{line}:{column} {msg}"

    def pretty_print(self, *, colors: bool = False) -> str:
        """Pretty prints the Alert to show the alert with source location."""
        from jaclang.pycore.helpers import pretty_print_source_location

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


class BaseTransform(ABC, Generic[T_in, T_out]):
    """Base abstract class for all transforms (no UniNode constraint).

    Use this base class for transforms that don't operate on AST nodes,
    such as parser transforms that take string input and produce parse trees.
    """

    def __init__(
        self, ir_in: T_in, prog: JacProgram, cancel_token: Event | None = None
    ) -> None:
        """Initialize pass."""
        self.logger = logging.getLogger(self.__class__.__name__)
        self.errors_had: list[Alert] = []
        self.warnings_had: list[Alert] = []
        self.prog = prog
        self.time_taken = 0.0
        self.ir_in: T_in = ir_in
        self.cancel_token = cancel_token
        self.pre_transform()
        self.ir_out: T_out = self.timed_transform(ir_in=ir_in)
        self.post_transform()

    def timed_transform(
        self,
        ir_in: T_in,
    ) -> T_out:
        """Transform with time tracking."""
        start_time = time.time()
        ir_out = self.transform(ir_in=ir_in)
        self.time_taken = time.time() - start_time
        return ir_out

    def pre_transform(self) -> None:
        """Pre-transform hook."""
        pass

    def post_transform(self) -> None:
        """Post-transform hook."""
        pass

    @abstractmethod
    def transform(self, ir_in: T_in) -> T_out:
        """Transform interface."""
        pass

    def log_info(self, msg: str) -> None:
        """Log info."""
        self.logger.info(msg)

    def is_canceled(self) -> bool:
        """Check if the pass has been canceled."""
        return self.cancel_token is not None and self.cancel_token.is_set()


class Transform(BaseTransform[T, R]):
    """Abstract class for IR passes that operate on AST nodes.

    This class extends BaseTransform with UniNode-specific functionality
    like error/warning logging with source location tracking.
    """

    def __init__(
        self, ir_in: T, prog: JacProgram, cancel_token: Event | None = None
    ) -> None:
        """Initialize pass."""
        self.cur_node: UniNode = ir_in  # tracks current node during traversal
        super().__init__(ir_in, prog, cancel_token)

    def log_error(self, msg: str, node_override: UniNode | None = None) -> None:
        """Pass Error."""
        alrt = Alert(
            msg,
            self.cur_node.loc if not node_override else node_override.loc,
            self.__class__,
        )
        self.errors_had.append(alrt)
        self.prog.errors_had.append(alrt)
        # self.logger.error(alrt.as_log())

    def log_warning(self, msg: str, node_override: UniNode | None = None) -> None:
        """Pass Error."""
        alrt = Alert(
            msg,
            self.cur_node.loc if not node_override else node_override.loc,
            self.__class__,
        )
        self.warnings_had.append(alrt)
        self.prog.warnings_had.append(alrt)
        # self.logger.warning(alrt.as_log())

    def ice(self, msg: str = "Something went horribly wrong!") -> RuntimeError:
        """Pass Error."""
        self.log_error(f"ICE: Pass {self.__class__.__name__} - {msg}")
        return RuntimeError(
            f"Internal Compiler Error: Pass {self.__class__.__name__} - {msg}"
        )
