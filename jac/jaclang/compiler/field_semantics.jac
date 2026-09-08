import from jaclang.compiler.frontend.unitree {
    AstSymbolNode,
    Bool,
    Expr,
    FuncCall,
    HasVar,
    KWPair,
    Module,
    ModuleItem,
    Name
}

obj FieldInitialization {
    has default_expr: Expr | None,
        factory_expr: Expr | None = None,
        participates_in_init: bool = True,
        keyword_only: bool = False;
}

def is_field_marker(nd: FuncCall) -> bool {
    import from jaclang.compiler.symbol_utils { erased_import_binds }
    owner = nd.parent;
    if not isinstance(owner, HasVar) or owner.value is not nd {
        return False;
    }
    tgt = nd.target;
    if not isinstance(tgt, Name) {
        return False;
    }
    if tgt.sym is not None
        and tgt.sym.decl is not None
        and not isinstance(tgt.sym.decl, ModuleItem)
        and not isinstance(tgt.sym.decl.parent, ModuleItem) {
        source = tgt.sym.decl.find_parent_of_type(Module);
        if source is not None {
            decl = tgt.sym.decl;
            return isinstance(decl, AstSymbolNode)
                and decl.sym_name == 'field'
                and source.source.file_path.replace('\\', '/').endswith(
                    '/runtime/object_model.jac'
                );
        }
    }
    return erased_import_binds(nd, tgt.sym_name, 'field');
}

def field_marker_argument(nd: FuncCall, name: str) -> (Expr | None) {
    for arg in (nd.params or []) {
        if not isinstance(arg, KWPair) or not isinstance(arg.key, Name) {
            continue;
        }
        if arg.key.sym_name == name and isinstance(arg.value, Expr) {
            return arg.value;
        }
    }
    return None;
}

def field_initialization(var: HasVar) -> FieldInitialization {
    value = var.value;
    if not isinstance(value, FuncCall) or not is_field_marker(value) {
        return FieldInitialization(default_expr=value);
    }
    init_flag = field_marker_argument(value, "init");
    keyword_flag = field_marker_argument(value, "kw_only");
    return FieldInitialization(
        default_expr=field_marker_argument(value, "default"),
        factory_expr=field_marker_argument(value, "default_factory"),
        participates_in_init=not (
            isinstance(init_flag, Bool) and not init_flag.lit_value
        ),
        keyword_only=isinstance(keyword_flag, Bool) and keyword_flag.lit_value
    );
}

def positional_field_names(fields: list[HasVar]) -> list[str] {
    names: list[str] = [];
    seen_default = False;
    for var in fields {
        initialization = field_initialization(var);
        if var.defer
            or not initialization.participates_in_init
            or initialization.keyword_only {
            continue;
        }
        defaulted = initialization.default_expr is not None
            or initialization.factory_expr is not None;
        if defaulted {
            seen_default = True;
        } elif seen_default {
            continue;
        }
        names.append(var.name.value);
    }
    return names;
}
