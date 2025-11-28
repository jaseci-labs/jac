"""Meaning Typed Programming constructs for Jac Language."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass


@dataclass(eq=False, repr=False)
class MTIR:
    """Meaning Typed Intermediate Representation."""

    caller: Callable
    args: dict[int | str, object]
    call_params: dict[str, object]
