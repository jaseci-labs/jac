impl jc_reg_value(
    index: int,
    code: int,
    tag: int,
    child: int,
    key_off: int,
    data_off: int,
    order_off: int
) -> int {
    _VALUES[index] = ValueRow(code, tag, child, key_off, data_off, order_off);
    return 0;
}

impl jc_reg_consts(
    none_h: int,
    true_h: int,
    false_h: int,
    empty_h: int,
    s_none: int,
    s_one: int,
    s_many: int,
    k_out: int,
    k_in: int,
    k_jac: int,
    k_shapes: int,
    k_arch: int
) -> int {
    _K.none_h = none_h;
    _K.true_h = true_h;
    _K.false_h = false_h;
    _K.empty_h = empty_h;
    _K.s_none = s_none;
    _K.s_one = s_one;
    _K.s_many = s_many;
    _K.k_out = k_out;
    _K.k_in = k_in;
    _K.k_jac = k_jac;
    _K.k_shapes = k_shapes;
    _K.k_arch = k_arch;
    return 0;
}

impl jc_reg_shape_roles(body_h: int, spec_h: int, acc_h: int) -> int {
    _K.body_h = body_h;
    _K.spec_h = spec_h;
    _K.acc_h = acc_h;
    return 0;
}

impl jc_mz_shape_keys(probe: int) {
    if _K.shapes_layout not in _VALUES {
        return;
    }
    layout = _VALUES[_K.shapes_layout];
    keys = _ld64(probe + layout.key_off);
    order = _ld64(probe + layout.order_off);
    extent = _hash_order_extent(probe, order);
    found: list[int] = [];
    i = 0;
    while i < extent {
        slot = _ld64(order + i * 8);
        i += 1;
        if slot >= 0 {
            found.append(_ld64(keys + slot * 8));
        }
    }
    if len(found) == 3 {
        _K.body_key = found[0];
        _K.spec_key = found[1];
        _K.acc_key = found[2];
    }
}

impl jc_reg_class(tag: int, cls_h: int, size: int, tagged: int, is_node: int) -> int {
    _CLS[tag] = ClassRow(
        cls_h=cls_h,
        size=size,
        tagged=tagged,
        is_node=is_node,
        rows=[],
        dflt_k=[],
        dflt_kind=[],
        plan=[]
    );
    return 0;
}

impl jc_reg_field(
    tag: int, key_h: int, code: int, off: int, aux_tag: int, enum_h: int, flags: int
) -> int {
    if tag not in _CLS {
        return 1;
    }
    row: ClassRow = _CLS[tag];
    row.rows.append(
        FieldRow(
            key_h=key_h, code=code, off=off, aux_tag=aux_tag, enum_h=enum_h, flags=flags
        )
    );
    if code == CODE_SHAPES {
        _K.shapes_layout = aux_tag;
    }
    return 0;
}

impl jc_reg_default(tag: int, key_h: int, kind: int) -> int {
    if tag not in _CLS {
        return 1;
    }
    row: ClassRow = _CLS[tag];
    row.dflt_k.append(key_h);
    row.dflt_kind.append(kind);
    return 0;
}

impl jc_reg_edge(tag: int, cls_h: int) -> int {
    _EDGE[tag] = cls_h;
    return 0;
}

impl jc_reg_hint_tags(srcdiag_tag: int, commentdata_tag: int) -> int {
    _HINTS[0] = srcdiag_tag;
    _HINTS[1] = commentdata_tag;
    return 0;
}

impl hint_srcdiag -> int {
    return _HINTS[0];
}

impl hint_commentdata -> int {
    return _HINTS[1];
}

impl _ld64(addr: int) -> int {
    return __mem_load_i64(addr);
}

impl _ld8(addr: int) -> int {
    return (__mem_load_i64(addr & -8) >> ((addr & 7) * 8)) & 255;
}

impl _tag_at(h: int) -> int {
    return _ld64(h + 8);
}

impl _nlist_len(l: int) -> int {
    return _ld64(l);
}

impl _seq_element_tag(layout: int) -> int {
    if layout not in _VALUES {
        return 0;
    }
    child = _VALUES[layout].child;
    if child in _VALUES and _VALUES[child].code == CODE_OBJ {
        return _VALUES[child].tag;
    }
    return -1;
}

impl _plan_row(row: ClassRow, src: FieldRow, slot_default: int) {
    aux = src.aux_tag;
    flags = src.flags;
    if src.code == CODE_NATLIST or src.code == CODE_OPTLIST {
        element_tag = _seq_element_tag(aux);
        if element_tag >= 0 {
            aux = element_tag;
        } else {
            flags = 1;
        }
    }
    row.plan.append(src.key_h);
    row.plan.append(src.code);
    row.plan.append(src.off);
    row.plan.append(aux);
    row.plan.append(src.enum_h);
    row.plan.append(flags);
    row.plan.append(slot_default);
}

impl _build_plan(row: ClassRow) {
    last: dict[int, int] = {};
    i = 0;
    for fr in row.rows {
        last[fr.key_h] = i;
        i += 1;
    }
    placed: dict[int, int] = {};
    while row.plan {
        row.plan.pop();
    }
    j = 0;
    n = len(row.dflt_k);
    while j < n {
        k = row.dflt_k[j];
        kind = row.dflt_kind[j];
        j += 1;
        if k in placed {
            continue;
        }
        placed[k] = 1;
        if k in last {
            _plan_row(row, row.rows[last[k]], kind);
        } else {
            _plan_row(
                row, FieldRow(key_h=k, code=CODE_DEFAULT, off=0, aux_tag=kind), kind
            );
        }
    }
    for fr in row.rows {
        if fr.key_h in placed {
            continue;
        }
        placed[fr.key_h] = 1;
        _plan_row(row, row.rows[last[fr.key_h]], -1);
    }
}

impl jc_reg_seal -> int {
    for tag in _CLS {
        _build_plan(_CLS[tag]);
    }
    return 0;
}

impl _enqueue(m: Mz, h: int, hint: int) {
    if h != 0 {
        m.q.append(h);
        m.q_hint.append(hint);
    }
}

impl _hash_order_extent(h: int, order: int) -> int {
    if order == 0 {
        return 0;
    }
    return _ld64(order + _ld64(h + 8) * 16);
}

impl _hashed(code: int) -> bool {
    return code == CODE_NATDICT or code == CODE_NATSET;
}

impl _container_order(h: int, row: ValueRow) -> int {
    return _ld64(h + row.order_off) if _hashed(row.code) else 0;
}

impl _container_extent(h: int, row: ValueRow, order: int) -> int {
    return _hash_order_extent(h, order) if _hashed(row.code) else _ld64(h);
}

impl _container_slot(row: ValueRow, order: int, i: int) -> int {
    return _ld64(order + i * 8) if _hashed(row.code) else i;
}

impl _container_items(h: int, row: ValueRow) -> int {
    return _ld64(h + (row.key_off if row.code == CODE_NATSET else row.data_off));
}

impl _enqueue_value(m: Mz, h: int, layout: int) {
    if h == 0 {
        return;
    }
    row = _VALUES[layout];
    if row.code == CODE_OBJ {
        _enqueue(m, h, row.tag);
    } elif row.code == CODE_NATLIST or _hashed(row.code) {
        order = _container_order(h, row);
        items = _container_items(h, row);
        for i in range(_container_extent(h, row, order)) {
            slot = _container_slot(row, order, i);
            if slot >= 0 {
                _enqueue_value(m, _ld64(items + slot * 8), row.child);
            }
        }
    }
}

impl _str(m: Mz, p: int) -> int {
    if p in m.strs {
        s = m.strs[p];
        Py_IncRef(s);
        return s;
    }
    s = PyUnicode_FromString(p);
    if s != 0 {
        Py_IncRef(s);
        m.strs[p] = s;
    }
    return s;
}

impl _copy_value(m: Mz, h: int, layout: int) -> int {
    if h == 0 {
        Py_IncRef(_K.none_h);
        return _K.none_h;
    }
    row = _VALUES[layout];
    if row.code == CODE_OBJ {
        obj_h = m.map.get(h, 0) or _K.none_h;
        Py_IncRef(obj_h);
        return obj_h;
    }
    if row.code == CODE_STR {
        return _str(m, h);
    }
    order = _container_order(h, row);
    items = _container_items(h, row);
    extent = _container_extent(h, row, order);
    keys = _ld64(h + row.key_off) if row.code == CODE_NATDICT else 0;
    out = 0;
    if row.code == CODE_NATDICT {
        out = PyDict_New();
    } elif row.code == CODE_NATSET {
        out = PySet_New(0);
    } else {
        out = PyList_New(extent);
    }
    for i in range(extent) {
        slot = _container_slot(row, order, i);
        if slot < 0 {
            continue;
        }
        value = _copy_value(m, _ld64(items + slot * 8), row.child);
        if row.code == CODE_NATDICT {
            key = _str(m, _ld64(keys + slot * 8));
            PyDict_SetItem(out, key, value);
            Py_DecRef(key);
            Py_DecRef(value);
        } elif row.code == CODE_NATSET {
            PySet_Add(out, value);
            Py_DecRef(value);
        } else {
            PyList_SetItem(out, i, value);
        }
    }
    return out;
}

impl _defer_ref(m: Mz, o: int, k: int, t: int, hint: int, slot_default: int) {
    if slot_default >= 0 {
        done = m.map.get(t, -1);
        if done >= 0 {
            PyObject_SetAttr(o, k, done if done != 0 else _K.none_h);
            return;
        }
        PyObject_SetAttr(o, k, _K.none_h);
    }
    m.ref_o.append(o);
    m.ref_k.append(k);
    m.ref_t.append(t);
    _enqueue(m, t, hint);
}

impl _set_fresh(o: int, k: int, v: int) -> None {
    if v == 0 {
        PyErr_Clear();
        PyObject_SetAttr(o, k, _K.none_h);
        return;
    }
    PyObject_SetAttr(o, k, v);
    Py_DecRef(v);
}

impl _set_default(o: int, k: int, kind: int) {
    if kind == DEFAULT_LIST {
        _set_fresh(o, k, PyList_New(0));
    } elif kind == DEFAULT_DICT {
        _set_fresh(o, k, PyDict_New());
    } elif kind == DEFAULT_SET {
        _set_fresh(o, k, PySet_New(0));
    } else {
        PyObject_SetAttr(o, k, _K.none_h);
    }
}

impl _set_enum(o: int, k: int, enum_h: int, raw: int) {
    member = 0;
    if enum_h != 0 {
        kk = PyLong_FromLongLong(raw);
        member = PyDict_GetItem(enum_h, kk);
        Py_DecRef(kk);
    }
    PyObject_SetAttr(o, k, member if member != 0 else _K.none_h);
}

impl _copy_union(m: Mz, o: int, k: int, flags: int, slot_default: int, a: int) -> None {
    kind = _ld8(a);
    pay = _ld64(a + 8);
    if kind == 7 {
        PyObject_SetAttr(o, k, _K.true_h if pay != 0 else _K.false_h);
        return;
    }
    if kind == 0 and pay != 0 {
        _set_fresh(o, k, PyLong_FromLongLong(pay));
        return;
    }
    if kind == 2 and (flags & 1) != 0 and pay != 0 {
        _set_fresh(o, k, _str(m, pay));
        return;
    }
    if kind == 6 and pay != 0 {
        _defer_ref(m, o, k, pay, 0, slot_default);
        return;
    }
    PyObject_SetAttr(o, k, _K.none_h);
}

impl _copy_list(m: Mz, o: int, k: int, hint: int, p: int) {
    n = _nlist_len(p) if p != 0 else 0;
    pl = PyList_New(n);
    if pl == 0 {
        PyErr_Clear();
        return;
    }
    if n > 0 {
        data = _ld64(p + 16);
        i = 0;
        while i < n {
            t = _ld64(data + (i * 8));
            done = m.map.get(t, -1);
            if done >= 0 {
                item = done if done != 0 else _K.none_h;
                Py_IncRef(item);
                PyList_SetItem(pl, i, item);
            } else {
                m.lst_l.append(pl);
                m.lst_i.append(i);
                m.lst_t.append(t);
                _enqueue(m, t, hint);
            }
            i += 1;
        }
    }
    PyObject_SetAttr(o, k, pl);
    Py_DecRef(pl);
}

impl _defer_container(
    m: Mz, o: int, k: int, value: int, layout: int, slot_default: int
) {
    if slot_default >= 0 {
        PyObject_SetAttr(o, k, _K.none_h);
    }
    m.containers.append(ContainerCopy(o, k, value, layout));
    _enqueue_value(m, value, layout);
}

impl _copy_seq(m: Mz, o: int, k: int, p: int, aux: int, flags: int, slot_default: int) {
    if flags == 0 or p == 0 {
        _copy_list(m, o, k, aux if flags == 0 else 0, p);
    } else {
        _defer_container(m, o, k, p, aux, slot_default);
    }
}

impl _str_is(p: int, word: int, n: int) -> bool {
    i = 0;
    while i <= n {
        if _ld8(p + i) != ((word >> (i * 8)) & 255) {
            return False;
        }
        i += 1;
    }
    return True;
}

impl _shape_value(p: int) -> int {
    if p == 0 {
        return _K.s_none;
    }
    if _str_is(p, 6647407, 3) {
        return _K.s_one;
    }
    if _str_is(p, 2037277037, 4) {
        return _K.s_many;
    }
    return _K.s_none;
}

impl _copy_shapes(o: int, k: int, layout_id: int, slot_default: int, a: int) {
    nd = _ld64(a + 8) if _ld8(a) != 0 else 0;
    if nd == 0 or layout_id not in _VALUES {
        _set_default(o, k, slot_default);
        return;
    }
    layout = _VALUES[layout_id];
    keys = _ld64(nd + layout.key_off);
    data = _ld64(nd + layout.data_off);
    order = _ld64(nd + layout.order_off);
    extent = _hash_order_extent(nd, order);
    body = 0;
    spec = 0;
    acc = 0;
    i = 0;
    while i < extent {
        slot = _ld64(order + i * 8);
        i += 1;
        if slot < 0 {
            continue;
        }
        role = _ld64(keys + slot * 8);
        if role == _K.body_key {
            body = _shape_value(_ld64(data + slot * 8));
        } elif role == _K.spec_key {
            spec = _shape_value(_ld64(data + slot * 8));
        } elif role == _K.acc_key {
            acc = _shape_value(_ld64(data + slot * 8));
        }
    }
    if body == 0 and spec == 0 and acc == 0 {
        _set_default(o, k, slot_default);
        return;
    }
    out = PyDict_New();
    if out == 0 {
        PyErr_Clear();
        _set_default(o, k, slot_default);
        return;
    }
    if body != 0 {
        PyDict_SetItem(out, _K.body_h, body);
    }
    if spec != 0 {
        PyDict_SetItem(out, _K.spec_h, spec);
    }
    if acc != 0 {
        PyDict_SetItem(out, _K.acc_h, acc);
    }
    PyObject_SetAttr(o, k, out);
    Py_DecRef(out);
}

impl _apply_plan(m: Mz, row: ClassRow, h: int, o: int) {
    plan = row.plan;
    n = len(plan);
    i = 0;
    while i < n {
        k = plan[i + P_KEY];
        code = plan[i + P_CODE];
        a = h + plan[i + P_OFF];
        if code == CODE_INT {
            _set_fresh(o, k, PyLong_FromLongLong(_ld64(a)));
        } elif code == CODE_BOOL {
            PyObject_SetAttr(o, k, _K.true_h if _ld8(a) != 0 else _K.false_h);
        } elif code == CODE_STR {
            p = _ld64(a);
            if p != 0 {
                _set_fresh(o, k, _str(m, p));
            } else {
                PyObject_SetAttr(o, k, _K.empty_h);
            }
        } elif code == CODE_OBJ {
            t = _ld64(a);
            if t != 0 {
                _defer_ref(m, o, k, t, plan[i + P_AUX], plan[i + P_SLOT]);
            } else {
                PyObject_SetAttr(o, k, _K.none_h);
            }
        } elif code == CODE_OPTREF {
            t = _ld64(a + 8);
            if _ld8(a) != 0 and t != 0 {
                _defer_ref(m, o, k, t, plan[i + P_AUX], plan[i + P_SLOT]);
            } else {
                PyObject_SetAttr(o, k, _K.none_h);
            }
        } elif code == CODE_DEFAULT {
            _set_default(o, k, plan[i + P_AUX]);
        } elif code == CODE_NATLIST {
            _copy_seq(
                m, o, k, _ld64(a), plan[i + P_AUX], plan[i + P_FLAGS], plan[i + P_SLOT]
            );
        } elif code == CODE_OPTSTR {
            p = _ld64(a + 8);
            if _ld8(a) != 0 and p != 0 {
                _set_fresh(o, k, _str(m, p));
            } else {
                PyObject_SetAttr(o, k, _K.none_h);
            }
        } elif code == CODE_OPTLIST {
            p = _ld64(a + 8);
            if _ld8(a) != 0 and p != 0 {
                _copy_seq(
                    m, o, k, p, plan[i + P_AUX], plan[i + P_FLAGS], plan[i + P_SLOT]
                );
            } else {
                PyObject_SetAttr(o, k, _K.none_h);
            }
        } elif code == CODE_ENUM {
            _set_enum(o, k, plan[i + P_ENUM], _ld64(a));
        } elif code == CODE_SHAPES {
            _copy_shapes(o, k, plan[i + P_AUX], plan[i + P_SLOT], a);
        } elif code == CODE_UNION {
            _copy_union(m, o, k, plan[i + P_FLAGS], plan[i + P_SLOT], a);
        } elif code == CODE_OPTENUM {
            if _ld8(a) != 0 {
                _set_enum(o, k, plan[i + P_ENUM], _ld64(a + 8));
            } else {
                PyObject_SetAttr(o, k, _K.none_h);
            }
        } elif _hashed(code) {
            value = _ld64(a);
            slot_default = plan[i + P_SLOT];
            if value != 0 {
                _defer_container(m, o, k, value, plan[i + P_AUX], slot_default);
            } elif slot_default >= 0 {
                _set_default(o, k, slot_default);
            }
        }
        i += P_STRIDE;
    }
}

impl _resolve_row(h: int, hint: int) -> int {
    if hint != 0 and hint in _CLS {
        hrow: ClassRow = _CLS[hint];
        if hrow.tagged == 0 {
            return hint;
        }
    }
    rt = _tag_at(h);
    if rt in _CLS {
        return rt;
    }
    if hint != 0 and hint in _CLS {
        return hint;
    }
    return 0;
}

impl _visit(m: Mz, h: int, hint: int) -> None {
    if h in m.map {
        return;
    }
    tag = _resolve_row(h, hint);
    if tag == 0 {
        m.map[h] = 0;
        m.skipped += 1;
        return;
    }
    row: ClassRow = _CLS[tag];
    o = PyType_GenericAlloc(row.cls_h, 0);
    if o == 0 {
        PyErr_Clear();
        m.map[h] = 0;
        m.skipped += 1;
        return;
    }
    m.map[h] = o;
    m.vis_o.append(o);
    _apply_plan(m, row, h, o);
    if row.is_node != 0 {
        _record_adj(m, h, o);
    }
}

impl _record_adj(m: Mz, h: int, o: int) {
    lo = len(m.adj);
    osp_adj_fill(h, DIR_OUT, m.adj);
    mid = len(m.adj);
    osp_adj_fill(h, DIR_IN, m.adj);
    hi = len(m.adj);
    if hi == lo {
        return;
    }
    m.nd_o.append(o);
    m.nd_lo.append(lo);
    m.nd_mid.append(mid);
    i = lo + 1;
    while i < hi {
        _enqueue(m, m.adj[i], 0);
        i += 2;
    }
}

impl _patch_refs(m: Mz) {
    n = len(m.ref_o);
    i = 0;
    while i < n {
        po = m.map.get(m.ref_t[i], 0);
        PyObject_SetAttr(m.ref_o[i], m.ref_k[i], po if po != 0 else _K.none_h);
        i += 1;
    }
    n = len(m.lst_l);
    i = 0;
    while i < n {
        po = m.map.get(m.lst_t[i], 0);
        if po == 0 {
            po = _K.none_h;
        }
        Py_IncRef(po);
        PyList_SetItem(m.lst_l[i], m.lst_i[i], po);
        i += 1;
    }
}

impl _edge_dict(m: Mz, lo: int, hi: int, weak: bool) -> int {
    d = 0;
    cur_tag = 0;
    cur_pl = 0;
    i = lo;
    while i < hi {
        tg = m.adj[i];
        t = m.adj[i + 1];
        i += 2;
        if tg not in _EDGE {
            continue;
        }
        val = m.map.get(t, 0);
        if val == 0 {
            continue;
        }
        if tg != cur_tag or cur_pl == 0 {
            if d == 0 {
                d = PyDict_New();
                if d == 0 {
                    PyErr_Clear();
                    break;
                }
            }
            ec = _EDGE[tg];
            existing = PyDict_GetItem(d, ec);
            if existing == 0 {
                pl = PyList_New(0);
                if pl == 0 {
                    PyErr_Clear();
                    break;
                }
                PyDict_SetItem(d, ec, pl);
                Py_DecRef(pl);
                existing = pl;
            }
            cur_pl = existing;
            cur_tag = tg;
        }
        if weak {
            w = PyWeakref_NewRef(val, 0);
            if w != 0 {
                PyList_Append(cur_pl, w);
                Py_DecRef(w);
            } else {
                PyErr_Clear();
            }
        } else {
            PyList_Append(cur_pl, val);
        }
    }
    return d;
}

impl _new_anchor(m: Mz, o: int) -> int {
    if ANCHOR_TAG not in _CLS {
        return PyObject_GetAttr(o, _K.k_jac);
    }
    row: ClassRow = _CLS[ANCHOR_TAG];
    a = PyType_GenericAlloc(row.cls_h, 0);
    if a == 0 {
        PyErr_Clear();
        return 0;
    }
    _apply_plan(m, row, 0, a);
    PyObject_SetAttr(a, _K.k_arch, o);
    PyObject_SetAttr(o, _K.k_jac, a);
    return a;
}

impl _edge_lists(m: Mz, o: int, lo: int, mid: int, hi: int) -> None {
    d_out = _edge_dict(m, lo, mid, False);
    d_in = _edge_dict(m, mid, hi, True);
    if d_out == 0 and d_in == 0 {
        return;
    }
    anchor = _new_anchor(m, o);
    if anchor != 0 {
        if d_out != 0 {
            PyObject_SetAttr(anchor, _K.k_out, d_out);
        }
        if d_in != 0 {
            PyObject_SetAttr(anchor, _K.k_in, d_in);
        }
        Py_DecRef(anchor);
    } else {
        PyErr_Clear();
    }
    if d_out != 0 {
        Py_DecRef(d_out);
    }
    if d_in != 0 {
        Py_DecRef(d_in);
    }
}

impl _all_edges(m: Mz) {
    n = len(m.nd_o);
    i = 0;
    while i < n {
        hi = m.nd_lo[i + 1] if i + 1 < n else len(m.adj);
        _edge_lists(m, m.nd_o[i], m.nd_lo[i], m.nd_mid[i], hi);
        i += 1;
    }
}

impl _release(m: Mz) {
    for o in m.vis_o {
        Py_DecRef(o);
    }
    for p in m.strs {
        Py_DecRef(m.strs[p]);
    }
}

impl _run(start_h: int, start_hint: int, do_edges: int) -> int {
    gc_was = PyGC_IsEnabled();
    if gc_was != 0 {
        PyGC_Disable();
    }
    m = Mz(
        map={},
        q=[],
        q_hint=[],
        ref_o=[],
        ref_k=[],
        ref_t=[],
        lst_l=[],
        lst_i=[],
        lst_t=[],
        vis_o=[],
        nd_o=[],
        nd_lo=[],
        nd_mid=[],
        adj=[],
        strs={},
        skipped=0,
        containers=[]
    );
    m.q.append(start_h);
    m.q_hint.append(start_hint);
    while m.q {
        h = m.q.pop();
        hint = m.q_hint.pop();
        _visit(m, h, hint);
    }
    _patch_refs(m);
    for copy in m.containers {
        _set_fresh(copy.owner, copy.key, _copy_value(m, copy.value, copy.layout));
    }
    if do_edges != 0 {
        _all_edges(m);
    }
    out = m.map.get(start_h, 0);
    if out != 0 {
        Py_IncRef(out);
    }
    _release(m);
    _STATS[0] = m.skipped;
    if gc_was != 0 {
        PyGC_Enable();
    }
    return out;
}

impl jc_mz_run(h: int) -> int {
    return _run(h, 0, 1);
}

impl jc_mz_obj(h: int, hint: int) -> int {
    return _run(h, hint, 0);
}

impl jc_mz_skipped -> int {
    return _STATS[0];
}
