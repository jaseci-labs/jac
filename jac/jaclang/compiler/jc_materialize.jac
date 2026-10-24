import from c { def osp_adj_fill(origin: int, dir: int, out: list[int]) -> int;  }
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
import from c { def PySet_Add(s: int, v: int) -> int;  }
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
     CODE_NATDICT: int = 10,
     CODE_SHAPES: int = 11,
     CODE_DEFAULT: int = 12,
     CODE_NATSET: int = 13,
     CODE_OPTSTR: int = 14,
     CODE_OPTLIST: int = 15;

glob DEFAULT_NONE: int = 0,
     DEFAULT_LIST: int = 1,
     DEFAULT_DICT: int = 2,
     DEFAULT_SET: int = 3;

glob DIR_IN: int = 1,
     DIR_OUT: int = 2;

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
) -> int;

glob P_KEY: int = 0,
     P_CODE: int = 1,
     P_OFF: int = 2,
     P_AUX: int = 3,
     P_ENUM: int = 4,
     P_FLAGS: int = 5,
     P_SLOT: int = 6,
     P_STRIDE: int = 7;

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
        dflt_kind: list[int] = [],
        plan: list[int] = [];
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
        acc_h: int = 0,
        body_key: int = 0,
        spec_key: int = 0,
        acc_key: int = 0,
        shapes_layout: int = 0;
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
) -> int;

def:pub jc_reg_shape_roles(body_h: int, spec_h: int, acc_h: int) -> int;

def jc_mz_shape_keys(probe: int);

def:pub jc_reg_class(
    tag: int, cls_h: int, size: int, tagged: int, is_node: int
) -> int;

def:pub jc_reg_field(
    tag: int, key_h: int, code: int, off: int, aux_tag: int, enum_h: int, flags: int
) -> int;

def:pub jc_reg_default(tag: int, key_h: int, kind: int) -> int;

def:pub jc_reg_edge(tag: int, cls_h: int) -> int;

glob _HINTS: list[int] = [0, 0];

def:pub jc_reg_hint_tags(srcdiag_tag: int, commentdata_tag: int) -> int;

def hint_srcdiag -> int;

def hint_commentdata -> int;

def _ld64(addr: int) -> int;

def _ld8(addr: int) -> int;

def _tag_at(h: int) -> int;

def _nlist_len(l: int) -> int;

def _seq_element_tag(layout: int) -> int;

def _plan_row(row: ClassRow, src: FieldRow, slot_default: int);

def _build_plan(row: ClassRow);

def:pub jc_reg_seal -> int;

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
        vis_o: list[int] = [],
        nd_o: list[int] = [],
        nd_lo: list[int] = [],
        nd_mid: list[int] = [],
        adj: list[int] = [],
        strs: dict[int, int] = {},
        skipped: int = 0,
        containers: list[ContainerCopy] = [];
}

def _enqueue(m: Mz, h: int, hint: int);

def _hash_order_extent(h: int, order: int) -> int;

def _hashed(code: int) -> bool;

def _container_order(h: int, row: ValueRow) -> int;

def _container_extent(h: int, row: ValueRow, order: int) -> int;

def _container_slot(row: ValueRow, order: int, i: int) -> int;

def _container_items(h: int, row: ValueRow) -> int;

def _enqueue_value(m: Mz, h: int, layout: int);

def _str(m: Mz, p: int) -> int;

def _copy_value(m: Mz, h: int, layout: int) -> int;

def _defer_ref(m: Mz, o: int, k: int, t: int, hint: int, slot_default: int);

def _set_fresh(o: int, k: int, v: int) -> None;

def _set_default(o: int, k: int, kind: int);

def _set_enum(o: int, k: int, enum_h: int, raw: int);

def _copy_union(m: Mz, o: int, k: int, flags: int, slot_default: int, a: int) -> None;

def _copy_list(m: Mz, o: int, k: int, hint: int, p: int);

def _defer_container(
    m: Mz, o: int, k: int, value: int, layout: int, slot_default: int
);

def _copy_seq(m: Mz, o: int, k: int, p: int, aux: int, flags: int, slot_default: int);

def _str_is(p: int, word: int, n: int) -> bool;

def _shape_value(p: int) -> int;

def _copy_shapes(o: int, k: int, layout_id: int, slot_default: int, a: int);

def _apply_plan(m: Mz, row: ClassRow, h: int, o: int);

def _resolve_row(h: int, hint: int) -> int;

def _visit(m: Mz, h: int, hint: int) -> None;

def _record_adj(m: Mz, h: int, o: int);

def _patch_refs(m: Mz);

def _edge_dict(m: Mz, lo: int, hi: int, weak: bool) -> int;

glob ANCHOR_TAG: int = 1;

def _new_anchor(m: Mz, o: int) -> int;

def _edge_lists(m: Mz, o: int, lo: int, mid: int, hi: int) -> None;

def _all_edges(m: Mz);

def _release(m: Mz);

def _run(start_h: int, start_hint: int, do_edges: int) -> int;

def:pub jc_mz_run(h: int) -> int;

def:pub jc_mz_obj(h: int, hint: int) -> int;

def:pub jc_mz_skipped -> int;
