"""Representation of types used during type analysis."""
import from abc { ABC }
import from enum { IntEnum, auto }
import from pathlib { Path }
import from typing { TYPE_CHECKING, ClassVar }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.unitree { Expr, Symbol }
        import from jaclang.pycore.unitree { UniScopeNode as SymbolTable }
    }
}

"""Enumeration of type categories."""
class TypeCategory(IntEnum) {
    with entry {
        Unbound = auto();
        Unknown = auto();
        Never = auto();
        Any = auto();
        Module = auto();
        TypeVar = auto();
        Class = auto();
        Function = auto();
        Overload = auto();
        Union = auto();
    }
}

"""
Flags to set on a type.

    foo = 42  # <-- Here type of foo is `int` class, Instance type.
    foo = int # <-- Here type of foo is `type[int]`, Instantiable is set.
    foo: int = 42
         ^^^------- Here the type of the expression `int` is `type[int]`
                    That is same as the prefetched int_class that has the
                    flag Instantiable set.

                    calling convertToInstance() will return the same type
                    with Instance flag set.
"""
class TypeFlags(IntEnum) {
    with entry {
        Null = 0;
        Instantiable = 1 << 0;
        Instance = 1 << 1;
        Ambiguous = 1 << 2;
    }
}

"""Enumeration of parameter categories."""
class ParameterCategory(IntEnum) {
    with entry {
        Positional = auto();
        ArgsList = auto();
        KwargsDict = auto();
    }
}

"""
Maps to pyright's TypeBase<T> in the types.ts file.

    This is the base class for all type instance of the jaclang that holds
    information about the type's category and any additional metadata and
    utilities to analyze type information and provide type checking.
"""
class TypeBase(ABC) {
    with entry {
        CATEGORY: ClassVar[TypeCategory];
    }

    def init(self: TypeBase, flags: TypeFlags = TypeFlags.Null) -> None;
    @property
    def category(self: TypeBase) -> TypeCategory;

    static def unknown -> UnknownType;
    def is_instantiable(self: TypeBase) -> bool;
    def is_instance(self: TypeBase) -> bool;
    def is_instantiable_class(self: TypeBase) -> bool;
    def is_class_instance(self: TypeBase) -> bool;
}

"""Represents a type that is not bound to a specific value or context."""
class UnboundType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unbound;
    }
}

"""Represents a type that is not known or cannot be determined."""
class UnknownType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unknown;
    }
}

"""Represents a type that can never occur."""
class NeverType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Never;
    }
}

"""Represents a type that can be anything."""
class AnyType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Any;
    }
}

"""Represents a module type."""
class ModuleType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Module;
    }

    def init(
        self: ModuleType, mod_name: str, file_uri: Path, symbol_table: SymbolTable
    ) -> None;
}

"""Represents a type variable."""
class TypeVarType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.TypeVar;
    }

    def init(self: TypeVarType) -> None;
}

"""Represents a class type."""
class ClassType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Class;
    }

    """
Holds the shared details of class type.

        The shared detail of classes will points to the same instance across multiple clones
        of the same class. This is needed when we do `==` between two classes, if they have the
        same shared object, that means they both are the same class (with different context).
    """
    class ClassDetailsShared {
        def init(
            self: ClassDetailsShared,
            class_name: str,
            symbol_table: SymbolTable,
            *,
            type_params: (list[TypeVarType] | None) = None,
            base_classes: (list[TypeBase] | None) = None,
            is_builtin_class: bool = False,
            is_data_class: bool = False,
            is_root_class: bool = False
        ) -> None;
    }

    """
Holds the private details of class type.

        The private details of classes will be unique to each class instance.
    """
    class ClassDetailsPrivate {
        def init(
            self: ClassDetailsPrivate, type_args: (list[TypeBase] | None) = None
        ) -> None;
    }

    def init(
        self: ClassType,
        shared: ClassType.ClassDetailsShared,
        private: (ClassType.ClassDetailsPrivate | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def __str__(self: ClassType) -> str;
    def clone_as_instance(self: ClassType) -> ClassType;
    def clone_as_class(self: ClassType) -> ClassType;
    def specialize_generics(self: ClassType, type_args: list[TypeBase]) -> ClassType;
    def get_class_symbol(self: ClassType) -> Symbol;
    def lookup_member_symbol(
        self: ClassType, member: str, r_overloaded: list | None = None
    ) -> (Symbol | None);

    def is_builtin(self: ClassType, class_name: (str | None) = None) -> bool;
    def is_data_class(self: ClassType) -> bool;
    def is_edge_type(self: ClassType) -> bool;
    def is_node_type(self: ClassType) -> bool;
}

"""Enumeration of parameter kinds."""
class ParamKind(IntEnum) {
    with entry {
        POSONLY = 0;
        NORMAL = 1;
        VARARG = 2;
        KWONLY = 3;
        KWARG = 4;
    }
}

"""Represents a function parameter."""
class Parameter {
    def init(
        self: Parameter,
        name: str,
        category: ParameterCategory,
        param_type: (TypeBase | None),
        default_value: (Expr | None) = None,
        is_self: bool = False,
        is_cls: bool = False,
        param_kind: ParamKind = ParamKind.NORMAL
    ) -> None;
}

"""Represents a function type."""
class FunctionType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Function;
    }

    def init(
        self: FunctionType,
        func_name: str,
        return_type: (TypeBase | None) = None,
        parameters: (list[Parameter] | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def specialize(self: FunctionType, class_type: ClassType) -> FunctionType;
    def _index_of_type_param(
        self: FunctionType, class_type: ClassType, type_var: TypeVarType
    ) -> int;
}

"""Represents an overloaded type."""
class OverloadedType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Overload;
    }

    def init(self: OverloadedType, overloads: list[FunctionType]) -> None;
}

"""Represents a union type."""
class UnionType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Union;
    }

    def init(self: UnionType, types: list[TypeBase]) -> None;
}
