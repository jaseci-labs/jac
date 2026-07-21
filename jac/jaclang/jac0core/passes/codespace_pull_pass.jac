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

def _pullable_by_client_reference(elem: uni.UniNode) -> bool {
    if isinstance(elem, (uni.Archetype, uni.TypeAlias)) {
        return False;
    }
    if isinstance(elem, (uni.Ability, uni.GlobalVars)) {
        return elem.access is None;
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
    module = ir_in;
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
    if ((not client_tops and not native_tops) or not inferable) {
        return module;
    }
    import from jaclang.jac0core.compiler { _stamp_context_element }

    cl_sources: set[int] = set();
    cl_ref_ids: set[int] = set();
    na_sources: set[int] = set();
    na_ref_ids: set[int] = set();
    uses_map: dict[int, set[int]] = {};

    def _is_sv_import(elem: uni.UniNode) -> bool {
        return isinstance(elem, uni.Import) and elem.is_sv_marked;
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
            _stamp_context_element(elem, CodeContext.NATIVE);
            na_sources.add(id(elem));
            na_ref_ids.update(uses_map[id(elem)]);
        } elif in_cl {
            _stamp_context_element(elem, CodeContext.CLIENT);
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
                not cl_sources.isdisjoint(refs)
                or (id(elem) in cl_ref_ids and _pullable_by_client_reference(elem))
            );
            want_na = (
                not na_sources.isdisjoint(refs)
                or (id(elem) in na_ref_ids and _pullable_native(elem))
            );
            if (want_cl and want_na) {
                continue;
            }
            if want_na {
                _stamp_context_element(elem, CodeContext.NATIVE);
                if not _is_sv_import(elem) {
                    na_sources.add(id(elem));
                }
                na_ref_ids.update(refs);
                changed = True;
            } elif want_cl {
                _stamp_context_element(elem, CodeContext.CLIENT);
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
    return module;
}
