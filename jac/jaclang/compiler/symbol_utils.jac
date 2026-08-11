import from collections.abc { Sequence }
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok, SymbolType }
import from jaclang.jac0core.diagnostics { E5082, E5084, W6006, W6007 }
import from jaclang.jac0core.compiler {
    ClientImportVerdict,
    ability_of_symbol,
    classify_client_import_item,
    is_client_boundary_import,
    symbol_linked_source_module
}

enum CallKind {
    METHOD = "method",
    INSTANTIATION = "instantiation",
    BUILTIN = "builtin",
    CLIB = "clib",
    FUNCTION = "function",
    INTRINSIC = "intrinsic"
}

def is_builtin_region_name(nm: object) -> bool {
    if not isinstance(nm, uni.Name) or nm.sym_name != "Region" {
        return False;
    }
    if nm.sym is None or nm.sym.decl is None {
        return True;
    }
    _loc = nm.sym.decl.loc;
    _mp = _loc.mod_path if _loc is not None else "";
    return isinstance(_mp, str) and _mp.endswith(".pyi");
}

def resolve_expr_symbol(
    expr: uni.Expr, module: (uni.Module | None) = None
) -> (uni.Symbol | None) {
    if isinstance(expr, uni.AstSymbolNode) and expr.sym {
        return expr.sym;
    }

    if isinstance(expr, uni.AtomTrailer) {
        attrs = expr.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, uni.AstSymbolNode) and last.sym {
                return last.sym;
            }
        }
    }

    if module is not None and isinstance(expr, uni.Name) {
        return module.lookup(expr.sym_name);
    }
    return None;
}

def _is_user_symbol(sym: uni.Symbol) -> bool {
    scope: (uni.UniScopeNode | None) = sym.parent_tab;
    while scope is not None {
        if isinstance(scope, uni.Module) {
            if scope.stub_only {
                return False;
            }
            return not scope.source.file_path.endswith(".pyi");
        }
        scope = scope.parent_scope;
    }
    return False;
}

def _symbol_defining_module(sym: uni.Symbol) -> (uni.Module | None) {
    decl = sym.decl;
    if decl is None {
        return None;
    }
    return decl.find_parent_of_type(uni.Module);
}

def _is_local_user_shadow(sym: uni.Symbol, call: uni.FuncCall) -> bool {
    if not _is_user_symbol(sym) {
        return False;
    }
    call_mod = call.find_parent_of_type(uni.Module);
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

def classify_call(nd: uni.FuncCall) -> CallKind {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

    if isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr {
        return CallKind.METHOD;
    }

    intrinsics = intrinsic_registry_if_ready();
    if intrinsics is not None
        and isinstance(nd.target, uni.Name)
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
        _imp = sym.decl.find_parent_of_type(uni.Import);
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

    if isinstance(nd.target, uni.Name)
        and JAC_TYPE_REGISTRY.is_builtin(nd.target.sym_name) {
        return CallKind.BUILTIN;
    }
    return CallKind.FUNCTION;
}

def symbol_owner_archetype(sym: uni.Symbol) -> (uni.Archetype | None) {
    decl = sym.decl;
    if decl is None {
        return None;
    }
    owner = decl?.name_of;
    if isinstance(owner, uni.Archetype) {
        return owner;
    }
    return None;
}

def collect_field_names(
    sym: (uni.Symbol | None), arch_type_filter: (str | None) = None
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

def int_subscript_suffix(right: uni.IndexSlice) -> str | None {
    if (not right.is_range and len(right.slices) == 1) {
        idx = right.slices[0];
        if (idx.start is not None and idx.stop is None and idx.step is None) {
            start = idx.start;

            if isinstance(start, uni.Int) {
                return f"[{start.lit_value}]";
            }

            if (
                isinstance(start, uni.UnaryExpr)
                and isinstance(start.op, uni.Token)
                and start.op.name == "MINUS"
                and isinstance(start.operand, uni.Int)
            ) {
                return f"[-{start.operand.lit_value}]";
            }

            if isinstance(start, uni.MultiString)
                and len(start.strings) == 1
                and isinstance(start.strings[0], uni.String) {
                return f'[{start.strings[0].lit_value!r}]';
            }

            if isinstance(start, uni.Name) {
                return f"[{start.value}]";
            }
        }
    }
    return None;
}

def reference_key_deps(expr: uni.Expr) -> set[str] {
    deps: set[str] = set();
    cur: uni.UniNode | None = expr;
    while cur is not None {
        if isinstance(cur, uni.AtomUnit) and cur.value is not None {
            cur = cur.value;
            continue;
        }
        if isinstance(cur, uni.Name) {
            deps.add(cur.value);
            return deps;
        }
        if isinstance(cur, uni.AtomTrailer) {
            if (
                not cur.is_attr
                and isinstance(cur.right, uni.IndexSlice)
                and not cur.right.is_range
                and len(cur.right.slices) == 1
            ) {
                idx = cur.right.slices[0];
                if (
                    idx.start is not None
                    and idx.stop is None
                    and idx.step is None
                    and isinstance(idx.start, uni.Name)
                ) {
                    deps.add(idx.start.value);
                }
            }
            cur = cur.target;
            continue;
        }
        break;
    }
    return deps;
}

def get_expr_key(expr: uni.Expr) -> str | None {
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.AtomTrailer) and expr.is_attr {
        base = get_expr_key(expr.target);
        if base and isinstance(expr.right, uni.Name) {
            return f"{base}.{expr.right.value}";
        }
    }
    if isinstance(expr, uni.AtomTrailer) and not expr.is_attr {
        base = get_expr_key(expr.target);
        if base and isinstance(expr.right, uni.IndexSlice) {
            suffix = int_subscript_suffix(expr.right);
            if suffix {
                return f"{base}{suffix}";
            }
        }
    }

    if isinstance(expr, uni.AtomUnit) and expr.value {
        return get_expr_key(expr.value);
    }
    return None;
}

def _extract_first_arg_key(arg: uni.Expr) -> str | None {
    if isinstance(arg, uni.AtomUnit) and arg.value {
        arg = arg.value;
    }
    if isinstance(arg, uni.Name) {
        return arg.value;
    }
    if isinstance(arg, uni.AtomTrailer) {
        return get_expr_key(arg);
    }
    if (
        isinstance(arg, uni.BinaryExpr)
        and isinstance(arg.op, uni.Token)
        and arg.op.name == "WALRUS_EQ"
        and isinstance(arg.left, uni.Name)
    ) {
        return arg.left.value;
    }
    return None;
}

def _extract_compare_left_key(left: uni.Expr) -> str | None {
    if isinstance(left, uni.AtomUnit) and left.value {
        left = left.value;
    }
    if isinstance(left, uni.Name) {
        return left.value;
    }
    if isinstance(left, uni.AtomTrailer) {
        return get_expr_key(left);
    }
    if (
        isinstance(left, uni.BinaryExpr)
        and isinstance(left.op, uni.Token)
        and left.op.name == "WALRUS_EQ"
        and isinstance(left.left, uni.Name)
    ) {
        return left.left.value;
    }
    return None;
}

def classify_condition_key(condition: uni.Expr) -> str | None {
    if isinstance(condition, uni.FuncCall) and isinstance(condition.target, uni.Name) {
        if (
            condition.target.value in ("isinstance", "callable", "hasattr")
            and len(condition.params) >= 1
        ) {
            return _extract_first_arg_key(condition.params[0]);
        }
    }

    if isinstance(condition, uni.CompareExpr) {
        return _extract_compare_left_key(condition.left);
    }

    if isinstance(condition, uni.Name) {
        return condition.value;
    }
    if isinstance(condition, uni.AtomTrailer) and condition.is_attr {
        return get_expr_key(condition);
    }

    if (
        isinstance(condition, uni.BinaryExpr)
        and isinstance(condition.op, uni.Token)
        and condition.op.name == "WALRUS_EQ"
        and isinstance(condition.left, uni.Name)
    ) {
        return condition.left.value;
    }
    return None;
}

def collect_narrowing_symbols(condition: uni.Expr) -> set[str] {
    symbols: set[str] = set();

    if isinstance(condition, uni.CfgExpr) {
        symbols.update(collect_narrowing_symbols(condition.expr));
    } elif isinstance(condition, uni.AtomUnit)
        and isinstance(condition.value, uni.Expr) {
        symbols.update(collect_narrowing_symbols(condition.value));
    } elif isinstance(condition, uni.UnaryExpr) {
        symbols.update(collect_narrowing_symbols(condition.operand));
    } elif isinstance(condition, uni.BoolExpr) {
        for val in condition.values {
            symbols.update(collect_narrowing_symbols(val));
        }
    } else {
        key = classify_condition_key(condition);
        if key is not None {
            symbols.add(key);
        }
    }
    return symbols;
}

def find_destructure_index_path(target: uni.UniNode, key: str) -> list[int] | None {
    if isinstance(target, uni.Name) {
        return [] if target.value == key else None;
    }
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        matched_key = get_expr_key(target);
        return [] if matched_key == key else None;
    }
    if isinstance(target, uni.AtomUnit) and isinstance(target.value, uni.UniNode) {
        return find_destructure_index_path(target.value, key);
    }
    if isinstance(target, (uni.TupleVal, uni.ListVal)) and target.values {
        for (i, sub) in enumerate(target.values) {
            if not isinstance(sub, uni.UniNode) {
                continue;
            }

            if (
                isinstance(sub, uni.UnaryExpr)
                and isinstance(sub.op, uni.Token)
                and sub.op.name == Tok.STAR_MUL
            ) {
                continue;
            }
            sub_path = find_destructure_index_path(sub, key);
            if sub_path is not None {
                return [i] + sub_path;
            }
        }
    }
    return None;
}

def collect_assignment_target_keys(target: uni.UniNode) -> set[str] {
    keys: set[str] = set();
    if isinstance(target, uni.Name) {
        keys.add(target.value);
    } elif isinstance(target, uni.AtomTrailer) {
        if key := get_expr_key(target) {
            keys.add(key);
        }
    } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
        if target.values {
            for sub in target.values {
                if isinstance(sub, uni.UniNode) {
                    keys.update(collect_assignment_target_keys(sub));
                }
            }
        }
    } elif (
        isinstance(target, uni.UnaryExpr)
        and isinstance(target.op, uni.Token)
        and target.op.name == Tok.STAR_MUL
    ) {
        keys.update(collect_assignment_target_keys(target.operand));
    } elif isinstance(target, uni.AtomUnit) and isinstance(target.value, uni.UniNode) {
        keys.update(collect_assignment_target_keys(target.value));
    }
    return keys;
}

def collect_assigned_symbols(nd: uni.UniNode) -> set[str] {
    symbols: set[str] = set();

    if isinstance(nd, uni.Assignment) {
        for target in nd.target {
            symbols.update(collect_assignment_target_keys(target));
        }
    } elif isinstance(nd, uni.InForStmt) {
        if isinstance(nd.target, uni.Name) {
            symbols.add(nd.target.value);
        }
    } elif isinstance(nd, uni.AssignCompr) {
        if isinstance(nd.target, uni.Name) {
            symbols.add(nd.target.value);
        }
    }
    return symbols;
}

def collect_method_names(arch: uni.Archetype) -> set[str] {
    names: set[str] = set();
    if arch.body is not None and isinstance(arch.body, Sequence) {
        for stmt in arch.body {
            if isinstance(stmt, uni.Ability) {
                mn = stmt.name_ref.sym_name if stmt.name_ref else None;
                if mn is not None {
                    names.add(mn);
                }
            }
        }
    }
    return names;
}

def resolve_importer_path_from_node(nd: uni.UniNode) -> (str | None) {
    importer_mod = nd.find_parent_of_type(uni.Module);
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

def resolve_import_source_module(prog: any, nd: uni.Import) -> (uni.Module | None) {
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

def import_target_pinned_server(nd: uni.Import) -> bool {
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

def decl_has_access(source_mod: uni.Module, item: uni.ModuleItem) -> bool {
    nm = item.name.value if isinstance(item.name, uni.Name) else '';
    if not nm or source_mod.sym_tab is None {
        return False;
    }
    sym = source_mod.sym_tab.lookup(nm, deep=True);
    if not (sym and sym.defn) {
        return False;
    }
    decl = sym.defn[0];
    owner = decl.parent if (isinstance(decl, uni.NameAtom) and decl.parent) else decl;
    return owner?.access is not None;
}

def report_dead_client_import(
    reporter: any, nd: uni.Import, item: uni.ModuleItem
) -> None {
    name = item.name.sym_name
        if isinstance(item.name, uni.Name)
        else str(item.name.value);
    module_name = nd.from_loc.dot_path_str if nd.from_loc is not None else '';
    for e in reporter.prog.errors_had {
        if (
            e.code is E5082
            and e.loc.mod_path == item.loc.mod_path
            and e.loc.first_line == item.loc.first_line
            and e.loc.col_start == item.loc.col_start
        ) {
            return;
        }
    }
    reporter.emit(E5082, node_override=item, name=name, module=module_name);
}


def report_client_bare_import_uses(reporter: any, mod: uni.Module) {
    for stmt in mod.body {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            _report_client_bare_import_uses(reporter, mod, stmt);
        }
    }
}

def _already_warned(reporter: any, diag: any, nd: uni.UniNode) -> bool {
    for w in reporter.prog.warnings_had {
        if (
            w.code is diag
            and w.loc.mod_path == nd.loc.mod_path
            and w.loc.first_line == nd.loc.first_line
            and w.loc.col_start == nd.loc.col_start
        ) {
            return True;
        }
    }
    return False;
}

def _in_annotation_position(nm: uni.Name, stop: uni.UniNode) -> bool {
    cur = nm.parent;
    while cur is not None and cur is not stop {
        if isinstance(cur, uni.SubTag) {
            return True;
        }
        if isinstance(cur, uni.ParamVar) {
            return False;
        }
        if isinstance(cur, uni.FuncSignature) {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

def _bare_py_import_bindings(mod: uni.Module) -> dict[str, tuple] {
    out: dict[str, tuple] = {};
    for imp in mod.get_all_sub_nodes(uni.Import) {
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
            if not isinstance(item, uni.ModuleItem) {
                continue;
            }
            if item.alias is not None {
                binding = item.alias.sym_name;
            } elif isinstance(item.name, uni.Name) {
                binding = item.name.sym_name;
            } else {
                binding = str(item.name.value);
            }
            out[binding] = (item, imp);
        }
    }
    return out;
}


def _shadows_bare_import(nm: uni.Name) -> bool {
    sym = nm.sym;
    if sym is None or sym.decl is None {
        return False;
    }
    decl = sym.decl;
    if isinstance(decl, uni.ModuleItem) or isinstance(decl.parent, uni.ModuleItem) {
        return False;
    }
    cur = decl.parent;
    while cur is not None {
        if isinstance(cur, (uni.ParamVar, uni.HasVar)) {
            return True;
        }
        if isinstance(cur, uni.Assignment) {
            return decl in cur.target
                or any([decl in t.get_all_sub_nodes(uni.Name) for t in cur.target]);
        }
        if isinstance(cur, uni.ElementStmt) {
            return False;
        }
        cur = cur.parent;
    }
    return False;
}


def _report_client_bare_import_uses(reporter: any, mod: uni.Module, stmt: uni.UniNode) {
    bindings = _bare_py_import_bindings(mod);
    if not bindings {
        return;
    }
    for nm in stmt.get_all_sub_nodes(uni.Name) {
        par = nm.parent;
        if (isinstance(par, uni.AtomTrailer) and par.is_attr and par.right is nm) {
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
        already = False;
        for e in reporter.prog.errors_had {
            if (
                e.code is E5084
                and e.loc.mod_path == item.loc.mod_path
                and e.loc.first_line == item.loc.first_line
                and e.loc.col_start == item.loc.col_start
            ) {
                already = True;
                break;
            }
        }
        if not already {
            reporter.emit(
                E5084,
                node_override=item,
                name=item.name.sym_name
                    if isinstance(item.name, uni.Name)
                    else str(item.name.value),
                module=module_name
            );
        }
    }
}

def report_placement_warnings(reporter: any, mod: uni.Module) {
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
        if not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        if (
            isinstance(stmt, uni.GlobalVars)
            and stmt.codespace_dual
            and idx in written_glob_idxs
        ) {
            es = ps.elements[idx] if idx < len(ps.elements) else None;
            gname = es.name if es is not None else 'glob';
            if not _already_warned(reporter, W6006, stmt) {
                reporter.emit(W6006, node_override=stmt, name=gname);
            }
        }
        if stmt.code_context == CodeContext.CLIENT and not stmt.codespace_dual {
            _report_client_bare_import_uses(reporter, mod, stmt);
        }
        is_clientish = stmt.code_context == CodeContext.CLIENT or stmt.codespace_dual;
        if not is_clientish or idx >= len(ps.elements) {
            continue;
        }
        for esc in ps.elements[idx].escapes {
            tidx = esc[0];
            if tidx >= len(mod.body) {
                continue;
            }
            target = mod.body[tidx];
            if (
                isinstance(target, uni.ContextAwareNode)
                and isinstance(target, uni.Ability)
                and target.code_context == CodeContext.SERVER
                and not target.codespace_dual
            ) {
                tes = ps.elements[tidx] if tidx < len(ps.elements) else None;
                tname = tes.name if tes is not None else 'function';
                if not _already_warned(reporter, W6007, stmt) {
                    reporter.emit(W6007, node_override=stmt, name=tname);
                }
            }
        }
    }
}
