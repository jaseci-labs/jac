"""Functions that operate on Type objects.\n\nPyrightReference: packages/pyright-internal/src/analyzer/typeUtils.ts\n"""
import from dataclasses { dataclass }
import from enum { Enum }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.unitree { Symbol }
import from . { types }
"""Represents a member of a class."""
class ClassMember {
    """Initialize obviously."""
    def init(self: ClassMember, symbol: Symbol, class_type: types.ClassType) -> None {
        self.symbol = symbol;
        self.class_type = class_type;
        self.is_instance_member = True;
        self.is_class_member = False;
        self.is_slots_member = False;
        self.is_class_var = False;
        self.is_read_only = False;
        self.is_type_declared = False;
        self.skipped_undeclared_type = False;
    }
}

"""Compute the method resolution order (MRO) for a class type.\n\n    This uses the C3 linearization algorithm to compute the MRO.\n    See https://www.python.org/download/releases/2.3/mro/\n    """
def compute_mro_linearization(cls: types.ClassType) -> None {
    if cls.shared.mro {
        return;
    }
    cls.shared.mro.append(cls);
    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            compute_mro_linearization(base);
        }
    }
    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            for mro_cls in base.shared.mro {
                if (mro_cls not in cls.shared.mro) {
                    cls.shared.mro.append(mro_cls);
                }
            }
        }
    }
}

"""Tracks parameter assignments for function calls.\n\n    This class helps in tracking which parameters have been matched\n    with arguments in a function call. It supports positional, named,\n    *args, and **kwargs arguments.\n    """
class ParamAssignmentTracker {
    """Initialize obviously."""
    def init(self: ParamAssignmentTracker, params: list[types.Parameter]) -> None {
        self.params = params;
        self.curr_param_idx = 0;
        self.matched_params: set[types.Parameter] = <>set();
        self.varargs: (types.Parameter | None) = None;
        self.kwargs: (types.Parameter | None) = None;
        for param in self.params {
            if (param.param_kind == types.ParamKind.VARARG) {
                self.varargs = param;
            } elif (param.param_kind == types.ParamKind.KWARG) {
                self.kwargs = param;
            }
        }
    }

    """Lookup a named parameter by name and if any match is found we mark it as such."""
    def lookup_named_parameter(
        self: ParamAssignmentTracker, param_name: str
    ) -> (types.Parameter | None) {
        for param in self.params {
            if (
                (param.param_kind == types.ParamKind.POSONLY)
                and (param_name == param.name)
            ) {
                self.matched_params.add(param);
                raise Exception(
                    f"Positional only parameter '{param.name}' cannot be matched with a named argument"
                ) ;
            }
            if (
                param.param_kind not in (
                    types.ParamKind.NORMAL,
                    types.ParamKind.KWONLY
                )
            ) {
                continue;
            }
            if (param.name == param_name) {
                if (param in self.matched_params) {
                    raise Exception(f"Parameter '{param.name}' already matched") ;
                }
                self.matched_params.add(param);
                return param;
            }
        }
        return self.kwargs;
    }

    """Mark all named parameters as matched."""
    def _mark_all_named_params_as_matched(self: ParamAssignmentTracker) -> None {
        for param in self.params {
            if (
                param.param_kind in (
                    types.ParamKind.NORMAL,
                    types.ParamKind.KWONLY,
                    types.ParamKind.KWARG
                )
            ) {
                self.matched_params.add(param);
            }
        }
    }

    """Mark all positional parameters as matched."""
    def _mark_all_positional_params_as_matched(self: ParamAssignmentTracker) -> None {
        for param in self.params {
            if (
                param.param_kind in (
                    types.ParamKind.POSONLY,
                    types.ParamKind.NORMAL,
                    types.ParamKind.VARARG
                )
            ) {
                self.matched_params.add(param);
            }
        }
        self.curr_param_idx = -1;
    }

    """Match a named argument to a parameter."""
    def match_named_argument(
        self: ParamAssignmentTracker, arg: uni.KWPair
    ) -> (types.Parameter | None) {
        if (arg.key is None) {
            self._mark_all_named_params_as_matched();
            return None;
        } else {
            if (param := self.lookup_named_parameter(arg.key.sym_name)) {
                return param;
            }
            raise Exception(
                f"Named argument '{arg.key.sym_name}' does not match any parameter"
            ) ;
        }
    }

    """Match a positional argument to a parameter."""
    def match_positional_argument(
        self: ParamAssignmentTracker, arg: uni.Expr
    ) -> (types.Parameter | None) {
        if (self.curr_param_idx == -1) {
            return self.varargs;
        }
        if (isinstance(arg, uni.UnaryExpr) and (arg.op.name == Tok.STAR_MUL)) {
            self._mark_all_positional_params_as_matched();
            return None;
        } else {
            if (self.curr_param_idx < len(self.params)) {
                param = self.params[self.curr_param_idx];
                if (param.param_kind == types.ParamKind.VARARG) {
                    self.matched_params.add(param);
                    return param;
                }
                if (
                    param.param_kind in (
                        types.ParamKind.NORMAL,
                        types.ParamKind.POSONLY
                    )
                ) {
                    self.curr_param_idx += 1;
                    self.matched_params.add(param);
                    return param;
                }
            }
            raise Exception('Too many positional arguments') ;
        }
    }

    """Check if there are any unmatched required parameters."""
    def get_unmatched_required_params(
        self: ParamAssignmentTracker
    ) -> list[types.Parameter] {
        ret: list[types.Parameter] = [];
        for param in self.params {
            if (
                (param not in self.matched_params)
                and (param.default_value is None)
                and (
                    param.param_kind not in (
                        types.ParamKind.VARARG,
                        types.ParamKind.KWARG
                    )
                )
            ) {
                ret.append(param);
            }
        }
        return ret;
    }
}

"""A completion item."""
@dataclass
class CompletionItem {
    with entry {
        label: str;
        kind: int;
        detail: (str | None) = None;
    }
}

"""The kind of a completion entry."""
class CompletionItemKind(int , Enum) {
    with entry {
        Text = 1;
        Method = 2;
        Function = 3;
        Constructor = 4;
        Field = 5;
        Variable = 6;
        Class = 7;
        Interface = 8;
        Module = 9;
        Property = 10;
        Unit = 11;
        Value = 12;
        Enum = 13;
        Keyword = 14;
        Snippet = 15;
        Color = 16;
        File = 17;
        Reference = 18;
        Folder = 19;
        EnumMember = 20;
        Constant = 21;
        Struct = 22;
        Event = 23;
        Operator = 24;
        TypeParameter = 25;
    }
}

"""Get the completion item kind from a symbol."""
def completion_kind_from_sym(sym: Symbol) -> int {
    match sym.decl.name_of {
        case uni.ModulePath():
            return CompletionItemKind.Module;

        case uni.Ability():
            return CompletionItemKind.Function;

        case uni.Archetype():
            return CompletionItemKind.Class;

        case uni.Enum():
            return CompletionItemKind.Enum;

        case uni.HasVar():
            return CompletionItemKind.Variable;

    }
    return CompletionItemKind.Text;
}

"""Return a list of completion items for the type."""
def get_completion_items(
    ty: (types.TypeBase | uni.UniScopeNode)
) -> list[CompletionItem] {
    ret = [];
    if isinstance(ty, uni.UniScopeNode) {
        scope: (uni.UniScopeNode | None) = ty;
        while scope {
            for (name, sym) in scope.names_in_scope.items() {
                kind = completion_kind_from_sym(sym);
                ret.append(CompletionItem(label=name, kind=kind));
            }
            scope = scope.parent_scope;
        }
    } elif isinstance(ty, types.ClassType) {
        if not ty.shared.mro {
            compute_mro_linearization(ty);
        }
        for cls in ty.shared.mro {
            for (name, sym) in cls.shared.symbol_table.names_in_scope.items() {
                kind = completion_kind_from_sym(sym);
                ret.append(CompletionItem(label=name, kind=kind));
            }
        }
    } elif isinstance(ty, types.ModuleType) {
        for (name, sym) in ty.symbol_table.names_in_scope.items() {
            kind = completion_kind_from_sym(sym);
            ret.append(CompletionItem(label=name, kind=kind));
        }
    }
    return ret;
}

"""Lookup a symbol in the symbol table."""
def lookup_symtab(
    symtable: uni.UniScopeNode, name: str, builtins_to_inject: uni.Module
) -> (Symbol | None) {
    mod: (uni.Module | None) = None;
    if isinstance(symtable, uni.Module) {
        mod = symtable;
    } else {
        mod = symtable.find_parent_of_type(uni.Module);
    }
    if (mod and ((mod.parent_scope is None) and (mod != builtins_to_inject))) {
        mod.parent_scope = builtins_to_inject;
    }
    return symtable.lookup(name, deep=True, incl_inner_scope=True);
}

"""Determine if a class implements a protocol.

This is a placeholder function and should be implemented based on
the specific requirements for protocol conformance checking.
"""
def class_implements_protocol(cls: types.ClassType, proto: types.ClassType) -> bool {
    cls_ast: uni.Archetype = cls.shared.symbol_table;
    proto_ast: uni.Archetype = proto.shared.symbol_table;

    # FIXME: For now I'm only checking if method names are equal
    # However we need to check the full signature compatibility.
    cls_method_names = {method.sym_name for method in cls_ast.get_methods()};
    proto_method_names = {method.sym_name for method in proto_ast.get_methods()};
    return proto_method_names.issubset(cls_method_names);
}
