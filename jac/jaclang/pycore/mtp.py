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
    mtir: MTIR

    @staticmethod
    def factory(
        caller: Callable[..., object],
        args: dict[int | str, object],
        call_params: dict[str, object],
        mtir: MTIR = None,
    ) -> "MTRuntime":
        """Create a new MTRuntime instance."""
        return MTRuntime(caller=caller, args=args, call_params=call_params, mtir=mtir)


@dataclass
class MTIR:
    """Intermediate Representation for Meaning Typed Programming."""

    caller: Callable[..., object]
    args: dict[int | str, object]
    call_params: dict[str, object]
    ir_info: Info = None

    @property
    def runtime(self) -> MTRuntime:
        """Convert to runtime context."""
        return MTRuntime.factory(self.caller, self.args, self.call_params)

# PRIMITIVE_TYPES = {'int', 'float', 'str', 'bool', 'None', 'bytes', 'list', 'dict', 'set', 'tuple'}

@dataclass
class Info :
    name: str
    semstr: str | None

@dataclass
class VarInfo(Info) :
    type_info: ClassInfo | str | None = None

@dataclass
class ParamInfo(VarInfo):
    pass

@dataclass
class FieldInfo(VarInfo):
    pass

@dataclass
class ClassInfo(Info) :
    fields: list[FieldInfo]
    base_classes: list[ClassInfo]
    methods: list[MethodInfo]
    # archetype_node: uni.Archetype = None

    def post_init__(self):
        # Ensure fields and methods are initialized to empty lists if None
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
    by_call: bool = False

    def post_init__(self):
        # Ensure params and tools are initialized to empty lists if None
        if self.params is None:
            self.params = []
        if self.tools is None:
            self.tools = []


@dataclass
class MethodInfo(FunctionInfo) :
    parent_class: ClassInfo = None