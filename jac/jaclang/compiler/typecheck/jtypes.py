"""Representation of types used during type analysis."""

# Pyright Reference: packages\pyright-internal\src\analyzer\types.ts
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import ClassVar

from jaclang.compiler.unitree import Expr

from .types import SymbolTable, Uri


class TypeCategory(Enum):
    """Enumeration of type categories."""

    Unbound = auto()  # Name is not bound to a value of any type
    Unknown = auto()  # Implicit Any type
    Never = auto()  # The bottom type, equivalent to an empty union
    Any = auto()  # Type can be anything
    Module = auto()  # Module instance
    Class = auto()  # Class definition
    Function = auto()  # Callable type
    Union = auto()  # Union of two or more other types


class ParameterCategory(Enum):
    """Enumeration of parameter categories."""

    Positional = auto()
    ArgsList = auto()
    KwargsDict = auto()


@dataclass
class Jtype:
    """Maps to pyright's TypeBase<T> in the types.ts file.

    This is the base class for all type instance of the jaclang that holds
    information about the type's category and any additional metadata and
    utilities to analyze type information and provide type checking.
    """

    # Each subclass should provide a class-level CATEGORY constant indicating its type category.
    CATEGORY: ClassVar[TypeCategory]

    @property
    def category(self) -> TypeCategory:
        """Returns the category of the type."""
        return self.CATEGORY


@dataclass
class UnboundType(Jtype):
    """Represents a type that is not bound to a specific value or context."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unbound


@dataclass
class UnknownType(Jtype):
    """Represents a type that is not known or cannot be determined."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unknown


@dataclass
class NeverType(Jtype):
    """Represents a type that can never occur."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Never


@dataclass
class AnyType(Jtype):
    """Represents a type that can be anything."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Any


@dataclass
class ModuleType(Jtype):
    """Represents a module type."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Module

    mod_name: str
    file_uri: Uri
    symbol_table: SymbolTable = field(default_factory=SymbolTable)


@dataclass
class ClassType(Jtype):
    """Represents a class type."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Class

    class_name: str
    base_classes: list[Jtype] = field(default_factory=list)
    symbol_table: SymbolTable = field(default_factory=SymbolTable)


@dataclass
class Parameter:
    """Represents a function parameter."""

    name: str
    category: ParameterCategory
    param_type: Jtype | None
    default_expr: Expr | None


@dataclass
class FunctionType(Jtype):
    """Represents a function type."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Function

    func_name: str
    return_type: Jtype | None = None
    parameters: list[Parameter] = field(default_factory=list)


@dataclass
class UnionType(Jtype):
    """Represents a union type."""

    CATEGORY: ClassVar[TypeCategory] = TypeCategory.Union

    types: list[Jtype] = field(default_factory=list)
