import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes.transform { Transform }

def _top_element(module: uni.Module, nd: uni.UniNode) -> (uni.UniNode | None) {
    cur: (uni.UniNode | None) = nd;
    while (cur is not None and cur.parent is not module) {
        cur = cur.parent;
    }
    return cur;
}

def _is_client_top(elem: uni.UniNode) -> bool {
    if isinstance(elem, uni.ClientBlock) {
        return True;
    }
    return isinstance(elem, uni.ContextAwareNode)
    and elem.code_context == CodeContext.CLIENT;
}

def _pullable_by_client_reference(
    elem: uni.UniNode, module: uni.Module, body_refs: dict[int, set[int]]
) -> bool {
    import from jaclang.jac0core.compiler { is_server_anchored_module }
    if isinstance(elem, uni.Archetype) and elem.arch_kind is not None {
        return False;
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
    return isinstance(elem, uni.Import) and (elem.is_sv_marked or elem.is_na_marked);
}

def _references_browser_global(elem: uni.UniNode) -> bool {
    import from jaclang.jac0core.constant { BROWSER_SEED_GLOBALS }
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
            return True;
        }
    }
    return False;
}

def _seed_browser_global_tops(module: uni.Module) {
    import from jaclang.jac0core.ext_registry { codespace_of }
    import from jaclang.jac0core.compiler {
        _stamp_context_element,
        is_server_anchored_module
    }
    if codespace_of(module.loc.mod_path or '') is not None
    or is_server_anchored_module(module) {
        return;
    }
    for stmt in module.body {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and not isinstance(stmt, uni.Import)
            and stmt.code_context == CodeContext.SERVER
            and stmt._source_context_token() is None
            and _references_browser_global(stmt)
        ) {
            _stamp_context_element(stmt, CodeContext.CLIENT);
        }
    }
}

def _named_top_element(target: uni.Module, name: str) -> (uni.UniNode | None) {
    sym = target.names_in_scope.get(name) if target.names_in_scope else None;
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    return _top_element(target, decl);
}

def _import_source_module(elem: uni.Import, prog: any) -> (uni.Module | None) {
    import from jaclang.jac0core.compiler { hub_module_for_path }
    if elem.from_loc is None {
        return None;
    }
    resolved = elem.from_loc.resolve_relative_path();
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return None;
    }
    return hub_module_for_path(resolved, prog);
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
        if top.is_sv_marked or top.is_na_marked {
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

def pull_import_items_client(items: list, target: uni.Module, prog: any) {
    seed_ids: set[int] = set();
    for item in items {
        if not (isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)) {
            continue;
        }
        top = _named_top_element(target, item.name.value);
        if top is not None and _closure_pullable(top, target, prog, set()) {
            seed_ids.add(id(top));
        }
    }
    if seed_ids {
        run_codespace_pull(
            target, prog, seed_ref_ids=seed_ids, dual=True, pull_dependents=False
        );
    }
}

def run_codespace_pull(
    module: uni.Module,
    prog: any,
    seed_ref_ids: (set[int] | None) = None,
    dual: bool = False,
    pull_dependents: bool = True
) -> uni.Module {
    import from jaclang.jac0core.compiler { _stamp_context_element }

    stamp_count: list[int] = [0];

    def _stamp(elem: uni.UniNode, ctx: CodeContext) {
        _stamp_context_element(elem, ctx);
        stamp_count[0] += 1;
        if (
            dual
            and ctx == CodeContext.CLIENT
            and isinstance(elem, uni.ContextAwareNode)
        ) {
            elem.codespace_dual = True;
        }
    }

    def _invalidate_stale_codegen {
        if stamp_count[0] and (module.gen.js or module.gen.es_ast is not None) {
            module.gen.js = '';
            module.gen.es_ast = None;
        }
    }

    _seed_browser_global_tops(module);
    client_tops: list[uni.UniNode] = [];
    native_tops: list[uni.UniNode] = [];
    inferable: list[uni.UniNode] = [];
    for stmt in module.body {
        if isinstance(stmt, (uni.ClientBlock, uni.ServerBlock, uni.NativeBlock)) {
            continue;
        }
        if not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        if stmt.code_context == CodeContext.CLIENT {
            if stmt._source_context_token() is None {
                client_tops.append(stmt);
            }
            continue;
        }
        if stmt.code_context == CodeContext.NATIVE {
            if stmt._source_context_token() is None {
                native_tops.append(stmt);
            }
            continue;
        }

        is_placement_pinned = (
            stmt._source_context_token() is not None
            and not isinstance(stmt, uni.Import)
        );
        if (stmt.code_context != CodeContext.SERVER or is_placement_pinned) {
            continue;
        }
        inferable.append(stmt);
    }
    has_seeds = bool(seed_ref_ids);
    if ((not client_tops and not native_tops and not has_seeds) or not inferable) {
        return module;
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
    def _hard_closure(seed_ids: set[int]) -> set[int] {
        result: set[int] = set(seed_ids);
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
            na_sources.add(id(elem));
            na_ref_ids.update(uses_map[id(elem)]);
        } elif in_cl {
            _stamp(elem, CodeContext.CLIENT);
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
                if not _is_sv_import(elem) {
                    na_sources.add(id(elem));
                }
                na_ref_ids.update(refs);
                changed = True;
            } elif want_cl {
                _stamp(elem, CodeContext.CLIENT);
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
    return module;
}

obj CodespacePullPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    static has PROVIDES: tuple = ('codespace-pull', );

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
}

impl CodespacePullPass.postinit -> None {
    super.postinit();
}

impl CodespacePullPass.transform(ir_in: uni.Module) -> uni.Module {
    return run_codespace_pull(ir_in, self.prog);
}
