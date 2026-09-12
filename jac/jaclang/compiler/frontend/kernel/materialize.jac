import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }
import from c { def osp_adj_pairs(origin: int, dir: int) -> list[int];  }
import from c { def PyType_GenericAlloc(t: int, n: int) -> int;  }
import from c { def PyObject_SetAttr(o: int, k: int, v: int) -> int;  }
import from c { def PyObject_GetAttr(o: int, k: int) -> int;  }
import from c { def PyErr_Clear -> int;  }
import from c { def PyUnicode_FromString(p: int) -> int;  }
import from c { def PyLong_FromLongLong(v: int) -> int;  }
import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }
import from c { def PyList_Append(l: int, v: int) -> int;  }
import from c { def PyDict_New -> int;  }
import from c { def PyDict_SetItem(d: int, k: int, v: int) -> int;  }
import from c { def PyDict_GetItem(d: int, k: int) -> int;  }
import from c { def PySet_New(i: int) -> int;  }
import from c { def PyWeakref_NewRef(o: int, cb: int) -> int;  }
import from c { def Py_IncRef(o: int) -> int;  }
import from c { def Py_DecRef(o: int) -> int;  }
import from c { def PyGC_Disable -> int;  }
import from c { def PyGC_Enable -> int;  }
import from c { def PyGC_IsEnabled -> int;  }

glob CODE_SKIP: int = 0,
     CODE_INT: int = 1,
     CODE_BOOL: int = 2,
     CODE_STR: int = 3,
     CODE_ENUM: int = 4,
     CODE_OPTREF: int = 5,
     CODE_OBJ: int = 6,
     CODE_NATLIST: int = 7,
     CODE_UNION: int = 8,
     CODE_OPTENUM: int = 9,
     CODE_NATDICT: int = 10;

obj ValueRow {
    has code: int,
        tag: int,
        child: int,
        key_off: int,
        data_off: int,
        order_off: int;
}

obj ContainerCopy {
    has owner: int,
        key: int,
        value: int,
        layout: int;
}

glob _VALUES: dict[int, ValueRow] = {};

def:pub jc_reg_value(
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

obj FieldRow {
    has key_h: int,
        code: int,
        off: int,
        aux_tag: int = 0,
        enum_h: int = 0,
        flags: int = 0;
}

obj ClassRow {
    has cls_h: int,
        size: int,
        tagged: int = 0,
        is_node: int = 0,
        rows: list[FieldRow] = [],
        dflt_k: list[int] = [],
        dflt_kind: list[int] = [];
}

obj MzConsts {
    has none_h: int = 0,
        true_h: int = 0,
        false_h: int = 0,
        empty_h: int = 0,
        s_none: int = 0,
        s_one: int = 0,
        s_many: int = 0,
        k_out: int = 0,
        k_in: int = 0,
        k_jac: int = 0,
        k_shapes: int = 0,
        k_arch: int = 0,
        body_h: int = 0,
        spec_h: int = 0,
        acc_h: int = 0;
}

glob _CLS: dict[int, ClassRow] = {},
     _EDGE: dict[int, int] = {},
     _K: MzConsts = MzConsts(),
     _STATS: list[int] = [0];

def:pub jc_reg_consts(
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

def:pub jc_reg_shape_roles(body_h: int, spec_h: int, acc_h: int) -> int {
    _K.body_h = body_h;
    _K.spec_h = spec_h;
    _K.acc_h = acc_h;
    return 0;
}

def:pub jc_reg_class(
    tag: int, cls_h: int, size: int, tagged: int, is_node: int
) -> int {
    _CLS[tag] = ClassRow(
        cls_h=cls_h,
        size=size,
        tagged=tagged,
        is_node=is_node,
        rows=[],
        dflt_k=[],
        dflt_kind=[]
    );
    return 0;
}

def:pub jc_reg_field(
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
    return 0;
}

def:pub jc_reg_default(tag: int, key_h: int, kind: int) -> int {
    if tag not in _CLS {
        return 1;
    }
    row: ClassRow = _CLS[tag];
    row.dflt_k.append(key_h);
    row.dflt_kind.append(kind);
    return 0;
}

def:pub jc_reg_edge(tag: int, cls_h: int) -> int {
    _EDGE[tag] = cls_h;
    return 0;
}

glob _HINTS: list[int] = [0, 0];

def:pub jc_reg_hint_tags(srcdiag_tag: int, commentdata_tag: int) -> int {
    _HINTS[0] = srcdiag_tag;
    _HINTS[1] = commentdata_tag;
    return 0;
}

def hint_srcdiag -> int {
    return _HINTS[0];
}

def hint_commentdata -> int {
    return _HINTS[1];
}

def _ld64u(buf: bytes, off: int) -> int {
    return (
        buf[off]
        | (buf[off + 1] << 8)
        | (buf[off + 2] << 16)
        | (buf[off + 3] << 24)
        | (buf[off + 4] << 32)
        | (buf[off + 5] << 40)
        | (buf[off + 6] << 48)
        | (buf[off + 7] << 56)
    );
}

def _ld64s(buf: bytes, off: int) -> int {
    v = _ld64u(buf, off);
    if v >= 9223372036854775808 {
        v -= 18446744073709551616;
    }
    return v;
}

def _ld8(buf: bytes, off: int) -> int {
    return buf[off];
}

def _peek64(addr: int) -> int {
    buf = b"\x00" * 8;
    memcpy(buf, addr, u64(8));
    return int.from_bytes(buf, "little");
}

def _tag_at(h: int) -> int {
    return _peek64(h + 8);
}

def _nlist_len(l: int) -> int {
    return _peek64(l);
}

def _nlist_get(l: int, i: int) -> int {
    return _peek64(_peek64(l + 16) + (i * 8));
}

obj Mz {
    has map: dict[int, int] = {},
        q: list[int] = [],
        q_hint: list[int] = [],
        ref_o: list[int] = [],
        ref_k: list[int] = [],
        ref_t: list[int] = [],
        lst_l: list[int] = [],
        lst_i: list[int] = [],
        lst_t: list[int] = [],
        skipped: int = 0,
        containers: list[ContainerCopy] = [];
}

glob _LAST: list[Mz] = [];

def _enqueue(m: Mz, h: int, hint: int) {
    if h != 0 {
        m.q.append(h);
        m.q_hint.append(hint);
    }
}

def _enqueue_value(m: Mz, h: int, layout: int) {
    if h == 0 {
        return;
    }
    row = _VALUES[layout];
    if row.code == CODE_OBJ {
        _enqueue(m, h, row.tag);
    } elif row.code == CODE_NATLIST or row.code == CODE_NATDICT {
        n = _peek64(h);
        data = _peek64(h + row.data_off);
        order = _peek64(h + row.order_off) if row.code == CODE_NATDICT else 0;
        for i in range(n) {
            slot = _peek64(order + i * 8) if row.code == CODE_NATDICT else i;
            _enqueue_value(m, _peek64(data + slot * 8), row.child);
        }
    }
}

def _copy_value(m: Mz, h: int, layout: int) -> int {
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
        return PyUnicode_FromString(h);
    }
    n = _peek64(h);
    data = _peek64(h + row.data_off);
    out = PyDict_New() if row.code == CODE_NATDICT else PyList_New(n);
    keys = _peek64(h + row.key_off) if row.code == CODE_NATDICT else 0;
    order = _peek64(h + row.order_off) if row.code == CODE_NATDICT else 0;
    for i in range(n) {
        slot = _peek64(order + i * 8) if row.code == CODE_NATDICT else i;
        value = _copy_value(m, _peek64(data + slot * 8), row.child);
        if row.code == CODE_NATDICT {
            key = PyUnicode_FromString(_peek64(keys + slot * 8));
            PyDict_SetItem(out, key, value);
            Py_DecRef(key);
            Py_DecRef(value);
        } else {
            PyList_SetItem(out, i, value);
        }
    }
    return out;
}

def _defer_ref(m: Mz, o: int, k: int, t: int, hint: int) {
    m.ref_o.append(o);
    m.ref_k.append(k);
    m.ref_t.append(t);
    _enqueue(m, t, hint);
}

def _set_fresh(o: int, k: int, v: int) -> None {
    if v == 0 {
        PyErr_Clear();
        PyObject_SetAttr(o, k, _K.none_h);
        return;
    }
    PyObject_SetAttr(o, k, v);
    Py_DecRef(v);
}

def _fill_defaults(row: ClassRow, o: int) {
    n = len(row.dflt_k);
    i = 0;
    while i < n {
        kind = row.dflt_kind[i];
        k = row.dflt_k[i];
        if kind == 0 {
            PyObject_SetAttr(o, k, _K.none_h);
        } elif kind == 1 {
            _set_fresh(o, k, PyList_New(0));
        } elif kind == 2 {
            _set_fresh(o, k, PyDict_New());
        } elif kind == 3 {
            _set_fresh(o, k, PySet_New(0));
        }
        i += 1;
    }
}

def _set_enum(o: int, k: int, enum_h: int, raw: int) -> None {
    if enum_h == 0 {
        PyObject_SetAttr(o, k, _K.none_h);
        return;
    }
    kk = PyLong_FromLongLong(raw);
    member = PyDict_GetItem(enum_h, kk);
    Py_DecRef(kk);
    if member != 0 {
        PyObject_SetAttr(o, k, member);
    } else {
        PyObject_SetAttr(o, k, _K.none_h);
    }
}

def _copy_union(m: Mz, o: int, fr: FieldRow, buf: bytes) -> None {
    kind = _ld8(buf, fr.off);
    pay = _ld64s(buf, fr.off + 8);
    if kind == 7 {
        PyObject_SetAttr(o, fr.key_h, _K.true_h if pay != 0 else _K.false_h);
        return;
    }
    if kind == 0 and pay != 0 {
        _set_fresh(o, fr.key_h, PyLong_FromLongLong(pay));
        return;
    }
    if kind == 2 and (fr.flags & 1) != 0 and pay != 0 {
        _set_fresh(o, fr.key_h, PyUnicode_FromString(pay));
        return;
    }
    if kind == 6 and pay != 0 {
        _defer_ref(m, o, fr.key_h, pay, 0);
        return;
    }
    PyObject_SetAttr(o, fr.key_h, _K.none_h);
}

def _copy_fields(m: Mz, row: ClassRow, h: int, o: int) {
    buf = b"\x00" * row.size;
    memcpy(buf, h, u64(row.size));
    for fr in row.rows {
        code = fr.code;
        if code == CODE_INT {
            _set_fresh(o, fr.key_h, PyLong_FromLongLong(_ld64s(buf, fr.off)));
        } elif code == CODE_BOOL {
            PyObject_SetAttr(
                o, fr.key_h, _K.true_h if _ld8(buf, fr.off) != 0 else _K.false_h
            );
        } elif code == CODE_STR {
            p = _ld64u(buf, fr.off);
            if p != 0 {
                _set_fresh(o, fr.key_h, PyUnicode_FromString(p));
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.empty_h);
            }
        } elif code == CODE_ENUM {
            _set_enum(o, fr.key_h, fr.enum_h, _ld64s(buf, fr.off));
        } elif code == CODE_OPTREF {
            t = _ld64u(buf, fr.off + 8);
            if _ld8(buf, fr.off) != 0 and t != 0 {
                _defer_ref(m, o, fr.key_h, t, fr.aux_tag);
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.none_h);
            }
        } elif code == CODE_OBJ {
            t = _ld64u(buf, fr.off);
            if t != 0 {
                _defer_ref(m, o, fr.key_h, t, fr.aux_tag);
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.none_h);
            }
        } elif code == CODE_NATLIST {
            p = _ld64u(buf, fr.off);
            n = _nlist_len(p) if p != 0 else 0;
            pl = PyList_New(n);
            if pl != 0 {
                i = 0;
                while i < n {
                    t = _nlist_get(p, i);
                    m.lst_l.append(pl);
                    m.lst_i.append(i);
                    m.lst_t.append(t);
                    _enqueue(m, t, fr.aux_tag);
                    i += 1;
                }
                PyObject_SetAttr(o, fr.key_h, pl);
                Py_DecRef(pl);
            } else {
                PyErr_Clear();
            }
        } elif code == CODE_UNION {
            _copy_union(m, o, fr, buf);
        } elif code == CODE_OPTENUM {
            if _ld8(buf, fr.off) != 0 {
                _set_enum(o, fr.key_h, fr.enum_h, _ld64s(buf, fr.off + 8));
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.none_h);
            }
        } elif code == CODE_NATDICT {
            value = _ld64u(buf, fr.off);
            if value != 0 {
                m.containers.append(ContainerCopy(o, fr.key_h, value, fr.aux_tag));
                _enqueue_value(m, value, fr.aux_tag);
            }
        }
    }
}

def _resolve_row(h: int, hint: int) -> int {
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

def _visit(m: Mz, h: int, hint: int) -> None {
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
    _fill_defaults(row, o);
    _copy_fields(m, row, h, o);
    if row.is_node != 0 {
        _enqueue_adj(m, h, 2);
        _enqueue_adj(m, h, 1);
    }
}

def _enqueue_adj(m: Mz, h: int, dir: int) {
    po = osp_adj_pairs(h, dir);
    n = len(po);
    i = 0;
    while i < n {
        _enqueue(m, po[i + 1], 0);
        i += 2;
    }
}

def _patch_refs(m: Mz) {
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

def _edge_dict_from_pairs(m: Mz, h: int, dir: int, weak: int) -> int {
    po = osp_adj_pairs(h, dir);
    n = len(po);
    d = 0;
    cur_tag = 0;
    cur_pl = 0;
    i = 0;
    while i < n {
        tg = po[i];
        t = po[i + 1];
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
                existing = PyDict_GetItem(d, ec);
            }
            cur_pl = existing;
            cur_tag = tg;
        }
        if weak != 0 {
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

glob ANCHOR_TAG: int = 1;

def _new_anchor(o: int) -> int {
    if ANCHOR_TAG not in _CLS {
        return PyObject_GetAttr(o, _K.k_jac);
    }
    row: ClassRow = _CLS[ANCHOR_TAG];
    a = PyType_GenericAlloc(row.cls_h, 0);
    if a == 0 {
        PyErr_Clear();
        return 0;
    }
    _fill_defaults(row, a);
    PyObject_SetAttr(a, _K.k_arch, o);
    PyObject_SetAttr(o, _K.k_jac, a);
    return a;
}

def _edge_lists(m: Mz, h: int, o: int) -> None {
    d_out = _edge_dict_from_pairs(m, h, 2, 0);
    d_in = _edge_dict_from_pairs(m, h, 1, 1);
    if d_out == 0 and d_in == 0 {
        return;
    }
    anchor = _new_anchor(o);
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

def _run(start_h: int, start_hint: int, do_edges: int) -> int {
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
        skipped=0
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
        for h in m.map {
            if m.map[h] != 0 {
                _edge_lists(m, h, m.map[h]);
            }
        }
    }
    out = 0;
    if start_h in m.map {
        out = m.map[start_h];
    }
    if out != 0 {
        Py_IncRef(out);
    }
    for h in m.map {
        po = m.map[h];
        if po != 0 {
            Py_DecRef(po);
        }
    }
    _STATS[0] = m.skipped;
    if _LAST {
        _LAST.pop();
    }
    _LAST.append(m);
    if gc_was != 0 {
        PyGC_Enable();
    }
    return out;
}

def:pub jc_mz_run(h: int) -> int {
    return _run(h, 0, 1);
}

def:pub jc_mz_obj(h: int, hint: int) -> int {
    return _run(h, hint, 0);
}

def:pub jc_mz_skipped -> int {
    return _STATS[0];
}

def _shape_entry(d: int, cls_h: int, code: int) {
    if code == 1 {
        PyDict_SetItem(d, cls_h, _K.s_none);
    } elif code == 2 {
        PyDict_SetItem(d, cls_h, _K.s_one);
    } elif code == 3 {
        PyDict_SetItem(d, cls_h, _K.s_many);
    }
}

def:pub jc_mz_lookup(h: int) -> int {
    if _LAST {
        m: Mz = _LAST[0];
        if h in m.map {
            return m.map[h];
        }
    }
    return 0;
}

def:pub jc_mz_shapes3(h: int, packed: int) -> int {
    o = jc_mz_lookup(h);
    if o == 0 or packed == 0 {
        return 1;
    }
    d = PyDict_New();
    if d == 0 {
        PyErr_Clear();
        return 1;
    }
    _shape_entry(d, _K.body_h, packed & 15);
    _shape_entry(d, _K.spec_h, (packed >> 4) & 15);
    _shape_entry(d, _K.acc_h, (packed >> 8) & 15);
    PyObject_SetAttr(o, _K.k_shapes, d);
    Py_DecRef(d);
    return 0;
}

def:pub jc_mz_dispose -> int {
    if _LAST {
        _LAST.pop();
    }
    return 0;
}
