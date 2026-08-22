import from pathlib { Path }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    ContextAwareNode,
    ElementStmt,
    Enum as UniEnum,
    Expr,
    FuncCall,
    FuncSignature,
    GlobalVars,
    HasVar,
    Import,
    KWPair,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    NameAtom,
    ParamVar,
    SubTag,
    Symbol,
    UniNode,
    UniScopeNode
}
import from jaclang.jac0core.constant {
    CodeContext,
    JS_HOST_CONSTRUCTORS,
    Tokens as Tok,
    SymbolType
}
import from jaclang.jac0core.diagnostics { E5082, E5084, W6006, W6007 }
import from jaclang.jac0core.compiler {
    ClientImportVerdict,
    ability_of_symbol,
    classify_client_import_item,
    is_client_boundary_import,
    symbol_linked_source_module
}
import from jaclang.compiler.expr_keys {
    classify_condition_key,
    collect_assigned_symbols,
    collect_assignment_target_keys,
    collect_narrowing_symbols,
    find_destructure_index_path,
    get_expr_key,
    int_subscript_suffix,
    reference_key_deps
}

enum CallKind {
    METHOD = "method",
    INSTANTIATION = "instantiation",
    BUILTIN = "builtin",
    CLIB = "clib",
    FUNCTION = "function",
    INTRINSIC = "intrinsic"
}

def erased_import_binds(nd: UniNode, name: str) -> bool {
    import from jaclang.jac0core.codeinfo { NATIVE_ERASED_IMPORTS }
    mod = nd.find_parent_of_type(Module);
    if mod is None {
        return False;
    }
    for imp in mod.get_all_sub_nodes(Import) {
        if imp.from_loc is None or imp.is_absorb {
            continue;
        }
        allowed = NATIVE_ERASED_IMPORTS.get(imp.from_loc.dot_path_str.lstrip('.'));
        if allowed is None or name not in allowed {
            continue;
        }
        for item in imp.items {
            if not isinstance(item, ModuleItem) {
                continue;
            }
            bound = item.alias if item.alias is not None else item.name;
            if isinstance(bound, Name) and bound.value == name {
                return True;
            }
        }
    }
    return False;
}

def erased_identity_call_arg(nd: FuncCall) -> (Expr | None) {
    import from jaclang.jac0core.codeinfo { NATIVE_ERASED_IDENTITY_CALLS }
    tgt = nd.target;
    if not isinstance(tgt, Name) or tgt.sym_name not in NATIVE_ERASED_IDENTITY_CALLS {
        return None;
    }
    params = nd.params or [];
    if len(params) != 2
        or not isinstance(params[0], Expr)
        or not isinstance(params[1], Expr) {
        return None;
    }
    if not erased_import_binds(nd, tgt.sym_name) {
        return None;
    }
    return params[1];
}

def is_erased_field_marker(nd: FuncCall) -> bool {
    import from jaclang.jac0core.codeinfo { NATIVE_ERASED_FIELD_MARKERS }
    owner = nd.parent;
    if not isinstance(owner, HasVar) or owner.value is not nd {
        return False;
    }
    tgt = nd.target;
    if not isinstance(tgt, Name) or tgt.sym_name not in NATIVE_ERASED_FIELD_MARKERS {
        return False;
    }
    return erased_import_binds(nd, tgt.sym_name);
}

def erased_field_marker_default(nd: FuncCall) -> (Expr | None) {
    for arg in (nd.params or []) {
        if not isinstance(arg, KWPair) or not isinstance(arg.key, Name) {
            continue;
        }
        if arg.key.sym_name == 'default' and isinstance(arg.value, Expr) {
            return arg.value;
        }
    }
    return None;
}

def resolve_expr_symbol(expr: Expr, module: (Module | None) = None) -> (Symbol | None) {
    if isinstance(expr, AstSymbolNode) and expr.sym {
        return expr.sym;
    }

    if isinstance(expr, AtomTrailer) {
        attrs = expr.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, AstSymbolNode) and last.sym {
                return last.sym;
            }
        }
    }

    if module is not None and isinstance(expr, Name) {
        return module.lookup(expr.sym_name);
    }
    return None;
}

def _is_user_symbol(sym: Symbol) -> bool {
    scope: (UniScopeNode | None) = sym.parent_tab;
    while scope is not None {
        if isinstance(scope, Module) {
            if scope.stub_only {
                return False;
            }
            return not scope.source.file_path.endswith(".pyi");
        }
        scope = scope.parent_scope;
    }
    return False;
}

def _symbol_defining_module(sym: Symbol) -> (Module | None) {
    decl = sym.decl;
    if decl is None {
        return None;
    }
    return decl.find_parent_of_type(Module);
}

def _is_local_user_shadow(sym: Symbol, call: FuncCall) -> bool {
    if not _is_user_symbol(sym) {
        return False;
    }
    call_mod = call.find_parent_of_type(Module);
    sym_mod = _symbol_defining_module(sym);
    return call_mod is not None and sym_mod is call_mod;
}

def intrinsic_registry_if_ready -> object | None {
    import sys;
    _mod = sys.modules.get("jaclang.compiler.intrinsic_registry");
    if _mod is not None and _mod?.INTRINSIC_REGISTRY is None {
        return None;
    }
    import from jaclang.compiler.intrinsic_registry { INTRINSIC_REGISTRY }
    return INTRINSIC_REGISTRY;
}

def classify_call(nd: FuncCall) -> CallKind {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

    if isinstance(nd.target, AtomTrailer) and nd.target.is_attr {
        return CallKind.METHOD;
    }

    intrinsics = intrinsic_registry_if_ready();
    if intrinsics is not None
        and isinstance(nd.target, Name)
        and intrinsics.is_intrinsic(nd.target.sym_name) {
        return CallKind.INTRINSIC;
    }

    sym = resolve_expr_symbol(nd.target);

    if sym is not None
        and sym.decl is not None
        and sym.sym_type
            not in (
                SymbolType.OBJECT_ARCH,
                SymbolType.NODE_ARCH,
                SymbolType.EDGE_ARCH,
                SymbolType.WALKER_ARCH,
                SymbolType.ENUM_ARCH
            ) {
        _imp = sym.decl.find_parent_of_type(Import);
        if _imp is not None and _imp.clib_decls {
            return CallKind.CLIB;
        }
    }
    if sym is not None and _is_local_user_shadow(sym, nd) {
        if sym.sym_type
            in (
                SymbolType.OBJECT_ARCH,
                SymbolType.NODE_ARCH,
                SymbolType.EDGE_ARCH,
                SymbolType.WALKER_ARCH,
                SymbolType.ENUM_ARCH
            ) {
            return CallKind.INSTANTIATION;
        }
        return CallKind.FUNCTION;
    }

    if isinstance(nd.target, Name)
        and JAC_TYPE_REGISTRY.is_builtin(nd.target.sym_name) {
        return CallKind.BUILTIN;
    }
    return CallKind.FUNCTION;
}

def symbol_owner_archetype(sym: Symbol) -> (Archetype | None) {
    decl = sym.decl;
    if decl is None {
        return None;
    }
    owner = decl?.name_of;
    if isinstance(owner, Archetype) {
        return owner;
    }
    return None;
}

def collect_field_names(
    sym: (Symbol | None), arch_type_filter: (str | None) = None
) -> list[str] {
    if not sym {
        return [];
    }
    arch = symbol_owner_archetype(sym);
    if arch is None {
        return [];
    }
    if arch_type_filter is not None and arch.arch_type.name != arch_type_filter {
        return [];
    }
    return [field.sym_name for field in arch.get_has_vars()];
}

def collect_method_names(arch: Archetype) -> set[str] {
    import from jaclang.compiler.passes.main.layout_pass { archetype_accessors }
    names: set[str] = set();
    if arch.body is not None and isinstance(arch.body, Sequence) {
        for stmt in arch.body {
            if isinstance(stmt, Ability) {
                mn = stmt.name_ref.sym_name if stmt.name_ref else None;
                if mn is not None {
                    names.add(mn);
                }
            }
        }
    }

    for (slot_name, _var, _acc) in archetype_accessors(arch) {
        names.add(slot_name);
    }
    return names;
}

def is_js_host_constructor_call(nd: FuncCall) -> bool {
    if not nd.in_client_context() {
        return False;
    }
    if not isinstance(nd.target, Name) {
        return False;
    }
    if nd.target.sym_name == "new" {
        return False;
    }

    if nd.target.sym is not None and _is_user_symbol(nd.target.sym) {
        return False;
    }

    return nd.target.sym_name in JS_HOST_CONSTRUCTORS;
}

def resolve_importer_path_from_node(nd: UniNode) -> (str | None) {
    importer_mod = nd.find_parent_of_type(Module);
    if (
        importer_mod is None
        or importer_mod.source is None
        or not importer_mod.source.file_path
    ) {
        return None;
    }
    try {
        return str(Path(importer_mod.source.file_path).resolve());
    } except OSError {
        return None;
    }
}

def resolve_import_source_module(prog: any, nd: Import) -> (Module | None) {
    if not nd.from_loc {
        return None;
    }
    resolved_path = nd.from_loc.resolve_relative_path();
    if not Path(resolved_path).exists() {
        return None;
    }
    importer_path = resolve_importer_path_from_node(nd);
    saved_opts = prog?._compile_options;
    try {
        return prog.load_dependency_module(resolved_path, importer_path=importer_path);
    } finally {
        if saved_opts is not None {
            prog._compile_options = saved_opts;
        }
    }
}

def import_target_pinned_server(nd: Import) -> bool {
    if nd.from_loc is None {
        return False;
    }
    try {
        target = nd.from_loc.resolve_relative_path();
        if isinstance(target, str) and target.endswith('.jac') {
            import from jaclang.jac0core.placement_facts { pinned_module_space }
            return pinned_module_space(target) == 'server';
        }
    } except Exception {
        return False;
    }
    return False;
}

def decl_has_access(source_mod: Module, item: ModuleItem) -> bool {
    nm = item.name.value if isinstance(item.name, Name) else '';
    if not nm or source_mod.sym_tab is None {
        return False;
    }
    sym = source_mod.sym_tab.lookup(nm, deep=True);
    if not (sym and sym.defn) {
        return False;
    }
    decl = sym.defn[0];
    owner = decl.parent if (isinstance(decl, NameAtom) and decl.parent) else decl;
    return owner?.access is not None;
}

def _already_reported(reporter: any, diag: any, nd: UniNode) -> bool {
    for pool in (
        reporter.prog.errors_had,
        reporter.prog.warnings_had,
        reporter.errors_had,
        reporter.warnings_had
    ) {
        for e in pool {
            if (
                e.code is diag
                and e.loc.mod_path == nd.loc.mod_path
                and e.loc.first_line == nd.loc.first_line
                and e.loc.col_start == nd.loc.col_start
            ) {
                return True;
            }
        }
    }
    return False;
}

def note_unbound_client_name(reporter: any, name: str) {
    seen = reporter?._unbound_reported;
    if seen is not None {
        seen.add(name);
    }
}

def report_dead_client_import(reporter: any, nd: Import, item: ModuleItem) -> None {
    name = item.name.sym_name if isinstance(item.name, Name) else str(item.name.value);
    module_name = nd.from_loc.dot_path_str if nd.from_loc is not None else '';
    note_unbound_client_name(reporter, name);
    if _already_reported(reporter, E5082, item) {
        return;
    }
    reporter.emit(E5082, node_override=item, name=name, module=module_name);
}


def report_client_bare_import_uses(reporter: any, mod: Module) {
    for stmt in mod.body {
        if (
            isinstance(stmt, ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            _report_client_bare_import_uses(reporter, mod, stmt);
        }
    }
}

def _in_annotation_position(nm: Name, stop: UniNode) -> bool {
    cur = nm.parent;
    while cur is not None and cur is not stop {
        if isinstance(cur, SubTag) {
            return True;
        }
        if isinstance(cur, ParamVar) {
            return False;
        }
        if isinstance(cur, FuncSignature) {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

def _bare_py_import_bindings(mod: Module) -> dict[str, tuple] {
    out: dict[str, tuple] = {};
    for imp in mod.get_all_sub_nodes(Import) {
        if imp.is_service_import or imp.is_typed {
            continue;
        }
        if imp.ecosystem != 'py' {
            continue;
        }
        if imp.from_loc is None or imp.from_loc.level > 0 {
            continue;
        }
        if imp.code_context == CodeContext.CLIENT {
            continue;
        }
        for item in imp.items {
            if not isinstance(item, ModuleItem) {
                continue;
            }
            if item.alias is not None {
                binding = item.alias.sym_name;
            } elif isinstance(item.name, Name) {
                binding = item.name.sym_name;
            } else {
                binding = str(item.name.value);
            }
            out[binding] = (item, imp);
        }
    }
    return out;
}


def _shadows_bare_import(nm: Name) -> bool {
    sym = nm.sym;
    if sym is None or sym.decl is None {
        return False;
    }
    decl = sym.decl;
    if isinstance(decl, ModuleItem) or isinstance(decl.parent, ModuleItem) {
        return False;
    }
    cur = decl.parent;
    while cur is not None {
        if isinstance(cur, (ParamVar, HasVar)) {
            return True;
        }
        if isinstance(cur, Assignment) {
            return decl in cur.target
                or any([decl in t.get_all_sub_nodes(Name) for t in cur.target]);
        }
        if isinstance(cur, ElementStmt) {
            return False;
        }
        cur = cur.parent;
    }
    return False;
}


def _report_client_bare_import_uses(reporter: any, mod: Module, stmt: UniNode) {
    bindings = _bare_py_import_bindings(mod);
    if not bindings {
        return;
    }
    for nm in stmt.get_all_sub_nodes(Name) {
        par = nm.parent;
        if (isinstance(par, AtomTrailer) and par.is_attr and par.right is nm) {
            continue;
        }
        hit = bindings.get(nm.value);
        if hit is None {
            continue;
        }
        if _shadows_bare_import(nm) {
            continue;
        }
        if _in_annotation_position(nm, stmt) {
            continue;
        }
        (item, imp) = hit;
        module_name = imp.from_loc.dot_path_str if imp.from_loc is not None else '';
        item_name = item.name.sym_name
            if isinstance(item.name, Name)
            else str(item.name.value);
        note_unbound_client_name(reporter, item_name);
        note_unbound_client_name(reporter, nm.sym_name);
        already = _already_reported(reporter, E5084, item);
        if not already {
            reporter.emit(
                E5084, node_override=item, name=item_name, module=module_name
            );
        }
    }
}

def report_placement_warnings(reporter: any, mod: Module) {
    import from jaclang.jac0core.placement { get_module_summary }
    import from jaclang.jac0core.constant { CodeContext }
    ps = get_module_summary(mod, reporter.prog);
    written_glob_idxs: set[int] = set();
    for es in ps.elements {
        for widx in es.glob_writes {
            written_glob_idxs.add(widx);
        }
    }
    for (idx, stmt) in enumerate(mod.body) {
        if not isinstance(stmt, ContextAwareNode) {
            continue;
        }
        if (
            isinstance(stmt, GlobalVars)
            and stmt.codespace_dual
            and idx in written_glob_idxs
        ) {
            es = ps.elements[idx] if idx < len(ps.elements) else None;
            gname = es.name if es is not None else 'glob';
            if not _already_reported(reporter, W6006, stmt) {
                reporter.emit(W6006, node_override=stmt, name=gname);
            }
        }
        if stmt.code_context == CodeContext.CLIENT and not stmt.codespace_dual {
            _report_client_bare_import_uses(reporter, mod, stmt);
        }
    }
    for (nm, top) in client_value_ref_targets(mod) {
        if not isinstance(top, Ability) or client_bridged_endpoint(mod, top) {
            continue;
        }
        if not _already_reported(reporter, W6007, nm) {
            reporter.emit(W6007, node_override=nm, name=element_display_name(top));
        }
    }
}


def element_display_name(top: UniNode) -> str {
    if isinstance(top, Ability) and isinstance(top.name_ref, Name) {
        return top.name_ref.sym_name;
    }
    if isinstance(top, (Archetype, UniEnum)) and top.name is not None {
        return top.name.value;
    }
    if isinstance(top, GlobalVars) {
        for assign in top.assignments {
            for tgt in assign.target {
                if isinstance(tgt, Name) {
                    return tgt.sym_name;
                }
            }
        }
    }
    return 'element';
}


def _client_emitted_top(stmt: UniNode, extra_bound: set[str]) -> bool {
    if not isinstance(stmt, ContextAwareNode) {
        return False;
    }
    if stmt.code_context == CodeContext.CLIENT {
        return True;
    }
    return (
        isinstance(stmt, Archetype)
        and stmt.name is not None
        and stmt.name.value in extra_bound
    );
}


def _module_top_element(mod: Module, nd: UniNode) -> (UniNode | None) {
    cur: (UniNode | None) = nd;
    while (cur is not None and cur.parent is not mod) {
        cur = cur.parent;
    }
    return cur;
}


def client_bridged_endpoint(mod: Module, top: UniNode) -> bool {
    import from jaclang.jac0core.placement { project_has_server }
    return (
        isinstance(top, Ability)
        and isinstance(top, ContextAwareNode)
        and top.access is not None
        and top.access.tag.name == Tok.KW_PUB
        and top.code_context == CodeContext.SERVER
        and project_has_server(mod.loc.mod_path or '')
    );
}


def client_value_ref_targets(
    mod: Module, extra_bound: (set[str] | None) = None
) -> list[tuple[Name, UniNode]] {
    bound = extra_bound if extra_bound is not None else set();
    out: list[tuple[Name, UniNode]] = [];
    seen: set[tuple] = set();
    for stmt in mod.body {
        if not _client_emitted_top(stmt, bound) {
            continue;
        }
        for nm in stmt.get_all_sub_nodes(Name) {
            par = nm.parent;
            if (isinstance(par, AtomTrailer) and par.is_attr and par.right is nm) {
                continue;
            }
            if (isinstance(par, FuncCall) and par.target is nm) {
                continue;
            }
            if (isinstance(par, KWPair) and par.key is nm) {
                continue;
            }
            if _in_annotation_position(nm, stmt) {
                continue;
            }
            sym = nm.sym;
            decl = sym.decl if sym is not None else None;
            if decl is None {
                continue;
            }
            top = _module_top_element(mod, decl);
            if (top is None or top is stmt or isinstance(top, Import)) {
                continue;
            }
            if not isinstance(top, (Ability, Archetype, UniEnum, GlobalVars)) {
                continue;
            }
            if _client_emitted_top(top, bound) {
                continue;
            }
            if (
                isinstance(top, ContextAwareNode)
                and top.code_context == CodeContext.NATIVE
            ) {
                continue;
            }
            key = (nm.loc.first_line, nm.loc.col_start, id(top));
            if key in seen {
                continue;
            }
            seen.add(key);
            out.append((nm, top));
        }
    }
    return out;
}

def _import_bound_names(imp: Import) -> set[str] {
    names: set[str] = set();
    for item in imp.items {
        if isinstance(item, ModuleItem) {
            if item.alias is not None {
                names.add(item.alias.sym_name);
            } elif isinstance(item.name, Name) {
                names.add(item.name.sym_name);
            }
        } elif isinstance(item, ModulePath) {
            if item.alias is not None {
                names.add(item.alias.sym_name);
            } elif item.base_module_name {
                names.add(item.base_module_name);
            }
        }
    }
    return names;
}


def _import_used_as_value(mod: Module, imp: Import) -> bool {
    names = _import_bound_names(imp);
    if not names {
        return False;
    }
    for stmt in mod.body {
        if stmt is imp {
            continue;
        }
        for nm in stmt.get_all_sub_nodes(Name) {
            if nm.sym_name not in names {
                continue;
            }
            par = nm.parent;
            if (isinstance(par, AtomTrailer) and par.is_attr and par.right is nm) {
                continue;
            }
            if _in_annotation_position(nm, stmt) {
                continue;
            }
            return True;
        }
    }
    return False;
}


def serverless_server_evidence(mod: Module, prog: any) -> list[tuple] {
    import from jaclang.jac0core.placement { get_module_summary, project_has_server }
    if project_has_server(mod.loc.mod_path or '') {
        return [];
    }
    out: list[tuple] = [];
    for es in get_module_summary(mod, prog).elements {
        if es.index >= len(mod.body) {
            continue;
        }
        stmt = mod.body[es.index];
        for req in es.reqs {
            if len(req) < 2 {
                continue;
            }
            cap = req[0];
            blocking = cap in ('PERSIST', 'FFI');
            if cap == 'PY' {
                blocking = not isinstance(stmt, Import)
                    or (not stmt.is_typed and _import_used_as_value(mod, stmt));
            }
            if blocking {
                out.append((es.name or 'element', str(req[1]), stmt));
                break;
            }
        }
    }
    return out;
}


def report_serverless_kind_errors(reporter: any, mod: Module) {
    import from jaclang.jac0core.diagnostics { E5087 }
    import from jaclang.jac0core.placement { project_kind_name }
    evidence = serverless_server_evidence(mod, reporter.prog);
    if not evidence {
        return;
    }
    kind = project_kind_name(mod.loc.mod_path or '') or 'client-only';
    for (name, reason, stmt) in evidence {
        already = _already_reported(reporter, E5087, stmt);
        if not already {
            reporter.emit(
                E5087, node_override=stmt, kind=kind, name=name, reason=reason
            );
        }
    }
}
