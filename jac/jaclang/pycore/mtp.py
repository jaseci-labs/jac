"""Meaning Typed Programming constructs for Jac Language."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

# from jaclang.vendor.cattrs._compat import has


@dataclass
class MTRuntime:
    """Runtime context for Meaning Typed Programming."""

    caller: Callable[..., object]
    args: dict[int | str, object]
    call_params: dict[str, object]
    mtir: MTIR | None

    @staticmethod
    def factory(
        caller: Callable[..., object],
        args: dict[int | str, object],
        call_params: dict[str, object],
        mtir: MTIR | None = None,
    ) -> MTRuntime:
        """Create a new MTRuntime instance."""
        return MTRuntime(caller=caller, args=args, call_params=call_params, mtir=mtir)


@dataclass
class MTIR:
    """Intermediate Representation for Meaning Typed Programming."""

    caller: Callable[..., object]
    args: dict[int | str, object]
    call_params: dict[str, object]
    ir_info: Info | None = None

    @property
    def runtime(self) -> MTRuntime:
        """Convert to runtime context."""
        return MTRuntime.factory(self.caller, self.args, self.call_params)


# PRIMITIVE_TYPES = {'int', 'float', 'str', 'bool', 'None', 'bytes', 'list', 'dict', 'set', 'tuple'}


@dataclass
class Info:
    name: str
    semstr: str | None


@dataclass
class VarInfo(Info):
    # type_info may be a simple primitive name (`str`), a resolved `ClassInfo`,
    # or a tuple-based generic encoding (see helpers below).
    type_info: ClassInfo | str | tuple | None = None


@dataclass
class ParamInfo(VarInfo):
    pass


@dataclass
class FieldInfo(VarInfo):
    pass


@dataclass
class EnumInfo(Info):
    members: list[FieldInfo]


@dataclass
class ClassInfo(Info):
    fields: list[FieldInfo]
    base_classes: list[ClassInfo]
    methods: list[MethodInfo]
    # archetype_node: uni.Archetype = None

    def __post_init__(self):
        # Ensure fields and methods are initialized to empty lists if None
        if self.fields is None:
            self.fields = []
        if self.base_classes is None:
            self.base_classes = []
        if self.methods is None:
            self.methods = []


@dataclass
class FunctionInfo(Info):
    params: list[ParamInfo] | None = None
    return_type: str | ClassInfo | tuple | None = None
    tools: list[MethodInfo] | None = None
    by_call: bool = False

    def __post_init__(self):
        # Ensure params and tools are initialized to empty lists if None
        if self.params is None:
            self.params = []
        if self.tools is None:
            self.tools = []


@dataclass
class MethodInfo(FunctionInfo):
    parent_class: ClassInfo | None = None


# Minimal, backward-compatible helpers for representing generic/collection types
# without introducing a new dataclass. These use simple tuple encodings:
#  - list[T]  -> ("list", T)
#  - dict[K,V] -> ("dict", K, V)
#  - tuple[A,B,...] -> ("tuple", A, B, ...)
#  - union types -> ("union", T1, T2, ...)


def mk_list(inner: object) -> tuple:
    return ("list", inner)


def mk_dict(key: object, val: object) -> tuple:
    return ("dict", key, val)


def mk_tuple(*types: object) -> tuple:
    return ("tuple",) + tuple(types)


def mk_union(*types: object) -> tuple:
    return ("union",) + tuple(types)


def is_list_type(t: object) -> bool:
    return isinstance(t, tuple) and len(t) >= 2 and t[0] == "list"


def is_dict_type(t: object) -> bool:
    return isinstance(t, tuple) and len(t) == 3 and t[0] == "dict"


def is_tuple_type(t: object) -> bool:
    return isinstance(t, tuple) and len(t) >= 2 and t[0] == "tuple"


def is_union_type(t: object) -> bool:
    return isinstance(t, tuple) and len(t) >= 2 and t[0] == "union"


def inner_types(t: object) -> tuple:
    if isinstance(t, tuple) and len(t) >= 2:
        return t[1:]
    return ()


def type_to_str(t: object) -> str:
    """Pretty-print a type-info value (primitive, ClassInfo, or tuple generic)."""
    if t is None:
        return "None"
    if isinstance(t, str):
        return t
    try:
        # avoid importing heavy modules; rely on dataclass repr for ClassInfo
        from dataclasses import is_dataclass

        if is_dataclass(t) and hasattr(t, "name"):
            return t.name
    except Exception:
        pass
    if isinstance(t, tuple):
        head = t[0]
        if head == "list":
            return f"list[{type_to_str(t[1])}]"
        if head == "dict":
            return f"dict[{type_to_str(t[1])},{type_to_str(t[2])}]"
        if head == "tuple":
            return "tuple[" + ",".join(type_to_str(x) for x in t[1:]) + "]"
        if head == "union":
            return "|".join(type_to_str(x) for x in t[1:])
        # fallback generic
        return head + "[" + ",".join(type_to_str(x) for x in t[1:]) + "]"
    return str(t)
