"""Meaning Typed Programming constructs for Jac Language."""

from collections.abc import Callable
from dataclasses import dataclass


@dataclass
class MTRuntime:
    """Runtime context for Meaning Typed Programming."""

    caller: Callable[..., object]
    args: dict[int | str, object]
    call_params: dict[str, object]

    @staticmethod
    def factory(
        caller: Callable[..., object],
        args: dict[int | str, object],
        call_params: dict[str, object],
    ) -> "MTRuntime":
        """Create a new MTRuntime instance."""
        return MTRuntime(caller=caller, args=args, call_params=call_params)


@dataclass
class MTIR:
    """Intermediate Representation for Meaning Typed Programming."""

    caller: Callable[..., object]
    args: dict[int | str, object]
    call_params: dict[str, object]

    @property
    def runtime(self) -> MTRuntime:
        """Convert to runtime context."""
        return MTRuntime.factory(self.caller, self.args, self.call_params)
