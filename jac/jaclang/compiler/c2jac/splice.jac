import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.c2jac.directir {
    SLOT_SENTINEL,
    is_slot_placeholder,
    slot_id_of
}
import from jaclang.compiler.c2jac.uni_builder { CUniBuilder }

def _replace_pair_in_list(
    lst: list, old_a: object, old_b: object, replacement: object
) -> list {
    out: list = [];
    inserted = False;
    for item in lst {
        if item is old_a or item is old_b {
            if not inserted {
                out.append(replacement);
                inserted = True;
            }
        } else {
            out.append(item);
        }
    }
    return out;
}

def _promote_for(sentinel: uni.ExprStmt) {
    while_stmt = sentinel.parent;
    if while_stmt is None or not isinstance(while_stmt, uni.WhileStmt) {
        raise ValueError(
            f"c2jac: for-promotion sentinel is not inside a WhileStmt — the "
            f"desugar/splice protocol is broken"
        );
    }
    wbody = while_stmt.body;
    if sentinel not in wbody {
        raise ValueError(
            f"c2jac: for-promotion sentinel is not in its while-body — cannot "
            f"locate the loop body to promote"
        );
    }
    m_idx = wbody.index(sentinel);
    if (len(wbody) - m_idx) < 2 {
        raise ValueError(
            f"c2jac: promotable C-for while-body has no count_by step after the "
            f"sentinel — the IterForStmt would be malformed"
        );
    }
    count_by = wbody[-1];
    body_mid = wbody[m_idx + 1:len(wbody) - 1];
    gp = while_stmt.parent;
    gbody = gp?.body;
    if gp is None
    or gbody is None
    or not isinstance(gbody, list)
    or while_stmt not in gbody {
        raise ValueError(
            f"c2jac: promotable C-for while is not in its parent's body list — "
            f"cannot locate the iter (preceding sibling) to promote"
        );
    }
    g_idx = gbody.index(while_stmt);
    if g_idx < 1 {
        raise ValueError(
            f"c2jac: promotable C-for has no iter statement before the while — "
            f"the desugar must emit `iter; while ...`"
        );
    }
    iter_old = gbody[g_idx - 1];
    if not isinstance(iter_old, uni.Assignment) {
        raise ValueError(
            f"c2jac: promotable C-for iter is not an Assignment — cannot build "
            f"the IterForStmt `iter=` clause"
        );
    }

    tgt = iter_old.target[0];
    val = iter_old.value;
    new_iter = uni.Assignment(
        kid=[tgt, val],
        target=[tgt],
        value=val,
        type_tag=None,
        mutable=True,
        aug_op=None,
        is_enum_stmt=False,
    );
    cond = while_stmt.condition;

    if isinstance(cond, uni.AtomUnit) {
        cond = cond.value;
    }
    iterfor = uni.IterForStmt(
        kid=[new_iter, cond, count_by, *body_mid],
        iter=new_iter,
        condition=cond,
        count_by=count_by,
        body=body_mid,
        else_body=None,
        is_async=False,
    );
    for child in [new_iter, cond, count_by, *body_mid] {
        child.parent = iterfor;
    }
    iterfor.parent = gp;

    gp.body = _replace_pair_in_list(gbody, iter_old, while_stmt, iterfor);
    gp.kid = _replace_pair_in_list(gp.kid, iter_old, while_stmt, iterfor);
    gp._invalidate_sub_node_tab();
}

def _hoist_to_module_body(
    sentinel: uni.ExprStmt,
    immediate_parent: uni.UniNode,
    replacements: list[uni.UniNode]
) -> None {
    nd: uni.UniNode | None = immediate_parent;
    while nd is not None and not isinstance(nd, uni.Module) {
        nd = nd.parent;
    }
    if nd is None or not isinstance(nd, uni.Module) {
        return;
    }
    mod = nd;
    if immediate_parent is mod {
        return;
    }
    cur: uni.UniNode = immediate_parent;
    while cur.parent is not None and cur.parent is not mod {
        cur = cur.parent;
    }
    if cur.parent is not mod {
        return;
    }
    containing_child = cur;
    for r in replacements {
        if r in immediate_parent.kid {
            immediate_parent.kid.remove(r);
        }
    }
    local_body = immediate_parent?.body;
    if local_body is not None and isinstance(local_body, list) {
        for r in replacements {
            if r in local_body {
                local_body.remove(r);
            }
        }
    }
    immediate_parent._invalidate_sub_node_tab();

    if containing_child not in mod.body {
        raise ValueError(
            f"c2jac: ENUM_AS_CONSTS hoist target is not in Module.body — enum "
            f"constants would be silently dropped from the emitted Jac"
        );
    }
    mc_idx = mod.body.index(containing_child);
    kid_idx = mod.kid.index(containing_child)
        if containing_child in mod.kid
        else mc_idx;
    for (i, r) in enumerate(replacements) {
        mod.body.insert(mc_idx + i, r);
        mod.kid.insert(kid_idx + i, r);
        r.parent = mod;
    }
    mod._invalidate_sub_node_tab();
}

def _do_splice(sentinel: uni.ExprStmt, replacements: list[uni.UniNode]) -> None {
    parent = sentinel.parent;
    if parent is None {
        return;
    }
    if sentinel not in parent.kid {
        raise ValueError(
            f"c2jac: direct-IR sentinel is not in its parent's kid list — the uni "
            f"tree's parent/kid pointers disagree; splice cannot proceed"
        );
    }
    kid_idx = parent.kid.index(sentinel);
    new_kid = [*parent.kid[:kid_idx], *replacements, *parent.kid[kid_idx + 1:]];

    for r in replacements {
        r.parent = parent;
    }
    parent.kid = new_kid;
    parent._invalidate_sub_node_tab();
    body = parent?.body;
    if body is not None and isinstance(body, list) and sentinel in body {
        body_idx = body.index(sentinel);
        body[body_idx:body_idx + 1] = replacements;
    }
    if any(
        isinstance(r, uni.GlobalVars) or isinstance(r, uni.Enum) for r in replacements
    ) {
        _hoist_to_module_body(sentinel, parent, replacements);
    }
}

def splice_directir(
    mod_root: uni.Module, slot_map: dict[int, object], builder: CUniBuilder
) {
    sentinels = mod_root.get_all_sub_nodes(uni.ExprStmt);
    to_replace: list[tuple[uni.ExprStmt, int]] = [];
    for s in sentinels {
        if is_slot_placeholder(s) {
            slot_id = slot_id_of(s);
            if slot_id is None {
                raise ValueError(
                    f"c2jac: malformed direct-IR placeholder (no int slot id) — "
                    f"the {SLOT_SENTINEL} protocol is broken"
                );
            }
            to_replace.append((s, slot_id));
        }
    }
    for (sentinel, slot_id) in to_replace {
        c_node = slot_map.get(slot_id);
        if c_node is None {
            raise ValueError(
                f"c2jac: direct-IR placeholder references unregistered slot "
                f"{slot_id} — mapper.slot_map and the emitted placeholders are "
                f"out of sync"
            );
        }

        if type(c_node).__name__ == "For" {
            _promote_for(sentinel);
        } else {
            replacements = builder.build(c_node);
            _do_splice(sentinel, replacements);
        }
    }

    leaked = [
        s
        for s in mod_root.get_all_sub_nodes(uni.ExprStmt)
        if is_slot_placeholder(s)
    ];
    if leaked {
        raise ValueError(
            f"c2jac: {len(leaked)} direct-IR placeholder(s) survived the splice — "
            f"would leak {SLOT_SENTINEL} into emitted Jac"
        );
    }
}
