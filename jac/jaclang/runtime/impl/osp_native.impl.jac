impl _tag_of(h: any) -> int {
    address: int = h;
    return __mem_load_i64(address + TAG_OFFSET);
}

impl _is_a(tag: int, base: int) -> bool {
    return osp_is_a(tag, base);
}

impl _node_desc(tag: int) -> OspNodeDesc {
    return osp_node_desc(tag);
}

impl _on_complete(scope: OspWalkScope, ok: bool) {
    if not scope.nested {
        NATIVE.reports = scope.reports;
    }
}

impl _runtime -> OspRuntime {
    found = NATIVE.runtime;
    if found is not None {
        return found;
    }
    osp_pin_refs();
    osp_kernel_pin_refs();
    made = OspRuntime(
        tag_of=_tag_of, is_a=_is_a, node_desc=_node_desc, on_complete=_on_complete
    );
    NATIVE.runtime = made;
    return made;
}

impl _walker_desc(tag: int) -> OspWalkerDesc {
    if tag in NATIVE.walkers {
        found: OspWalkerDesc = NATIVE.walkers[tag];
        return found;
    }
    made = OspWalkerDesc(type_tag=tag, `entry=[], `exit=[]);
    NATIVE.walkers[tag] = made;
    return made;
}

impl _pin_each(handles: list[int], hold: bool) {
    i = 0;
    while i < len(handles) {
        if hold {
            __jac_rt_retain(handles[i]);
        } else {
            __jac_rt_release(handles[i]);
        }
        i += 1;
    }
}

impl _sync {
    if NATIVE.syncing
        or int(__mem_load_i8(__global_block("__rc_collecting", 1))) != 0 {
        return;
    }
    NATIVE.syncing = True;
    if osp_kernel_pending() != 0 {
        _pin_each(osp_take_acquired(), True);
        _pin_each(osp_take_released(), False);
    }
    while osp_unpinned_count() != 0 {
        _pin_each(osp_take_unpinned(), False);
    }
    NATIVE.syncing = False;
}

impl __jac_osp_register(tag: int, bases: list[int], walker: bool) {
    _runtime();
    osp_register_type(tag, bases);
    if walker {
        NATIVE.walkers[tag] = OspWalkerDesc(type_tag=tag, `entry=[], `exit=[]);
    } else {
        osp_register_desc(tag, OspNodeDesc(type_tag=tag, `entry=[], `exit=[]));
    }
}

impl __jac_osp_slot(
    tag: int, is_entry: bool, trig_tag: int, fn: Callable[([any, any], any)]
) {
    slot = OspSlot(trig_tag=trig_tag, fn=fn);
    if tag in NATIVE.walkers {
        wdesc = _walker_desc(tag);
        if is_entry {
            wdesc.`entry.append(slot);
        } else {
            wdesc.`exit.append(slot);
        }
        wdesc.plans = None;
        return;
    }
    ndesc = osp_node_desc(tag);
    if is_entry {
        ndesc.`entry.append(slot);
    } else {
        ndesc.`exit.append(slot);
    }
}

impl __jac_osp_spawn(wlk: any, wtag: int, start: int) -> (list[any] | None) {
    if osp_is_dead(start) != 0 {
        raise RuntimeError("cannot spawn on a destroyed graph object");
    }
    nested = _current_scope() is not None;
    osp_spawn(_runtime(), wlk, _walker_desc(wtag), [start]);
    _sync();
    if nested {
        return None;
    }
    done = NATIVE.reports;
    NATIVE.reports = None;
    return done;
}

impl __jac_osp_visit(targets: list[int], insert_loc: int) -> bool {
    did = osp_visit(targets, insert_loc);
    _sync();
    return did;
}

impl __jac_osp_report(val: any) {
    osp_report(val);
}

impl __jac_osp_disengage {
    osp_disengage();
}

impl __jac_osp_skip {
    osp_skip_rest();
}

impl __jac_osp_generic_edge -> int {
    edge = __jac_rt_alloc(GENERIC_EDGE_SIZE);
    __mem_store_i64(edge, 0);
    __mem_store_i64(edge + TAG_OFFSET, GENERIC_EDGE_TAG);
    return edge;
}

impl __jac_osp_connect(
    src: int, tgt: int, eobj: int, undirected: bool, edge_tag: int
) {
    _runtime();
    if osp_conn(src, tgt, eobj, 1 if undirected else 0, edge_tag, 0, 0) == -1 {
        raise RuntimeError("cannot connect a destroyed node");
    }
    __jac_rt_retain(src);
    __jac_rt_retain(tgt);
    __jac_rt_retain(eobj);
}

impl __jac_osp_refs(origin: int, dir: int, edge_tag: int, edges_only: bool) -> list[int] {
    return osp_refs(origin, dir, edge_tag, 1 if edges_only else 0);
}

impl __jac_osp_refs_many(
    origins: list[int], dir: int, edge_tag: int, edges_only: bool
) -> list[int] {
    return osp_refs_many(origins, dir, edge_tag, 1 if edges_only else 0);
}

impl __jac_osp_refs_pred(
    origins: list[int],
    dir: int,
    edge_tag: int,
    edges_only: bool,
    pred: Callable[([int], bool)]
) -> list[int] {
    return osp_refs_edge_pred(origins, dir, edge_tag, 1 if edges_only else 0, pred);
}

impl __jac_osp_filter(hs: list[int], pred: Callable[([int], bool)]) -> list[int] {
    return osp_filter(hs, pred);
}

impl __jac_osp_keep_toward(
    hs: list[int], origins: list[int], dir: int, edges_only: bool, wanted: list[int]
) -> list[int] {
    return osp_keep_toward(hs, origins, dir, 1 if edges_only else 0, wanted);
}

impl __jac_osp_disconnect(src: int, tgt: int, dir: int, edge_tag: int) -> bool {
    removed = osp_disconn_between(src, tgt, dir, edge_tag);
    _sync();
    return removed != 0;
}

impl __jac_osp_disconnect_pred(
    src: int, tgt: int, dir: int, edge_tag: int, pred: Callable[([int], bool)]
) -> bool {
    removed = osp_disconn_between_pred(src, tgt, dir, edge_tag, pred);
    _sync();
    return removed != 0;
}

impl __jac_osp_disconnect_many(
    srcs: list[int], tgts: list[int], dir: int, edge_tag: int
) -> bool {
    removed = osp_disconn_between_many(srcs, tgts, dir, edge_tag);
    _sync();
    return removed != 0;
}

impl __jac_osp_destroy(h: int) {
    osp_destroy(h);
    osp_forget(h);
    _sync();
}

impl __jac_osp_destroy_all(hs: list[int]) {
    osp_destroy_all(hs);
    osp_forget_all(hs);
    _sync();
}

impl __jac_osp_reclaimed(h: int, is_edge: bool) {
    if is_edge {
        osp_forget_edge(h);
        return;
    }
    osp_forget_node(h);
    _sync();
}

impl __jac_osp_jid(h: int) -> str {
    return osp_jid(h, 0);
}

impl __jac_osp_is_a(tag: int, base: int) -> bool {
    return osp_is_a(tag, base);
}
