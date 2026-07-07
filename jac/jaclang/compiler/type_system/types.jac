import from abc { ABC }
import from enum { IntEnum, auto }
import from pathlib { Path }
import from typing { ClassVar }
import type from jaclang.jac0core.unitree { Expr, Symbol }
import type from jaclang.jac0core.unitree { UniScopeNode as SymbolTable }

enum TypeCategory(IntEnum) {
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

class TypeFlags(IntEnum) {
    with entry {
        Null = 0;
        Instantiable = 1 << 0;
        Instance = 1 << 1;
        Ambiguous = 1 << 2;
    }
}

class ParameterCategory(IntEnum) {
    with entry {
        Positional = auto();
        ArgsList = auto();
        KwargsDict = auto();
    }
}

obj TypeBase(ABC) {
    has flags: TypeFlags = TypeFlags.Null;

    with entry {
        CATEGORY: ClassVar[TypeCategory];
    }

    has category: TypeCategory { getter; }

    def mangle -> str;
    def is_instantiable -> bool;
    def is_instance -> bool;
    def is_instantiable_class -> bool;
    def is_class_instance -> bool;
    def is_any_type -> bool;
}

obj UnknownType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unknown;
    }

    has is_diagnosed: bool = False;

    def __str__ -> str;
}

obj NeverType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Never;
    }

    def __str__ -> str;
}

obj AnyType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Any;
    }

    has is_foreign: bool = False;

    def __str__ -> str;
}

obj ModuleType(TypeBase) {
    has mod_name: str = "",
        file_uri: Path = Path(""),
        symbol_table: SymbolTable | None = None,
        is_external: bool = False;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Module;
    }

    def __str__ -> str;
}

obj TypeVarType(TypeBase) {
    has name: str = "",
        is_covariant: bool = False,
        is_contravariant: bool = False,
        is_self: bool = False,
        is_param_spec: bool = False,
        is_class_type_param: bool = False,
        bound: (TypeBase | None) = None,
        constraints: (list[TypeBase] | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.TypeVar;
    }

    def __str__ -> str;
}

obj ClassType(TypeBase) {
    has _shared: (ClassType.ClassDetailsShared | None) = None,
        private: ClassType.ClassDetailsPrivate = ClassType.ClassDetailsPrivate();

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Class;
    }

    has shared: ClassType.ClassDetailsShared { getter; }

    obj ClassDetailsShared {
        has class_name: str,
            symbol_table: SymbolTable,
            mro: list[ClassType] = [],
            type_params: (list[TypeVarType] | None) = None,
            base_classes: (list[TypeBase] | None) = None,
            is_builtin_class: bool = False,
            is_from_stdlib_stub: bool = False,
            is_data_class: bool = False,
            is_namedtuple: bool = False,
            is_typeddict: bool = False,
            typeddict_fields: (dict[str, TypeBase] | None) = None,
            is_root_class: bool = False,
            is_enum_class: bool = False,
            enum_value_type: (TypeBase | None) = None,
            enum_members: (dict[str, EnumMemberInfo] | None) = None,
            _identity_key: (tuple[str, int, int, str] | None) = None;

        def postinit -> None;
        def canonical_key -> (tuple[str, int, int, str] | None);
        def same_class(other: ClassType.ClassDetailsShared) -> bool;
    }

    obj ClassDetailsPrivate {
        has type_args: (list[TypeBase] | None) = None,
            alias_name: (str | None) = None,
            literal_value: (str | int | bool | None) = None;

        def postinit -> None;
    }

    def __str__ -> str;
    def clone_as_instance -> ClassType;
    def clone_as_class -> ClassType;
    def specialize_generics(type_args: list[TypeBase]) -> ClassType;
    def get_class_symbol -> Symbol;
    def lookup_member_symbol(
        member: str, r_overloaded: list | None = None
    ) -> (Symbol | None);

    def is_builtin(class_name: (str | list[str] | None) = None) -> bool;
    def is_data_class -> bool;
    def is_namedtuple -> bool;
    def is_typeddict -> bool;
    def is_enum_class -> bool;
    def is_edge_type -> bool;
    def is_node_type -> bool;
    def is_walker_type -> bool;
    def is_special_form(name: (str | None) = None) -> bool;
    def clone_with_literal(value: (str | int | bool | None)) -> ClassType;
    def is_literal_type -> bool;
    def get_literal_value -> (str | int | bool | None);
}

class ParamKind(IntEnum) {
    with entry {
        POSONLY = 0;
        NORMAL = 1;
        VARARG = 2;
        KWONLY = 3;
        KWARG = 4;
    }
}

enum FunctionTypeFlags(IntEnum) {
    Null = 0,
    GradualCallableForm = 1 << 0,
    StaticMethod = 1 << 1,
    ClassMethod = 1 << 2,
    SynthesizedMethod = 1 << 3,
}

obj Parameter {
    has name: str,
        category: ParameterCategory,
        param_type: (TypeBase | None),
        default_value: (Expr | None) = None,
        is_self: bool = False,
        is_cls: bool = False,
        param_kind: ParamKind = ParamKind.NORMAL,
        has_default: bool = False;

    def clone -> Parameter;

    has is_optional: bool { getter; }
}

obj FunctionType(TypeBase) {
    has func_name: str = "",
        return_type: (TypeBase | None) = None,
        parameters: (list[Parameter] | None) = None,
        function_flags: int = 0,
        type_params: (list[TypeVarType] | None) = None,
        is_async: bool = False;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Function;
    }

    def postinit -> None;
    def __str__ -> str;
    def specialize(class_type: ClassType) -> FunctionType;
    def specialize_func_type_vars(solution: dict[(str, TypeBase)]) -> FunctionType;
    def is_gradual_callable_form -> bool;
    def is_from_callable_annotation -> bool;
}

def create_callable_type(
    param_types: list[TypeBase], return_type: TypeBase, is_gradual: bool = False
) -> FunctionType {
    parameters: list[Parameter] = [];

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

obj OverloadedType(TypeBase) {
    has overloads: (list[FunctionType] | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Overload;
    }

    def postinit -> None;
    def __str__ -> str;
}

obj UnionType(TypeBase) {
    has types: (list[TypeBase] | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Union;
    }

    def postinit -> None;
    def __str__ -> str;
}

obj EnumMemberInfo {
    has member_name: str,
        value_type: (TypeBase | None) = None,
        literal_value: (int | str | None) = None;
}

obj EnumMemberType(TypeBase) {
    has enum_class: (ClassType | None) = None,
        member_info: (EnumMemberInfo | None) = None;

    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.EnumMember;
    }

    def __str__ -> str;
    def get_value_type -> TypeBase;
}
