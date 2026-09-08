import from enum { IntEnum, auto }
import from pathlib { Path }
import type from jaclang.compiler.frontend.unitree { Expr, Symbol }
import type from jaclang.compiler.frontend.unitree { UniScopeNode as SymbolTable }
import from jaclang.compiler.frontend.relations {
    BaseOf,
    BoundOf,
    ConstraintOf,
    DeclScopeOf,
    EnumClassOf,
    EnumMemberOf,
    GuardOf,
    MemberInfoOf,
    MroOf,
    OverloadOf,
    ParamDefaultOf,
    ParamOf,
    ParamTypeOf,
    PrivOf,
    ReturnsOf,
    SharedOf,
    TypeArgOf,
    TypeMemberOf,
    TypeParamOf,
    UnionMemberOf,
    ValueTypeOf
}

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

node TypeBase {
    has flags: TypeFlags = TypeFlags.Null,
        _acc_cache: (dict[str, any] | None) = None;

    static has CATEGORY: TypeCategory;
    has category: TypeCategory { getter; }

    def mangle -> str;
    def is_instantiable -> bool;
    def is_instance -> bool;
    def is_instantiable_class -> bool;
    def is_class_instance -> bool;
    def is_any_instance -> bool;
    def is_any_type -> bool;
}

node UnknownType(TypeBase) {
    static has CATEGORY: TypeCategory = TypeCategory.Unknown;
    has is_diagnosed: bool = False,
        is_incomplete: bool = False;

    def __str__ -> str;
}

node NeverType(TypeBase) {
    static has CATEGORY: TypeCategory = TypeCategory.Never;

    def __str__ -> str;
}

node AnyType(TypeBase) {
    static has CATEGORY: TypeCategory = TypeCategory.Any;
    has is_foreign: bool = False,
        foreign_scalar: (str | None) = None;

    def __str__ -> str;
}

node ModuleType(TypeBase) {
    has mod_name: str = "",
        file_uri: Path = Path(""),
        is_external: bool = False;

    static has CATEGORY: TypeCategory = TypeCategory.Module;
    has symbol_table: (SymbolTable | None) {
        getter;
        setter(symbol_table: (SymbolTable | None));
    }

    def init(
        *,
        mod_name: str = "",
        file_uri: Path = Path(""),
        symbol_table: (SymbolTable | None) = None,
        is_external: bool = False,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def __str__ -> str;
}

node TypeVarType(TypeBase) {
    has name: str = "",
        is_covariant: bool = False,
        is_contravariant: bool = False,
        is_self: bool = False,
        is_param_spec: bool = False,
        is_class_type_param: bool = False;

    static has CATEGORY: TypeCategory = TypeCategory.TypeVar;
    has bound: (TypeBase | None) { getter; setter(bound: (TypeBase | None)); }
    has constraints: list[TypeBase] {
        getter;
        setter(constraints: (list[TypeBase] | None));
    }

    def init(
        *,
        name: str = "",
        is_covariant: bool = False,
        is_contravariant: bool = False,
        is_self: bool = False,
        is_param_spec: bool = False,
        is_class_type_param: bool = False,
        bound: (TypeBase | None) = None,
        constraints: (list[TypeBase] | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def __str__ -> str;
}

node ClassDetailsShared {
    has class_name: str = "",
        is_builtin_class: bool = False,
        is_from_stdlib_stub: bool = False,
        is_data_class: bool = False,
        is_namedtuple: bool = False,
        is_typeddict: bool = False,
        is_root_class: bool = False,
        is_enum_class: bool = False,
        _identity_key: (tuple[str, int, int, str] | None) = None,
        _derived_special_types: (dict[str, ClassType] | None) = None,
        ct_params: (list[str] | None) = None,
        _mro_cache: (list[ClassType] | None) = None,
        _acc_cache: (dict[str, any] | None) = None;

    has symbol_table: SymbolTable { getter; setter(symbol_table: SymbolTable); }
    has mro: list[ClassType] { getter; setter(mro: list[ClassType]); }
    has type_params: list[TypeVarType] {
        getter;
        setter(type_params: (list[TypeVarType] | None));
    }

    has base_classes: list[TypeBase] {
        getter;
        setter(base_classes: (list[TypeBase] | None));
    }

    has typeddict_fields: dict[str, TypeBase] {
        getter;
        setter(typeddict_fields: (dict[str, TypeBase] | None));
    }

    has enum_value_type: (TypeBase | None) {
        getter;
        setter(enum_value_type: (TypeBase | None));
    }

    has enum_members: dict[str, EnumMemberInfo] {
        getter;
        setter(enum_members: (dict[str, EnumMemberInfo] | None));
    }

    def init(
        *,
        class_name: str,
        symbol_table: SymbolTable,
        mro: (list[ClassType] | None) = None,
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
        _identity_key: (tuple[str, int, int, str] | None) = None,
        _derived_special_types: (dict[str, ClassType] | None) = None,
        ct_params: (list[str] | None) = None
    ) -> None;

    def canonical_key -> (tuple[str, int, int, str] | None);
    def same_class(other: ClassDetailsShared) -> bool;
}

node ClassDetailsPrivate {
    has ct_args: (dict[str, any] | None) = None,
        alias_name: (str | None) = None,
        literal_value: (str | int | bool | None) = None,
        distinct_key: (str | None) = None,
        _targs_cache: (list[TypeBase] | None) = None,
        _acc_cache: (dict[str, any] | None) = None;

    has type_args: list[TypeBase] {
        getter;
        setter(type_args: (list[TypeBase] | None));
    }

    def init(
        *,
        type_args: (list[TypeBase] | None) = None,
        ct_args: (dict[str, any] | None) = None,
        alias_name: (str | None) = None,
        literal_value: (str | int | bool | None) = None,
        distinct_key: (str | None) = None
    ) -> None;
}

node ClassType(TypeBase) {
    static has CATEGORY: TypeCategory = TypeCategory.Class;
    has _shared: (ClassDetailsShared | None) {
        getter;
        setter(_shared: (ClassDetailsShared | None));
    }

    has private: ClassDetailsPrivate { getter; setter(private: ClassDetailsPrivate); }
    has shared: ClassDetailsShared { getter; }

    def init(
        *,
        _shared: (ClassDetailsShared | None) = None,
        private: (ClassDetailsPrivate | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def __str__ -> str;
    def clone_as_instance -> ClassType;
    def clone_as_class -> ClassType;
    def specialize_generics(type_args: list[TypeBase]) -> ClassType;
    def get_class_symbol -> (Symbol | None);
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

node Parameter {
    has _acc_cache: (dict[str, any] | None) = None,
        name: str = "",
        category: (ParameterCategory | None) = None,
        is_self: bool = False,
        is_cls: bool = False,
        param_kind: ParamKind = ParamKind.NORMAL,
        has_default: bool = False,
        is_comptime: bool = False;

    has param_type: (TypeBase | None) {
        getter;
        setter(param_type: (TypeBase | None));
    }

    has default_value: (Expr | None) { getter; setter(default_value: (Expr | None)); }

    def init(
        *,
        name: str,
        category: (ParameterCategory | None),
        param_type: (TypeBase | None),
        default_value: (Expr | None) = None,
        is_self: bool = False,
        is_cls: bool = False,
        param_kind: ParamKind = ParamKind.NORMAL,
        has_default: bool = False,
        is_comptime: bool = False
    ) -> None;

    def clone -> Parameter;

    has is_optional: bool { getter; }
}

node FunctionType(TypeBase) {
    has func_name: str = "",
        function_flags: int = 0,
        is_async: bool = False,
        type_guard_is_strict: bool = False,
        _params_cache: (list[Parameter] | None) = None;

    static has CATEGORY: TypeCategory = TypeCategory.Function;
    has return_type: (TypeBase | None) {
        getter;
        setter(return_type: (TypeBase | None));
    }

    has parameters: list[Parameter] {
        getter;
        setter(parameters: (list[Parameter] | None));
    }

    has type_params: list[TypeVarType] {
        getter;
        setter(type_params: (list[TypeVarType] | None));
    }

    has type_guard: (TypeBase | None) {
        getter;
        setter(type_guard: (TypeBase | None));
    }

    def init(
        *,
        func_name: str = "",
        return_type: (TypeBase | None) = None,
        parameters: (list[Parameter] | None) = None,
        function_flags: int = 0,
        type_params: (list[TypeVarType] | None) = None,
        is_async: bool = False,
        type_guard: (TypeBase | None) = None,
        type_guard_is_strict: bool = False,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

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

node OverloadedType(TypeBase) {
    static has CATEGORY: TypeCategory = TypeCategory.Overload;
    has overloads: list[FunctionType] {
        getter;
        setter(overloads: (list[FunctionType] | None));
    }

    def init(
        *,
        overloads: (list[FunctionType] | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def __str__ -> str;
}

node UnionType(TypeBase) {
    static has CATEGORY: TypeCategory = TypeCategory.Union;
    has types: list[TypeBase] { getter; setter(types: (list[TypeBase] | None)); }

    def init(
        *, types: (list[TypeBase] | None) = None, flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def __str__ -> str;
}

node EnumMemberInfo {
    has _acc_cache: (dict[str, any] | None) = None,
        member_name: str = "",
        literal_value: (int | str | None) = None;

    has value_type: (TypeBase | None) {
        getter;
        setter(value_type: (TypeBase | None));
    }

    def init(
        *,
        member_name: str,
        value_type: (TypeBase | None) = None,
        literal_value: (int | str | None) = None
    ) -> None;
}

node EnumMemberType(TypeBase) {
    static has CATEGORY: TypeCategory = TypeCategory.EnumMember;
    has enum_class: (ClassType | None) {
        getter;
        setter(enum_class: (ClassType | None));
    }

    has member_info: (EnumMemberInfo | None) {
        getter;
        setter(member_info: (EnumMemberInfo | None));
    }

    def init(
        *,
        enum_class: (ClassType | None) = None,
        member_info: (EnumMemberInfo | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None;

    def __str__ -> str;
    def get_value_type -> TypeBase;
}
