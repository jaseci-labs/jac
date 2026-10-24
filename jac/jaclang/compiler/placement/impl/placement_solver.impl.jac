impl native_scan_memo_clear {
    _na_scan_memo.clear();
}

impl placement_work(prog: JacProgram) -> PlacementWork {
    work = prog.analysis.placement_work;
    if work is None {
        work = PlacementWork();
        prog.analysis.placement_work = work;
    }
    return work;
}

impl refresh_placement_module(module: uni.Module, prog: JacProgram) {
    placement_work(prog).refresh(module);
}

impl _native_dep_scan(
    path: str, hold_exempt: bool = False
) -> (tuple[str, list[str]] | None) {
    host = active_host();
    files = [path]
        + host.annex_files(path, '.impl.jac')
        + host.annex_files(path, '.test.jac');
    arch = host.wiring_file(path);
    stamped = files + ([arch] if arch is not None else []);
    fresh: list[tuple[str, float, int]] = [];
    for f in stamped {
        try {
            fresh.append((f, os.path.getmtime(f), os.path.getsize(f)));
        } except OSError {
            return None;
        }
    }
    memo_key = f"{int(hold_exempt)}:{path}";
    cached = _na_scan_memo.get(memo_key);
    if cached is not None and cached.fresh == fresh {
        return (cached.reason, cached.deps);
    }
    sv_reason = '';
    deps: list[str] = [];
    base_dir = os.path.dirname(os.path.abspath(path)) or '.';
    woven = host.woven_module(path, JacProgram()) if arch is not None else None;
    if woven is not None {
        (sv_reason, deps) = scan_native_blockers(
            woven, base_dir, allow_pub=True, hold_exempt=hold_exempt
        );
    } else {
        for f in files {
            try {
                src = host.read_source(f);
            } except Exception {
                sv_reason = "unreadable annex";
                break;
            }
            (dep_mod, had_err) = rd_parse(src, f, prog=JacProgram());
            if had_err {
                sv_reason = "parse error";
                break;
            }
            (f_sv, f_deps) = scan_native_blockers(
                dep_mod, base_dir, allow_pub=True, hold_exempt=hold_exempt
            );
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
    _na_scan_memo[memo_key] = NativeDepScan(fresh=fresh, reason=sv_reason, deps=deps);
    return (sv_reason, deps);
}

impl _native_deps_ok(
    root_path: str, root_deps: list[str], hold_exempt: bool = False
) -> bool {
    edges: dict[str, list[str]] = {root_path: list(root_deps)};
    queue: list[str] = list(root_deps);
    while queue {
        dep = queue.pop();
        if dep in edges {
            continue;
        }
        if in_native_scope_path(dep) and not native_unit_compile_active() {
            return False;
        }
        info = _native_dep_scan(dep, hold_exempt=hold_exempt);
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

impl native_default_path_ok(path: str) -> bool {
    ap = os.path.abspath(path);

    _ap_posix = ap.replace(os.sep, "/");
    exempt = any(marker in _ap_posix for marker in PLACEMENT_HOLD_EXEMPT_ROOTS);
    info = _native_dep_scan(ap, hold_exempt=exempt);
    if info is None {
        return False;
    }
    (has_sv, deps) = info;
    if has_sv {
        return False;
    }
    return _native_deps_ok(ap, deps, hold_exempt=exempt);
}

impl native_placement_candidate(
    module: uni.Module, prog: JacProgram
) -> tuple[bool, str] {
    mod_path = module.loc.mod_path if module.loc is not None else '';
    if not mod_path {
        return (False, "no module path");
    }
    if not prog.infers_native_codespace(mod_path) {
        return (False, "the default codespace is not native");
    }
    if module.app_kind == 'web-app' {
        return (False, "web-app project: native is opt-in");
    }
    (env_ok, env_reason) = active_host().native_pipeline_available();
    if not env_ok {
        return (False, env_reason);
    }
    native_unit_compile = bool(prog.options is not None and prog.options.native_unit);
    if in_native_scope_path(mod_path) and not native_unit_compile {
        return (False, "compiler frontend module: native only inside the kernel build");
    }
    if not any([isinstance(e, uni.ElementStmt) for e in module.elements]) {
        return (False, "empty module: nothing to lower");
    }
    for elem in module.elements {
        if isinstance(elem, uni.ContextAwareNode)
            and elem.code_context == CodeContext.CLIENT {
            return (False, "declares client elements");
        }
    }
    return (True, '');
}

impl dependency_summary(prog: JacProgram, path: str) -> (PlacementSummary | None) {
    key = os.path.abspath(path);
    store = summary_store(prog);
    if key in store {
        return store[key];
    }
    mod = hub_module_for_path(key, prog);
    if mod is None {
        try {
            mod = prog.load_dependency_module(key);
        } except Exception {
            return store.get(key);
        }
        if key in store {
            return store[key];
        }
    }
    if mod is None or mod.stub_only or mod.loc is None or not mod.loc.mod_path {
        return store.get(key);
    }
    return get_module_summary(mod, prog, with_refs=False);
}

impl native_closure_blocker(
    prog: JacProgram, root_path: str, deps: list[str]
) -> tuple[str, bool] {
    seen: set[str] = {os.path.abspath(root_path)};
    queue: list[str] = [os.path.abspath(dep) for dep in deps];
    while queue {
        dep = queue.pop();
        if dep in seen {
            continue;
        }
        seen.add(dep);
        name = os.path.basename(dep);
        if in_native_scope_path(dep) and not native_unit_compile_active() {
            return (f"'{name}' is a compiler frontend module", False);
        }
        if pinned_module_space(dep) == 'server' {
            return (f"'{name}' is pinned to the server", True);
        }
        summary = dependency_summary(prog, dep);
        if summary is None {
            return (f"'{name}' has no placement facts", False);
        }
        if summary.native_blocker {
            return (f"'{name}' cannot be native ({summary.native_blocker})", False);
        }
        for more in summary.jac_deps {
            if os.path.abspath(more) not in seen {
                queue.append(os.path.abspath(more));
            }
        }
    }
    return ('', False);
}

impl _endpoint_veto_applies(module: uni.Module) -> bool {
    return project_has_server(module);
}

impl _is_client_top(elem: uni.UniNode) -> bool {
    return isinstance(elem, uni.ContextAwareNode)
        and elem.code_context == CodeContext.CLIENT;
}

impl _py_import_client_portable(elem: uni.Import, app_kind: str = '') -> bool {
    kind = app_kind or 'web-app';
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
        if not supports(tgt, 'client', kind) {
            return False;
        }
    }
    return True;
}

impl _pullable_by_client_reference(
    elem: uni.UniNode, module: uni.Module, body_refs: dict[int, set[int]]
) -> bool {
    if isinstance(elem, uni.Archetype) and elem.arch_kind is not None {
        import from jaclang.compiler.placement.placement { module_has_root_access }
        if module_has_root_access(elem) {
            return False;
        }
    }
    if isinstance(elem, uni.Import) {
        if elem.has_string_path {
            return True;
        }
        if elem.from_loc is None {
            return _py_import_client_portable(elem, module.app_kind);
        }
        resolved = elem.from_loc.resolve_relative_path();
        if isinstance(resolved, str) and resolved.endswith('.jac') {
            return True;
        }
        return _py_import_client_portable(elem, module.app_kind);
    }
    if isinstance(elem, (uni.Archetype, uni.TypeAlias)) {
        for top in module.elements {
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
        return elem.access is None
            or not _endpoint_veto_applies(module)
            or not is_server_anchored_module(module);
    }
    return True;
}

impl _ref_top_ids(module: uni.Module, elem: uni.UniNode) -> set[int] {
    refs: set[int] = set();
    for nm in elem.element_sub_nodes(uni.Name) {
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
        top = decl.element_in(module);
        if (top is None or top is elem) {
            continue;
        }
        refs.add(id(top));
    }
    return refs;
}

impl _is_sv_import(elem: uni.UniNode) -> bool {
    return isinstance(elem, uni.Import)
        and (elem.is_service_import or import_crosses_apps(elem));
}

impl _named_top_element(target: uni.Module, name: str) -> (uni.UniNode | None) {
    sym = target.names_in_scope.get(name) if target.names_in_scope else None;
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    return decl.element_in(target);
}

impl _materialize_module(path: str, prog: JacProgram) -> (uni.Module | None) {
    found = hub_module_for_path(path, prog);
    if found is not None {
        return found;
    }
    if not os.path.exists(path) {
        return None;
    }
    try {
        return prog.load_dependency_module(path, need_tree=True);
    } except Exception {
        return None;
    }
}

impl _import_source_module(elem: uni.Import, prog: JacProgram) -> (uni.Module | None) {
    if elem.from_loc is None {
        return None;
    }
    resolved = elem.from_loc.resolve_relative_path();
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return None;
    }
    placement_work(prog).observe_path(resolved);
    found = _materialize_module(os.path.abspath(resolved), prog);
    import from jaclang.compiler.types.stubcat.reader { CatModule }
    import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
    if isinstance(found, CatModule) and is_compiler_source_path(resolved) {
        return None;
    }
    return found;
}

impl _closure_pullable(
    top: uni.UniNode, module: uni.Module, prog: JacProgram, seen: set[int]
) -> bool {
    work = placement_work(prog);
    work.observe(module);
    if id(top) in seen {
        return True;
    }
    seen.add(id(top));
    if isinstance(top, uni.ContextAwareNode)
        and top.code_context == CodeContext.CLIENT {
        return True;
    }
    if isinstance(top, uni.Import) {
        if _is_sv_import(top) {
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
    import from jaclang.compiler.driver.boundary_classify { is_server_anchored_module }
    if isinstance(top, uni.Archetype) and top.arch_kind is not None {
        import from jaclang.compiler.placement.placement { module_has_root_access }
        if module_has_root_access(top) {
            return False;
        }
    }
    if (
        isinstance(top, uni.Ability)
        and top.access is not None
        and _endpoint_veto_applies(module)
        and is_server_anchored_module(module)
    ) {
        return False;
    }
    elem_by_id: dict[int, uni.UniNode] = {id(stmt): stmt for stmt in module.elements};
    for ref_id in work.refs(module).get(id(top), set()) {
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

impl _module_externally_pinned(mod_path: str) -> bool {
    return config_module_pin(mod_path) != '';
}

impl _python_backend_forced(prog: JacProgram) -> bool {
    return prog.options.force_codespace == "server";
}

impl _seed_from_summary(module: uni.Module, prog: JacProgram) -> int {
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
            if cap == 'FFI' and _python_backend_forced(prog) {
                continue;
            }
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
            if cap == 'NPM' {
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

impl solve_module_placement(
    module: uni.Module,
    prog: JacProgram,
    seed_ref_ids: (set[int] | None) = None,
    dual: bool = False,
    pull_dependents: bool = True
) -> int {
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
            import from jaclang.compiler.driver.pipeline { invalidate }
            import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
            invalidate(prog, module, CompilationProduct.CLIENT);
        }
    }

    if module.gen.placement_mode != 'inferred' {
        stamp_count[0] += _seed_from_summary(module, prog);
    }
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
        if not isinstance(stmt, uni.ContextAwareNode) or stmt.top_element is not stmt {
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
    if module.gen.placement_mode == 'inferred' {
        client_tops = [];
        native_tops = [];
    }
    if ((not client_tops and not native_tops and not has_seeds) or not inferable) {
        _invalidate_stale_codegen();
        return stamp_count[0];
    }

    cl_sources: set[int] = set();
    cl_ref_ids: set[int] = set(seed_ref_ids) if seed_ref_ids else set();
    na_sources: set[int] = set();
    na_ref_ids: set[int] = set();
    uses_map: dict[int, set[int]] = {};
    body_refs = placement_work(prog).refs(module);

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
        cl_ref_ids.update(body_refs[id(elem)]);
    }
    for elem in native_tops {
        if not _is_sv_import(elem) {
            na_sources.add(id(elem));
            na_seed_ids.add(id(elem));
        }
        na_ref_ids.update(body_refs[id(elem)]);
    }
    for elem in inferable {
        uses_map[id(elem)] = body_refs[id(elem)];
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
    refusals = prog.analysis.placement_refusals.get(os.path.realpath(mod_path), {});
    cl_refused: set[int] = refusals.get('client', set());
    na_refused: set[int] = refusals.get('native', set());
    cl_star = _hard_closure(cl_seed_ids) - cl_refused;
    na_star = _hard_closure(na_seed_ids) - na_refused;
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
            want_cl = id(elem) not in cl_refused
                and (
                    (pull_dependents and not cl_sources.isdisjoint(refs))
                    or (
                        id(elem) in cl_ref_ids
                        and _pullable_by_client_reference(elem, module, body_refs)
                    )
                );
            want_na = id(elem) not in na_refused
                and (
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

impl _emit_solver_warning(
    prog: JacProgram, diag: DiagnosticInfo, nd: uni.UniNode, name: str
) {
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
                msg=diag.format_message(name=name),
                loc=nd.loc.span(),
                from_pass=CompilerPass,
                code=diag,
                help_text=diag.format_help(name=name)
            )
        );
    } except Exception {}
}

impl _warn_state_forks(target: uni.Module, prog: JacProgram) {
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

impl _held_pull_ids(target: uni.Module, target_path: str) -> set[int] {
    held: set[int] = set();
    for part in active_host().client_pulls(target_path).split(",") {
        if not part {
            continue;
        }
        index = int(part);
        if index < len(target.body) {
            held.add(id(target.body[index]));
        }
    }
    return held;
}

impl _pull_into_target(
    imp: uni.Import, target: uni.Module, module: uni.Module, prog: JacProgram
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
    import from jaclang.compiler.frontend.host { active_host }
    work = placement_work(prog);
    target_path = os.path.realpath(target.loc.mod_path or '');
    if id(target) not in work.seeded {
        work.seeded.add(id(target));
        held_ids = _held_pull_ids(target, target_path);
        if held_ids
            and solve_module_placement(
                target, prog, seed_ref_ids=held_ids, dual=True, pull_dependents=False
            ) {
            work.changed(target);
        }
    }
    new_stamps = solve_module_placement(
        target, prog, seed_ref_ids=seed_ids, dual=True, pull_dependents=False
    );
    if new_stamps {
        active_host().client_pull_grew(target_path);
        work.changed(target);
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

impl _pull_boundary_import(
    imp: uni.Import, module: uni.Module, prog: JacProgram
) -> int {
    work = placement_work(prog);
    work.observe(module);
    if (
        _is_sv_import(imp)
        or imp.is_typed
        or imp.is_virtual_jac
        or imp.has_string_path
        or imp.from_loc is None
        or not imp.items
        or not imp.in_client_context()
    ) {
        return 0;
    }
    import from jaclang.compiler.driver.boundary_classify { plain_native_import_target }
    if plain_native_import_target(imp, prog) is not None {
        return 0;
    }
    resolved = imp.from_loc.resolve_relative_path();
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return 0;
    }
    work.observe_path(resolved);
    if _module_externally_pinned(resolved) {
        return 0;
    }
    targets: list[uni.Module] = [];
    hub_target = _materialize_module(os.path.abspath(resolved), prog);
    if hub_target is not None and hub_target is not module {
        targets.append(hub_target);
    }
    try {
        import from jaclang.compiler.driver.boundary_classify {
            symbol_linked_source_module
        }
        linked = symbol_linked_source_module(imp);
        if (
            linked is not None
            and linked is not module
            and not any(linked is t for t in targets)
        ) {
            targets.append(linked);
        }
    } except Exception {}
    new_stamps = 0;
    for target in targets {
        work.observe(target);
        new_stamps += _pull_into_target(imp, target, module, prog);
    }
    return new_stamps;
}

impl solve_program_placement(entry_mod: uni.Module, prog: JacProgram) {
    work = placement_work(prog);
    work.track(entry_mod);
    for module in list(prog.mod.hub.values()) {
        work.track(module);
    }
    work.drain(prog);
}

impl invalidate_importers_es(prog: JacProgram, mod_path: str) -> list[uni.Module] {
    cleared: list[uni.Module] = [];
    key = os.path.realpath(mod_path);
    for m in list(prog.mod.hub.values()) {
        if m.loc is None or os.path.realpath(m.loc.mod_path) == key {
            continue;
        }
        for imp in m.get_all_sub_nodes(uni.Import) {
            if imp.from_loc is None {
                continue;
            }
            try {
                target = imp.from_loc.resolve_relative_path();
            } except Exception {
                continue;
            }
            if isinstance(target, str) and os.path.realpath(target) == key {
                import from jaclang.compiler.driver.pipeline { invalidate }
                import from jaclang.compiler.driver.pipeline_types {
                    CompilationProduct
                }
                invalidate(prog, m, CompilationProduct.CLIENT);
                cleared.append(m);
                break;
            }
        }
    }
    return cleared;
}

impl PlacementApplyPass._run_impl(ir_in: uni.Module) -> uni.Module {
    """What syntax alone decides about placement is decided here, before the
    module is typed: client seeds, and whether the module's native preference
    is open. A construct that closes it (an async or by-llm ability, inline
    Python, an endpoint, a Python-only import, persistent-graph access) is
    known from the tree, and the checker needs the answer to know whether a
    native-only idiom is a requirement or an error.""";
    import from jaclang.compiler.symbol_utils { report_serverless_kind_errors }
    if ir_in.loc is not None {
        self.prog.analysis.placement_refusals.pop(
            os.path.realpath(ir_in.loc.mod_path), None
        );
    }
    if ir_in.gen.native_undecided and ir_in.loc is not None and ir_in.loc.mod_path {
        import from jaclang.compiler.placement.placement { native_blocker_scan }
        base_dir = os.path.dirname(os.path.abspath(ir_in.loc.mod_path)) or ".";
        closed = native_blocker_scan(ir_in, base_dir).first();
        if closed {
            ir_in.gen.native_undecided = False;
            ir_in.gen.native_closed_why = closed;
        }
    }
    refresh_placement_module(ir_in, self.prog);
    if solve_module_placement(ir_in, self.prog) {
        placement_work(self.prog).changed(ir_in);
    }
    report_serverless_kind_errors(self, ir_in);
    return ir_in;
}

impl PlacementApplyPass.run_walk with uni.Module entry {
    self.module = self._run_impl(here);
}
