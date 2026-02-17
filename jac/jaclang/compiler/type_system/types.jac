"""Representation of types used during type analysis."""
import from abc { ABC }
import from enum { IntEnum, auto }
import from pathlib { Path }
import from typing { TYPE_CHECKING, ClassVar }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.unitree { Expr, Symbol }
        import from jaclang.jac0core.unitree { UniScopeNode as SymbolTable }
    }
}

"""Enumeration of type categories."""
enum TypeCategory ( IntEnum ) {
    Unbound,
    Unknown,
    Never,
    Any,
    Module,
    TypeVar,
    Class,
    Function,
    Overload,
    Union,
    EnumMember
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
obj TypeBase(ABC) {
    has flags: TypeFlags = TypeFlags.Null;

    with entry {
        CATEGORY: ClassVar[TypeCategory];
    }

    @property
    def category -> TypeCategory;

    static def unknown -> UnknownType;
    def is_instantiable -> bool;
    def is_instance -> bool;
    def is_instantiable_class -> bool;
    def is_class_instance -> bool;
    def is_any_type -> bool;
}

"""Represents a type that is not bound to a specific value or context."""
obj UnboundType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unbound;
    }

    def __str__ -> str;
}

"""Represents a type that is not known or cannot be determined."""
obj UnknownType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unknown;
    }

    def __str__ -> str;
}

"""Represents a type that can never occur."""
obj NeverType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Never;
    }

    def __str__ -> str;
}

"""Represents a type that can be anything."""
obj AnyType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Any;
    }

    def __str__ -> str;
}

"""Represents a module type."""
obj ModuleType(TypeBase) {
    has mod_name: str = "",
        file_uri: Path = Path(""),
        symbol_table: SymbolTable = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Module;
    }

    def __str__ -> str;
}

"""Represents a type variable."""
obj TypeVarType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.TypeVar;
    }

    def __str__ -> str;
}

"""Represents a class type."""
obj ClassType(TypeBase) {
    has shared: (ClassType.ClassDetailsShared | None) = None,
        private: (ClassType.ClassDetailsPrivate | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Class;
    }

    """
Holds the shared details of class type.

        The shared detail of classes will points to the same instance across multiple clones
        of the same class. This is needed when we do `==` between two classes, if they have the
        same shared object, that means they both are the same class (with different context).
    """
    obj ClassDetailsShared {
        has class_name: str,
            symbol_table: SymbolTable,
            mro: list[ClassType],
            type_params: (list[TypeVarType] | None) = None,
            base_classes: (list[TypeBase] | None) = None,
            is_builtin_class: bool = False,
            is_data_class: bool = False,
            is_root_class: bool = False,
            is_enum_class: bool = False,
            enum_value_type: (TypeBase | None) = None,
            enum_members: (dict[str, EnumMemberInfo] | None) = None;

        def postinit -> None;
    }

    """
Holds the private details of class type.

        The private details of classes will be unique to each class instance.
    """
    obj ClassDetailsPrivate {
        has type_args: (list[TypeBase] | None) = None,
            # Alias name for special forms (e.g., "Callable", "Union").
            # Similar to Pyright's classType.priv.aliasName.
            # This is set when loading special forms from typing module
            # to distinguish between different _SpecialForm instances.
            alias_name: (str | None) = None;

        def postinit -> None;
    }

    def postinit -> None;
    def __str__ -> str;
    def clone_as_instance -> ClassType;
    def clone_as_class -> ClassType;
    def specialize_generics(type_args: list[TypeBase]) -> ClassType;
    def get_class_symbol -> Symbol;
    def lookup_member_symbol(
        member: str, r_overloaded: list | None = None
    ) -> (Symbol | None);

    def is_builtin(class_name: (str | None) = None) -> bool;
    def is_data_class -> bool;
    def is_enum_class -> bool;
    def is_edge_type -> bool;
    def is_node_type -> bool;
    # Check if this is a special form with the given alias name (like Pyright's isSpecialBuiltIn)
    def is_special_form(name: (str | None) = None) -> bool;
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

"""
Based on Pyright's FunctionTypeFlags. These flags control how the
function type behaves during type checking.
"""
enum FunctionTypeFlags ( IntEnum ) {
    Null = 0,
    # The *args and **kwargs parameters do not need to be present for this
    # function to be compatible. This is used for Callable[..., x] (gradual typing).
    # When set, the function accepts any arguments.
    # Note: In Jac, all function parameters are typed (Any if unknown), so
    # GradualCallableForm can only come from Callable[..., T] annotations.
    GradualCallableForm = 1 << 0,
    # Function is decorated with @staticmethod
    StaticMethod = 1 << 1,
    # Function is decorated with @classmethod
    ClassMethod = 1 << 2,
    # Function is a synthesized method (e.g., dataclass __init__)
    SynthesizedMethod = 1 << 3,
}

"""Represents a function parameter."""
obj Parameter {
    has name: str,
        category: ParameterCategory,
        param_type: (TypeBase | None),
        default_value: (Expr | None) = None,
        is_self: bool = False,
        is_cls: bool = False,
        param_kind: ParamKind = ParamKind.NORMAL;
}

"""
This Type is used for both actual function definitions and for
Callable type annotations.
Callable annotations are distinguished by having an empty `func_name`.
    - `Callable[[int, str], bool]` creates a FunctionType with empty func_name.
    - `Callable[..., bool]` creates a FunctionType with GradualCallableForm flag.
"""
obj FunctionType(TypeBase) {
    has func_name: str = "",
        return_type: (TypeBase | None) = None,
        parameters: (list[Parameter] | None) = None,
        # Using int for bitwise flag operations (FunctionTypeFlags values combined)
        function_flags: int = 0;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Function;
    }

    def postinit -> None;
    def __str__ -> str;
    def specialize(class_type: ClassType) -> FunctionType;
    def _index_of_type_param(class_type: ClassType, type_var: TypeVarType) -> int;
    # --- Flag checking methods (following Pyright's pattern) ---
    """Check if this is a gradual callable form (Callable[..., T])."""
    def is_gradual_callable_form -> bool;

    """Check if this function type was created from a Callable annotation."""
    def is_from_callable_annotation -> bool;
}

"""
This is a factory function for creating FunctionType instances that
represent Callable type annotations. The resulting FunctionType has
an empty func_name to distinguish it from actual function definitions.
"""
def create_callable_type(
    param_types: list[TypeBase], return_type: TypeBase, is_gradual: bool = False
) -> FunctionType {
    parameters: list[Parameter] = [];

    # Create positional-only parameters with synthesized names
    for (idx, param_type) in enumerate(param_types) {
        parameters.append(
            Parameter(
                name=f"__p{idx}",
                category=ParameterCategory.Positional,
                param_type=param_type,
                default_value=None,
                is_self=False,
                is_cls=False,
                param_kind=ParamKind.POSONLY
            )
        );
    }

    # Set GradualCallableForm flag only for Callable[..., T] form
    flags: int = FunctionTypeFlags.GradualCallableForm
    if is_gradual
    else FunctionTypeFlags.Null;

    return FunctionType(
        func_name="",
        return_type=return_type,
        parameters=parameters,
        function_flags=flags
    );
}

"""Represents an overloaded type."""
obj OverloadedType(TypeBase) {
    has overloads: (list[FunctionType] | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Overload;
    }

    def postinit -> None;
    def __str__ -> str;
}

"""Represents a union type."""
obj UnionType(TypeBase) {
    has types: (list[TypeBase] | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Union;
    }

    def postinit -> None;
    def __str__ -> str;
}

"""Information about a specific enum member."""
obj EnumMemberInfo {
    has member_name: str,
        value_type: (TypeBase | None) = None,
        literal_value: (int | str | None) = None;
}

"""Represents a specific enum member type (e.g., Color.RED)."""
obj EnumMemberType(TypeBase) {
    has enum_class: (ClassType | None) = None,
        member_info: (EnumMemberInfo | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.EnumMember;
    }

    def __str__ -> str;
    def get_value_type -> TypeBase;
    def get_name_as_str -> str;
}
