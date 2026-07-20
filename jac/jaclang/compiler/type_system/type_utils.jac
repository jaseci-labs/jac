import from enum { Enum }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.unitree { Symbol }
import from . { types }

class PropertyWriteKind(Enum) {
    with entry {
        NOT_PROPERTY = 0;
        READ_ONLY = 1;
        WRITABLE = 2;
    }
}

obj PropertyWriteResult {
    has kind: PropertyWriteKind,
        write_type: (types.TypeBase | None) = None;
}

obj ClassMember {
    has symbol: Symbol,
        class_type: types.ClassType,
        overloads: list[Symbol];
}

def compute_mro_linearization(
    cls: types.ClassType, _visiting: (set | None) = None
) -> None;

def primitive_type_name_of(ty: (types.TypeBase | None)) -> (str | None);

def expr_primitive_name(prog: any, expr_node: uni.UniNode) -> str;

obj ParamAssignmentTracker {
    has params: list[types.Parameter],
        curr_param_idx: int = 0,
        matched_params: set[types.Parameter] = set(),
        spread_filled: set[types.Parameter] = set(),
        varargs: (types.Parameter | None) = None,
        kwargs: (types.Parameter | None) = None;

    def postinit -> None;
    def lookup_named_parameter(param_name: str) -> (types.Parameter | None);
    def _mark_all_named_params_as_matched -> None;
    def _mark_all_positional_params_as_matched -> None;
    def match_named_argument(arg: uni.KWPair) -> (types.Parameter | None);
    def match_positional_argument(arg: uni.Expr) -> (types.Parameter | None);
    def get_unmatched_required_params -> list[types.Parameter];
}

obj CompletionItem {
    has label: str,
        kind: int,
        detail: (str | None) = None,
        documentation: (str | None) = None;
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

def doc_of_sym(sym: Symbol) -> (str | None);

def completion_item_from_sym(name: str, sym: Symbol) -> CompletionItem;

def completion_kind_from_sym(sym: Symbol) -> int;

def get_completion_items(
    ty: (types.TypeBase | uni.UniScopeNode)
) -> list[CompletionItem];

def lookup_symtab(
    symtable: uni.UniScopeNode, name: str, builtins_to_inject: uni.Module
) -> (Symbol | None);

def collect_member_syms(
    scope: uni.UniScopeNode, name: str, deep: bool = False
) -> list[Symbol];

def class_implements_protocol(
    cls: types.ClassType, proto: types.ClassType, evaluator: any = None
) -> bool;

def get_generator_type_args(
    return_type: types.TypeBase
) -> (list[types.TypeBase] | None);

def get_generator_yield_type(
    declared_return_type: types.TypeBase, is_async: bool
) -> (types.TypeBase | None);

def get_declared_generator_return_type(
    return_type: types.TypeBase
) -> (types.TypeBase | None);

def is_generator_family_type(return_type: types.TypeBase) -> bool;

obj ModuleSourceFlags {
    has is_stub_file: bool = False,
        is_stdlib_stub: bool = False,
        is_typing_stub: bool = False,
        is_builtin_stub: bool = False;
}

def compute_module_source_flags(file_path: str) -> ModuleSourceFlags;

def convert_to_instance(ty: types.TypeBase) -> types.TypeBase;

def synthesize_self_type_var -> types.TypeVarType;

def apply_solved_type_vars(
    ty: types.TypeBase,
    solution: dict[str, types.TypeBase],
    class_type: (types.ClassType | None) = None
) -> types.TypeBase;

def build_type_var_solution(class_type: types.ClassType) -> dict[str, types.TypeBase];

def build_solution_from_specialized_class(
    class_type: types.ClassType
) -> dict[str, types.TypeBase];

def specialize_for_base_class(
    src_type: types.ClassType, base_class: types.ClassType
) -> types.ClassType;
