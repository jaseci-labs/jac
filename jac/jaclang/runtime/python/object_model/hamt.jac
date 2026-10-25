import from c {
    obj HamtIterSlots {
        has n0: ptr[PyObject] = ptr[PyObject](),
            n1: ptr[PyObject] = ptr[PyObject](),
            n2: ptr[PyObject] = ptr[PyObject](),
            n3: ptr[PyObject] = ptr[PyObject](),
            n4: ptr[PyObject] = ptr[PyObject](),
            n5: ptr[PyObject] = ptr[PyObject](),
            n6: ptr[PyObject] = ptr[PyObject](),
            n7: ptr[PyObject] = ptr[PyObject](),
            p0: i64 = 0,
            p1: i64 = 0,
            p2: i64 = 0,
            p3: i64 = 0,
            p4: i64 = 0,
            p5: i64 = 0,
            p6: i64 = 0,
            p7: i64 = 0,
            level: i8 = i8(0);
    }  def jacpy_stack_address(slots: &mut HamtIterSlots) -> int;  glob:priv PyHamt_methods:
             list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("set"),
                 ml_meth=ptr(hamt_py_set),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get"),
                 ml_meth=ptr(hamt_py_get),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("delete"),
                 ml_meth=ptr(hamt_py_delete),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("items"),
                 ml_meth=ptr(hamt_py_items),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("keys"),
                 ml_meth=ptr(hamt_py_keys),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("values"),
                 ml_meth=ptr(hamt_py_values),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         PyHamt_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_contains=hamt_tp_contains
         ),
         PyHamt_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=hamt_tp_len, mp_subscript=hamt_tp_subscript
         ),
         PyHamtIterator_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=hamt_baseiter_tp_len
         ); glob _PyHamtItems_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT),
                 ob_size=0
             ),
             tp_name=ptr[u8]("items"),
             tp_basicsize=PyHamtIterator_SIZE,
             tp_itemsize=0,
             tp_as_mapping=addressof(PyHamtIterator_as_mapping),
             tp_dealloc=hamt_baseiter_tp_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=hamt_baseiter_tp_traverse,
             tp_clear=hamt_baseiter_tp_clear,
             tp_iter=PyObject_SelfIter,
             tp_iternext=hamt_baseiter_tp_iternext
         ),
         _PyHamtKeys_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT),
                 ob_size=0
             ),
             tp_name=ptr[u8]("keys"),
             tp_basicsize=PyHamtIterator_SIZE,
             tp_itemsize=0,
             tp_as_mapping=addressof(PyHamtIterator_as_mapping),
             tp_dealloc=hamt_baseiter_tp_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=hamt_baseiter_tp_traverse,
             tp_clear=hamt_baseiter_tp_clear,
             tp_iter=PyObject_SelfIter,
             tp_iternext=hamt_baseiter_tp_iternext
         ),
         _PyHamtValues_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT),
                 ob_size=0
             ),
             tp_name=ptr[u8]("values"),
             tp_basicsize=PyHamtIterator_SIZE,
             tp_itemsize=0,
             tp_as_mapping=addressof(PyHamtIterator_as_mapping),
             tp_dealloc=hamt_baseiter_tp_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=hamt_baseiter_tp_traverse,
             tp_clear=hamt_baseiter_tp_clear,
             tp_iter=PyObject_SelfIter,
             tp_iternext=hamt_baseiter_tp_iternext
         ),
         _PyHamt_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("hamt"),
             tp_basicsize=PyHamtObject_SIZE,
             tp_dealloc=hamt_tp_dealloc,
             tp_as_sequence=addressof(PyHamt_as_sequence),
             tp_as_mapping=addressof(PyHamt_as_mapping),
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=hamt_tp_traverse,
             tp_clear=hamt_tp_clear,
             tp_richcompare=hamt_tp_richcompare,
             tp_weaklistoffset=PyHamtObject_H_WEAKREFLIST,
             tp_iter=hamt_tp_iter,
             tp_methods=addressof(PyHamt_methods),
             tp_new=hamt_tp_new
         ),
         _PyHamt_ArrayNode_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("hamt_array_node"),
             tp_basicsize=PyHamtNode_Array_SIZE,
             tp_itemsize=0,
             tp_dealloc=hamt_node_array_dealloc,
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=hamt_node_array_traverse,
             tp_free=PyObject_GC_Del
         ),
         _PyHamt_BitmapNode_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("hamt_bitmap_node"),
             tp_basicsize=PyHamtNode_Bitmap_BASICSIZE,
             tp_itemsize=8,
             tp_dealloc=hamt_node_bitmap_dealloc,
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=hamt_node_bitmap_traverse,
             tp_free=PyObject_GC_Del
         ),
         _PyHamt_CollisionNode_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("hamt_collision_node"),
             tp_basicsize=PyHamtNode_Collision_BASICSIZE,
             tp_itemsize=8,
             tp_dealloc=hamt_node_collision_dealloc,
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=hamt_node_collision_traverse,
             tp_free=PyObject_GC_Del
         );
}

glob:priv F_ERROR: i32 = 0,
     F_NOT_FOUND: i32 = 1,
     F_FOUND: i32 = 2,
     W_ERROR: i32 = 0,
     W_NOT_FOUND: i32 = 1,
     W_EMPTY: i32 = 2,
     W_NEWNODE: i32 = 3,
     I_ITEM: i32 = 0,
     I_END: i32 = 1,
     HAMT_ARRAY_NODE_SIZE: i64 = 32;

def hamt_of(o: ptr[PyObject]) -> ptr[PyHamtObject];

def bitmap_of(nd: ptr[PyObject]) -> ptr[PyHamtNode_Bitmap];

def collision_of(nd: ptr[PyObject]) -> ptr[PyHamtNode_Collision];

def array_of(nd: ptr[PyObject]) -> ptr[PyHamtNode_Array];

def bitmap_items(nd: ptr[PyObject]) -> ptr[ptr[PyObject]];

def collision_items(nd: ptr[PyObject]) -> ptr[ptr[PyObject]];

def array_items(nd: ptr[PyObject]) -> ptr[ptr[PyObject]];

def is_array_node(nd: ptr[PyObject]) -> bool;

def is_bitmap_node(nd: ptr[PyObject]) -> bool;

def hamt_root(o: ptr[PyHamtObject]) -> ptr[PyObject];

def empty_hamt -> ptr[PyHamtObject];

def bitmap_node_empty -> ptr[PyObject];

def hamt_hash(o: ptr[PyObject]) -> i32;

def hamt_mask(hash: i32, shift: u32) -> u32;

def hamt_bitpos(hash: i32, shift: u32) -> u32;

def hamt_bitindex(bitmap: u32, bit: u32) -> u32;

def hamt_node_bitmap_new(size: i64) -> ptr[PyObject];

def hamt_node_bitmap_count(nd: ptr[PyObject]) -> i64;

def hamt_node_bitmap_clone(nd: ptr[PyObject]) -> ptr[PyObject];

def hamt_node_bitmap_clone_without(o: ptr[PyObject], bit: u32) -> ptr[PyObject];

def hamt_node_new_bitmap_or_collision(
    shift: u32,
    key1: ptr[PyObject],
    val1: ptr[PyObject],
    key2_hash: i32,
    key2: ptr[PyObject],
    val2: ptr[PyObject]
) -> ptr[PyObject];

def hamt_node_bitmap_assoc(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32];

def hamt_node_bitmap_without(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_node_bitmap_find(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_node_bitmap_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def hamt_node_bitmap_dealloc(self_: ptr[PyObject]);

def hamt_node_collision_new(hash: i32, size: i64) -> ptr[PyObject];

def hamt_node_collision_find_index(
    self_: ptr[PyObject], key: ptr[PyObject]
) -> tuple[i32, i64];

def hamt_node_collision_assoc(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32];

def hamt_node_collision_count(nd: ptr[PyObject]) -> i64;

def hamt_node_collision_without(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_node_collision_find(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_node_collision_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def hamt_node_collision_dealloc(self_: ptr[PyObject]);

def hamt_node_array_new(count: i64) -> ptr[PyObject];

def hamt_node_array_clone(nd: ptr[PyObject]) -> ptr[PyObject];

def hamt_node_array_assoc(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32];

def hamt_node_array_without(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_node_array_find(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_node_array_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def hamt_node_array_dealloc(self_: ptr[PyObject]);

def hamt_node_assoc(
    nd: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32];

def hamt_node_without(
    nd: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_node_find(
    nd: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def iter_nodes(iter: ptr[PyHamtIteratorState]) -> ptr[ptr[PyObject]];

def iter_positions(iter: ptr[PyHamtIteratorState]) -> ptr[i64];

def hamt_iterator_init(iter: ptr[PyHamtIteratorState], top: ptr[PyObject]);

def hamt_iterator_bitmap_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def hamt_iterator_collision_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def hamt_iterator_array_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def hamt_iterator_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def hamt_find(o: ptr[PyHamtObject], key: ptr[PyObject]) -> tuple[i32, ptr[PyObject]];

def hamt_find_value(
    o: ptr[PyHamtObject], key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def hamt_alloc -> ptr[PyHamtObject];

def hamt_baseiter_state(op: ptr[PyObject]) -> ptr[PyHamtIteratorState];

def hamt_baseiter_tp_clear(op: ptr[PyObject]) -> i32;

def hamt_baseiter_tp_dealloc(it: ptr[PyObject]);

def hamt_baseiter_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def hamt_baseiter_tp_iternext(op: ptr[PyObject]) -> ptr[PyObject];

def hamt_baseiter_tp_len(op: ptr[PyObject]) -> i64;

def hamt_baseiter_new(
    type: ptr[PyTypeObject], yield_fn: int, o: ptr[PyHamtObject]
) -> ptr[PyObject];

def hamt_iter_yield_items(key: ptr[PyObject], val: ptr[PyObject]) -> ptr[PyObject];

def hamt_iter_yield_keys(key: ptr[PyObject], val: ptr[PyObject]) -> ptr[PyObject];

def hamt_iter_yield_values(key: ptr[PyObject], val: ptr[PyObject]) -> ptr[PyObject];

def hamt_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def hamt_tp_clear(op: ptr[PyObject]) -> i32;

def hamt_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def hamt_tp_dealloc(self_: ptr[PyObject]);

def hamt_tp_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def hamt_tp_contains(op: ptr[PyObject], key: ptr[PyObject]) -> i32;

def hamt_tp_subscript(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def hamt_tp_len(op: ptr[PyObject]) -> i64;

def hamt_tp_iter(op: ptr[PyObject]) -> ptr[PyObject];

def hamt_py_set(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def hamt_py_get(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def hamt_py_delete(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def hamt_py_items(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def hamt_py_values(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def hamt_py_keys(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyHamt_Assoc(
        o: ptr[PyHamtObject], key: ptr[PyObject], val: ptr[PyObject]
    ) -> ptr[PyHamtObject] {
        key_hash = hamt_hash(key);
        if key_hash == i32(-1) {
            return ptr[PyHamtObject]();
        }
        top_node = hamt_root(o);
        (new_root, added_leaf) = hamt_node_assoc(top_node, u32(0), key_hash, key, val);
        if not new_root {
            return ptr[PyHamtObject]();
        }
        if new_root == top_node {
            object_decref(new_root);
            return ptr[PyHamtObject](object_new_ref(ptr[PyObject](o)));
        }
        new_o = hamt_alloc();
        if not new_o {
            object_decref(new_root);
            return ptr[PyHamtObject]();
        }
        new_o.view(1)[0].h_root = ptr[PyHamtNode](new_root);
        count = o.view(1)[0].h_count;
        if added_leaf != i32(0) {
            count = count + 1;
        }
        new_o.view(1)[0].h_count = count;
        return new_o;
    }  def _PyHamt_Without(
        o: ptr[PyHamtObject], key: ptr[PyObject]
    ) -> ptr[PyHamtObject] {
        key_hash = hamt_hash(key);
        if key_hash == i32(-1) {
            return ptr[PyHamtObject]();
        }
        (res, new_root) = hamt_node_without(hamt_root(o), u32(0), key_hash, key);
        if res == W_ERROR {
            return ptr[PyHamtObject]();
        }
        if res == W_EMPTY {
            return _PyHamt_New();
        }
        if res == W_NOT_FOUND {
            return ptr[PyHamtObject](object_new_ref(ptr[PyObject](o)));
        }
        new_o = hamt_alloc();
        if not new_o {
            object_decref(new_root);
            return ptr[PyHamtObject]();
        }
        new_o.view(1)[0].h_root = ptr[PyHamtNode](new_root);
        new_o.view(1)[0].h_count = o.view(1)[0].h_count - 1;
        return new_o;
    }  def _PyHamt_Find(
        o: ptr[PyHamtObject], key: ptr[PyObject], val: ptr[ptr[PyObject]]
    ) -> i32 {
        (res, found) = hamt_find_value(o, key);
        if res == i32(1) and val {
            val.view(1)[0] = found;
        }
        return res;
    }  def _PyHamt_Eq(v: ptr[PyHamtObject], w: ptr[PyHamtObject]) -> i32 {
        if v == w {
            return i32(1);
        }
        if v.view(1)[0].h_count != w.view(1)[0].h_count {
            return i32(0);
        }
        object_incref(ptr[PyObject](v));
        object_incref(ptr[PyObject](w));
        res: i32 = 1;
        slots: own HamtIterSlots = HamtIterSlots();
        iter = ptr[PyHamtIteratorState](jacpy_stack_address(&mut slots));
        hamt_iterator_init(iter, hamt_root(v));
        while True {
            (iter_res, v_key, v_val) = hamt_iterator_next(iter);
            if iter_res != I_ITEM {
                break;
            }
            (find_res, w_val) = hamt_find(w, v_key);
            if find_res == F_ERROR {
                res = i32(-1);
                break;
            }
            if find_res == F_NOT_FOUND {
                res = i32(0);
                break;
            }
            object_incref(v_key);
            object_incref(v_val);
            object_incref(w_val);
            cmp = PyObject_RichCompareBool(v_val, w_val, Py_EQ);
            object_decref(v_key);
            object_decref(v_val);
            object_decref(w_val);
            if cmp < 0 {
                res = i32(-1);
                break;
            }
            if cmp == 0 {
                res = i32(0);
                break;
            }
        }
        object_decref(ptr[PyObject](v));
        object_decref(ptr[PyObject](w));
        return res;
    }  def _PyHamt_Len(o: ptr[PyHamtObject]) -> i64 {
        return o.view(1)[0].h_count;
    }  def _PyHamt_New -> ptr[PyHamtObject] {
        return ptr[PyHamtObject](object_new_ref(ptr[PyObject](empty_hamt())));
    }  def _PyHamt_NewIterItems(o: ptr[PyHamtObject]) -> ptr[PyObject] {
        return hamt_baseiter_new(
            addressof(_PyHamtItems_Type), int(ptr(hamt_iter_yield_items)), o
        );
    }  def _PyHamt_NewIterKeys(o: ptr[PyHamtObject]) -> ptr[PyObject] {
        return hamt_baseiter_new(
            addressof(_PyHamtKeys_Type), int(ptr(hamt_iter_yield_keys)), o
        );
    }  def _PyHamt_NewIterValues(o: ptr[PyHamtObject]) -> ptr[PyObject] {
        return hamt_baseiter_new(
            addressof(_PyHamtValues_Type), int(ptr(hamt_iter_yield_values)), o
        );
    }
}

impl hamt_of(o: ptr[PyObject]) -> ptr[PyHamtObject] {
    return ptr[PyHamtObject](o);
}

impl bitmap_of(nd: ptr[PyObject]) -> ptr[PyHamtNode_Bitmap] {
    return ptr[PyHamtNode_Bitmap](nd);
}

impl collision_of(nd: ptr[PyObject]) -> ptr[PyHamtNode_Collision] {
    return ptr[PyHamtNode_Collision](nd);
}

impl array_of(nd: ptr[PyObject]) -> ptr[PyHamtNode_Array] {
    return ptr[PyHamtNode_Array](nd);
}

impl bitmap_items(nd: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](nd) + PyHamtNode_Bitmap_B_ARRAY);
}

impl collision_items(nd: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](nd) + PyHamtNode_Collision_C_ARRAY);
}

impl array_items(nd: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](nd) + PyHamtNode_Array_A_ARRAY);
}

impl is_array_node(nd: ptr[PyObject]) -> bool {
    return object_is_type(nd, addressof(_PyHamt_ArrayNode_Type));
}

impl is_bitmap_node(nd: ptr[PyObject]) -> bool {
    return object_is_type(nd, addressof(_PyHamt_BitmapNode_Type));
}

impl hamt_root(o: ptr[PyHamtObject]) -> ptr[PyObject] {
    return ptr[PyObject](o.view(1)[0].h_root);
}

impl empty_hamt -> ptr[PyHamtObject] {
    return ptr[PyHamtObject](current_interp() + PyInterpreterState_HAMT_EMPTY);
}

impl bitmap_node_empty -> ptr[PyObject] {
    return ptr[PyObject](
        int(addressof(_PyRuntime)) + _PyRuntimeState_HAMT_BITMAP_NODE_EMPTY
    );
}

impl hamt_hash(o: ptr[PyObject]) -> i32 {
    hash = PyObject_Hash(o);
    if hash == -1 {
        return i32(-1);
    }
    xored = i32.wrap(hash & 0xFFFFFFFF) ^ i32(hash >> 32);
    if xored == i32(-1) {
        return i32(-2);
    }
    return xored;
}

impl hamt_mask(hash: i32, shift: u32) -> u32 {
    return (u32.wrap(hash) >> shift) & u32(0x1F);
}

impl hamt_bitpos(hash: i32, shift: u32) -> u32 {
    return u32(1) << hamt_mask(hash, shift);
}

impl hamt_bitindex(bitmap: u32, bit: u32) -> u32 {
    return u32(popcount_digit(bitmap & (bit - u32(1))));
}

impl hamt_node_bitmap_new(size: i64) -> ptr[PyObject] {
    if size == 0 {
        return bitmap_node_empty();
    }
    nd = _PyObject_GC_NewVar(ptr[PyObject](addressof(_PyHamt_BitmapNode_Type)), size);
    if not nd {
        return NULL;
    }
    ptr[PyVarObject](nd).view(1)[0].ob_size = size;
    items = bitmap_items(nd);
    for i in range(size) {
        (items + i).view(1)[0] = NULL;
    }
    bitmap_of(nd).view(1)[0].b_bitmap = u32(0);
    object_gc_track(nd);
    return nd;
}

impl hamt_node_bitmap_count(nd: ptr[PyObject]) -> i64 {
    return object_size(nd) // 2;
}

impl hamt_node_bitmap_clone(nd: ptr[PyObject]) -> ptr[PyObject] {
    size = object_size(nd);
    clone = hamt_node_bitmap_new(size);
    if not clone {
        return NULL;
    }
    source = bitmap_items(nd);
    target = bitmap_items(clone);
    for i in range(size) {
        (target + i).view(1)[0] = object_xnew_ref((source + i).view(1)[0]);
    }
    bitmap_of(clone).view(1)[0].b_bitmap = bitmap_of(nd).view(1)[0].b_bitmap;
    return clone;
}

impl hamt_node_bitmap_clone_without(o: ptr[PyObject], bit: u32) -> ptr[PyObject] {
    size = object_size(o);
    new_node = hamt_node_bitmap_new(size - 2);
    if not new_node {
        return NULL;
    }
    bitmap = bitmap_of(o).view(1)[0].b_bitmap;
    idx = hamt_bitindex(bitmap, bit);
    key_idx = i64(idx) * 2;
    val_idx = key_idx + 1;
    source = bitmap_items(o);
    target = bitmap_items(new_node);
    for i in range(key_idx) {
        (target + i).view(1)[0] = object_xnew_ref((source + i).view(1)[0]);
    }
    j = val_idx + 1;
    while j < size {
        (target + (j - 2)).view(1)[0] = object_xnew_ref((source + j).view(1)[0]);
        j += 1;
    }
    bitmap_of(new_node).view(1)[0].b_bitmap = bitmap & ~bit;
    return new_node;
}

impl hamt_node_new_bitmap_or_collision(
    shift: u32,
    key1: ptr[PyObject],
    val1: ptr[PyObject],
    key2_hash: i32,
    key2: ptr[PyObject],
    val2: ptr[PyObject]
) -> ptr[PyObject] {
    key1_hash = hamt_hash(key1);
    if key1_hash == i32(-1) {
        return NULL;
    }
    if key1_hash == key2_hash {
        n = hamt_node_collision_new(key1_hash, 4);
        if not n {
            return NULL;
        }
        items = collision_items(n);
        items.view(1)[0] = object_new_ref(key1);
        (items + 1).view(1)[0] = object_new_ref(val1);
        (items + 2).view(1)[0] = object_new_ref(key2);
        (items + 3).view(1)[0] = object_new_ref(val2);
        return n;
    }
    empty = hamt_node_bitmap_new(0);
    if not empty {
        return NULL;
    }
    (n2, _first) = hamt_node_assoc(empty, shift, key1_hash, key1, val1);
    object_decref(empty);
    if not n2 {
        return NULL;
    }
    (n3, _second) = hamt_node_assoc(n2, shift, key2_hash, key2, val2);
    object_decref(n2);
    return n3;
}

impl hamt_node_bitmap_assoc(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32] {
    bit = hamt_bitpos(hash, shift);
    bitmap = bitmap_of(self_).view(1)[0].b_bitmap;
    idx = hamt_bitindex(bitmap, bit);
    items = bitmap_items(self_);
    if (bitmap & bit) != u32(0) {
        key_idx = i64(idx) * 2;
        val_idx = key_idx + 1;
        key_or_null = (items + key_idx).view(1)[0];
        val_or_node = (items + val_idx).view(1)[0];
        if not key_or_null {
            (sub_node, sub_added) = hamt_node_assoc(
                val_or_node, shift + u32(5), hash, key, val
            );
            if not sub_node {
                return (NULL, sub_added);
            }
            if val_or_node == sub_node {
                object_decref(sub_node);
                return (object_new_ref(self_), sub_added);
            }
            ret = hamt_node_bitmap_clone(self_);
            if not ret {
                object_decref(sub_node);
                return (NULL, sub_added);
            }
            py_xsetref(bitmap_items(ret) + val_idx, sub_node);
            return (ret, sub_added);
        }
        comp_err = PyObject_RichCompareBool(key, key_or_null, Py_EQ);
        if comp_err < 0 {
            return (NULL, i32(0));
        }
        if comp_err == 1 {
            if val == val_or_node {
                return (object_new_ref(self_), i32(0));
            }
            ret = hamt_node_bitmap_clone(self_);
            if not ret {
                return (NULL, i32(0));
            }
            py_xsetref(bitmap_items(ret) + val_idx, object_new_ref(val));
            return (ret, i32(0));
        }

        sub_node = hamt_node_new_bitmap_or_collision(
            shift + u32(5), key_or_null, val_or_node, hash, key, val
        );
        if not sub_node {
            return (NULL, i32(0));
        }
        ret = hamt_node_bitmap_clone(self_);
        if not ret {
            object_decref(sub_node);
            return (NULL, i32(0));
        }
        py_xsetref(bitmap_items(ret) + key_idx, NULL);
        py_xsetref(bitmap_items(ret) + val_idx, sub_node);
        return (ret, i32(1));
    }
    n = u32(popcount_digit(bitmap));
    if n >= u32(16) {
        jdx = i64(hamt_mask(hash, shift));
        added: i32 = 0;
        new_node = hamt_node_array_new(i64(n) + 1);
        if not new_node {
            return (NULL, added);
        }
        empty = hamt_node_bitmap_new(0);
        if not empty {
            object_decref(new_node);
            return (NULL, added);
        }
        slots = array_items(new_node);
        (child, child_added) = hamt_node_assoc(empty, shift + u32(5), hash, key, val);
        added = added | child_added;
        (slots + jdx).view(1)[0] = child;
        if not child {
            object_xdecref(empty);
            object_xdecref(new_node);
            return (NULL, added);
        }
        j: i64 = 0;
        for i in range(HAMT_ARRAY_NODE_SIZE) {
            if ((bitmap >> u32(i)) & u32(1)) != u32(0) {
                key_j = (items + j).view(1)[0];
                if not key_j {
                    (slots + i).view(1)[0] = object_new_ref(
                        (items + (j + 1)).view(1)[0]
                    );
                } else {
                    rehash = hamt_hash(key_j);
                    if rehash == i32(-1) {
                        object_xdecref(empty);
                        object_xdecref(new_node);
                        return (NULL, added);
                    }
                    (moved, moved_added) = hamt_node_assoc(
                        empty,
                        shift + u32(5),
                        rehash,
                        key_j,
                        (items + (j + 1)).view(1)[0]
                    );
                    added = added | moved_added;
                    (slots + i).view(1)[0] = moved;
                    if not moved {
                        object_xdecref(empty);
                        object_xdecref(new_node);
                        return (NULL, added);
                    }
                }
                j += 2;
            }
        }
        object_xdecref(empty);
        return (new_node, added);
    }

    key_idx = i64(idx) * 2;
    val_idx = key_idx + 1;
    new_node = hamt_node_bitmap_new(2 * (i64(n) + 1));
    if not new_node {
        return (NULL, i32(1));
    }
    target = bitmap_items(new_node);
    for i in range(key_idx) {
        (target + i).view(1)[0] = object_xnew_ref((items + i).view(1)[0]);
    }
    (target + key_idx).view(1)[0] = object_new_ref(key);
    (target + val_idx).view(1)[0] = object_new_ref(val);
    size = object_size(self_);
    k = key_idx;
    while k < size {
        (target + (k + 2)).view(1)[0] = object_xnew_ref((items + k).view(1)[0]);
        k += 1;
    }
    bitmap_of(new_node).view(1)[0].b_bitmap = bitmap | bit;
    return (new_node, i32(1));
}

impl hamt_node_bitmap_without(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    bit = hamt_bitpos(hash, shift);
    bitmap = bitmap_of(self_).view(1)[0].b_bitmap;
    if (bitmap & bit) == u32(0) {
        return (W_NOT_FOUND, NULL);
    }
    idx = hamt_bitindex(bitmap, bit);
    key_idx = i64(idx) * 2;
    val_idx = key_idx + 1;
    items = bitmap_items(self_);
    key_or_null = (items + key_idx).view(1)[0];
    val_or_node = (items + val_idx).view(1)[0];
    if not key_or_null {
        (res, sub_node) = hamt_node_without(val_or_node, shift + u32(5), hash, key);
        if res != W_NEWNODE {
            return (res, NULL);
        }
        if is_bitmap_node(sub_node) {
            sub_items = bitmap_items(sub_node);
            if hamt_node_bitmap_count(sub_node) == 1 and sub_items.view(1)[0] {
                clone = hamt_node_bitmap_clone(self_);
                if not clone {
                    object_decref(sub_node);
                    return (W_ERROR, NULL);
                }
                sub_key = sub_items.view(1)[0];
                sub_val = (sub_items + 1).view(1)[0];
                py_xsetref(bitmap_items(clone) + key_idx, object_new_ref(sub_key));
                py_xsetref(bitmap_items(clone) + val_idx, object_new_ref(sub_val));
                object_decref(sub_node);
                return (W_NEWNODE, clone);
            }
        }
        clone = hamt_node_bitmap_clone(self_);
        if not clone {
            object_decref(sub_node);
            return (W_ERROR, NULL);
        }
        py_xsetref(bitmap_items(clone) + val_idx, sub_node);
        return (W_NEWNODE, clone);
    }
    cmp = PyObject_RichCompareBool(key_or_null, key, Py_EQ);
    if cmp < 0 {
        return (W_ERROR, NULL);
    }
    if cmp == 0 {
        return (W_NOT_FOUND, NULL);
    }
    if hamt_node_bitmap_count(self_) == 1 {
        return (W_EMPTY, NULL);
    }
    new_node = hamt_node_bitmap_clone_without(self_, bit);
    if not new_node {
        return (W_ERROR, NULL);
    }
    return (W_NEWNODE, new_node);
}

impl hamt_node_bitmap_find(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    bit = hamt_bitpos(hash, shift);
    bitmap = bitmap_of(self_).view(1)[0].b_bitmap;
    if (bitmap & bit) == u32(0) {
        return (F_NOT_FOUND, NULL);
    }
    idx = hamt_bitindex(bitmap, bit);
    key_idx = i64(idx) * 2;
    items = bitmap_items(self_);
    key_or_null = (items + key_idx).view(1)[0];
    val_or_node = (items + (key_idx + 1)).view(1)[0];
    if not key_or_null {
        return hamt_node_find(val_or_node, shift + u32(5), hash, key);
    }
    comp_err = PyObject_RichCompareBool(key, key_or_null, Py_EQ);
    if comp_err < 0 {
        return (F_ERROR, NULL);
    }
    if comp_err == 1 {
        return (F_FOUND, val_or_node);
    }
    return (F_NOT_FOUND, NULL);
}

impl hamt_node_bitmap_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    items = bitmap_items(op);
    i = object_size(op);
    while i > 0 {
        i -= 1;
        vret = visit_reference((items + i).view(1)[0], visitor, arg);
        if vret != i32(0) {
            return vret;
        }
    }
    return i32(0);
}

impl hamt_node_bitmap_dealloc(self_: ptr[PyObject]) {
    size = object_size(self_);
    if size == 0 {
        return;
    }
    PyObject_GC_UnTrack(self_);
    items = bitmap_items(self_);
    i = size;
    while i > 0 {
        i -= 1;
        object_xdecref((items + i).view(1)[0]);
    }
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl hamt_node_collision_new(hash: i32, size: i64) -> ptr[PyObject] {
    nd = _PyObject_GC_NewVar(
        ptr[PyObject](addressof(_PyHamt_CollisionNode_Type)), size
    );
    if not nd {
        return NULL;
    }
    items = collision_items(nd);
    for i in range(size) {
        (items + i).view(1)[0] = NULL;
    }
    ptr[PyVarObject](nd).view(1)[0].ob_size = size;
    collision_of(nd).view(1)[0].c_hash = hash;
    object_gc_track(nd);
    return nd;
}

impl hamt_node_collision_find_index(
    self_: ptr[PyObject], key: ptr[PyObject]
) -> tuple[i32, i64] {
    items = collision_items(self_);
    size = object_size(self_);
    i: i64 = 0;
    while i < size {
        cmp = PyObject_RichCompareBool(key, (items + i).view(1)[0], Py_EQ);
        if cmp < 0 {
            return (F_ERROR, i64(-1));
        }
        if cmp == 1 {
            return (F_FOUND, i);
        }
        i += 2;
    }
    return (F_NOT_FOUND, i64(-1));
}

impl hamt_node_collision_assoc(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32] {
    c_hash = collision_of(self_).view(1)[0].c_hash;
    if hash == c_hash {
        (found, key_idx) = hamt_node_collision_find_index(self_, key);
        if found == F_ERROR {
            return (NULL, i32(0));
        }
        items = collision_items(self_);
        size = object_size(self_);
        if found == F_NOT_FOUND {
            new_node = hamt_node_collision_new(c_hash, size + 2);
            if not new_node {
                return (NULL, i32(0));
            }
            target = collision_items(new_node);
            for i in range(size) {
                (target + i).view(1)[0] = object_new_ref((items + i).view(1)[0]);
            }
            (target + size).view(1)[0] = object_new_ref(key);
            (target + (size + 1)).view(1)[0] = object_new_ref(val);
            return (new_node, i32(1));
        }
        val_idx = key_idx + 1;
        if (items + val_idx).view(1)[0] == val {
            return (object_new_ref(self_), i32(0));
        }

        new_node = hamt_node_collision_new(c_hash, size);
        if not new_node {
            return (NULL, i32(0));
        }
        target = collision_items(new_node);
        for i in range(size) {
            (target + i).view(1)[0] = object_new_ref((items + i).view(1)[0]);
        }
        py_xsetref(target + val_idx, object_new_ref(val));
        return (new_node, i32(0));
    }

    new_node = hamt_node_bitmap_new(2);
    if not new_node {
        return (NULL, i32(0));
    }
    bitmap_of(new_node).view(1)[0].b_bitmap = hamt_bitpos(c_hash, shift);
    (bitmap_items(new_node) + 1).view(1)[0] = object_new_ref(self_);
    (assoc_res, added) = hamt_node_bitmap_assoc(new_node, shift, hash, key, val);
    object_decref(new_node);
    return (assoc_res, added);
}

impl hamt_node_collision_count(nd: ptr[PyObject]) -> i64 {
    return object_size(nd) // 2;
}

impl hamt_node_collision_without(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    c_hash = collision_of(self_).view(1)[0].c_hash;
    if hash != c_hash {
        return (W_NOT_FOUND, NULL);
    }
    (found, key_idx) = hamt_node_collision_find_index(self_, key);
    if found == F_ERROR {
        return (W_ERROR, NULL);
    }
    if found == F_NOT_FOUND {
        return (W_NOT_FOUND, NULL);
    }
    new_count = hamt_node_collision_count(self_) - 1;
    if new_count == 0 {
        return (W_EMPTY, NULL);
    }
    items = collision_items(self_);
    if new_count == 1 {
        nd = hamt_node_bitmap_new(2);
        if not nd {
            return (W_ERROR, NULL);
        }
        target = bitmap_items(nd);
        if key_idx == 0 {
            target.view(1)[0] = object_new_ref((items + 2).view(1)[0]);
            (target + 1).view(1)[0] = object_new_ref((items + 3).view(1)[0]);
        } else {
            target.view(1)[0] = object_new_ref(items.view(1)[0]);
            (target + 1).view(1)[0] = object_new_ref((items + 1).view(1)[0]);
        }
        bitmap_of(nd).view(1)[0].b_bitmap = hamt_bitpos(hash, shift);
        return (W_NEWNODE, nd);
    }
    size = object_size(self_);
    new_node = hamt_node_collision_new(c_hash, size - 2);
    if not new_node {
        return (W_ERROR, NULL);
    }
    target = collision_items(new_node);
    for i in range(key_idx) {
        (target + i).view(1)[0] = object_new_ref((items + i).view(1)[0]);
    }
    j = key_idx + 2;
    while j < size {
        (target + (j - 2)).view(1)[0] = object_new_ref((items + j).view(1)[0]);
        j += 1;
    }
    return (W_NEWNODE, new_node);
}

impl hamt_node_collision_find(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    (res, idx) = hamt_node_collision_find_index(self_, key);
    if res == F_ERROR or res == F_NOT_FOUND {
        return (res, NULL);
    }
    return (F_FOUND, (collision_items(self_) + (idx + 1)).view(1)[0]);
}

impl hamt_node_collision_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    items = collision_items(op);
    i = object_size(op);
    while i > 0 {
        i -= 1;
        vret = visit_reference((items + i).view(1)[0], visitor, arg);
        if vret != i32(0) {
            return vret;
        }
    }
    return i32(0);
}

impl hamt_node_collision_dealloc(self_: ptr[PyObject]) {
    size = object_size(self_);
    PyObject_GC_UnTrack(self_);
    if size > 0 {
        items = collision_items(self_);
        while size > 0 {
            size -= 1;
            object_xdecref((items + size).view(1)[0]);
        }
    }
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl hamt_node_array_new(count: i64) -> ptr[PyObject] {
    nd = _PyObject_GC_New(ptr[PyObject](addressof(_PyHamt_ArrayNode_Type)));
    if not nd {
        return NULL;
    }
    slots = array_items(nd);
    for i in range(HAMT_ARRAY_NODE_SIZE) {
        (slots + i).view(1)[0] = NULL;
    }
    array_of(nd).view(1)[0].a_count = count;
    object_gc_track(nd);
    return nd;
}

impl hamt_node_array_clone(nd: ptr[PyObject]) -> ptr[PyObject] {
    clone = hamt_node_array_new(array_of(nd).view(1)[0].a_count);
    if not clone {
        return NULL;
    }
    source = array_items(nd);
    target = array_items(clone);
    for i in range(HAMT_ARRAY_NODE_SIZE) {
        (target + i).view(1)[0] = object_xnew_ref((source + i).view(1)[0]);
    }
    return clone;
}

impl hamt_node_array_assoc(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32] {
    idx = i64(hamt_mask(hash, shift));
    slots = array_items(self_);
    nd = (slots + idx).view(1)[0];
    if not nd {
        empty = hamt_node_bitmap_new(0);
        if not empty {
            return (NULL, i32(0));
        }
        (child_node, added) = hamt_node_bitmap_assoc(
            empty, shift + u32(5), hash, key, val
        );
        object_decref(empty);
        if not child_node {
            return (NULL, added);
        }
        new_node = hamt_node_array_new(array_of(self_).view(1)[0].a_count + 1);
        if not new_node {
            object_decref(child_node);
            return (NULL, added);
        }
        target = array_items(new_node);
        for i in range(HAMT_ARRAY_NODE_SIZE) {
            (target + i).view(1)[0] = object_xnew_ref((slots + i).view(1)[0]);
        }
        (target + idx).view(1)[0] = child_node;
        return (new_node, added);
    }
    (child, child_added) = hamt_node_assoc(nd, shift + u32(5), hash, key, val);
    if not child {
        return (NULL, child_added);
    }
    if child == self_ {
        object_decref(child);
        return (self_, child_added);
    }
    clone = hamt_node_array_clone(self_);
    if not clone {
        object_decref(child);
        return (NULL, child_added);
    }
    py_xsetref(array_items(clone) + idx, child);
    return (clone, child_added);
}

impl hamt_node_array_without(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    idx = i64(hamt_mask(hash, shift));
    slots = array_items(self_);
    nd = (slots + idx).view(1)[0];
    if not nd {
        return (W_NOT_FOUND, NULL);
    }
    (res, sub_node) = hamt_node_without(nd, shift + u32(5), hash, key);
    if res == W_NOT_FOUND or res == W_ERROR {
        return (res, NULL);
    }
    if res == W_NEWNODE {
        clone = hamt_node_array_clone(self_);
        if not clone {
            object_decref(sub_node);
            return (W_ERROR, NULL);
        }
        py_xsetref(array_items(clone) + idx, sub_node);
        return (W_NEWNODE, clone);
    }
    if res != W_EMPTY {
        return (res, NULL);
    }

    new_count = array_of(self_).view(1)[0].a_count - 1;
    if new_count == 0 {
        return (W_EMPTY, NULL);
    }
    if new_count >= 16 {
        new_array = hamt_node_array_clone(self_);
        if not new_array {
            return (W_ERROR, NULL);
        }
        array_of(new_array).view(1)[0].a_count = new_count;
        py_clear(array_items(new_array) + idx);
        return (W_NEWNODE, new_array);
    }

    bitmap: u32 = 0;
    new_bitmap = hamt_node_bitmap_new(new_count * 2);
    if not new_bitmap {
        return (W_ERROR, NULL);
    }
    target = bitmap_items(new_bitmap);
    new_i: i64 = 0;
    for i in range(HAMT_ARRAY_NODE_SIZE) {
        if i == idx {
            continue;
        }
        child = (slots + i).view(1)[0];
        if not child {
            continue;
        }
        bitmap = bitmap | (u32(1) << u32(i));
        inlined = False;
        if is_bitmap_node(child) {
            child_items = bitmap_items(child);
            if hamt_node_bitmap_count(child) == 1 and child_items.view(1)[0] {
                (target + new_i).view(1)[0] = object_new_ref(child_items.view(1)[0]);
                (target + (new_i + 1)).view(1)[0] = object_new_ref(
                    (child_items + 1).view(1)[0]
                );
                inlined = True;
            }
        }
        if not inlined {
            (target + new_i).view(1)[0] = NULL;
            (target + (new_i + 1)).view(1)[0] = object_new_ref(child);
        }
        new_i += 2;
    }
    bitmap_of(new_bitmap).view(1)[0].b_bitmap = bitmap;
    return (W_NEWNODE, new_bitmap);
}

impl hamt_node_array_find(
    self_: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    nd = (array_items(self_) + i64(hamt_mask(hash, shift))).view(1)[0];
    if not nd {
        return (F_NOT_FOUND, NULL);
    }
    return hamt_node_find(nd, shift + u32(5), hash, key);
}

impl hamt_node_array_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    slots = array_items(op);
    for i in range(HAMT_ARRAY_NODE_SIZE) {
        vret = visit_reference((slots + i).view(1)[0], visitor, arg);
        if vret != i32(0) {
            return vret;
        }
    }
    return i32(0);
}

impl hamt_node_array_dealloc(self_: ptr[PyObject]) {
    PyObject_GC_UnTrack(self_);
    slots = array_items(self_);
    for i in range(HAMT_ARRAY_NODE_SIZE) {
        object_xdecref((slots + i).view(1)[0]);
    }
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl hamt_node_assoc(
    nd: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject], val: ptr[PyObject]
) -> tuple[ptr[PyObject], i32] {
    if is_bitmap_node(nd) {
        return hamt_node_bitmap_assoc(nd, shift, hash, key, val);
    }
    if is_array_node(nd) {
        return hamt_node_array_assoc(nd, shift, hash, key, val);
    }
    return hamt_node_collision_assoc(nd, shift, hash, key, val);
}

impl hamt_node_without(
    nd: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    if is_bitmap_node(nd) {
        return hamt_node_bitmap_without(nd, shift, hash, key);
    }
    if is_array_node(nd) {
        return hamt_node_array_without(nd, shift, hash, key);
    }
    return hamt_node_collision_without(nd, shift, hash, key);
}

impl hamt_node_find(
    nd: ptr[PyObject], shift: u32, hash: i32, key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    if is_bitmap_node(nd) {
        return hamt_node_bitmap_find(nd, shift, hash, key);
    }
    if is_array_node(nd) {
        return hamt_node_array_find(nd, shift, hash, key);
    }
    return hamt_node_collision_find(nd, shift, hash, key);
}

impl iter_nodes(iter: ptr[PyHamtIteratorState]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](iter);
}

impl iter_positions(iter: ptr[PyHamtIteratorState]) -> ptr[i64] {
    return ptr[i64](ptr[u8](iter) + PyHamtIteratorState_I_POS);
}

impl hamt_iterator_init(iter: ptr[PyHamtIteratorState], top: ptr[PyObject]) {
    nodes = iter_nodes(iter);
    positions = iter_positions(iter);
    for i in range(_Py_HAMT_MAX_TREE_DEPTH) {
        (nodes + i).view(1)[0] = NULL;
        (positions + i).view(1)[0] = 0;
    }
    iter.view(1)[0].i_level = i8(0);
    nodes.view(1)[0] = top;
}

impl hamt_iterator_bitmap_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    level = iter.view(1)[0].i_level;
    nodes = iter_nodes(iter);
    positions = iter_positions(iter);
    nd = (nodes + i64(level)).view(1)[0];
    pos = (positions + i64(level)).view(1)[0];
    if pos + 1 >= object_size(nd) {
        iter.view(1)[0].i_level = level - i8(1);
        return hamt_iterator_next(iter);
    }
    items = bitmap_items(nd);
    if not (items + pos).view(1)[0] {
        (positions + i64(level)).view(1)[0] = pos + 2;
        next_level = level + i8(1);
        iter.view(1)[0].i_level = next_level;
        (positions + i64(next_level)).view(1)[0] = 0;
        (nodes + i64(next_level)).view(1)[0] = (items + (pos + 1)).view(1)[0];
        return hamt_iterator_next(iter);
    }
    key = (items + pos).view(1)[0];
    val = (items + (pos + 1)).view(1)[0];
    (positions + i64(level)).view(1)[0] = pos + 2;
    return (I_ITEM, key, val);
}

impl hamt_iterator_collision_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    level = iter.view(1)[0].i_level;
    positions = iter_positions(iter);
    nd = (iter_nodes(iter) + i64(level)).view(1)[0];
    pos = (positions + i64(level)).view(1)[0];
    if pos + 1 >= object_size(nd) {
        iter.view(1)[0].i_level = level - i8(1);
        return hamt_iterator_next(iter);
    }
    items = collision_items(nd);
    key = (items + pos).view(1)[0];
    val = (items + (pos + 1)).view(1)[0];
    (positions + i64(level)).view(1)[0] = pos + 2;
    return (I_ITEM, key, val);
}

impl hamt_iterator_array_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    level = iter.view(1)[0].i_level;
    nodes = iter_nodes(iter);
    positions = iter_positions(iter);
    nd = (nodes + i64(level)).view(1)[0];
    pos = (positions + i64(level)).view(1)[0];
    if pos >= HAMT_ARRAY_NODE_SIZE {
        iter.view(1)[0].i_level = level - i8(1);
        return hamt_iterator_next(iter);
    }
    slots = array_items(nd);
    i = pos;
    while i < HAMT_ARRAY_NODE_SIZE {
        child = (slots + i).view(1)[0];
        if child {
            (positions + i64(level)).view(1)[0] = i + 1;
            next_level = level + i8(1);
            (positions + i64(next_level)).view(1)[0] = 0;
            (nodes + i64(next_level)).view(1)[0] = child;
            iter.view(1)[0].i_level = next_level;
            return hamt_iterator_next(iter);
        }
        i += 1;
    }
    iter.view(1)[0].i_level = level - i8(1);
    return hamt_iterator_next(iter);
}

impl hamt_iterator_next(
    iter: ptr[PyHamtIteratorState]
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    level = iter.view(1)[0].i_level;
    if level < i8(0) {
        return (I_END, NULL, NULL);
    }
    current = (iter_nodes(iter) + i64(level)).view(1)[0];
    if is_bitmap_node(current) {
        return hamt_iterator_bitmap_next(iter);
    }
    if is_array_node(current) {
        return hamt_iterator_array_next(iter);
    }
    return hamt_iterator_collision_next(iter);
}

impl hamt_find(o: ptr[PyHamtObject], key: ptr[PyObject]) -> tuple[i32, ptr[PyObject]] {
    if o.view(1)[0].h_count == 0 {
        return (F_NOT_FOUND, NULL);
    }
    key_hash = hamt_hash(key);
    if key_hash == i32(-1) {
        return (F_ERROR, NULL);
    }
    return hamt_node_find(hamt_root(o), u32(0), key_hash, key);
}

impl hamt_find_value(
    o: ptr[PyHamtObject], key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    (res, val) = hamt_find(o, key);
    if res == F_ERROR {
        return (i32(-1), NULL);
    }
    if res == F_NOT_FOUND {
        return (i32(0), NULL);
    }
    return (i32(1), val);
}

impl hamt_alloc -> ptr[PyHamtObject] {
    op = _PyObject_GC_New(ptr[PyObject](addressof(_PyHamt_Type)));
    if not op {
        return ptr[PyHamtObject]();
    }
    o = hamt_of(op);
    o.view(1)[0].h_count = 0;
    o.view(1)[0].h_root = ptr[PyHamtNode]();
    o.view(1)[0].h_weakreflist = NULL;
    PyObject_GC_Track(op);
    return o;
}

impl hamt_baseiter_state(op: ptr[PyObject]) -> ptr[PyHamtIteratorState] {
    return ptr[PyHamtIteratorState](ptr[u8](op) + PyHamtIterator_HI_ITER);
}

impl hamt_baseiter_tp_clear(op: ptr[PyObject]) -> i32 {
    it = ptr[PyHamtIterator](op);
    old = ptr[PyObject](it.view(1)[0].hi_obj);
    if old {
        it.view(1)[0].hi_obj = ptr[PyHamtObject]();
        object_decref(old);
    }
    return i32(0);
}

impl hamt_baseiter_tp_dealloc(it: ptr[PyObject]) {
    PyObject_GC_UnTrack(it);
    hamt_baseiter_tp_clear(it);
    PyObject_GC_Del(it);
}

impl hamt_baseiter_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(
        ptr[PyObject](ptr[PyHamtIterator](op).view(1)[0].hi_obj), visitor, arg
    );
}

impl hamt_baseiter_tp_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    (res, key, val) = hamt_iterator_next(hamt_baseiter_state(op));
    if res == I_END {
        PyErr_SetNone(PyExc_StopIteration);
        return NULL;
    }
    return ptr[PyHamtIterator](op).view(1)[0].hi_yield(key, val);
}

impl hamt_baseiter_tp_len(op: ptr[PyObject]) -> i64 {
    return ptr[PyHamtIterator](op).view(1)[0].hi_obj.view(1)[0].h_count;
}

impl hamt_baseiter_new(
    type: ptr[PyTypeObject], yield_fn: int, o: ptr[PyHamtObject]
) -> ptr[PyObject] {
    op = _PyObject_GC_New(ptr[PyObject](type));
    if not op {
        return NULL;
    }
    it = ptr[PyHamtIterator](op);
    it.view(1)[0].hi_obj = ptr[PyHamtObject](object_new_ref(ptr[PyObject](o)));
    it.view(1)[0].hi_yield = yield_fn;
    hamt_iterator_init(hamt_baseiter_state(op), hamt_root(o));
    return op;
}

impl hamt_iter_yield_items(key: ptr[PyObject], val: ptr[PyObject]) -> ptr[PyObject] {
    return PyTuple_Pack(2, key, val);
}

impl hamt_iter_yield_keys(key: ptr[PyObject], val: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(key);
}

impl hamt_iter_yield_values(key: ptr[PyObject], val: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(val);
}

impl hamt_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return ptr[PyObject](_PyHamt_New());
}

impl hamt_tp_clear(op: ptr[PyObject]) -> i32 {
    self_ = hamt_of(op);
    old = hamt_root(self_);
    if old {
        self_.view(1)[0].h_root = ptr[PyHamtNode]();
        object_decref(old);
    }
    return i32(0);
}

impl hamt_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(hamt_root(hamt_of(op)), visitor, arg);
}

impl hamt_tp_dealloc(self_: ptr[PyObject]) {
    o = hamt_of(self_);
    if o == empty_hamt() {
        return;
    }
    PyObject_GC_UnTrack(self_);
    if o.view(1)[0].h_weakreflist {
        PyObject_ClearWeakRefs(self_);
    }
    hamt_tp_clear(self_);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl hamt_tp_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not object_is_type(v, addressof(_PyHamt_Type))
        or not object_is_type(w, addressof(_PyHamt_Type))
        or (op != Py_EQ and op != Py_NE) {
        return object_new_ref(Py_NotImplemented);
    }
    res = _PyHamt_Eq(hamt_of(v), hamt_of(w));
    if res < 0 {
        return NULL;
    }
    if op == Py_NE {
        if res != 0 {
            res = i32(0);
        } else {
            res = i32(1);
        }
    }
    return PyBool_FromLong(i64(res));
}

impl hamt_tp_contains(op: ptr[PyObject], key: ptr[PyObject]) -> i32 {
    (res, _val) = hamt_find_value(hamt_of(op), key);
    return res;
}

impl hamt_tp_subscript(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    (res, val) = hamt_find(hamt_of(op), key);
    if res == F_ERROR {
        return NULL;
    }
    if res == F_FOUND {
        return object_new_ref(val);
    }
    PyErr_SetObject(PyExc_KeyError, key);
    return NULL;
}

impl hamt_tp_len(op: ptr[PyObject]) -> i64 {
    return _PyHamt_Len(hamt_of(op));
}

impl hamt_tp_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    return _PyHamt_NewIterKeys(hamt_of(op));
}

impl hamt_py_set(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    key = NULL;
    val = NULL;
    if PyArg_UnpackTuple(args, "set", 2, 2, &mut key, &mut val) == 0 {
        return NULL;
    }
    return ptr[PyObject](_PyHamt_Assoc(hamt_of(op), key, val));
}

impl hamt_py_get(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    key = NULL;
    dflt = NULL;
    if PyArg_UnpackTuple(args, "get", 1, 2, &mut key, &mut dflt) == 0 {
        return NULL;
    }
    (res, val) = hamt_find(hamt_of(op), key);
    if res == F_ERROR {
        return NULL;
    }
    if res == F_FOUND {
        return object_new_ref(val);
    }
    if not dflt {
        return object_new_ref(Py_None);
    }
    return object_new_ref(dflt);
}

impl hamt_py_delete(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](_PyHamt_Without(hamt_of(op), key));
}

impl hamt_py_items(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _PyHamt_NewIterItems(hamt_of(op));
}

impl hamt_py_values(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _PyHamt_NewIterValues(hamt_of(op));
}

impl hamt_py_keys(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _PyHamt_NewIterKeys(hamt_of(op));
}
