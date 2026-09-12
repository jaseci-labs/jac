import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.session.import_paths { resolve_import_path }
import from jaclang.compiler.analysis.boundaries.classify { is_service_bridge_import }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.pipeline.keys { PLACEMENT_SUMMARY }
import type from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.analysis.placement.state { PlacementState }
import os;
import json;
import jaclang.compiler.ir.schema as uni;
import from jaclang.runtime.object_model { field }
import from jaclang.compiler.ir.enums { CodeContext, Tokens as Tok }

import from jaclang.compiler.analysis.placement.summary {
    ElementSummary,
    PlacementSummary
}
import from jaclang.compiler.analysis.placement.summary { PLACEMENT_SCHEMA }
glob PLACEMENT_SV_SIGNAL_NODES: tuple = (
         ("TypedCtxBlock", uni.TypedCtxBlock),
         ("PyInlineCode", uni.PyInlineCode),
         ("JsxElement", uni.JsxElement)
     ),
     PLACEMENT_NATIVE_REJECT_NODES: tuple = (),
     PLACEMENT_INFERENCE_HELD: dict[str, str] = {
         "compiler/backends/common/artifacts.jac": (
             "runtime JIT inference stays conservative: admitting codeinfo "
             "opens the jaclang-internal import universe to default-native "
             "flips (walker identity splits, sv envelopes). The compiler's "
             "own roots are exempt via PLACEMENT_HOLD_EXEMPT_ROOTS, which "
             "is what B4 (#8323) actually needed"
         )
     },
     PLACEMENT_HOLD_EXEMPT_ROOTS: tuple = (
         "/jaclang/compiler/",
         "/jaclang/runtime/",
         "/jaclang/lib/",
         "/jaclang/jac0core/"
     );

def element_display_name(stmt: uni.UniNode) -> str {
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

def _is_pub_element(stmt: uni.UniNode) -> bool {
    return (
        isinstance(stmt, (uni.Ability, uni.GlobalVars, uni.Archetype, uni.Enum))
        and stmt.access is not None
        and stmt.access.tag.name == Tok.KW_PUB
    );
}

def project_kind_name(module: (uni.Module | None)) -> str {
    if module is None {
        return '';
    }
    if module.app_kind {
        return module.app_kind;
    }
    import from jaclang.compiler.analysis.placement.pins { config_project_kind }
    return config_project_kind(module.loc.mod_path or '') if module.loc else '';
}

def project_has_server(module: (uni.Module | None)) -> bool {
    import from jaclang.compiler.session.workspace { kind_codespace }
    return kind_codespace(project_kind_name(module)) != 'client';
}

def _resolve_import_path(nd: (uni.ModulePath | uni.ModuleItem)) -> (str | None) {
    path: (str | None) = None;
    try {
        resolved = resolve_import_path(nd);
        if isinstance(resolved, str) {
            path = resolved;
        }
    } except Exception {
        return None;
    }
    if path and os.path.exists(path) {
        return path;
    }
    return None;
}

def _fill_import_facts(es: ElementSummary, imp: uni.Import) {
    es.import_eco = imp.ecosystem;
    es.sv_import = is_service_bridge_import(imp);
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

def module_has_root_access(stmt: uni.UniNode) -> bool {
    mod = stmt
        if isinstance(stmt, uni.Module)
        else stmt.find_parent_of_type(uni.Module);
    if mod is None {
        return True;
    }

    cached = artifact_for(mod).has_root_access;
    if cached is not None {
        return cached;
    }
    found = False;
    for svr in mod.get_all_sub_nodes(uni.SpecialVarRef) {
        if svr.orig.name == Tok.KW_ROOT {
            found = True;
            break;
        }
    }
    artifact_for(mod).has_root_access = found;
    return found;
}

def _element_reqs(stmt: uni.UniNode) -> list {
    reqs: list = [];
    if isinstance(stmt, uni.Import) {
        eco = stmt.ecosystem;
        if stmt.has_clib_decls {
            reqs.append(['FFI', 'clib extern import']);
        } elif eco == 'string' {
            reqs.append(['NPM', 'string-path import']);
        } elif eco == 'virtual' {
            reqs.append(['NPM', 'virtual @jac import']);
        } elif eco == 'py' {
            npm_dep = False;
            if isinstance(stmt, uni.Import) and stmt.from_loc is not None {
                import from jaclang.compiler.session.resolver { is_client_npm_import }
                mod_path = stmt.loc.mod_path or '';
                npm_dep = is_client_npm_import(stmt.from_loc.dot_path_str, mod_path);
            }
            if npm_dep {
                reqs.append(['NPM', 'npm dependency']);
            } else {
                reqs.append(['PY', 'python import']);
            }
        }
        return reqs;
    }
    if isinstance(stmt, uni.PyInlineCode) {
        reqs.append(['PY', 'inline ::py:: block']);
        return reqs;
    }
    if stmt.get_all_sub_nodes(uni.JsxElement) {
        reqs.append(['DOM', 'jsx construction']);
    }
    for svr in stmt.get_all_sub_nodes(uni.SpecialVarRef) {
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
    for ab in stmt.get_all_sub_nodes(uni.Ability) {
        if ab.is_async {
            reqs.append(['SERVER', 'async ability']);
            break;
        }
    }
    if isinstance(stmt, uni.Ability)
        and isinstance(stmt.signature, uni.EventSignature) {
        reqs.append(['SERVER', 'event ability outside an archetype']);
    }
    if _is_pub_element(stmt)
        and project_has_server(stmt.find_parent_of_type(uni.Module)) {
        reqs.append(['ENDPOINT', 'pub access']);
    }
    return reqs;
}

def _summary_top_element(module: uni.Module, nd: uni.UniNode) -> (uni.UniNode | None) {
    cur: (uni.UniNode | None) = nd;
    while (cur is not None and cur.parent is not module) {
        cur = cur.parent;
    }
    return cur;
}

def _element_ref_ids(module: uni.Module, elem: uni.UniNode) -> set[int] {
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
        top = _summary_top_element(module, decl);
        if (top is None or top is elem) {
            continue;
        }
        refs.add(id(top));
    }
    return refs;
}

def _escape_kind(nm: uni.Name, elem: uni.UniNode) -> str {
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

def _element_escape_edges(
    module: uni.Module, elem: uni.UniNode
) -> list[tuple[int, str]] {
    edges: list[tuple[int, str]] = [];
    seen: set[tuple] = set();
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
        if sym is None or sym.decl is None {
            continue;
        }
        top = _summary_top_element(module, sym.decl);
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

def _element_glob_write_ids(module: uni.Module, elem: uni.UniNode) -> set[int] {
    writes: set[int] = set();
    for assign in elem.get_all_sub_nodes(uni.Assignment) {
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
            top = _summary_top_element(module, sym.decl);
            if (
                top is not None and top is not elem and isinstance(top, uni.GlobalVars)
            ) {
                writes.add(id(top));
            }
        }
    }
    return writes;
}

def _references_browser_seed_global(elem: uni.UniNode) -> str {
    import from jaclang.compiler.ir.enums { BROWSER_SEED_GLOBALS }
    for nm in elem.get_all_sub_nodes(uni.Name) {
        if nm.value not in BROWSER_SEED_GLOBALS {
            continue;
        }
        par = nm.parent;
        if (isinstance(par, uni.AtomTrailer) and par.is_attr and par.right is nm) {
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

def module_anchor_reasons(module: uni.Module) -> list[str] {
    import from jaclang.compiler.analysis.placement.pins { config_module_pin }
    reasons: list[str] = [];
    mod_path = module.loc.mod_path or '';
    if config_module_pin(mod_path) == 'server' {
        reasons.append('config pin');
    }
    if mod_path {
        import from jaclang.compiler.analysis.boundaries.classify {
            is_service_app_entry
        }
        if is_service_app_entry(mod_path) {
            reasons.append('service app entry');
        }
    }
    for arch in module.get_all_sub_nodes(uni.Archetype) {
        if arch.arch_kind is not None and module_has_root_access(module) {
            reasons.append(f"graph archetype '{arch.name.value}'");
            break;
        }
    }
    if module.get_all_sub_nodes(uni.PyInlineCode) {
        reasons.append('inline ::py:: block');
    }
    for stmt in module.body {
        if isinstance(stmt, uni.TypedCtxBlock) {
            reasons.append('typed context block');
            break;
        }
    }
    import from jaclang.compiler.session.resolver { is_client_npm_import }
    for imp in module.get_all_sub_nodes(uni.Import) {
        if imp.has_clib_decls or imp.is_virtual_jac or imp.has_string_path {
            continue;
        }
        if imp.is_comptime {
            continue;
        }
        if imp.from_loc is None {
            reasons.append('plain python import');
            break;
        }
        if is_client_npm_import(imp.from_loc.dot_path_str, mod_path) {
            continue;
        }
        resolved = None;
        try {
            resolved = resolve_import_path(imp.from_loc);
        } except Exception {
            resolved = None;
        }
        if not isinstance(resolved, str) or not resolved.endswith('.jac') {
            reasons.append('plain python import');
            break;
        }
    }
    return reasons;
}

def _erased_only_import(imp: uni.Import) -> bool {
    import from jaclang.compiler.analysis.capabilities.native_policy {
        native_erased_import_names
    }
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

walker NativeBlockerScan(uni.TreeWalker) {
    has classify_imports: bool = False,
        signals: set[type] = set(),
        root_access: bool = False,
        ability_reason: str = '',
        imports: list[uni.Import] = [];

    can signal with uni.TypedCtxBlock | uni.PyInlineCode | uni.JsxElement exit {
        self.signals.add(type(here));
    }

    can root_reference with uni.SpecialVarRef exit {
        if here.orig.name == Tok.KW_ROOT {
            self.root_access = True;
        }
    }

    can ability with uni.Ability exit {
        if self.ability_reason {
            return;
        }
        if here.is_async {
            self.ability_reason = 'async ability';
            return;
        }
        if isinstance(here.signature, uni.EventSignature) {
            if here.find_parent_of_type(uni.Archetype) is None {
                self.ability_reason = 'event ability outside an archetype';
                return;
            }
            tag = here.signature.arch_tag_info;
            names = [tag]
                if isinstance(tag, uni.Name)
                else (tag.get_all_sub_nodes(uni.Name) if tag is not None else []);
            for name in names {
                if name.value in ('Root', 'root') {
                    self.ability_reason = 'root access (persistent graph)';
                    return;
                }
            }
        }
    }

    can import_statement with uni.Import exit {
        if self.classify_imports {
            import from jaclang.compiler.analysis.binding.import_classification {
                detect_jac_import
            }
            here.jac_detected = detect_jac_import(here);
        }
        self.imports.append(here);
    }
}

def scan_native_blockers(
    module: uni.Module,
    base_dir: str,
    allow_pub: bool = False,
    hold_exempt: bool = False,
    classify_imports: bool = False
) -> tuple[str, list[str]] {
    import from jaclang.compiler.analysis.capabilities.native_policy {
        NATIVE_SUPPORTED_STDLIB
    }
    import from jaclang.compiler.session.native_resolution {
        is_bundled_native_module,
        resolve_native_module
    }
    deps: list[str] = [];
    _held_path = (module.loc.mod_path if module.loc is not None else '') or '';
    if not hold_exempt {
        for (_held_rel, _held_why) in PLACEMENT_INFERENCE_HELD.items() {
            if _held_path.replace(os.sep, "/").endswith("/jaclang/" + _held_rel) {
                return (f"inference held: {_held_why}", deps);
            }
        }
    }
    scan = NativeBlockerScan(classify_imports=classify_imports);
    module spawn scan;
    for (nd_name, typ) in PLACEMENT_SV_SIGNAL_NODES {
        if typ in scan.signals {
            return (f"contains {nd_name}", deps);
        }
    }
    for (nd_name, typ) in PLACEMENT_NATIVE_REJECT_NODES {
        if module.get_all_sub_nodes(typ) {
            return (f"native-unsupported {nd_name}", deps);
        }
    }
    if scan.root_access {
        return ("root access (persistent graph)", deps);
    }
    if scan.ability_reason {
        return (scan.ability_reason, deps);
    }
    scan_mod_path = module.loc.mod_path or '';
    for stmt in module.body {
        if isinstance(stmt, uni.ContextAwareNode) and scan_mod_path {
            import from jaclang.compiler.analysis.placement.pins { config_pin_for }
            pin = config_pin_for(scan_mod_path, element_display_name(stmt));
            if pin in ('server', 'client') {
                return ("explicit sv/cl pin", deps);
            }
        }

        if not allow_pub and _is_pub_element(stmt) {
            return ("pub access", deps);
        }
    }
    for imp in scan.imports {
        if imp.has_clib_decls {
            continue;
        }
        if imp.is_typed or imp.is_comptime {
            continue;
        }
        if imp.find_parent_of_type(uni.Ability) is not None
            or imp.find_parent_of_type(uni.ImplDef) is not None {
            continue;
        }
        if imp.is_virtual_jac or imp.has_string_path {
            return ("virtual/string-path import", deps);
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
                    return (f"non-native import '{clean}'", deps);
                }
            }
            if path is not None {
                import from jaclang.compiler.analysis.placement.pins {
                    config_module_pin as _cmp
                }
                if _cmp(path) == 'client' {
                    return ("client module import", deps);
                }
            }
            if path is not None and path.endswith('.jac') {
                deps.append(os.path.abspath(path));
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
            return (f"unresolved import '{clean}'", deps);
        }
    }
    return ('', deps);
}

def summarize_module(module: uni.Module, with_refs: bool = True) -> PlacementSummary {
    ps = PlacementSummary();
    ps.schema = PLACEMENT_SCHEMA;
    ps.mod_path = module.loc.mod_path or '';
    ps.decided = module.decided_codespace or '';
    ps.anchors = module_anchor_reasons(module);
    base_dir = os.path.dirname(os.path.abspath(ps.mod_path)) if ps.mod_path else '';
    (blocker, deps) = scan_native_blockers(module, base_dir);
    ps.native_blocker = blocker;
    ps.jac_deps = deps;
    ps.has_refs = with_refs;
    index_by_id: dict[int, int] = {};
    for (idx, stmt) in enumerate(module.body) {
        index_by_id[id(stmt)] = idx;
    }
    server_anchored = bool(ps.anchors);
    for (idx, stmt) in enumerate(module.body) {
        if not isinstance(stmt, uni.UniNode) {
            continue;
        }
        es = ElementSummary();
        es.index = idx;
        es.kind = type(stmt).__name__;
        es.name = element_display_name(stmt);
        es.pinned = '';
        if ps.mod_path {
            import from jaclang.compiler.analysis.placement.pins { effective_pin_for }
            es.pinned = effective_pin_for(ps.mod_path, es.name);
        }
        es.is_pub = _is_pub_element(stmt);
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
                    es.escapes.append([eidx, esc[1]]);
                }
            }
        }
        ps.elements.append(es);
    }
    return ps;
}


def placement_state(prog: AnalysisServices) -> PlacementState {
    return prog.analysis.placement_state;
}

def record_placement_evidence(
    prog: AnalysisServices, mod_path: str, index: int, note: str
) {
    key = f"{os.path.abspath(mod_path)}::{index}";
    notes = prog.analysis.placement_state.evidence.setdefault(key, []);
    if note not in notes {
        notes.append(note);
    }
}

def _collect_placement_rows(prog: AnalysisServices) -> dict {
    rows_by_module: dict = {};
    hub = prog?.mod?.hub;
    if not isinstance(hub, dict) or not hub {
        return rows_by_module;
    }
    state = placement_state(prog);
    evidence = state.evidence;
    for (path, mod) in list(hub.items()) {
        if not isinstance(mod, uni.Module) {
            continue;
        }
        mod_path = mod.loc.mod_path or path;
        if not str(mod_path).endswith('.jac') {
            continue;
        }
        ps = get_module_summary(mod, prog);
        mod_rows: list = [];
        for (idx, stmt) in enumerate(mod.body) {
            if not isinstance(stmt, uni.ContextAwareNode) {
                continue;
            }
            es = ps.elements[idx] if idx < len(ps.elements) else None;
            notes: list[str] = [];
            if es is not None {
                if es.pinned {
                    notes.append(f"pinned '{es.pinned}' ([placement.pins])");
                }
                for req in es.reqs {
                    if len(req) >= 2 {
                        notes.append(f"{req[0]}: {req[1]}");
                    }
                }
            }
            key = f"{os.path.abspath(str(mod_path))}::{idx}";
            raw_extras = evidence.get(key);
            if isinstance(raw_extras, list) {
                for extra in raw_extras {
                    if isinstance(extra, str) and extra not in notes {
                        notes.append(extra);
                    }
                }
            }
            rname = element_display_name(stmt);
            if idx < len(ps.elements) {
                rname = ps.elements[idx].name;
            }
            mod_rows.append(
                {
                    'name': rname,
                    'kind': type(stmt).__name__,
                    'space': stmt.code_context.value,
                    'dual': stmt.codespace_dual,
                    'evidence': notes
                }
            );
        }
        crossings = 0;
        for stmt in mod.body {
            if not (
                isinstance(stmt, uni.Import) and stmt.code_context == CodeContext.CLIENT
            ) {
                continue;
            }
            try {
                import from jaclang.compiler.analysis.binding.symbol_utils {
                    ClientImportVerdict,
                    classify_client_import_item,
                    is_client_boundary_import,
                    resolve_import_source_module
                }
                if is_client_boundary_import(stmt) {
                    src = resolve_import_source_module(prog, stmt);
                    if src is not None {
                        for item in stmt.items {
                            verdict = classify_client_import_item(src, item);
                            if verdict == ClientImportVerdict.BRIDGED {
                                crossings += 1;
                            }
                        }
                    }
                }
            } except Exception {}
        }
        rows_by_module[os.path.abspath(str(mod_path))] = {
            'decided': mod.decided_codespace or '',
            'rows': mod_rows,
            'crossings': crossings
        };
    }
    return rows_by_module;
}

def get_module_summary(
    module: uni.Module, prog: AnalysisServices, with_refs: bool = True
) -> PlacementSummary {
    prog = prog.module_context(module);
    key = os.path.abspath(module.loc.mod_path)
        if module.loc.mod_path
        else f'@{id(module)}';
    cached = prog.analysis.lookup(key, PLACEMENT_SUMMARY);
    if (isinstance(cached, PlacementSummary) and (cached.has_refs or not with_refs)) {
        return cached;
    }
    import from jaclang.compiler.pipeline.products {
        require_product,
        invalidate_product
    }
    import from jaclang.compiler.pipeline.contracts { CompilationProduct }
    invalidate_product(prog, module, CompilationProduct.PLACEMENT_SUMMARY);
    require_product(prog, module, CompilationProduct.PLACEMENT_SUMMARY);
    return prog.analysis.result(key, PLACEMENT_SUMMARY);
}
