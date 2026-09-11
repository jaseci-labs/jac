import type from jaclang.compiler.types.type_evaluator { TypeEvaluator }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    AtomTrailer,
    ElseIf,
    ElseStmt,
    Expr,
    HasVar,
    IfStmt,
    Import,
    ImplDef,
    KWPair,
    Module,
    ModuleItem,
    Name,
    ModulePath,
    Symbol,
    UnaryExpr,
    UniNode,
    UniScopeNode
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from .types {
    NeverType,
    EnumMemberType,
    AnyType,
    ClassType,
    FunctionType,
    ParamKind,
    Parameter,
    TypeBase,
    TypeVarType,
    UnionType,
    UnknownType
}

enum PropertyWriteKind { NOT_PROPERTY = 0, READ_ONLY = 1, WRITABLE = 2, }

obj PropertyWriteResult {
    has kind: PropertyWriteKind,
        write_type: (TypeBase | None) = None;
}

obj ClassMember {
    has symbol: Symbol,
        class_type: ClassType,
        overloads: list[Symbol];
}

def compute_mro_linearization(
    cls: ClassType, _visiting: (set[int] | None) = None
) -> None;

def linearize_mro(
    cls: ClassType, _visiting: (set[int] | None) = None
) -> list[ClassType];

def mro_signature(cls: ClassType) -> tuple;

def ensure_mro_fresh(cls: ClassType, _visiting: (set[int] | None) = None) -> bool;

def primitive_type_name_of(ty: (TypeBase | None)) -> (str | None);

def expr_primitive_name(expr_node: UniNode) -> str;

obj ParamAssignmentTracker {
    has params: list[Parameter],
        curr_param_idx: int = 0,
        matched_params: set[Parameter] = set(),
        spread_filled: set[Parameter] = set(),
        varargs: (Parameter | None) = None,
        kwargs: (Parameter | None) = None;

    def postinit -> None;
    def lookup_named_parameter(param_name: str) -> (Parameter | None);
    def _mark_all_named_params_as_matched -> None;
    def _mark_all_positional_params_as_matched -> None;
    def match_named_argument(arg: KWPair) -> (Parameter | None);
    def match_positional_argument(arg: Expr) -> (Parameter | None);
    def get_unmatched_required_params -> list[Parameter];
}

def lookup_symtab(
    symtable: UniScopeNode, name: str, builtins_to_inject: Module | None
) -> (Symbol | None);

def types_equivalent(a: TypeBase, b: TypeBase, depth: int = 0) -> bool;

def origin_of_local_name(nd: UniNode, local: str) -> tuple[str, (str | None)];

def collect_member_syms(
    scope: UniScopeNode, name: str, deep: bool = False
) -> list[Symbol];

def class_implements_protocol(
    cls: ClassType, proto: ClassType, evaluator: TypeEvaluator | None = None
) -> bool;

def get_generator_type_args(return_type: TypeBase) -> (list[TypeBase] | None);

def get_generator_yield_type(
    declared_return_type: TypeBase, is_async: bool
) -> (TypeBase | None);

def get_declared_generator_return_type(return_type: TypeBase) -> (TypeBase | None);

def is_generator_family_type(return_type: TypeBase) -> bool;

obj ModuleSourceFlags {
    has is_stub_file: bool = False,
        is_stdlib_stub: bool = False,
        is_typing_stub: bool = False,
        is_builtin_stub: bool = False;
}

def compute_module_source_flags(file_path: str) -> ModuleSourceFlags;

def convert_to_instance(ty: TypeBase) -> TypeBase;

def synthesize_self_type_var -> TypeVarType;

def apply_solved_type_vars(
    ty: TypeBase,
    solution: dict[str, TypeBase],
    class_type: (ClassType | None) = None,
    shadowed: (set[str] | None) = None
) -> TypeBase;

def build_type_var_solution(class_type: ClassType) -> dict[str, TypeBase];

def shadowed_type_var_names(
    solution: dict[str, TypeBase], declaring_class: (ClassType | None)
) -> (set[str] | None);

def build_solution_from_specialized_class(
    class_type: ClassType
) -> dict[str, TypeBase];

def specialize_for_base_class(src_type: ClassType, base_class: ClassType) -> ClassType;
