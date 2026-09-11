import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.session.import_paths { resolve_import_path }
import from jaclang.compiler.analysis.boundaries.classify { is_service_bridge_import }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import os;
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.enums { CodeContext, Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { DiagnosticInfo }
import from jaclang.compiler.pipeline.pass_base { Transform }
import type from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.analysis.placement.worklist { PlacementWork }
import from jaclang.compiler.analysis.placement.evidence {
    PLACEMENT_HOLD_EXEMPT_ROOTS,
    get_module_summary,
    placement_state,
    record_placement_evidence,
    scan_native_blockers,
    summarize_module
}

glob _SPACE_BY_NAME: dict[str, CodeContext] = {
         'server': CodeContext.SERVER,
         'client': CodeContext.CLIENT,
         'native': CodeContext.NATIVE
     };

def placement_work(prog: AnalysisServices) -> PlacementWork {
    state = placement_state(prog);
    work = state.work;
    if not isinstance(work, PlacementWork) {
        work = PlacementWork(program=prog);
        state.work = work;
    }
    return work;
}

def refresh_placement_module(module: uni.Module, prog: AnalysisServices) {
    placement_work(prog).refresh(module);
}

def _endpoint_veto_applies(module: uni.Module) -> bool {
    import from jaclang.compiler.analysis.placement.evidence { project_has_server }
    return project_has_server(module);
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

def _py_import_client_portable(elem: uni.Import, app_kind: str = '') -> bool {
    import from jaclang.runtime.portability { supports }
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

def _pullable_by_client_reference(
    elem: uni.UniNode, module: uni.Module, body_refs: dict[int, set[int]]
) -> bool {
    import from jaclang.compiler.analysis.boundaries.classify {
        is_server_anchored_module
    }
    if isinstance(elem, uni.Archetype) and elem.arch_kind is not None {
        import from jaclang.compiler.analysis.placement.evidence {
            module_has_root_access
        }
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
        resolved = resolve_import_path(elem.from_loc);
        if isinstance(resolved, str) and resolved.endswith('.jac') {
            return True;
        }
        return _py_import_client_portable(elem, module.app_kind);
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
        return elem.access is None
            or not _endpoint_veto_applies(module)
            or not is_server_anchored_module(module);
    }
    return True;
}

def _is_sv_import(elem: uni.UniNode) -> bool {
    import from jaclang.compiler.analysis.boundaries.classify { import_crosses_apps }
    return isinstance(elem, uni.Import)
        and (is_service_bridge_import(elem) or import_crosses_apps(elem));
}

def _named_top_element(target: uni.Module, name: str) -> (uni.UniNode | None) {
    sym = target.names_in_scope.get(name) if target.names_in_scope else None;
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    return _top_element(target, decl);
}

def _materialize_module(path: str, prog: AnalysisServices) -> (uni.Module | None) {
    import from jaclang.compiler.analysis.boundaries.classify { hub_module_for_path }
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

def _import_source_module(
    elem: uni.Import, prog: AnalysisServices
) -> (uni.Module | None) {
    if elem.from_loc is None {
        return None;
    }
    resolved = resolve_import_path(elem.from_loc);
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return None;
    }
    placement_work(prog).observe_path(resolved);
    return _materialize_module(os.path.abspath(resolved), prog);
}

def _closure_pullable(
    top: uni.UniNode, module: uni.Module, prog: AnalysisServices, seen: set[int]
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
    import from jaclang.compiler.analysis.boundaries.classify {
        is_server_anchored_module
    }
    if isinstance(top, uni.Archetype) and top.arch_kind is not None {
        import from jaclang.compiler.analysis.placement.evidence {
            module_has_root_access
        }
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
    elem_by_id: dict[int, uni.UniNode] = {id(stmt): stmt for stmt in module.body};
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


def _module_externally_pinned(mod_path: str) -> bool {
    import from jaclang.compiler.analysis.placement.pins { config_module_pin }
    return config_module_pin(mod_path) != '';
}

def _seed_from_summary(module: uni.Module, prog: AnalysisServices) -> int {
    import from jaclang.compiler.analysis.boundaries.classify { _stamp_context_element }
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
    prog: AnalysisServices,
    seed_ref_ids: (set[int] | None) = None,
    dual: bool = False,
    pull_dependents: bool = True
) -> int {
    import from jaclang.compiler.analysis.boundaries.classify { _stamp_context_element }
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
        if stamp_count[0]
            and (artifact_for(module).js or artifact_for(module).es_ast is not None) {
            import from jaclang.compiler.pipeline.products { invalidate_client_product }
            invalidate_client_product(prog, module);
        }
    }

    stamp_count[0] += _seed_from_summary(module, prog);
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

def _emit_solver_warning(
    prog: AnalysisServices, diag: DiagnosticInfo, nd: uni.UniNode, **kwargs: any
) {
    import from jaclang.compiler.pipeline.pass_base { Alert }
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
                loc=nd.loc.span(),
                from_pass=PlacementApplyPass,
                code=diag,
                help_text=diag.format_help(**kwargs)
            )
        );
    } except Exception {}
}

def _warn_state_forks(target: uni.Module, prog: AnalysisServices) {
    import from jaclang.compiler.frontend.diagnostics { W6006 }
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
    imp: uni.Import, target: uni.Module, module: uni.Module, prog: AnalysisServices
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
        placement_work(prog).changed(target);
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

def _pull_boundary_import(
    imp: uni.Import, module: uni.Module, prog: AnalysisServices
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
    import from jaclang.compiler.analysis.boundaries.classify {
        plain_native_import_target
    }
    if plain_native_import_target(imp, prog) is not None {
        return 0;
    }
    resolved = resolve_import_path(imp.from_loc);
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
        import from jaclang.compiler.analysis.binding.symbol_utils {
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

def solve_program_placement(entry_mod: uni.Module, prog: AnalysisServices) {
    work = placement_work(prog);
    work.track(entry_mod);
    hub = prog?.mod?.hub;
    if isinstance(hub, dict) {
        for module in list(hub.values()) {
            if isinstance(module, uni.Module) {
                work.track(module);
            }
        }
    }
    work.drain(prog);
}

walker PlacementApplyPass(Transform) {
    has prog: AnalysisServices,
        ir_in: uni.Module,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
}

impl PlacementApplyPass.postinit -> None {
    super.postinit();
}

impl PlacementApplyPass._run_impl(ir_in: uni.Module) -> uni.Module {
    import from jaclang.compiler.analysis.binding.symbol_utils {
        report_serverless_kind_errors
    }
    refresh_placement_module(ir_in, self.prog);
    if solve_module_placement(ir_in, self.prog) {
        placement_work(self.prog).changed(ir_in);
    }
    report_serverless_kind_errors(self, ir_in);
    return ir_in;
}

impl PlacementApplyPass.transform(ir_in: uni.Module) -> uni.Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, uni.Module);
    return out;
}

impl PlacementApplyPass.run_walk with uni.Module entry {
    self.ir_out = self._run_impl(here);
}
