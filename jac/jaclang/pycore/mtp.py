"""Meaning Typed Programming constructs for Jac Language."""

from __future__ import annotations
from collections.abc import Callable
from dataclasses import dataclass

# from jaclang.vendor.cattrs._compat import has
from jaclang.pycore import unitree as uni

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
    # info: Info

    @property
    def runtime(self) -> MTRuntime:
        """Convert to runtime context."""
        return MTRuntime.factory(self.caller, self.args, self.call_params)

PRIMITIVE_TYPES = {'int', 'float', 'str', 'bool', 'None', 'bytes', 'list', 'dict', 'set', 'tuple'}

@dataclass
class Info :
    name: str
    symbol: uni.Symbol
    semstr: str | None


@dataclass
class VarInfo(Info) :
    type_symbol: ClassInfo | str | None = None

@dataclass
class ParamInfo(VarInfo):
    pass

@dataclass
class FieldInfo(VarInfo):
    pass

@dataclass
class ClassInfo(Info) :
    fields: list[FieldInfo] = None
    base_classes: list[str] = None
    methods: list[str] = None  # Method names
    archetype_node: uni.Archetype = None

    def __post_init__(self):
        if self.fields is None:
            self.fields = []
        if self.base_classes is None:
            self.base_classes = []
        if self.methods is None:
            self.methods = []

@dataclass
class FunctionInfo(Info) :
    params: list[ParamInfo] = None
    return_type: str | ClassInfo | None = None
    tools: list[MethodInfo] = None

    def __post_init__(self):
        if self.params is None:
            self.params = []

@dataclass
class MethodInfo(FunctionInfo) :
    parent_class: ClassInfo = None