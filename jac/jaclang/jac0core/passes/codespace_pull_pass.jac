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
    static has PROVIDES: tuple = ('codespace-pull', );
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
}

impl CodespacePullPass.postinit -> None {
    super.postinit();
}

impl CodespacePullPass.transform(ir_in: uni.Module) -> uni.Module {
    module = ir_in;
    client_tops: list[uni.UniNode] = [];
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

        is_placement_pinned = (
            stmt._source_context_token() is not None
            and not isinstance(stmt, uni.Import)
        );
        if (stmt.code_context != CodeContext.SERVER or is_placement_pinned) {
            continue;
        }
        inferable.append(stmt);
    }
    if (not client_tops or not inferable) {
        return module;
    }
    import from jaclang.jac0core.compiler { _stamp_client_element }

    pull_source_ids: set[int] = set();
    client_ref_ids: set[int] = set();
    uses_map: dict[int, set[int]] = {};

    def _is_sv_import(elem: uni.UniNode) -> bool {
        return isinstance(elem, uni.Import) and elem.is_sv_marked;
    }
    for elem in client_tops {
        if not _is_sv_import(elem) {
            pull_source_ids.add(id(elem));
        }
        client_ref_ids.update(_ref_top_ids(module, elem));
    }
    for elem in inferable {
        uses_map[id(elem)] = _ref_top_ids(module, elem);
    }
    changed = True;
    while changed {
        changed = False;
        remaining: list[uni.UniNode] = [];
        for elem in inferable {
            refs = uses_map[id(elem)];
            pull = (
                not pull_source_ids.isdisjoint(refs)
                or (id(elem) in client_ref_ids and _pullable_by_client_reference(elem))
            );
            if pull {
                _stamp_client_element(elem);
                if not _is_sv_import(elem) {
                    pull_source_ids.add(id(elem));
                }
                client_ref_ids.update(refs);
                changed = True;
            } else {
                remaining.append(elem);
            }
        }
        inferable = remaining;
    }
    return module;
}
