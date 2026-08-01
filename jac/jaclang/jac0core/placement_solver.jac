import os;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.placement {
    get_module_summary,
    placement_state,
    record_placement_evidence,
    scan_native_blockers,
    summarize_module
}

glob _na_scan_memo: dict[str, tuple] = {},
     _SPACE_BY_NAME: dict[str, CodeContext] = {
         'server': CodeContext.SERVER,
         'client': CodeContext.CLIENT,
         'native': CodeContext.NATIVE
     };

def native_scan_memo_clear {
    _na_scan_memo.clear();
}

def _native_dep_scan(path: str) -> (tuple[str, list[str]] | None) {
    import from jaclang.jac0core.compiler { _is_demoted_native }
    import from jaclang.jac0core.helpers { read_file_with_encoding }
    import from jaclang.jac0core.program { JacProgram }
    if _is_demoted_native(os.path.realpath(path)) {
        return ("previously-demoted", []);
    }
    import from jaclang.jac0core.bccache { discover_annex_files }
    import from jaclang.jac0core.parser { parse as rd_parse }
    files = [path]
        + discover_annex_files(path, '.impl.jac')
        + discover_annex_files(path, '.test.jac');
    fresh_parts: list[tuple] = [];
    for f in files {
        try {
            st = os.stat(f);
            fresh_parts.append((f, st.st_mtime_ns, st.st_size));
        } except OSError {
            return None;
        }
    }
    fresh_key = tuple(fresh_parts);
    cached = _na_scan_memo.get(path);
    if cached is not None and cached[0] == fresh_key {
        return (cached[1], cached[2]);
    }
    sv_reason = '';
    deps: list[str] = [];
    if not sv_reason {
        base_dir = os.path.dirname(os.path.abspath(path)) or '.';
        for f in files {
            try {
                src = read_file_with_encoding(f);
            } except Exception {
                sv_reason = "unreadable annex";
                break;
            }
            (dep_mod, had_err) = rd_parse(src, f, prog=JacProgram());
            if had_err {
                sv_reason = "parse error";
                break;
            }
            (f_sv, f_deps) = scan_native_blockers(dep_mod, base_dir, allow_pub=True);
            if f_sv {
                sv_reason = f_sv;
                break;
            }
            deps.extend(f_deps);
        }
    }
    if sv_reason {
        deps = [];
    }
    _na_scan_memo[path] = (fresh_key, sv_reason, deps);
    return (sv_reason, deps);
}

def _native_deps_ok(root_path: str, root_deps: list[str]) -> bool {
    import from jaclang.jac0core.codeinfo { effective_native_closure_cap }
    import from jaclang.jac0core.compiler { _note_native_closure_cap }
    cap = effective_native_closure_cap();
    edges: dict[str, list[str]] = {root_path: list(root_deps)};
    queue: list[str] = list(root_deps);
    while queue {
        if len(edges) > cap {
            _note_native_closure_cap(root_path, cap);
            return False;
        }
        dep = queue.pop();
        if dep in edges {
            continue;
        }
        info = _native_dep_scan(dep);
        if info is None {
            return False;
        }
        (dep_sv, dep_deps) = info;
        if dep_sv {
            return False;
        }
        edges[dep] = list(dep_deps);
        for d in dep_deps {
            if d not in edges {
                queue.append(d);
            }
        }
    }
    return True;
}

def native_default_path_ok(path: str) -> bool {
    ap = os.path.abspath(path);
    info = _native_dep_scan(ap);
    if info is None {
        return False;
    }
    (has_sv, deps) = info;
    if has_sv {
        return False;
    }
    return _native_deps_ok(ap, deps);
}

def native_default_verdict(module: uni.Module) -> tuple[bool, str] {
    import from jaclang.jac0core.compiler { _is_demoted_native }
    mod_path = module.loc.mod_path if module.loc is not None else '';
    if not mod_path {
        return (False, "no module path");
    }
    if _is_demoted_native(os.path.realpath(mod_path)) {
        return (False, "previously-demoted");
    }
    base_dir = os.path.dirname(os.path.abspath(mod_path)) or '.';
    (sv_reason, deps) = scan_native_blockers(module, base_dir);
    if sv_reason {
        return (False, sv_reason);
    }
    if not _native_deps_ok(os.path.abspath(mod_path), deps) {
        return (False, "import-closure (sv dep or cap)");
    }
    return (True, '');
}

def _top_element(module: uni.Module, nd: uni.UniNode) -> (uni.UniNode | None) {
    cur: (uni.UniNode | None) = nd;
    while (cur is not None and cur.parent is not module) {
        cur = cur.parent;
    }
    return cur;
}

def _is_client_top(elem: uni.UniNode) -> bool {
    return isinstance(elem, uni.ContextAwareNode)
        and elem.code_context == CodeContext.CLIENT;
}

def _py_import_client_portable(elem: uni.Import) -> bool {
    import from jaclang.jac0core.portability { client_supports_py_module }
    targets: list[str] = [];
    if elem.from_loc is not None {
        targets.append(elem.from_loc.dot_path_str);
    } else {
        for item in elem.items {
            if isinstance(item, uni.ModulePath) {
                targets.append(item.dot_path_str);
            }
        }
    }
    if not targets {
        return False;
    }
    for tgt in targets {
        if not client_supports_py_module(tgt) {
            return False;
        }
    }
    return True;
}

def _pullable_by_client_reference(
    elem: uni.UniNode, module: uni.Module, body_refs: dict[int, set[int]]
) -> bool {
    import from jaclang.jac0core.compiler { is_server_anchored_module }
    if isinstance(elem, uni.Archetype) and elem.arch_kind is not None {
        return False;
    }
    if isinstance(elem, uni.Import) {
        if elem.has_string_path {
            return True;
        }
        if elem.from_loc is None {
            return _py_import_client_portable(elem);
        }
        resolved = elem.from_loc.resolve_relative_path();
        if isinstance(resolved, str) and resolved.endswith('.jac') {
            return True;
        }
        return _py_import_client_portable(elem);
    }
    if isinstance(elem, (uni.Archetype, uni.TypeAlias)) {
        for top in module.body {
            if top is elem {
                continue;
            }
            if (id(elem) in body_refs[id(top)] and not _is_client_top(top)) {
                return False;
            }
        }
        return True;
    }
    if isinstance(elem, uni.Ability) {
        return elem.access is None or not is_server_anchored_module(module);
    }
    return True;
}

def _ref_top_ids(module: uni.Module, elem: uni.UniNode) -> set[int] {
    refs: set[int] = set();
    for nm in elem.get_all_sub_nodes(uni.Name) {
        par = nm.parent;
        if (isinstance(par, uni.AtomTrailer) and par.is_attr and par.right is nm) {
            continue;
        }
        tab = nm?.sym_tab;
        if tab is None {
            continue;
        }
        sym = tab.lookup(name=nm.value, deep=True);
        if sym is None {
            continue;
        }
        decl = sym.decl;
        if decl is None {
            continue;
        }
        top = _top_element(module, decl);
        if (top is None or top is elem) {
            continue;
        }
        refs.add(id(top));
    }
    return refs;
}

def _is_sv_import(elem: uni.UniNode) -> bool {
    return isinstance(elem, uni.Import) and elem.is_service_import;
}

def _named_top_element(target: uni.Module, name: str) -> (uni.UniNode | None) {
    sym = target.names_in_scope.get(name) if target.names_in_scope else None;
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    return _top_element(target, decl);
}

def _materialize_module(path: str, prog: any) -> (uni.Module | None) {
    import from jaclang.jac0core.compiler { hub_module_for_path }
    found = hub_module_for_path(path, prog);
    if found is not None {
        return found;
    }
    if not os.path.exists(path) {
        return None;
    }
    try {
        import from jaclang.jac0core.compile_options { CompileOptions }
        prog.compile(
            file_path=path,
            options=CompileOptions(
                symtab_ir_only=True,
                no_cgen=True,
                type_check=False,
                force_target_program=True
            )
        );
    } except Exception {
        return None;
    }
    return hub_module_for_path(path, prog);
}

def _import_source_module(elem: uni.Import, prog: any) -> (uni.Module | None) {
    if elem.from_loc is None {
        return None;
    }
    resolved = elem.from_loc.resolve_relative_path();
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return None;
    }
    return _materialize_module(os.path.abspath(resolved), prog);
}

def _closure_pullable(
    top: uni.UniNode, module: uni.Module, prog: any, seen: set[int]
) -> bool {
    if id(top) in seen {
        return True;
    }
    seen.add(id(top));
    if isinstance(top, uni.ContextAwareNode)
        and top.code_context == CodeContext.CLIENT {
        return True;
    }
    if isinstance(top, uni.Import) {
        if top.is_service_import {
            return True;
        }
        source_mod = _import_source_module(top, prog);
        if source_mod is None {
            return False;
        }
        for item in top.items {
            if not (
                isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)
            ) {
                continue;
            }
            item_top = _named_top_element(source_mod, item.name.value);
            if item_top is None
                or not _closure_pullable(item_top, source_mod, prog, seen) {
                return False;
            }
        }
        return True;
    }
    import from jaclang.jac0core.compiler { is_server_anchored_module }
    if isinstance(top, uni.Archetype) and top.arch_kind is not None {
        return False;
    }
    if (
        isinstance(top, uni.Ability)
        and top.access is not None
        and is_server_anchored_module(module)
    ) {
        return False;
    }
    elem_by_id: dict[int, uni.UniNode] = {id(stmt): stmt for stmt in module.body};
    for ref_id in _ref_top_ids(module, top) {
        ref_elem = elem_by_id.get(ref_id);
        if ref_elem is None {
            continue;
        }
        if not _closure_pullable(ref_elem, module, prog, seen) {
            return False;
        }
    }
    return True;
}


def _module_externally_pinned(mod_path: str) -> bool {
    import from jaclang.jac0core.placement_pins { config_module_pin }
    return config_module_pin(mod_path) != '';
}

def _seed_from_summary(module: uni.Module, prog: any) -> int {
    import from jaclang.jac0core.compiler { _stamp_context_element }
    mod_path = module.loc.mod_path or '';
    ps = get_module_summary(module, prog);
    seeded = 0;
    for es in ps.elements {
        if es.index >= len(module.body) {
            continue;
        }
        stmt = module.body[es.index];
        if not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        if es.pinned {
            pin_ctx = _SPACE_BY_NAME.get(es.pinned);
            if pin_ctx is not None and stmt.code_context != pin_ctx {
                _stamp_context_element(stmt, pin_ctx);
                record_placement_evidence(
                    prog, mod_path, es.index, f"config pin: {es.pinned}"
                );
                seeded += 1;
            }
            continue;
        }
        if stmt.code_context != CodeContext.SERVER {
            continue;
        }
        target_ctx: (CodeContext | None) = None;
        why = '';
        ctx_label = '';
        for req in es.reqs {
            if len(req) < 2 {
                continue;
            }
            (cap, reason) = (req[0], req[1]);
            if cap == 'FFI' {
                target_ctx = CodeContext.NATIVE;
                ctx_label = 'native';
                why = reason;
                break;
            }
            if cap == 'DOM' {
                target_ctx = CodeContext.CLIENT;
                ctx_label = 'client';
                why = reason;
                break;
            }
            if cap == 'NPM'
                and reason
                    in (
                        'string-path import',
                        'virtual @jac import',
                        'npm dependency'
                    ) {
                target_ctx = CodeContext.CLIENT;
                ctx_label = 'client';
                why = reason;
                break;
            }
        }
        if target_ctx is None {
            continue;
        }
        _stamp_context_element(stmt, target_ctx);
        record_placement_evidence(
            prog, mod_path, es.index, f"seeded {ctx_label}: {why}"
        );
        seeded += 1;
    }
    return seeded;
}

def solve_module_placement(
    module: uni.Module,
    prog: any,
    seed_ref_ids: (set[int] | None) = None,
    dual: bool = False,
    pull_dependents: bool = True
) -> int {
    import from jaclang.jac0core.compiler { _stamp_context_element }
    mod_path = module.loc.mod_path or '';
    index_by_id: dict[int, int] = {};
    for (bidx, bstmt) in enumerate(module.body) {
        index_by_id[id(bstmt)] = bidx;
    }
    stamp_count: list[int] = [0];

    def _note(elem: uni.UniNode, note: str) {
        eidx = index_by_id.get(id(elem));
        if eidx is not None {
            record_placement_evidence(prog, mod_path, eidx, note);
        }
    }

    def _stamp(elem: uni.UniNode, ctx: CodeContext) {
        already = isinstance(elem, uni.ContextAwareNode) and elem.code_context == ctx;
        _stamp_context_element(elem, ctx);
        if not already {
            stamp_count[0] += 1;
        }
        if (
            dual
            and ctx == CodeContext.CLIENT
            and isinstance(elem, uni.ContextAwareNode)
        ) {
            if not elem.codespace_dual {
                stamp_count[0] += 1;
            }
            elem.codespace_dual = True;
        }
    }

    def _invalidate_stale_codegen {
        if stamp_count[0] and (module.gen.js or module.gen.es_ast is not None) {
            module.gen.js = '';
            module.gen.es_ast = None;
        }
    }

    _seed_from_summary(module, prog);
    pinned_idx: set[int] = set();
    for pes in get_module_summary(module, prog).elements {
        if pes.pinned {
            pinned_idx.add(pes.index);
        }
    }
    client_tops: list[uni.UniNode] = [];
    native_tops: list[uni.UniNode] = [];
    inferable: list[uni.UniNode] = [];
    for (sidx, stmt) in enumerate(module.body) {
        if not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        if stmt.code_context == CodeContext.CLIENT {
            if sidx not in pinned_idx {
                client_tops.append(stmt);
            }
            continue;
        }
        if stmt.code_context == CodeContext.NATIVE {
            if sidx not in pinned_idx {
                native_tops.append(stmt);
            }
            continue;
        }
        is_placement_pinned = sidx in pinned_idx and not isinstance(stmt, uni.Import);
        if (stmt.code_context != CodeContext.SERVER or is_placement_pinned) {
            continue;
        }
        inferable.append(stmt);
    }
    has_seeds = bool(seed_ref_ids);
    if ((not client_tops and not native_tops and not has_seeds) or not inferable) {
        return stamp_count[0];
    }

    cl_sources: set[int] = set();
    cl_ref_ids: set[int] = set(seed_ref_ids) if seed_ref_ids else set();
    na_sources: set[int] = set();
    na_ref_ids: set[int] = set();
    uses_map: dict[int, set[int]] = {};
    body_refs: dict[int, set[int]] = {};
    for top in module.body {
        body_refs[id(top)] = _ref_top_ids(module, top);
    }

    def _pullable_native(elem: uni.UniNode) -> bool {
        return not _is_sv_import(elem);
    }
    cl_seed_ids: set[int] = set();
    na_seed_ids: set[int] = set();
    for elem in client_tops {
        if not _is_sv_import(elem) {
            cl_sources.add(id(elem));
            cl_seed_ids.add(id(elem));
        }
        cl_ref_ids.update(_ref_top_ids(module, elem));
    }
    for elem in native_tops {
        if not _is_sv_import(elem) {
            na_sources.add(id(elem));
            na_seed_ids.add(id(elem));
        }
        na_ref_ids.update(_ref_top_ids(module, elem));
    }
    for elem in inferable {
        uses_map[id(elem)] = _ref_top_ids(module, elem);
    }
    def _hard_closure(hc_seed_ids: set[int]) -> set[int] {
        result: set[int] = set(hc_seed_ids);
        grew = True;
        while grew {
            grew = False;
            for elem in inferable {
                if (id(elem) in result or _is_sv_import(elem)) {
                    continue;
                }
                if not result.isdisjoint(uses_map[id(elem)]) {
                    result.add(id(elem));
                    grew = True;
                }
            }
        }
        return result;
    }
    cl_star = _hard_closure(cl_seed_ids);
    na_star = _hard_closure(na_seed_ids);
    hard_remaining: list[uni.UniNode] = [];
    for elem in inferable {
        in_cl = id(elem) in cl_star;
        in_na = id(elem) in na_star;
        if (in_cl and in_na) {
            continue;
        }
        if in_na {
            _stamp(elem, CodeContext.NATIVE);
            _note(elem, "pulled native: depends on a native element");
            na_sources.add(id(elem));
            na_ref_ids.update(uses_map[id(elem)]);
        } elif in_cl {
            _stamp(elem, CodeContext.CLIENT);
            _note(elem, "pulled client: depends on a client element");
            cl_sources.add(id(elem));
            cl_ref_ids.update(uses_map[id(elem)]);
        } else {
            hard_remaining.append(elem);
        }
    }
    inferable = hard_remaining;
    changed = True;
    while changed {
        changed = False;
        remaining: list[uni.UniNode] = [];
        for elem in inferable {
            refs = uses_map[id(elem)];
            want_cl = (
                (pull_dependents and not cl_sources.isdisjoint(refs))
                or (
                    id(elem) in cl_ref_ids
                    and _pullable_by_client_reference(elem, module, body_refs)
                )
            );
            want_na = (
                not na_sources.isdisjoint(refs)
                or (id(elem) in na_ref_ids and _pullable_native(elem))
            );
            if (want_cl and want_na) {
                continue;
            }
            if want_na {
                _stamp(elem, CodeContext.NATIVE);
                _note(elem, "pulled native: closure of native elements");
                if not _is_sv_import(elem) {
                    na_sources.add(id(elem));
                }
                na_ref_ids.update(refs);
                changed = True;
            } elif want_cl {
                _stamp(elem, CodeContext.CLIENT);
                _note(
                    elem,
                    "pulled client (dual): closure of client elements"
                        if dual
                        else "pulled client: closure of client elements"
                );
                if not _is_sv_import(elem) {
                    cl_sources.add(id(elem));
                }
                cl_ref_ids.update(refs);
                changed = True;
            } else {
                remaining.append(elem);
            }
        }
        inferable = remaining;
    }
    _invalidate_stale_codegen();
    return stamp_count[0];
}

def _emit_solver_warning(prog: any, diag: any, nd: uni.UniNode, **kwargs: any) {
    import from jaclang.jac0core.passes.transform { Alert }
    for w in prog.warnings_had {
        if (
            w.code is diag
            and w.loc.mod_path == nd.loc.mod_path
            and w.loc.first_line == nd.loc.first_line
            and w.loc.col_start == nd.loc.col_start
        ) {
            return;
        }
    }
    try {
        prog.warnings_had.append(
            Alert(
                msg=diag.format_message(**kwargs),
                loc=nd.loc.snapshot(),
                from_pass=PlacementApplyPass,
                code=diag,
                help_text=diag.format_help(**kwargs)
            )
        );
    } except Exception {
        ;
    }
}

def _warn_state_forks(target: uni.Module, prog: any) {
    import from jaclang.jac0core.diagnostics { W6006 }
    ps = get_module_summary(target, prog);
    written: set[int] = set();
    for es in ps.elements {
        for widx in es.glob_writes {
            written.add(widx);
        }
    }
    for (idx, stmt) in enumerate(target.body) {
        if (
            isinstance(stmt, uni.GlobalVars) and stmt.codespace_dual and idx in written
        ) {
            gname = ps.elements[idx].name if idx < len(ps.elements) else 'glob';
            _emit_solver_warning(prog, W6006, stmt, name=gname);
            record_placement_evidence(
                prog,
                target.loc.mod_path or '',
                idx,
                "state fork: mutable glob duplicated across spaces (W6006)"
            );
        }
    }
}

def _pull_into_target(
    imp: uni.Import, target: uni.Module, module: uni.Module, prog: any
) -> int {
    seed_ids: set[int] = set();
    for item in imp.items {
        if not (isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)) {
            continue;
        }
        top = _named_top_element(target, item.name.value);
        if top is not None and _closure_pullable(top, target, prog, set()) {
            seed_ids.add(id(top));
        }
    }
    if not seed_ids {
        return 0;
    }
    new_stamps = solve_module_placement(
        target, prog, seed_ref_ids=seed_ids, dual=True, pull_dependents=False
    );
    if new_stamps {
        _warn_state_forks(target, prog);
        importer = os.path.basename(module.loc.mod_path or '');
        tidx_by_id: dict[int, int] = {};
        for (tidx, tstmt) in enumerate(target.body) {
            tidx_by_id[id(tstmt)] = tidx;
        }
        for sid in seed_ids {
            sidx = tidx_by_id.get(sid);
            if sidx is not None {
                record_placement_evidence(
                    prog,
                    target.loc.mod_path or '',
                    sidx,
                    f"dual client: pulled through plain import from {importer}"
                );
            }
        }
    }
    return new_stamps;
}

def _pull_boundary_import(imp: uni.Import, module: uni.Module, prog: any) -> int {
    if (
        imp.is_service_import
        or imp.is_virtual_jac
        or imp.has_string_path
        or imp.from_loc is None
        or not imp.items
        or imp.code_context != CodeContext.CLIENT
    ) {
        return 0;
    }
    resolved = imp.from_loc.resolve_relative_path();
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return 0;
    }
    if _module_externally_pinned(resolved) {
        return 0;
    }
    targets: list[uni.Module] = [];
    hub_target = _materialize_module(os.path.abspath(resolved), prog);
    if hub_target is not None and hub_target is not module {
        targets.append(hub_target);
    }
    try {
        import from jaclang.compiler.symbol_utils { symbol_linked_source_module }
        linked = symbol_linked_source_module(imp);
        if (
            linked is not None
            and linked is not module
            and not any(linked is t for t in targets)
        ) {
            targets.append(linked);
        }
    } except Exception {
        ;
    }
    new_stamps = 0;
    for target in targets {
        new_stamps += _pull_into_target(imp, target, module, prog);
    }
    return new_stamps;
}

def solve_program_placement(entry_mod: uni.Module, prog: any) -> None {
    state = placement_state(prog);
    if state.get('solving') {
        return;
    }
    state['solving'] = True;
    try {
        rounds = 0;
        changed = True;
        while changed and rounds < 32 {
            changed = False;
            rounds += 1;
            mods: list[uni.Module] = [entry_mod];
            hub = prog?.mod?.hub;
            if isinstance(hub, dict) {
                for m in list(hub.values()) {
                    if isinstance(m, uni.Module) and m is not entry_mod {
                        mods.append(m);
                    }
                }
            }
            for m in mods {
                if not isinstance(m, uni.Module) {
                    continue;
                }
                for stmt in m.body {
                    if (
                        isinstance(stmt, uni.Import)
                        and stmt.code_context == CodeContext.CLIENT
                    ) {
                        if _pull_boundary_import(stmt, m, prog) > 0 {
                            changed = True;
                        }
                    }
                }
            }
        }
    } finally {
        state['solving'] = False;
    }
}

def demote_client_pulled_elements(
    module: uni.Module, prog: any, err_mark: int, warn_mark: int
) -> bool {
    mod_path = module.loc.mod_path or '';
    demoted: list[str] = [];
    demote_pinned: set[int] = set();
    for des in get_module_summary(module, prog).elements {
        if des.pinned {
            demote_pinned.add(des.index);
        }
    }
    for (idx, stmt) in enumerate(module.body) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.codespace_dual
            and stmt.code_context == CodeContext.CLIENT
            and idx not in demote_pinned
        ) {
            stmt.code_context = CodeContext.SERVER;
            stmt.codespace_dual = False;
            ps = get_module_summary(module, prog);
            dname = ps.elements[idx].name if idx < len(ps.elements) else 'element';
            demoted.append(dname);
            record_placement_evidence(
                prog,
                mod_path,
                idx,
                "demoted server: pulled client but failed ES lowering"
            );
        }
    }
    if not demoted {
        return False;
    }
    first_err = '';
    if err_mark < len(prog.errors_had) {
        try {
            first_err = prog.errors_had[err_mark].pretty_print().splitlines()[0];
        } except Exception {
            first_err = '';
        }
    }
    del prog.errors_had[err_mark:];
    del prog.warnings_had[warn_mark:];
    module.gen.js = '';
    module.gen.es_ast = None;
    key = os.path.abspath(mod_path);
    hub = prog?.mod?.hub;
    if isinstance(hub, dict) {
        for m in list(hub.values()) {
            if not isinstance(m, uni.Module) or m is module {
                continue;
            }
            for stmt in m.body {
                if (
                    isinstance(stmt, uni.Import)
                    and stmt.code_context == CodeContext.CLIENT
                    and stmt.from_loc is not None
                ) {
                    resolved = stmt.from_loc.resolve_relative_path();
                    if (
                        isinstance(resolved, str) and os.path.abspath(resolved) == key
                    ) {
                        m.gen.js = '';
                        m.gen.es_ast = None;
                    }
                }
            }
        }
    }
    try {
        import sys;
        import from jaclang.cli.console { console }
        console.print(
            f"note: {mod_path} was pulled into the client but did not lower; "
            f"demoted {', '.join(demoted)} back to the server ({first_err})",
            style="dim",
            file=sys.stderr
        );
    } except Exception {
        ;
    }
    return True;
}

obj PlacementApplyPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    static has PROVIDES: tuple = ('codespace-pull', );

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
}

impl PlacementApplyPass.postinit -> None {
    super.postinit();
}

impl PlacementApplyPass.transform(ir_in: uni.Module) -> uni.Module {
    solve_module_placement(ir_in, self.prog);
    return ir_in;
}
