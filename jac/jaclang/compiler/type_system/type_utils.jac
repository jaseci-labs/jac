"""
Functions that operate on Type objects.

PyrightReference: packages/pyright-internal/src/analyzer/typeUtils.ts
"""
import from enum { Enum }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.unitree { Symbol }
import from . { types }
"""Represents a member of a class."""
obj ClassMember {
    has symbol: Symbol,
        class_type: types.ClassType,
        overloads: list[Symbol],
        is_instance_member: bool = True,
        is_class_member: bool = False,
        is_slots_member: bool = False,
        is_class_var: bool = False,
        is_read_only: bool = False,
        is_type_declared: bool = False,
        skipped_undeclared_type: bool = False;
}

def compute_mro_linearization(cls: types.ClassType) -> None;

"""
Tracks parameter assignments for function calls.

    This class helps in tracking which parameters have been matched
    with arguments in a function call. It supports positional, named,
    *args, and **kwargs arguments.
"""
obj ParamAssignmentTracker {
    has params: list[types.Parameter],
        curr_param_idx: int = 0,
        matched_params: set[types.Parameter] = set(),
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

"""A completion item."""
obj CompletionItem {
    has label: str,
        kind: int,
        detail: (str | None) = None;
}

"""The kind of a completion entry."""
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

def completion_kind_from_sym(sym: Symbol) -> int;

def get_completion_items(
    ty: (types.TypeBase | uni.UniScopeNode)
) -> list[CompletionItem];

def lookup_symtab(
    symtable: uni.UniScopeNode, name: str, builtins_to_inject: uni.Module
) -> (Symbol | None);

def class_implements_protocol(cls: types.ClassType, proto: types.ClassType) -> bool;
