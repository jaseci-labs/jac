impl PlacementSummary.element_at(index: int) -> (ElementSummary | None) {
    for es in self.elements {
        if es.index == index {
            return es;
        }
    }
    return None;
}

impl NativeBlockerScan.first -> str {
    if self.module {
        return self.module;
    }
    return self.sites[0][1] if self.sites else '';
}

impl element_display_name(stmt: uni.UniNode) -> str {
    if isinstance(stmt, uni.Ability) and isinstance(stmt.name_ref, uni.Name) {
        return stmt.name_ref.value;
    }
    if isinstance(stmt, (uni.Archetype, uni.Enum, uni.TypeAlias)) {
        return stmt.name.value;
    }
    if isinstance(stmt, uni.GlobalVars) {
        names: list[str] = [];
        for assign in stmt.assignments {
            for tgt in assign.target {
                if isinstance(tgt, uni.Name) {
                    names.append(tgt.value);
                }
            }
        }
        return ",".join(names) if names else "<glob>";
    }
    if isinstance(stmt, uni.Import) {
        if stmt.from_loc is not None {
            return f"from:{stmt.from_loc.dot_path_str}";
        }
        parts: list[str] = [];
        for item in stmt.items {
            if isinstance(item, uni.ModulePath) {
                parts.append(item.dot_path_str);
            }
        }
        return "import:" + ",".join(parts) if parts else "<import>";
    }
    if isinstance(stmt, uni.ModuleCode) {
        return "<entry>";
    }
    return f"<{type(stmt).__name__}>";
}

impl _endpoint_evidence(stmt: uni.UniNode) -> str {
    if not isinstance(stmt, (uni.Ability, uni.GlobalVars, uni.Archetype, uni.Enum)) {
        return '';
    }
    exposure = stmt.exposure;
    if exposure == SymbolAccess.PUBLIC {
        return 'pub access';
    }
    if exposure == SymbolAccess.PROTECTED
        and isinstance(stmt, (uni.Ability, uni.Archetype))
        and stmt.surface_kind {
        return 'protect access';
    }
    return '';
}

impl project_kind_name(module: (uni.Module | None)) -> str {
    if module is None {
        return '';
    }
    if module.app_kind {
        return module.app_kind;
    }
    import from jaclang.compiler.placement.placement_pins { config_project_kind }
    return config_project_kind(module.loc.mod_path or '') if module.loc else '';
}

impl project_has_server(module: (uni.Module | None)) -> bool {
    return kind_codespace(project_kind_name(module)) != 'client';
}

impl _resolve_import_path(nd: (uni.ModulePath | uni.ModuleItem)) -> (str | None) {
    path = '';
    try {
        if isinstance(nd, uni.ModulePath) {
            path = nd.resolve_relative_path();
        } else {
            path = nd.resolve_relative_path();
        }
    } except Exception {
        return None;
    }
    if path and os.path.exists(path) {
        return path;
    }
    return None;
}

impl _fill_import_facts(es: ElementSummary, imp: uni.Import) {
    es.import_eco = imp.ecosystem;
    es.sv_import = imp.is_service_import;
    if imp.from_loc is not None {
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name) {
                es.import_items.append(item.name.value);
            }
        }
        resolved = _resolve_import_path(imp.from_loc);
        if resolved is not None and resolved.endswith('.jac') {
            es.import_jac_target = os.path.abspath(resolved);
        } elif es.import_eco == 'py' {
            es.import_py_targets.append(imp.from_loc.dot_path_str);
        }
    } else {
        for item in imp.items {
            if isinstance(item, uni.ModulePath) {
                resolved = _resolve_import_path(item);
                if resolved is not None and resolved.endswith('.jac') {
                    es.import_jac_target = os.path.abspath(resolved);
                } elif es.import_eco == 'py' {
                    es.import_py_targets.append(item.dot_path_str);
                }
            }
        }
    }
}

impl module_has_root_access(stmt: uni.UniNode) -> bool {
    mod = stmt
        if isinstance(stmt, uni.Module)
        else stmt.find_parent_of_type(uni.Module);
    if mod is None {
        return True;
    }

    cached = mod.gen.has_root_access;
    if cached is not None {
        return cached;
    }
    found = False;
    for svr in mod.get_all_sub_nodes(uni.SpecialVarRef) {
        if svr.orig.name == Tok.KW_ROOT and not ModuleFacts.is_test_code(svr) {
            found = True;
            break;
        }
    }
    mod.gen.has_root_access = found;
    return found;
}

impl _element_reqs(stmt: uni.UniNode) -> list[list[str]] {
    reqs: list[list[str]] = [];
    if isinstance(stmt, uni.Import) {
        eco = stmt.ecosystem;
        if stmt.has_clib_decls {
            reqs.append(['FFI', 'clib extern import']);
        } elif eco == 'string' {
            reqs.append(['NPM', 'string-path import']);
        } elif eco == 'virtual' {
            reqs.append(['NPM', 'virtual @jac import']);
        } elif eco == 'py' {
            import from jaclang.compiler.driver.boundary_classify { classify_import }
            verdict = classify_import(stmt);
            reqs.append(['NPM' if verdict.world == 'npm' else 'PY', verdict.rule]);
        }
        return reqs;
    }
    if isinstance(stmt, uni.PyInlineCode) {
        reqs.append(['PY', 'inline ::py:: block']);
        return reqs;
    }
    if stmt.element_sub_nodes(uni.JsxElement) {
        reqs.append(['DOM', 'jsx construction']);
    }
    for svr in stmt.element_sub_nodes(uni.SpecialVarRef) {
        if svr.orig.name == Tok.KW_ROOT {
            reqs.append(['PERSIST', 'root access']);
            break;
        }
    }
    if isinstance(stmt, uni.Archetype) and stmt.arch_kind is not None {
        if module_has_root_access(stmt) {
            reqs.append(['PERSIST', f"{stmt.arch_kind} archetype"]);
        }
    }
    for ab in stmt.element_sub_nodes(uni.Ability) {
        if ab.is_async {
            reqs.append(['SERVER', 'async ability']);
            break;
        }
    }
    if isinstance(stmt, uni.Ability)
        and isinstance(stmt.signature, uni.EventSignature) {
        reqs.append(['SERVER', 'event ability outside an archetype']);
    }
    endpoint = _endpoint_evidence(stmt);
    if endpoint and project_has_server(stmt.find_parent_of_type(uni.Module)) {
        reqs.append(['ENDPOINT', endpoint]);
    }
    return reqs;
}

impl _element_ref_ids(module: uni.Module, elem: uni.UniNode) -> set[int] {
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

impl _escape_kind(nm: uni.Name, elem: uni.UniNode) -> str {
    prev: uni.UniNode = nm;
    cur = nm.parent;
    while cur is not None and cur is not elem {
        if isinstance(cur, uni.FuncCall) {
            if cur.target is prev {
                return '';
            }
            return 'call-arg';
        }
        if isinstance(cur, uni.ReturnStmt) {
            return 'returned';
        }
        if isinstance(cur, (uni.ListVal, uni.TupleVal, uni.SetVal, uni.DictVal)) {
            return 'container';
        }
        if isinstance(cur, uni.Assignment) {
            if any(t is prev for t in cur.target) {
                return '';
            }
            return 'assigned';
        }
        prev = cur;
        cur = cur.parent;
    }
    return '';
}

impl _element_escape_edges(
    module: uni.Module, elem: uni.UniNode
) -> list[tuple[int, str]] {
    edges: list[tuple[int, str]] = [];
    seen: set[tuple[int, str]] = set();
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
        if sym is None or sym.decl is None {
            continue;
        }
        top = sym.decl.element_in(module);
        if (
            top is None
            or top is elem
            or not isinstance(top, uni.Ability)
            or top.is_method
        ) {
            continue;
        }
        kind = _escape_kind(nm, elem);
        if not kind {
            continue;
        }
        key = (id(top), kind);
        if key in seen {
            continue;
        }
        seen.add(key);
        edges.append((id(top), kind));
    }
    return edges;
}

impl _element_glob_write_ids(module: uni.Module, elem: uni.UniNode) -> set[int] {
    writes: set[int] = set();
    for assign in elem.element_sub_nodes(uni.Assignment) {
        for tgt in assign.target {
            if not isinstance(tgt, uni.Name) {
                continue;
            }
            tab = tgt?.sym_tab;
            if tab is None {
                continue;
            }
            sym = tab.lookup(name=tgt.value, deep=True);
            if sym is None or sym.decl is None {
                continue;
            }
            top = sym.decl.element_in(module);
            if (
                top is not None and top is not elem and isinstance(top, uni.GlobalVars)
            ) {
                writes.add(id(top));
            }
        }
    }
    return writes;
}

impl _is_filter_field_name(nm: uni.Name) -> bool {
    par = nm.parent;
    if isinstance(par, uni.FilterCompr) {
        return par.f_type is not nm;
    }
    if isinstance(par, uni.UnaryExpr) and par.operand is nm {
        return isinstance(par.parent, uni.FilterCompr);
    }
    cur: uni.UniNode = nm;
    if isinstance(par, uni.TupleVal) {
        cur = par;
        par = par.parent;
    }
    return (
        isinstance(par, uni.CompareExpr)
        and par.left is cur
        and isinstance(par.parent, uni.FilterCompr)
    );
}

impl _names_a_member(nm: uni.Name) -> bool {
    par = nm.parent;
    if isinstance(par, uni.AtomTrailer) and par.is_attr and par.right is nm {
        return True;
    }
    if isinstance(par, uni.KWPair) and par.key is nm {
        return True;
    }
    if (
        isinstance(par, uni.MatchKVPair)
        and par.key is nm
        and isinstance(par.parent, uni.MatchArch)
    ) {
        return True;
    }
    return _is_filter_field_name(nm);
}

impl _references_browser_seed_global(elem: uni.UniNode) -> str {
    for nm in elem.element_sub_nodes(uni.Name) {
        if nm.value not in BROWSER_SEED_GLOBALS {
            continue;
        }
        if _names_a_member(nm) {
            continue;
        }
        tab = nm?.sym_tab;
        if tab is None {
            continue;
        }
        if tab.lookup(name=nm.value, deep=True) is None {
            return nm.value;
        }
    }
    return '';
}

impl module_anchor_reasons(module: uni.Module) -> list[str] {
    reasons: list[str] = [];
    mod_path = module.loc.mod_path or '';
    if config_module_pin(mod_path) == 'server' {
        reasons.append('config pin');
    }
    if mod_path {
        import from jaclang.compiler.driver.boundary_classify { is_service_app_entry }
        if is_service_app_entry(mod_path) {
            reasons.append('service app entry');
        }
    }
    for arch in module.get_all_sub_nodes(uni.Archetype) {
        if arch.arch_kind is not None
            and not ModuleFacts.is_test_code(arch)
            and module_has_root_access(module) {
            reasons.append(f"graph archetype '{arch.name.value}'");
            break;
        }
    }
    import from jaclang.compiler.driver.boundary_classify { ability_delegates_to_model }
    for ab in module.get_all_sub_nodes(uni.Ability) {
        if ability_delegates_to_model(ab) and not ModuleFacts.is_test_code(ab) {
            reasons.append(f"by llm ability '{ab.py_resolve_name()}'");
            break;
        }
    }
    for inline_py in module.get_all_sub_nodes(uni.PyInlineCode) {
        if not ModuleFacts.is_test_code(inline_py) {
            reasons.append('inline ::py:: block');
            break;
        }
    }
    for stmt in ModuleFacts.iter_placement_stmts(module) {
        if isinstance(stmt, uni.TypedCtxBlock) {
            reasons.append('typed context block');
            break;
        }
    }
    import from jaclang.compiler.driver.boundary_classify { classify_import }
    for imp in module.get_all_sub_nodes(uni.Import) {
        if imp.has_clib_decls or imp.is_virtual_jac or imp.has_string_path {
            continue;
        }
        if imp.is_comptime or ModuleFacts.is_test_code(imp) {
            continue;
        }
        if classify_import(imp).world == 'py' {
            reasons.append('plain python import');
            break;
        }
    }
    return reasons;
}

impl _erased_only_import(imp: uni.Import) -> bool {
    if imp.from_loc is None or imp.is_absorb {
        return False;
    }
    names: list[str] = [];
    for item in imp.items {
        if not (isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)) {
            return False;
        }
        names.append(item.name.value);
    }
    return native_erased_import_names(imp.from_loc.dot_path_str, names);
}

impl native_blocker_scan(
    module: uni.Module,
    base_dir: str,
    allow_pub: bool = False,
    hold_exempt: bool = False
) -> NativeBlockerScan {
    scan = NativeBlockerScan();
    _held_path = (module.loc.mod_path if module.loc is not None else '') or '';
    if not hold_exempt {
        for (_held_rel, _held_why) in PLACEMENT_INFERENCE_HELD.items() {
            if _held_path.replace(os.sep, "/").endswith("/jaclang/" + _held_rel) {
                scan.module = f"inference held: {_held_why}";
                return scan;
            }
        }
    }
    _scan_blockers_under(scan, module, module, base_dir, allow_pub);
    for stmt in module.body {
        if isinstance(stmt, uni.Test) {
            probe = NativeBlockerScan();
            _scan_blockers_under(probe, stmt, module, base_dir, True);
            why = probe.first();
            if why {
                scan.tests.append((stmt, why));
                continue;
            }
            for (dep_imp, dep_path) in probe.dep_imports {
                scan.test_dep_imports.append((stmt, dep_imp, dep_path));
            }
        }
    }
    return scan;
}

impl _scan_blockers_under(
    scan: NativeBlockerScan,
    scope_node: uni.UniNode,
    module: uni.Module,
    base_dir: str,
    allow_pub: bool
) {
    deps = scan.deps;
    skip_tests = scope_node is module;
    for (nd_name, typ) in PLACEMENT_SV_SIGNAL_NODES {
        for found in scope_node.get_all_sub_nodes(typ) {
            if skip_tests and ModuleFacts.is_test_code(found) {
                continue;
            }
            scan.sites.append((found, f"contains {nd_name}"));
        }
    }

    for (nd_name, typ) in PLACEMENT_NATIVE_REJECT_NODES {
        for found in scope_node.get_all_sub_nodes(typ) {
            if skip_tests and ModuleFacts.is_test_code(found) {
                continue;
            }
            scan.sites.append((found, f"native-unsupported {nd_name}"));
        }
    }
    for svr in scope_node.get_all_sub_nodes(uni.SpecialVarRef) {
        if skip_tests and ModuleFacts.is_test_code(svr) {
            continue;
        }
        if svr.orig.name == Tok.KW_ROOT and not scan.module {
            scan.module = "root access (persistent graph)";
        }
    }
    import from jaclang.compiler.driver.boundary_classify { ability_delegates_to_model }
    for ab in scope_node.get_all_sub_nodes(uni.Ability) {
        if skip_tests and ModuleFacts.is_test_code(ab) {
            continue;
        }
        if ability_delegates_to_model(ab) {
            scan.sites.append((ab, "by llm ability (needs the byLLM runtime)"));
            continue;
        }
        if ab.is_async {
            scan.sites.append((ab, "async ability"));
            continue;
        }
        if isinstance(ab.signature, uni.EventSignature) {
            if ab.enclosing_decl(uni.Archetype) is None {
                scan.sites.append((ab, "event ability outside an archetype"));
                continue;
            }
            _ti = ab.signature.arch_tag_info;
            _ti_names = [_ti]
                if isinstance(_ti, uni.Name)
                else (_ti.get_all_sub_nodes(uni.Name) if _ti is not None else []);
            for _tn in _ti_names {
                if _tn.value in ("Root", "root") and not scan.module {
                    scan.module = "root access (persistent graph)";
                }
            }
        }
    }
    scan_mod_path = module.loc.mod_path or '';
    weighed: list[uni.UniNode] = ModuleFacts.iter_placement_stmts(module)
        if skip_tests
        else [];
    for stmt in weighed {
        if stmt.top_element is not stmt {
            continue;
        }
        if isinstance(stmt, uni.ContextAwareNode) and scan_mod_path {
            import from jaclang.compiler.placement.placement_pins { config_pin_for }
            pin = config_pin_for(scan_mod_path, element_display_name(stmt));
            if pin in ('server', 'client') {
                scan.sites.append((stmt, "explicit sv/cl pin"));
                continue;
            }
        }

        endpoint = _endpoint_evidence(stmt);
        if not allow_pub and endpoint {
            scan.sites.append((stmt, endpoint));
        }
    }
    for imp in scope_node.get_all_sub_nodes(uni.Import) {
        if skip_tests and ModuleFacts.is_test_code(imp) {
            continue;
        }
        if imp.has_clib_decls {
            continue;
        }
        if imp.is_typed or imp.is_comptime {
            continue;
        }
        if imp.enclosing_decl(uni.Ability) is not None {
            continue;
        }
        if imp.is_virtual_jac or imp.has_string_path {
            scan.sites.append((imp, "virtual/string-path import"));
            continue;
        }
        if _erased_only_import(imp) {
            continue;
        }
        targets: list[tuple[str, (str | None), bool, bool]] = [];
        if imp.from_loc is not None {
            targets.append(
                (
                    imp.from_loc.dot_path_str,
                    _resolve_import_path(imp.from_loc),
                    False,
                    False
                )
            );
            for item in imp.items {
                if isinstance(item, uni.ModuleItem) {
                    item_path = _resolve_import_path(item);
                    if item_path is not None {
                        targets.append(("", item_path, False, False));
                    }
                }
            }
        } else {
            for item in imp.items {
                if isinstance(item, uni.ModulePath) {
                    targets.append(
                        (
                            item.dot_path_str,
                            _resolve_import_path(item),
                            not imp.is_absorb,
                            not imp.is_absorb and item.path is not None
                        )
                    );
                }
            }
        }
        for (name, path, is_bare, is_module_import) in targets {
            clean = name.lstrip('.') if name else '';
            if is_bare {
                if clean and clean in NATIVE_SUPPORTED_STDLIB {
                    continue;
                }
                if clean and is_bundled_native_module(clean) {
                    continue;
                }
                if not (
                    is_module_import and path is not None and path.endswith('.jac')
                ) {
                    scan.sites.append((imp, f"non-native import '{clean}'"));
                    break;
                }
            }
            if path is not None {
                import from jaclang.compiler.placement.placement_pins {
                    config_module_pin as _cmp
                }
                if _cmp(path) == 'client' {
                    scan.sites.append((imp, "client module import"));
                    break;
                }
            }
            if path is not None and path.endswith('.jac') {
                deps.append(os.path.abspath(path));
                scan.dep_imports.append((imp, os.path.abspath(path)));
                continue;
            }
            if clean and clean in NATIVE_SUPPORTED_STDLIB {
                continue;
            }
            if clean and is_bundled_native_module(clean) {
                continue;
            }
            if clean
                and resolve_native_module(clean, base_dir, allow_inferred=False)[1]
                    is not None {
                continue;
            }
            scan.sites.append((imp, f"unresolved import '{clean}'"));
            break;
        }
    }
}

impl scan_native_blockers(
    module: uni.Module,
    base_dir: str,
    allow_pub: bool = False,
    hold_exempt: bool = False
) -> tuple[str, list[str]] {
    scan = native_blocker_scan(module, base_dir, allow_pub, hold_exempt);
    return (scan.first(), scan.deps);
}

impl summarize_module(
    module: uni.Module, with_refs: bool = True, prog: (JacProgram | None) = None
) -> PlacementSummary {
    ps = PlacementSummary();
    ps.schema = PLACEMENT_SCHEMA;
    ps.mod_path = module.loc.mod_path or '';
    ps.decided = module.decided_codespace or '';
    ps.anchors = module_anchor_reasons(module);
    base_dir = os.path.dirname(os.path.abspath(ps.mod_path)) if ps.mod_path else '';
    (blocker, deps) = scan_native_blockers(module, base_dir, allow_pub=True);
    ps.native_blocker = blocker;
    ps.jac_deps = deps;
    ps.has_refs = with_refs;
    index_by_id: dict[int, int] = {};
    for (idx, stmt) in enumerate(module.body) {
        index_by_id[id(stmt)] = idx;
    }
    server_anchored = bool(ps.anchors);
    for (idx, stmt) in enumerate(module.body) {
        if stmt.top_element is not stmt {
            continue;
        }
        es = ElementSummary();
        es.index = idx;
        es.kind = type(stmt).__name__;
        es.name = element_display_name(stmt);
        es.pinned = '';
        if ps.mod_path {
            import from jaclang.compiler.placement.placement_pins {
                config_element_pin,
                config_module_pin,
                effective_pin_for
            }
            es.pinned = effective_pin_for(ps.mod_path, es.name, prog);
            if es.pinned == 'native'
                and prog is not None
                and config_module_pin(ps.mod_path) == 'native'
                and prog.prefers_native_codespace(ps.mod_path) {
                es.pinned = config_element_pin(ps.mod_path, es.name);
            }
        }
        es.is_pub = _endpoint_evidence(stmt) == 'pub access';
        es.reqs = _element_reqs(stmt);
        if isinstance(stmt, uni.Import) {
            _fill_import_facts(es, stmt);
        }
        if with_refs {
            if (
                not server_anchored
                and not isinstance(stmt, uni.Import)
                and not es.pinned
            ) {
                seed_global = _references_browser_seed_global(stmt);
                if seed_global {
                    es.reqs.append(['DOM', f"browser global '{seed_global}'"]);
                }
            }
            for rid in _element_ref_ids(module, stmt) {
                ridx = index_by_id.get(rid);
                if ridx is not None {
                    es.refs.append(ridx);
                }
            }
            es.refs.sort();
            for wid in _element_glob_write_ids(module, stmt) {
                widx = index_by_id.get(wid);
                if widx is not None {
                    es.glob_writes.append(widx);
                }
            }
            es.glob_writes.sort();
            for esc in _element_escape_edges(module, stmt) {
                eidx = index_by_id.get(esc[0]);
                if eidx is not None {
                    es.escapes.append((eidx, esc[1]));
                }
            }
        }
        ps.elements.append(es);
    }
    ps.client_declared = module.declares_codespace(CodeContext.CLIENT);
    ps.native_declared = module.declares_codespace(CodeContext.NATIVE);
    ps.native_anchor = module_own_native_anchor(module);
    return ps;
}

impl summary_store(prog: JacProgram) -> dict[str, PlacementSummary] {
    return prog.analysis.placement_summaries;
}

impl record_decided(prog: JacProgram, module: uni.Module) {
    if module.loc is None or not module.loc.mod_path {
        return;
    }
    held = summary_store(prog).get(os.path.abspath(module.loc.mod_path));
    if held is not None {
        held.decided = module.decided_codespace or '';
    }
}

impl jac_import_targets(module: uni.Module) -> list[str] {
    targets: list[str] = [];
    for imp in module.get_all_sub_nodes(uni.Import) {
        nodes: list[(uni.ModulePath | uni.ModuleItem)] = [];
        if imp.from_loc is not None {
            nodes.append(imp.from_loc);
        }
        for item in imp.items {
            if isinstance(item, (uni.ModulePath, uni.ModuleItem)) {
                nodes.append(item);
            }
        }
        for nd in nodes {
            path = _resolve_import_path(nd);
            if path is not None and path.endswith('.jac') {
                real = os.path.realpath(path);
                if real not in targets {
                    targets.append(real);
                }
            }
        }
    }
    return targets;
}

impl record_placement_evidence(prog: JacProgram, mod_path: str, index: int, note: str) {
    evidence = prog.analysis.placement_evidence;
    key = f"{os.path.abspath(mod_path)}::{index}";
    notes = evidence.get(key);
    if notes is None {
        notes = [];
        evidence[key] = notes;
    }
    if note not in notes {
        notes.append(note);
    }
}

impl placement_evidence_for(prog: JacProgram, mod_path: str, index: int) -> list[str] {
    return prog.analysis.placement_evidence.get(
        f"{os.path.abspath(mod_path)}::{index}", []
    );
}

impl get_module_summary(
    module: uni.Module, prog: JacProgram, with_refs: bool = True
) -> PlacementSummary {
    store = prog.analysis.placement_summaries;
    key = os.path.abspath(module.loc.mod_path) if module.loc.mod_path else '';
    cached = store.get(key);
    if cached is not None and (cached.has_refs or not with_refs) {
        return cached;
    }
    ps = summarize_module(module, with_refs=with_refs, prog=prog);
    if key {
        store[key] = ps;
    }
    return ps;
}
