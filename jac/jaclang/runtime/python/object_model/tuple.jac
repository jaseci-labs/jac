import from c {
    glob PyType_Type: PyTypeObject; def _PyEval_SliceIndexNotNone(
        arg0: ptr[PyObject], arg1: &mut i64
    ) -> i32;  def _PyObject_GC_Resize(
        arg0: ptr[PyObject], arg1: i64
    ) -> ptr[PyObject];  def _Py_NewReferenceNoTotal(op: ptr[PyObject]);  def _PyDebugAllocatorStats(
        out: ptr, block_name: str, num_blocks: i32, sizeof_block: u64
    );  obj RefTracerCall {
        has call: Callable[[ptr[PyObject], i32, ptr], i32] = 0;
    }  glob:priv tuple_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=tuple_length,
             sq_concat=tuple_concat,
             sq_repeat=tuple_repeat,
             sq_item=tuple_item,
             sq_contains=tuple_contains
         ),
         tuple_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=tuple_length, mp_subscript=tuple_subscript
         ),
         tuple_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__getnewargs__"),
                 ml_meth=ptr(tuple___getnewargs__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__getnewargs__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("index"),
                 ml_meth=ptr(tuple_index),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "index($self, value, start=0, stop=sys.maxsize, /)\n--\n\n"
                     "Return first index of value.\n\n"
                     "Raises ValueError if the value is not present."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("count"),
                 ml_meth=ptr(tuple_count),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "count($self, value, /)\n--\n\nReturn number of occurrences of value."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "Tuples are generic over the types of their contents.\n\n"
                     "For example, use ``tuple[int, str]`` for a pair whose first element is an int and second element is a string.\n\n"
                     "Tuples also support the form ``tuple[T, ...]`` to indicate an arbitrary length tuple of elements of type T."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         tupleiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(tupleiter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(tupleiter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(tupleiter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyTuple_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("tuple"),
             tp_basicsize=PyTupleObject_ITEMS,
             tp_itemsize=8,
             tp_dealloc=tuple_dealloc,
             tp_repr=tuple_repr,
             tp_as_sequence=addressof(tuple_as_sequence),
             tp_as_mapping=addressof(tuple_as_mapping),
             tp_hash=tuple_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_TUPLE_SUBCLASS
                 | _Py_TPFLAGS_MATCH_SELF
                 | Py_TPFLAGS_SEQUENCE,
             tp_doc=ptr[u8](
                 "tuple(iterable=(), /)\n--\n\n"
                 "Built-in immutable sequence.\n\n"
                 "If no argument is given, the constructor returns an empty tuple.\n"
                 "If iterable is specified the tuple is initialized from iterable's items.\n\n"
                 "If the argument is a tuple, the return value is the same object."
             ),
             tp_traverse=tuple_traverse,
             tp_richcompare=tuple_richcompare,
             tp_iter=tuple_iter,
             tp_methods=addressof(tuple_methods),
             tp_new=tuple_new,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=tuple_vectorcall,
             tp_version_tag=_Py_TYPE_VERSION_TUPLE
         ),
         PyTupleIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("tuple_iterator"),
             tp_basicsize=_PyTupleIterObject_SIZE,
             tp_dealloc=tupleiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=tupleiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=tupleiter_next,
             tp_methods=addressof(tupleiter_methods)
         );
}

glob:priv XXPRIME_1: u64 = u64(0x9E3779B185EBCA87),
     XXPRIME_2: u64 = u64(0xC2B2AE3D27D4EB4F),
     XXPRIME_5: u64 = u64(0x27D4EB2F165667C5),
     PYREFTRACER_DESTROY: i32 = 1,
     PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF;

def tuple_of(op: ptr[PyObject]) -> ptr[PyTupleObject];

def tupleiter_of(op: ptr[PyObject]) -> ptr[_PyTupleIterObject];

def tuple_check(op: ptr[PyObject]) -> bool;

def tuple_check_exact(op: ptr[PyObject]) -> bool;

def reset_hash_cache(op: ptr[PyObject]);

def tuple_get_empty -> ptr[PyObject];

def freelist_offset(index: i64) -> i64;

def maybe_tracked(ob: ptr[PyObject]) -> bool;

def gc_may_be_tracked(ob: ptr[PyObject]) -> bool;

def reftracer_track(op: ptr[PyObject], operation: i32);

def tuple_alloc(size: i64) -> ptr[PyObject];

def freelist_size(index: i64) -> i64;

def maybe_freelist_push(op: ptr[PyObject]) -> bool;

import from c {
    def PyTuple_New(size: i64) -> ptr[PyObject] {
        if size == 0 {
            return tuple_get_empty();
        }
        op = tuple_alloc(size);
        if not op {
            return NULL;
        }
        items = tuple_items(op);
        for i in range(size) {
            (items + i).view(1)[0] = NULL;
        }
        object_gc_track(op);
        return op;
    }  def PyTuple_Size(op: ptr[PyObject]) -> i64 {
        if not tuple_check(op) {
            PyErr_BadInternalCall();
            return -1;
        }
        return object_size(op);
    }  def PyTuple_GetItem(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
        if not tuple_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        if i < 0 or i >= object_size(op) {
            PyErr_SetString(PyExc_IndexError, "tuple index out of range");
            return NULL;
        }
        return tuple_get_item(op, i);
    }  def PyTuple_SetItem(op: ptr[PyObject], i: i64, newitem: ptr[PyObject]) -> i32 {
        if not tuple_check(op) or object_refcount(op) != 1 {
            object_xdecref(newitem);
            PyErr_BadInternalCall();
            return i32(-1);
        }
        if i < 0 or i >= object_size(op) {
            object_xdecref(newitem);
            PyErr_SetString(PyExc_IndexError, "tuple assignment index out of range");
            return i32(-1);
        }
        slot = tuple_items(op) + i;
        old = slot.view(1)[0];
        slot.view(1)[0] = newitem;
        object_xdecref(old);
        return i32(0);
    }  def _PyTuple_MaybeUntrack(op: ptr[PyObject]) {
        if not tuple_check_exact(op) or not object_gc_is_tracked(op) {
            return;
        }
        items = tuple_items(op);
        for i in range(object_size(op)) {
            elt = (items + i).view(1)[0];

            if not elt or gc_may_be_tracked(elt) {
                return;
            }
        }
        object_gc_untrack(op);
    }  def PyTuple_Pack(n: i64, *args: VaList) -> ptr[PyObject] {
        if n == 0 {
            return tuple_get_empty();
        }
        result = tuple_alloc(n);
        if not result {
            return NULL;
        }
        items = tuple_items(result);
        track = False;
        for i in range(n) {
            o = args.arg(ptr[PyObject]);
            if not track and maybe_tracked(o) {
                track = True;
            }
            (items + i).view(1)[0] = object_new_ref(o);
        }
        if track {
            object_gc_track(result);
        }
        return result;
    }  def _PyTuple_FromArray(src: ptr[ptr[PyObject]], n: i64) -> ptr[PyObject] {
        if n == 0 {
            return tuple_get_empty();
        }
        tuple = tuple_alloc(n);
        if not tuple {
            return NULL;
        }
        dst = tuple_items(tuple);
        track = False;
        for i in range(n) {
            item = (src + i).view(1)[0];
            if not track and maybe_tracked(item) {
                track = True;
            }
            (dst + i).view(1)[0] = object_new_ref(item);
        }
        if track {
            object_gc_track(tuple);
        }
        return tuple;
    }  def _PyTuple_FromStackRefStealOnSuccess(src: ptr[u64], n: i64) -> ptr[PyObject] {
        if n == 0 {
            return tuple_get_empty();
        }
        tuple = tuple_alloc(n);
        if not tuple {
            return NULL;
        }
        dst = tuple_items(tuple);
        track = False;
        for i in range(n) {
            bits = (src + i).view(1)[0];
            item = ptr[PyObject](i64.wrap(bits & u64(0xFFFFFFFFFFFFFFFE)));
            if (bits & u64(1)) != u64(0) {
                object_incref(item);
            }
            if not track and maybe_tracked(item) {
                track = True;
            }
            (dst + i).view(1)[0] = item;
        }
        if track {
            object_gc_track(tuple);
        }
        return tuple;
    }  def _PyTuple_FromArraySteal(src: ptr[ptr[PyObject]], n: i64) -> ptr[PyObject] {
        if n == 0 {
            return tuple_get_empty();
        }
        tuple = tuple_alloc(n);
        if not tuple {
            for i in range(n) {
                object_decref((src + i).view(1)[0]);
            }
            return NULL;
        }
        dst = tuple_items(tuple);
        for i in range(n) {
            (dst + i).view(1)[0] = (src + i).view(1)[0];
        }
        object_gc_track(tuple);
        return tuple;
    }  def PyTuple_GetSlice(op: ptr[PyObject], i: i64, j: i64) -> ptr[PyObject] {
        if not op or not tuple_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return tuple_slice(op, i, j);
    }  def _PyTuple_Resize(pv: ptr[ptr[PyObject]], newsize: i64) -> i32 {
        v = pv.view(1)[0];
        if not v
            or not object_is_type(v, addressof(PyTuple_Type))
            or (object_size(v) != 0 and object_refcount(v) != 1) {
            pv.view(1)[0] = NULL;
            object_xdecref(v);
            PyErr_BadInternalCall();
            return i32(-1);
        }
        oldsize = object_size(v);
        if oldsize == newsize {
            return i32(0);
        }
        if newsize == 0 {
            object_decref(v);
            pv.view(1)[0] = tuple_get_empty();
            return i32(0);
        }
        if oldsize == 0 {
            object_decref(v);
            pv.view(1)[0] = PyTuple_New(newsize);
            return i32(-1) if not pv.view(1)[0] else i32(0);
        }
        if object_gc_is_tracked(v) {
            object_gc_untrack(v);
        }
        items = tuple_items(v);
        for i in range(newsize, oldsize) {
            item = (items + i).view(1)[0];
            (items + i).view(1)[0] = NULL;
            object_xdecref(item);
        }
        reftracer_track(v, PYREFTRACER_DESTROY);
        sv = _PyObject_GC_Resize(v, newsize);
        if not sv {
            pv.view(1)[0] = NULL;
            PyObject_GC_Del(ptr(v));
            return i32(-1);
        }
        _Py_NewReferenceNoTotal(sv);
        if newsize > oldsize {
            grown = tuple_items(sv);
            for i in range(oldsize, newsize) {
                (grown + i).view(1)[0] = NULL;
            }
        }
        pv.view(1)[0] = sv;
        object_gc_track(sv);
        return i32(0);
    }  def _PyTuple_DebugMallocStats(out: ptr) {
        for i in range(PyTuple_MAXSAVESIZE) {
            length = i + 1;
            _PyDebugAllocatorStats(
                out,
                f"free {length}-sized PyTupleObject",
                i32(freelist_size(i)),
                u64(PyTupleObject_ITEMS + length * 8)
            );
        }
    }
}

def tuple_dealloc(op: ptr[PyObject]);

def tuple_repr(op: ptr[PyObject]) -> ptr[PyObject];

def tuple_hash(op: ptr[PyObject]) -> i64;

def tuple_length(op: ptr[PyObject]) -> i64;

def tuple_contains(op: ptr[PyObject], el: ptr[PyObject]) -> i32;

def tuple_item(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def tuple_slice(a: ptr[PyObject], ilow: i64, ihigh: i64) -> ptr[PyObject];

def tuple_concat(aa: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject];

def tuple_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def tuple_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def tuple_count(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def tuple_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def tuple_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def tuple_new_impl(type: ptr[PyTypeObject], iterable: ptr[PyObject]) -> ptr[PyObject];

def tuple_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def tuple_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def tuple_subtype_new(
    type: ptr[PyTypeObject], iterable: ptr[PyObject]
) -> ptr[PyObject];

def tuple_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def tuple___getnewargs__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def tuple_iter(seq: ptr[PyObject]) -> ptr[PyObject];

def tupleiter_dealloc(op: ptr[PyObject]);

def tupleiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def tupleiter_next(op: ptr[PyObject]) -> ptr[PyObject];

def tupleiter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def tupleiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def tupleiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

impl tuple_of(op: ptr[PyObject]) -> ptr[PyTupleObject] {
    return ptr[PyTupleObject](op);
}

impl tupleiter_of(op: ptr[PyObject]) -> ptr[_PyTupleIterObject] {
    return ptr[_PyTupleIterObject](op);
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl tuple_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyTuple_Type));
}

impl reset_hash_cache(op: ptr[PyObject]) {
    tuple_of(op).view(1)[0].ob_hash = -1;
}

impl tuple_get_empty -> ptr[PyObject] {
    return ptr[PyObject](int(addressof(_PyRuntime)) + _PyRuntimeState_TUPLE_EMPTY);
}

impl freelist_offset(index: i64) -> i64 {
    return _Py_freelists_TUPLES + index * _Py_freelist_SIZE;
}

impl maybe_tracked(ob: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(ob), Py_TPFLAGS_HAVE_GC);
}

impl gc_may_be_tracked(ob: ptr[PyObject]) -> bool {
    type = object_type(ob);
    if not type_has_feature(type, Py_TPFLAGS_HAVE_GC) {
        return False;
    }
    if int(type.view(1)[0].tp_is_gc) != 0 and type.view(1)[0].tp_is_gc(ob) == 0 {
        return False;
    }
    return not tuple_check_exact(ob) or object_gc_is_tracked(ob);
}

impl reftracer_track(op: ptr[PyObject], operation: i32) {
    runtime = int(addressof(_PyRuntime));
    tracer = ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_FUNC).view(1)[0];
    if not tracer {
        return;
    }
    data = ptr[ptr](runtime + _PyRuntimeState_REF_TRACER_DATA).view(1)[0];
    slot = ptr[RefTracerCall](
        __thread_local_block("jac_object_model_tuple_tracer_slot", 8)
    );
    slot.view(1)[0].call = int(tracer);
    slot.view(1)[0].call(op, operation, data);
}

impl tuple_alloc(size: i64) -> ptr[PyObject] {
    if size < 0 {
        PyErr_BadInternalCall();
        return NULL;
    }
    index = size - 1;
    if index < PyTuple_MAXSAVESIZE {
        op = freelist_pop(freelist_offset(index));
        if op {
            reset_hash_cache(op);
            return op;
        }
    }
    if size > (PY_SSIZE_T_MAX - (PY_TUPLE_OBJECT_SIZE - 8)) // 8 {
        return PyErr_NoMemory();
    }
    result = _PyObject_GC_NewVar(ptr[PyObject](addressof(PyTuple_Type)), size);
    if result {
        reset_hash_cache(result);
    }
    return result;
}

impl freelist_size(index: i64) -> i64 {
    return freelist(freelist_offset(index)).view(1)[0].size;
}

impl maybe_freelist_push(op: ptr[PyObject]) -> bool {
    if not tuple_check_exact(op) {
        return False;
    }
    index = object_size(op) - 1;
    if index < PyTuple_MAXSAVESIZE {
        return freelist_push(freelist_offset(index), op, Py_tuple_MAXFREELIST);
    }
    return False;
}

impl tuple_dealloc(op: ptr[PyObject]) {
    if object_size(op) == 0 and op == tuple_get_empty() {
        return;
    }
    PyObject_GC_UnTrack(ptr(op));
    items = tuple_items(op);
    i = object_size(op);
    while i > 0 {
        i -= 1;
        object_xdecref((items + i).view(1)[0]);
    }
    if not maybe_freelist_push(op) {
        object_type(op).view(1)[0].tp_free(ptr(op));
    }
}

impl tuple_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    n = object_size(op);
    if n == 0 {
        return PyUnicode_FromString(ptr[u8]("()"));
    }

    res = Py_ReprEnter(op);
    if res != 0 {
        return PyUnicode_FromString(ptr[u8]("(...)")) if res > 0 else NULL;
    }

    prealloc = 1 + 1 + (2 + 1) * (n - 1) + 1 if n > 1 else 4;
    writer = PyUnicodeWriter_Create(prealloc);
    if writer {
        ok = PyUnicodeWriter_WriteChar(writer, 40) >= 0;
        items = tuple_items(op);
        i = 0;
        while ok and i < n {
            if i > 0 {
                ok = PyUnicodeWriter_WriteChar(writer, 44) >= 0
                    and PyUnicodeWriter_WriteChar(writer, 32) >= 0;
            }
            if ok {
                ok = PyUnicodeWriter_WriteRepr(writer, (items + i).view(1)[0]) >= 0;
            }
            i += 1;
        }
        if ok and n == 1 {
            ok = PyUnicodeWriter_WriteChar(writer, 44) >= 0;
        }
        if ok and PyUnicodeWriter_WriteChar(writer, 41) >= 0 {
            Py_ReprLeave(op);
            return PyUnicodeWriter_Finish(writer);
        }
    }
    PyUnicodeWriter_Discard(writer);
    Py_ReprLeave(op);
    return NULL;
}

impl tuple_hash(op: ptr[PyObject]) -> i64 {
    t = tuple_of(op);
    cached = t.view(1)[0].ob_hash;
    if cached != -1 {
        return cached;
    }
    length = object_size(op);
    items = tuple_items(op);
    acc = XXPRIME_5;
    for i in range(length) {
        lane = PyObject_Hash((items + i).view(1)[0]);
        if lane == -1 {
            return -1;
        }
        acc = wrapping_add(acc, wrapping_mul(u64.wrap(lane), XXPRIME_2));
        acc = wrapping_shl(acc, u64(31)) | (acc >> u64(33));
        acc = wrapping_mul(acc, XXPRIME_1);
    }
    acc = wrapping_add(acc, u64.wrap(length) ^ (XXPRIME_5 ^ u64(3527539)));
    if acc == u64(0xFFFFFFFFFFFFFFFF) {
        acc = u64(1546275796);
    }
    result = i64.wrap(acc);
    t.view(1)[0].ob_hash = result;
    return result;
}

impl tuple_length(op: ptr[PyObject]) -> i64 {
    return object_size(op);
}

impl tuple_contains(op: ptr[PyObject], el: ptr[PyObject]) -> i32 {
    items = tuple_items(op);
    cmp = i32(0);
    i = 0;
    while cmp == 0 and i < object_size(op) {
        cmp = PyObject_RichCompareBool((items + i).view(1)[0], el, Py_EQ);
        i += 1;
    }
    return cmp;
}

impl tuple_item(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    if i < 0 or i >= object_size(op) {
        PyErr_SetString(PyExc_IndexError, "tuple index out of range");
        return NULL;
    }
    return object_new_ref(tuple_get_item(op, i));
}

impl tuple_slice(a: ptr[PyObject], ilow: i64, ihigh: i64) -> ptr[PyObject] {
    low = ilow;
    high = ihigh;
    size = object_size(a);
    if low < 0 {
        low = 0;
    }
    if high > size {
        high = size;
    }
    if high < low {
        high = low;
    }
    if low == 0 and high == size and tuple_check_exact(a) {
        return object_new_ref(a);
    }
    return _PyTuple_FromArray(tuple_items(a) + low, high - low);
}

impl tuple_concat(aa: ptr[PyObject], bb: ptr[PyObject]) -> ptr[PyObject] {
    if object_size(aa) == 0 and tuple_check_exact(bb) {
        return object_new_ref(bb);
    }
    if not tuple_check(bb) {
        PyErr_Format(
            PyExc_TypeError,
            "can only concatenate tuple (not \"%.200s\") to tuple",
            object_type(bb).view(1)[0].tp_name
        );
        return NULL;
    }
    if object_size(bb) == 0 and tuple_check_exact(aa) {
        return object_new_ref(aa);
    }
    size_a = object_size(aa);
    size_b = object_size(bb);
    size = size_a + size_b;
    if size == 0 {
        return tuple_get_empty();
    }
    np = tuple_alloc(size);
    if not np {
        return NULL;
    }
    dest = tuple_items(np);
    src = tuple_items(aa);
    for i in range(size_a) {
        (dest + i).view(1)[0] = object_new_ref((src + i).view(1)[0]);
    }
    src = tuple_items(bb);
    for i in range(size_b) {
        (dest + size_a + i).view(1)[0] = object_new_ref((src + i).view(1)[0]);
    }
    object_gc_track(np);
    return np;
}

impl tuple_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    input_size = object_size(op);
    if input_size == 0 or n == 1 {
        if tuple_check_exact(op) {
            return object_new_ref(op);
        }
    }
    if input_size == 0 or n <= 0 {
        return tuple_get_empty();
    }
    if input_size > PY_SSIZE_T_MAX // n {
        return PyErr_NoMemory();
    }
    output_size = input_size * n;
    np = tuple_alloc(output_size);
    if not np {
        return NULL;
    }
    dest = tuple_items(np);
    src = tuple_items(op);
    if input_size == 1 {
        elem = src.view(1)[0];
        refcnt_add(elem, n);
        for i in range(output_size) {
            (dest + i).view(1)[0] = elem;
        }
    } else {
        for i in range(input_size) {
            item = (src + i).view(1)[0];
            refcnt_add(item, n);
            (dest + i).view(1)[0] = item;
        }
        copied = input_size;
        while copied < output_size {
            chunk = min(copied, output_size - copied);
            jacpy_memory_copy(ptr(dest + copied), ptr(dest), chunk * 8);
            copied += chunk;
        }
    }
    object_gc_track(np);
    return np;
}

impl tuple_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional(ptr[u8]("index"), nargs, 1, 3) == 0 {
        return NULL;
    }
    value = args.view(1)[0];
    start: i64 = 0;
    stop: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2
        and _PyEval_SliceIndexNotNone((args + 1).view(1)[0], &mut start) == 0 {
        return NULL;
    }
    if nargs >= 3
        and _PyEval_SliceIndexNotNone((args + 2).view(1)[0], &mut stop) == 0 {
        return NULL;
    }
    size = object_size(op);
    if start < 0 {
        start += size;
        if start < 0 {
            start = 0;
        }
    }
    if stop < 0 {
        stop += size;
    } elif stop > size {
        stop = size;
    }
    items = tuple_items(op);
    i = start;
    while i < stop {
        cmp = PyObject_RichCompareBool((items + i).view(1)[0], value, Py_EQ);
        if cmp > 0 {
            return PyLong_FromSsize_t(i);
        }
        if cmp < 0 {
            return NULL;
        }
        i += 1;
    }
    PyErr_SetString(PyExc_ValueError, "tuple.index(x): x not in tuple");
    return NULL;
}

impl tuple_count(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    count: i64 = 0;
    items = tuple_items(op);
    for i in range(object_size(op)) {
        cmp = PyObject_RichCompareBool((items + i).view(1)[0], value, Py_EQ);
        if cmp > 0 {
            count += 1;
        } elif cmp < 0 {
            return NULL;
        }
    }
    return PyLong_FromSsize_t(count);
}

impl tuple_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    items = tuple_items(op);
    i = object_size(op);
    while i > 0 {
        i -= 1;
        status = visit_reference((items + i).view(1)[0], visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

impl tuple_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not tuple_check(v) or not tuple_check(w) {
        return object_new_ref(Py_NotImplemented);
    }
    vlen = object_size(v);
    wlen = object_size(w);
    vitems = tuple_items(v);
    witems = tuple_items(w);

    i = 0;
    while i < vlen and i < wlen {
        k = PyObject_RichCompareBool(
            (vitems + i).view(1)[0], (witems + i).view(1)[0], Py_EQ
        );
        if k < 0 {
            return NULL;
        }
        if k == 0 {
            break;
        }
        i += 1;
    }
    if i >= vlen or i >= wlen {
        return rich_compare_values(vlen, wlen, op);
    }
    if op == Py_EQ {
        return object_new_ref(py_false());
    }
    if op == Py_NE {
        return object_new_ref(py_true());
    }
    return PyObject_RichCompare((vitems + i).view(1)[0], (witems + i).view(1)[0], op);
}

impl tuple_new_impl(type: ptr[PyTypeObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
    if type != addressof(PyTuple_Type) {
        return tuple_subtype_new(type, iterable);
    }
    if not iterable {
        return tuple_get_empty();
    }
    return PySequence_Tuple(iterable);
}

impl tuple_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    base = addressof(PyTuple_Type);
    if (type == base or int(type.view(1)[0].tp_init) == int(base.view(1)[0].tp_init))
        and kwargs
        and _PyArg_NoKeywords(ptr[u8]("tuple"), kwargs) == 0 {
        return NULL;
    }
    nargs = object_size(args);
    if nargs > 1 and _PyArg_CheckPositional(ptr[u8]("tuple"), nargs, 0, 1) == 0 {
        return NULL;
    }
    iterable = tuple_get_item(args, 0) if nargs >= 1 else NULL;
    return tuple_new_impl(type, iterable);
}

impl tuple_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames and _PyArg_NoKwnames(ptr[u8]("tuple"), kwnames) == 0 {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if nargs > 1 and _PyArg_CheckPositional(ptr[u8]("tuple"), nargs, 0, 1) == 0 {
        return NULL;
    }
    if nargs != 0 {
        return tuple_new_impl(ptr[PyTypeObject](type), args.view(1)[0]);
    }
    return tuple_get_empty();
}

impl tuple_subtype_new(
    type: ptr[PyTypeObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    tmp = tuple_new_impl(addressof(PyTuple_Type), iterable);
    if not tmp {
        return NULL;
    }
    n = object_size(tmp);

    newobj = type.view(1)[0].tp_alloc(type, n);
    if not newobj {
        object_decref(tmp);
        return NULL;
    }
    for i in range(n) {
        tuple_set_item(newobj, i, object_new_ref(tuple_get_item(tmp, i)));
    }
    object_decref(tmp);
    reset_hash_cache(newobj);

    if not object_gc_is_tracked(newobj) {
        object_gc_track(newobj);
    }
    return newobj;
}

impl tuple_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        if i < 0 {
            i += object_size(op);
        }
        return tuple_item(op, i);
    }
    if not object_is_type(item, ptr[PyTypeObject](addressof(PySlice_Type))) {
        PyErr_Format(
            PyExc_TypeError,
            "tuple indices must be integers or slices, not %.200s",
            object_type(item).view(1)[0].tp_name
        );
        return NULL;
    }
    start: i64 = 0;
    stop: i64 = 0;
    step: i64 = 0;
    if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < 0 {
        return NULL;
    }
    slicelength = PySlice_AdjustIndices(object_size(op), &mut start, &mut stop, step);
    if slicelength <= 0 {
        return tuple_get_empty();
    }
    if start == 0
        and step == 1
        and slicelength == object_size(op)
        and tuple_check_exact(op) {
        return object_new_ref(op);
    }
    result = tuple_alloc(slicelength);
    if not result {
        return NULL;
    }
    src = tuple_items(op);
    dest = tuple_items(result);
    cur = start;
    for i in range(slicelength) {
        (dest + i).view(1)[0] = object_new_ref((src + cur).view(1)[0]);
        cur = wrapping_add(cur, step);
    }
    object_gc_track(result);
    return result;
}

impl tuple___getnewargs__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue(ptr[u8]("(N)"), tuple_slice(op, 0, object_size(op)));
}

impl tuple_iter(seq: ptr[PyObject]) -> ptr[PyObject] {
    if not tuple_check(seq) {
        PyErr_BadInternalCall();
        return NULL;
    }
    op = freelist_pop(_Py_freelists_TUPLE_ITERS);
    if not op {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyTupleIter_Type)));
        if not op {
            return NULL;
        }
    }
    it = tupleiter_of(op);
    it.view(1)[0].it_index = 0;
    it.view(1)[0].it_seq = ptr[PyTupleObject](object_new_ref(seq));
    object_gc_track(op);
    return op;
}

impl tupleiter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(ptr[PyObject](tupleiter_of(op).view(1)[0].it_seq));
    if not freelist_push(_Py_freelists_TUPLE_ITERS, op, Py_tuple_iters_MAXFREELIST) {
        PyObject_GC_Del(ptr(op));
    }
}

impl tupleiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(
        ptr[PyObject](tupleiter_of(op).view(1)[0].it_seq), visitor, arg
    );
}

impl tupleiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = tupleiter_of(op);
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    if not seq {
        return NULL;
    }
    index = it.view(1)[0].it_index;
    if index < object_size(seq) {
        it.view(1)[0].it_index = index + 1;
        return object_new_ref(tuple_get_item(seq, index));
    }
    it.view(1)[0].it_seq = ptr[PyTupleObject]();
    object_decref(seq);
    return NULL;
}

impl tupleiter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    it = tupleiter_of(op);
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    length: i64 = 0;
    if seq {
        length = object_size(seq) - it.view(1)[0].it_index;
    }
    return PyLong_FromSsize_t(length);
}

impl tupleiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    iter = eval_builtin("iter");
    it = tupleiter_of(op);
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    if seq {
        return Py_BuildValue(ptr[u8]("N(O)n"), iter, seq, it.view(1)[0].it_index);
    }
    return Py_BuildValue(ptr[u8]("N(())"), iter);
}

impl tupleiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    it = tupleiter_of(op);
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    if seq {
        if index < 0 {
            index = 0;
        } elif index > object_size(seq) {
            index = object_size(seq);
        }
        it.view(1)[0].it_index = index;
    }
    return object_new_ref(Py_None);
}
