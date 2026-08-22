import from enum { Enum }
import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    AstDocNode,
    ElseIf,
    ElseStmt,
    Enum as UniEnum,
    Expr,
    HasVar,
    IfStmt,
    KWPair,
    Module,
    ModulePath,
    Symbol,
    UnaryExpr,
    UniNode,
    UniScopeNode
}
import from jaclang.jac0core.constant { Tokens as Tok }
import from .types {
    AnyType,
    ClassType,
    FunctionType,
    ModuleType,
    ParamKind,
    Parameter,
    TypeBase,
    TypeVarType,
    UnionType,
    UnknownType
}

class PropertyWriteKind(Enum) {
    with entry {
        NOT_PROPERTY = 0;
        READ_ONLY = 1;
        WRITABLE = 2;
    }
}

obj PropertyWriteResult {
    has kind: PropertyWriteKind,
        write_type: (TypeBase | None) = None;
}

obj ClassMember {
    has symbol: Symbol,
        class_type: ClassType,
        overloads: list[Symbol];
}

def compute_mro_linearization(cls: ClassType, _visiting: (set | None) = None) -> None;

def primitive_type_name_of(ty: (TypeBase | None)) -> (str | None);

def expr_primitive_name(prog: object, expr_node: UniNode) -> str;

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

enum CompletionItemKind {
    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
    Unit = 11,
    Value = 12,
    Enum = 13,
    Keyword = 14,
    Snippet = 15,
    Color = 16,
    File = 17,
    Reference = 18,
    Folder = 19,
    EnumMember = 20,
    Constant = 21,
    Struct = 22,
    Event = 23,
    Operator = 24,
    TypeParameter = 25,
}

obj CompletionItem {
    has label: str,
        kind: CompletionItemKind,
        detail: (str | None) = None,
        documentation: (str | None) = None;
}

def doc_of_sym(sym: Symbol) -> (str | None);

def completion_item_from_sym(name: str, sym: Symbol) -> CompletionItem;

def completion_kind_from_sym(sym: Symbol) -> CompletionItemKind;

def get_completion_items(ty: (TypeBase | UniScopeNode)) -> list[CompletionItem];

def lookup_symtab(
    symtable: UniScopeNode, name: str, builtins_to_inject: Module
) -> (Symbol | None);

def collect_member_syms(
    scope: UniScopeNode, name: str, deep: bool = False
) -> list[Symbol];

def class_implements_protocol(
    cls: ClassType, proto: ClassType, evaluator: any = None
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
