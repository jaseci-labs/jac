import from c {
    glob PyType_Type: PyTypeObject,
         PyDictKeys_Type: PyTypeObject,
         PyDictValues_Type: PyTypeObject,
         PyDictItems_Type: PyTypeObject; def _PyEval_SliceIndexNotNone(
        arg0: ptr[PyObject], arg1: &mut i64
    ) -> i32;  def _PySet_NextEntryRef(
        set: ptr[PyObject], pos: &mut i64, key: &mut ptr[PyObject], hash: &mut i64
    ) -> i32;  def _PyTuple_FromArraySteal(
        src: ptr[ptr[PyObject]], n: i64
    ) -> ptr[PyObject];  def _PyDebugAllocatorStats(
        out: ptr, block_name: str, num_blocks: i32, sizeof_block: u64
    );  def memcmp(left: ptr, right: ptr, size: u64) -> i32;  glob:priv list_as_sequence:
             PySequenceMethods = PySequenceMethods(
             sq_length=list_length,
             sq_concat=list_concat,
             sq_repeat=list_repeat,
             sq_item=list_item,
             sq_ass_item=list_ass_item,
             sq_contains=list_contains,
             sq_inplace_concat=list_inplace_concat,
             sq_inplace_repeat=list_inplace_repeat
         ),
         list_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=list_length,
             mp_subscript=list_subscript,
             mp_ass_subscript=list_ass_subscript
         ),
         list_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__getitem__"),
                 ml_meth=ptr(list_subscript),
                 ml_flags=METH_O | METH_COEXIST,
                 ml_doc=ptr[u8](
                     "__getitem__($self, index, /)\n--\n\nReturn self[index]."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(list___reversed__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__reversed__($self, /)\n--\n\nReturn a reverse iterator over the list."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(list___sizeof__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__sizeof__($self, /)\n--\n\nReturn the size of the list in memory, in bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("clear"),
                 ml_meth=ptr(py_list_clear),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("clear($self, /)\n--\n\nRemove all items from list.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(list_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "copy($self, /)\n--\n\nReturn a shallow copy of the list."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("append"),
                 ml_meth=ptr(list_append),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "append($self, object, /)\n--\n\nAppend object to the end of the list."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("insert"),
                 ml_meth=ptr(list_insert),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "insert($self, index, object, /)\n--\n\nInsert object before index."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("extend"),
                 ml_meth=ptr(list_extend),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "extend($self, iterable, /)\n--\n\n"
                     "Extend list by appending elements from the iterable."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("pop"),
                 ml_meth=ptr(list_pop),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "pop($self, index=-1, /)\n--\n\n"
                     "Remove and return item at index (default last).\n\n"
                     "Raises IndexError if list is empty or index is out of range."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("remove"),
                 ml_meth=ptr(list_remove),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "remove($self, value, /)\n--\n\n"
                     "Remove first occurrence of value.\n\n"
                     "Raises ValueError if the value is not present."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("index"),
                 ml_meth=ptr(list_index),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "index($self, value, start=0, stop=sys.maxsize, /)\n--\n\n"
                     "Return first index of value.\n\n"
                     "Raises ValueError if the value is not present."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("count"),
                 ml_meth=ptr(list_count),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "count($self, value, /)\n--\n\nReturn number of occurrences of value."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("reverse"),
                 ml_meth=ptr(list_reverse),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("reverse($self, /)\n--\n\nReverse *IN PLACE*.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("sort"),
                 ml_meth=ptr(list_sort),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "sort($self, /, *, key=None, reverse=False)\n--\n\n"
                     "Sort the list in ascending order and return None.\n\n"
                     "The sort is in-place (i.e. the list itself is modified) and stable\n"
                     "(i.e. the order of two equal elements is maintained).\n\n"
                     "If a key function is given, apply it once to each list item and sort\n"
                     "them, ascending or descending, according to their function values.\n\n"
                     "The reverse flag can be set to sort in descending order."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8]("lists are generic over the type of their contents")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         listiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(listiter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(listiter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(listiter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         listreviter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(listreviter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(listreviter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(listreviter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyList_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("list"),
             tp_basicsize=PyListObject_SIZE,
             tp_dealloc=list_dealloc,
             tp_repr=list_repr,
             tp_as_sequence=addressof(list_as_sequence),
             tp_as_mapping=addressof(list_as_mapping),
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_LIST_SUBCLASS
                 | _Py_TPFLAGS_MATCH_SELF
                 | Py_TPFLAGS_SEQUENCE,
             tp_doc=ptr[u8](
                 "list(iterable=(), /)\n--\n\n"
                 "Built-in mutable sequence.\n\n"
                 "If no argument is given, the constructor creates a new empty list.\n"
                 "The argument must be an iterable if specified."
             ),
             tp_traverse=list_traverse,
             tp_clear=list_clear_slot,
             tp_richcompare=list_richcompare,
             tp_iter=list_iter,
             tp_methods=addressof(list_methods),
             tp_init=list___init__,
             tp_alloc=PyType_GenericAlloc,
             tp_new=PyType_GenericNew,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=list_vectorcall,
             tp_version_tag=_Py_TYPE_VERSION_LIST
         ),
         PyListIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("list_iterator"),
             tp_basicsize=_PyListIterObject_SIZE,
             tp_dealloc=listiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=listiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=listiter_next,
             tp_methods=addressof(listiter_methods)
         ),
         PyListRevIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("list_reverseiterator"),
             tp_basicsize=_PyListIterObject_SIZE,
             tp_dealloc=listreviter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=listreviter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=listreviter_next,
             tp_methods=addressof(listreviter_methods)
         );
}

glob:priv PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     MAX_MERGE_PENDING: i64 = 64,
     PENDING_WORDS: i64 = 4,
     MIN_GALLOP: i64 = 7,
     MAX_MINRUN: i64 = 64,
     COMPARE_SAFE: i64 = 0,
     COMPARE_OBJECT: i64 = 1,
     COMPARE_LATIN: i64 = 2,
     COMPARE_LONG: i64 = 3,
     COMPARE_FLOAT: i64 = 4,
     COMPARE_TUPLE: i64 = 5;

glob:priv list_sort_signature = CallSignature(
         "sort", ["key", "reverse"], 0, 0, 0, parser=PARSE_KEYWORDS
     );

def list_of(op: ptr[PyObject]) -> ptr[PyListObject];

def listiter_of(op: ptr[PyObject]) -> ptr[_PyListIterObject];

def no_items -> ptr[ptr[PyObject]];

def list_items(op: ptr[PyObject]) -> ptr[ptr[PyObject]];

def set_items(op: ptr[PyObject], items: ptr[ptr[PyObject]]);

def list_allocated(op: ptr[PyObject]) -> i64;

def set_allocated(op: ptr[PyObject], allocated: i64);

def set_size(op: ptr[PyObject], size: i64);

def item_at(items: ptr[ptr[PyObject]], index: i64) -> ptr[PyObject];

def set_item_at(items: ptr[ptr[PyObject]], index: i64, value: ptr[PyObject]);

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def list_check(op: ptr[PyObject]) -> bool;

def list_check_exact(op: ptr[PyObject]) -> bool;

def type_of_object(type: ptr[PyObject]) -> ptr[PyTypeObject];

def valid_index(i: i64, limit: i64) -> bool;

def items_new(count: i64) -> ptr[ptr[PyObject]];

def memory_repeat(dest: ptr[ptr[PyObject]], len_dest: i64, len_src: i64);

def list_resize(op: ptr[PyObject], newsize: i64) -> i32;

def list_preallocate_exact(op: ptr[PyObject], size: i64) -> i32;

def list_new_prealloc(size: i64) -> ptr[PyObject];

def list_get_item_ref(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def append_take_ref(op: ptr[PyObject], newitem: ptr[PyObject]) -> i32;

def ins1(op: ptr[PyObject], where: i64, v: ptr[PyObject]) -> i32;

def index_argument(arg: ptr[PyObject]) -> i64;

import from c {
    def _PyList_DebugMallocStats(out: ptr) {
        _PyDebugAllocatorStats(
            out,
            "free PyListObject",
            i32(freelist(_Py_freelists_LISTS).view(1)[0].size),
            u64(PyListObject_SIZE)
        );
    }  def PyList_New(size: i64) -> ptr[PyObject] {
        if size < 0 {
            PyErr_BadInternalCall();
            return NULL;
        }
        op = freelist_pop(_Py_freelists_LISTS);
        if not op {
            op = _PyObject_GC_New(ptr[PyObject](addressof(PyList_Type)));
            if not op {
                return NULL;
            }
        }
        if size <= 0 {
            set_items(op, no_items());
        } else {
            items = ptr[ptr[PyObject]](PyMem_Calloc(u64(size), u64(8)));
            set_items(op, items);
            if not items {
                object_decref(op);
                return PyErr_NoMemory();
            }
        }
        set_size(op, size);
        set_allocated(op, size);
        object_gc_track(op);
        return op;
    }  def PyList_Size(op: ptr[PyObject]) -> i64 {
        if not list_check(op) {
            PyErr_BadInternalCall();
            return -1;
        }
        return object_size(op);
    }  def PyList_GetItem(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
        if not list_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        if not valid_index(i, object_size(op)) {
            PyErr_SetString(PyExc_IndexError, "list index out of range");
            return NULL;
        }
        return item_at(list_items(op), i);
    }  def PyList_GetItemRef(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
        if not list_check(op) {
            PyErr_SetString(PyExc_TypeError, "expected a list");
            return NULL;
        }
        item = list_get_item_ref(op, i);
        if not item {
            PyErr_SetString(PyExc_IndexError, "list index out of range");
            return NULL;
        }
        return item;
    }  def _PyList_GetItemRef(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
        return list_get_item_ref(op, i);
    }  def PyList_SetItem(op: ptr[PyObject], i: i64, newitem: ptr[PyObject]) -> i32 {
        if not list_check(op) {
            object_xdecref(newitem);
            PyErr_BadInternalCall();
            return i32(-1);
        }
        if not valid_index(i, object_size(op)) {
            object_xdecref(newitem);
            PyErr_SetString(PyExc_IndexError, "list assignment index out of range");
            return i32(-1);
        }
        slot = list_items(op) + i;
        old = slot.view(1)[0];
        slot.view(1)[0] = newitem;
        object_xdecref(old);
        return i32(0);
    }  def PyList_Insert(op: ptr[PyObject], where: i64, newitem: ptr[PyObject]) -> i32 {
        if not list_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        return ins1(op, where, newitem);
    }  def _PyList_AppendTakeRefListResize(
        op: ptr[PyObject], newitem: ptr[PyObject]
    ) -> i32 {
        length = object_size(op);
        if list_resize(op, length + 1) < 0 {
            object_decref(newitem);
            return i32(-1);
        }
        set_item_at(list_items(op), length, newitem);
        return i32(0);
    }  def PyList_Append(op: ptr[PyObject], newitem: ptr[PyObject]) -> i32 {
        if list_check(op) and newitem {
            return append_take_ref(op, object_new_ref(newitem));
        }
        PyErr_BadInternalCall();
        return i32(-1);
    }  def PyList_GetSlice(a: ptr[PyObject], ilow: i64, ihigh: i64) -> ptr[PyObject] {
        if not list_check(a) {
            PyErr_BadInternalCall();
            return NULL;
        }
        size = object_size(a);
        low = ilow;
        high = ihigh;
        if low < 0 {
            low = 0;
        } elif low > size {
            low = size;
        }
        if high < low {
            high = low;
        } elif high > size {
            high = size;
        }
        return list_slice(a, low, high);
    }  def PyList_SetSlice(
        a: ptr[PyObject], ilow: i64, ihigh: i64, v: ptr[PyObject]
    ) -> i32 {
        if not list_check(a) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        return list_ass_slice(a, ilow, ihigh, v);
    }  def _PyList_Extend(op: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
        return list_extend(op, iterable);
    }  def PyList_Extend(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32 {
        if not list_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        return list_extend_any(op, iterable);
    }  def PyList_Clear(op: ptr[PyObject]) -> i32 {
        if not list_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        list_clear(op);
        return i32(0);
    }  def PyList_Sort(v: ptr[PyObject]) -> i32 {
        if not v or not list_check(v) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        result = list_sort_impl(v, NULL, i32(0));
        if not result {
            return i32(-1);
        }
        object_decref(result);
        return i32(0);
    }  def PyList_Reverse(v: ptr[PyObject]) -> i32 {
        if not v or not list_check(v) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        if object_size(v) > 1 {
            reverse_items(list_items(v), object_size(v));
        }
        return i32(0);
    }  def PyList_AsTuple(v: ptr[PyObject]) -> ptr[PyObject] {
        if not v or not list_check(v) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return _PyTuple_FromArray(list_items(v), object_size(v));
    }  def _PyList_AsTupleAndClear(op: ptr[PyObject]) -> ptr[PyObject] {
        items = list_items(op);
        if not items {
            return PyTuple_New(0);
        }
        size = object_size(op);
        set_items(op, no_items());
        set_size(op, 0);
        result = _PyTuple_FromArraySteal(items, size);
        PyMem_Free(ptr(items));
        return result;
    }  def _PyList_FromStackRefStealOnSuccess(src: ptr[u64], n: i64) -> ptr[PyObject] {
        if n == 0 {
            return PyList_New(0);
        }
        op = PyList_New(n);
        if not op {
            return NULL;
        }
        dst = list_items(op);
        for i in range(n) {
            bits = (src + i).view(1)[0];
            item = ptr[PyObject](i64.wrap(bits & u64(0xFFFFFFFFFFFFFFFE)));
            if (bits & u64(1)) != u64(0) {
                object_incref(item);
            }
            set_item_at(dst, i, item);
        }
        return op;
    }  def _PyList_SliceSubscript(
        op: ptr[PyObject], item: ptr[PyObject]
    ) -> ptr[PyObject] {
        return list_slice_subscript(op, item);
    }
}

def list_dealloc(op: ptr[PyObject]);

def list_repr(op: ptr[PyObject]) -> ptr[PyObject];

def list_length(op: ptr[PyObject]) -> i64;

def list_contains(op: ptr[PyObject], el: ptr[PyObject]) -> i32;

def list_item(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def list_slice(a: ptr[PyObject], ilow: i64, ihigh: i64) -> ptr[PyObject];

def list_concat(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def list_repeat(a: ptr[PyObject], n: i64) -> ptr[PyObject];

def list_clear(op: ptr[PyObject]);

def list_clear_slot(op: ptr[PyObject]) -> i32;

def list_ass_slice_items(
    a: ptr[PyObject], ilow: i64, ihigh: i64, v: ptr[PyObject]
) -> i32;

def list_ass_slice(a: ptr[PyObject], ilow: i64, ihigh: i64, v: ptr[PyObject]) -> i32;

def list_inplace_repeat_items(op: ptr[PyObject], n: i64) -> i32;

def list_inplace_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def list_ass_item(op: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32;

def list_insert(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def py_list_clear(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def list_copy(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def list_append(op: ptr[PyObject], object: ptr[PyObject]) -> ptr[PyObject];

def list_extend_fast(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32;

def list_extend_iter(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32;

def list_extend_sequence(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32;

def list_extend_set(op: ptr[PyObject], other: ptr[PyObject]) -> i32;

def dict_used(dict: ptr[PyObject]) -> i64;

def view_dict(view: ptr[PyObject]) -> ptr[PyObject];

def list_extend_dict(op: ptr[PyObject], dict: ptr[PyObject], which_item: i64) -> i32;

def list_extend_dictitems(op: ptr[PyObject], dict: ptr[PyObject]) -> i32;

def list_extend_any(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32;

def list_extend(op: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject];

def list_inplace_concat(op: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def list_pop(op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64) -> ptr[PyObject];

def reverse_items(items: ptr[ptr[PyObject]], n: i64);

obj MergeState {
    has key_compare: i64 = 0,
        tuple_elem_compare: i64 = 0,
        key_type: ptr[PyTypeObject] = ptr[PyTypeObject](),
        min_gallop: i64 = 7,
        listlen: i64 = 0,
        basekeys: ptr[ptr[PyObject]] = ptr[ptr[PyObject]](),
        has_values: bool = False,
        a_keys: ptr[ptr[PyObject]] = ptr[ptr[PyObject]](),
        a_values: ptr[ptr[PyObject]] = ptr[ptr[PyObject]](),
        alloced: i64 = 0,
        n: i64 = 0,
        pending: ptr[i64] = ptr[i64]();
}

def pending_keys(ms: MergeState, i: i64) -> ptr[ptr[PyObject]];

def pending_values(ms: MergeState, i: i64) -> ptr[ptr[PyObject]];

def pending_len(ms: MergeState, i: i64) -> i64;

def pending_power(ms: MergeState, i: i64) -> i64;

def set_pending(
    ms: MergeState,
    i: i64,
    keys: ptr[ptr[PyObject]],
    values: ptr[ptr[PyObject]],
    length: i64
);

def set_pending_len(ms: MergeState, i: i64, length: i64);

def set_pending_power(ms: MergeState, i: i64, power: i64);

def compact_value(op: ptr[PyObject]) -> i64;

def long_is_compact(op: ptr[PyObject]) -> bool;

def unicode_length(op: ptr[PyObject]) -> i64;

def unsafe_latin_compare(v: ptr[PyObject], w: ptr[PyObject]) -> i32;

def unsafe_object_compare(ms: MergeState, v: ptr[PyObject], w: ptr[PyObject]) -> i32;

def unsafe_tuple_compare(ms: MergeState, v: ptr[PyObject], w: ptr[PyObject]) -> i32;

def compare_with(ms: MergeState, mode: i64, v: ptr[PyObject], w: ptr[PyObject]) -> i32;

def islt(ms: MergeState, x: ptr[PyObject], y: ptr[PyObject]) -> i32;

def slice_copy(
    dk: ptr[ptr[PyObject]],
    dv: ptr[ptr[PyObject]],
    i: i64,
    sk: ptr[ptr[PyObject]],
    sv: ptr[ptr[PyObject]],
    j: i64,
    has_values: bool
);

def slice_memcpy(
    dk: ptr[ptr[PyObject]],
    dv: ptr[ptr[PyObject]],
    i: i64,
    sk: ptr[ptr[PyObject]],
    sv: ptr[ptr[PyObject]],
    j: i64,
    n: i64,
    has_values: bool
);

def slice_memmove(
    dk: ptr[ptr[PyObject]],
    dv: ptr[ptr[PyObject]],
    i: i64,
    sk: ptr[ptr[PyObject]],
    sv: ptr[ptr[PyObject]],
    j: i64,
    n: i64,
    has_values: bool
);

def slice_reverse(
    keys: ptr[ptr[PyObject]], values: ptr[ptr[PyObject]], n: i64, has_values: bool
);

def binarysort(
    ms: MergeState,
    keys: ptr[ptr[PyObject]],
    values: ptr[ptr[PyObject]],
    n: i64,
    ok: i64
) -> i32;

def count_run(
    ms: MergeState,
    keys: ptr[ptr[PyObject]],
    values: ptr[ptr[PyObject]],
    nremaining: i64
) -> i64;

def gallop_left(
    ms: MergeState, key: ptr[PyObject], a: ptr[ptr[PyObject]], n: i64, hint: i64
) -> i64;

def gallop_right(
    ms: MergeState, key: ptr[PyObject], a: ptr[ptr[PyObject]], n: i64, hint: i64
) -> i64;

def merge_freemem(ms: MergeState);

def merge_getmem(ms: MergeState, need: i64) -> i32;

glob:priv MERGE_RUN: i64 = 0,
     MERGE_SUCCEED: i64 = 1,
     MERGE_FAIL: i64 = 2,
     MERGE_COPY_REST: i64 = 3;

def merge_lo(
    ms: MergeState,
    a_keys: ptr[ptr[PyObject]],
    a_values: ptr[ptr[PyObject]],
    na_in: i64,
    b_keys: ptr[ptr[PyObject]],
    b_values: ptr[ptr[PyObject]],
    nb_in: i64
) -> i64;

def merge_hi(
    ms: MergeState,
    a_keys: ptr[ptr[PyObject]],
    a_values: ptr[ptr[PyObject]],
    na_in: i64,
    b_keys: ptr[ptr[PyObject]],
    b_values: ptr[ptr[PyObject]],
    nb_in: i64
) -> i64;

def merge_at(ms: MergeState, i: i64) -> i64;

def powerloop(s1: i64, n1: i64, n2: i64, n: i64) -> i64;

def found_new_run(ms: MergeState, n2: i64) -> i32;

def merge_force_collapse(ms: MergeState) -> i32;

def merge_compute_minrun(n: i64) -> i64;

def choose_compares(ms: MergeState, keys: ptr[ptr[PyObject]], n: i64);

def merge_sort(
    ms: MergeState, lo_keys: ptr[ptr[PyObject]], lo_values: ptr[ptr[PyObject]], n: i64
) -> i32;

def list_sort_impl(
    op: ptr[PyObject], keyfunc_in: ptr[PyObject], reverse: i32
) -> ptr[PyObject];

def list_sort_bound(args: BoundArguments) -> ptr[PyObject];

def list_sort(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def list_reverse(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def list_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def list_count(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def list_remove(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def list_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def list_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def list___init___impl(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32;

def list___init__(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def list_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def list___sizeof__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def list_slice_step(
    a: ptr[PyObject], start: i64, step: i64, length: i64
) -> ptr[PyObject];

def list_slice_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def slice_check(op: ptr[PyObject]) -> bool;

def list_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def list_delete_extended(
    op: ptr[PyObject], start_in: i64, stop_in: i64, step_in: i64, slicelength: i64
) -> i32;

def list_assign_extended(
    op: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def list_ass_subscript(
    op: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def list_iter(seq: ptr[PyObject]) -> ptr[PyObject];

def listiter_dealloc(op: ptr[PyObject]);

def listiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def listiter_next(op: ptr[PyObject]) -> ptr[PyObject];

def listiter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def listiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def listiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

def list___reversed__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def listreviter_dealloc(op: ptr[PyObject]);

def listreviter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def listreviter_next(op: ptr[PyObject]) -> ptr[PyObject];

def listreviter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def listreviter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def listreviter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

def listiter_reduce_general(op: ptr[PyObject], forward: bool) -> ptr[PyObject];

impl list_of(op: ptr[PyObject]) -> ptr[PyListObject] {
    return ptr[PyListObject](op);
}

impl listiter_of(op: ptr[PyObject]) -> ptr[_PyListIterObject] {
    return ptr[_PyListIterObject](op);
}

impl no_items -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]]();
}

impl list_items(op: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return list_of(op).view(1)[0].ob_item;
}

impl set_items(op: ptr[PyObject], items: ptr[ptr[PyObject]]) {
    list_of(op).view(1)[0].ob_item = items;
}

impl list_allocated(op: ptr[PyObject]) -> i64 {
    return list_of(op).view(1)[0].allocated;
}

impl set_allocated(op: ptr[PyObject], allocated: i64) {
    list_of(op).view(1)[0].allocated = allocated;
}

impl set_size(op: ptr[PyObject], size: i64) {
    ptr[PyVarObject](op).view(1)[0].ob_size = size;
}

impl item_at(items: ptr[ptr[PyObject]], index: i64) -> ptr[PyObject] {
    return (items + index).view(1)[0];
}

impl set_item_at(items: ptr[ptr[PyObject]], index: i64, value: ptr[PyObject]) {
    (items + index).view(1)[0] = value;
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl list_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LIST_SUBCLASS);
}

impl list_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyList_Type));
}

impl type_of_object(type: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](type);
}

impl valid_index(i: i64, limit: i64) -> bool {
    return u64.wrap(i) < u64.wrap(limit);
}

impl items_new(count: i64) -> ptr[ptr[PyObject]] {
    if count > PY_SSIZE_T_MAX // 8 {
        return no_items();
    }
    return ptr[ptr[PyObject]](PyMem_Malloc(u64(count * 8)));
}

impl memory_repeat(dest: ptr[ptr[PyObject]], len_dest: i64, len_src: i64) {
    copied = len_src;
    while copied < len_dest {
        chunk = min(copied, len_dest - copied);
        jacpy_memory_copy(ptr(dest + copied), ptr(dest), chunk * 8);
        copied += chunk;
    }
}

impl list_resize(op: ptr[PyObject], newsize: i64) -> i32 {
    allocated = list_allocated(op);
    if allocated >= newsize and newsize >= (allocated >> 1) {
        set_size(op, newsize);
        return i32(0);
    }

    wanted = u64.wrap(newsize);
    new_allocated = (wanted + (wanted >> u64(3)) + u64(6)) & u64(0xFFFFFFFFFFFFFFFC);

    if newsize - object_size(op) > i64.wrap(new_allocated - wanted) {
        new_allocated = (wanted + u64(3)) & u64(0xFFFFFFFFFFFFFFFC);
    }
    if newsize == 0 {
        new_allocated = u64(0);
    }
    items = no_items();
    if new_allocated <= u64(PY_SSIZE_T_MAX // 8) {
        items = ptr[ptr[PyObject]](
            PyMem_Realloc(ptr(list_items(op)), new_allocated * u64(8))
        );
    }
    if not items {
        PyErr_NoMemory();
        return i32(-1);
    }
    set_items(op, items);
    set_size(op, newsize);
    set_allocated(op, i64.wrap(new_allocated));
    return i32(0);
}

impl list_preallocate_exact(op: ptr[PyObject], size: i64) -> i32 {
    rounded = (size + 1) & -2;
    items = items_new(rounded);
    if not items {
        PyErr_NoMemory();
        return i32(-1);
    }
    set_items(op, items);
    set_allocated(op, rounded);
    return i32(0);
}

impl list_new_prealloc(size: i64) -> ptr[PyObject] {
    op = PyList_New(0);
    if not op {
        return NULL;
    }
    items = items_new(size);
    if not items {
        object_decref(op);
        return PyErr_NoMemory();
    }
    set_items(op, items);
    set_allocated(op, size);
    return op;
}

impl list_get_item_ref(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    if not valid_index(i, object_size(op)) {
        return NULL;
    }
    return object_new_ref(item_at(list_items(op), i));
}

impl append_take_ref(op: ptr[PyObject], newitem: ptr[PyObject]) -> i32 {
    length = object_size(op);
    if list_allocated(op) > length {
        set_item_at(list_items(op), length, newitem);
        set_size(op, length + 1);
        return i32(0);
    }
    return _PyList_AppendTakeRefListResize(op, newitem);
}

impl ins1(op: ptr[PyObject], where: i64, v: ptr[PyObject]) -> i32 {
    n = object_size(op);
    if not v {
        PyErr_BadInternalCall();
        return i32(-1);
    }
    if list_resize(op, n + 1) < 0 {
        return i32(-1);
    }
    at = where;
    if at < 0 {
        at += n;
        if at < 0 {
            at = 0;
        }
    }
    if at > n {
        at = n;
    }
    items = list_items(op);
    jacpy_memory_move(ptr(items + (at + 1)), ptr(items + at), (n - at) * 8);
    set_item_at(items, at, object_new_ref(v));
    return i32(0);
}

impl index_argument(arg: ptr[PyObject]) -> i64 {
    value: i64 = -1;
    index = _PyNumber_Index(arg);
    if index {
        value = PyLong_AsSsize_t(index);
        object_decref(index);
    }
    return value;
}

impl list_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    items = list_items(op);
    if items {
        i = object_size(op);
        while i > 0 {
            i -= 1;
            object_xdecref(item_at(items, i));
        }
        PyMem_Free(ptr(items));
        set_items(op, no_items());
    }
    if list_check_exact(op)
        and freelist_push(_Py_freelists_LISTS, op, Py_lists_MAXFREELIST) {
        return;
    }
    PyObject_GC_Del(ptr(op));
}

impl list_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    if object_size(op) == 0 {
        return PyUnicode_FromString(ptr[u8]("[]"));
    }
    res = Py_ReprEnter(op);
    if res != 0 {
        return PyUnicode_FromString(ptr[u8]("[...]")) if res > 0 else NULL;
    }

    prealloc = 1 + 1 + (2 + 1) * (object_size(op) - 1) + 1;
    writer = PyUnicodeWriter_Create(prealloc);
    ok = False;
    if writer {
        ok = PyUnicodeWriter_WriteChar(writer, 91) >= 0;
    }

    i = 0;
    while ok and i < object_size(op) {
        item = object_xnew_ref(item_at(list_items(op), i));
        if i > 0 {
            ok = PyUnicodeWriter_WriteChar(writer, 44) >= 0
                and PyUnicodeWriter_WriteChar(writer, 32) >= 0;
        }
        if ok {
            ok = PyUnicodeWriter_WriteRepr(writer, item) >= 0;
        }
        object_xdecref(item);
        i += 1;
    }
    if ok and PyUnicodeWriter_WriteChar(writer, 93) >= 0 {
        Py_ReprLeave(op);
        return PyUnicodeWriter_Finish(writer);
    }
    PyUnicodeWriter_Discard(writer);
    Py_ReprLeave(op);
    return NULL;
}

impl list_length(op: ptr[PyObject]) -> i64 {
    return object_size(op);
}

impl list_contains(op: ptr[PyObject], el: ptr[PyObject]) -> i32 {
    i = 0;
    while True {
        item = list_get_item_ref(op, i);
        if not item {
            return i32(0);
        }
        cmp = PyObject_RichCompareBool(item, el, Py_EQ);
        object_decref(item);
        if cmp != 0 {
            return cmp;
        }
        i += 1;
    }
    return i32(0);
}

impl list_item(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    if not valid_index(i, object_size(op)) {
        PyErr_SetString(PyExc_IndexError, "list index out of range");
        return NULL;
    }
    return object_new_ref(item_at(list_items(op), i));
}

impl list_slice(a: ptr[PyObject], ilow: i64, ihigh: i64) -> ptr[PyObject] {
    length = ihigh - ilow;
    if length <= 0 {
        return PyList_New(0);
    }
    np = list_new_prealloc(length);
    if not np {
        return NULL;
    }
    src = list_items(a) + ilow;
    dest = list_items(np);
    for i in range(length) {
        set_item_at(dest, i, object_new_ref(item_at(src, i)));
    }
    set_size(np, length);
    return np;
}

impl list_concat(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not list_check(b) {
        PyErr_Format(
            PyExc_TypeError,
            "can only concatenate list (not \"%.200s\") to list",
            object_type(b).view(1)[0].tp_name
        );
        return NULL;
    }
    size_a = object_size(a);
    size_b = object_size(b);
    size = size_a + size_b;
    if size == 0 {
        return PyList_New(0);
    }
    np = list_new_prealloc(size);
    if not np {
        return NULL;
    }
    dest = list_items(np);
    src = list_items(a);
    for i in range(size_a) {
        set_item_at(dest, i, object_new_ref(item_at(src, i)));
    }
    src = list_items(b);
    for i in range(size_b) {
        set_item_at(dest, size_a + i, object_new_ref(item_at(src, i)));
    }
    set_size(np, size);
    return np;
}

impl list_repeat(a: ptr[PyObject], n: i64) -> ptr[PyObject] {
    input_size = object_size(a);
    if input_size == 0 or n <= 0 {
        return PyList_New(0);
    }
    if input_size > PY_SSIZE_T_MAX // n {
        return PyErr_NoMemory();
    }
    output_size = input_size * n;
    np = list_new_prealloc(output_size);
    if not np {
        return NULL;
    }
    dest = list_items(np);
    src = list_items(a);
    if input_size == 1 {
        elem = item_at(src, 0);
        refcnt_add(elem, n);
        for i in range(output_size) {
            set_item_at(dest, i, elem);
        }
    } else {
        for i in range(input_size) {
            item = item_at(src, i);
            refcnt_add(item, n);
            set_item_at(dest, i, item);
        }
        memory_repeat(dest, output_size, input_size);
    }
    set_size(np, output_size);
    return np;
}

impl list_clear(op: ptr[PyObject]) {
    items = list_items(op);
    if not items {
        return;
    }
    i = object_size(op);
    set_size(op, 0);
    set_items(op, no_items());
    set_allocated(op, 0);
    while i > 0 {
        i -= 1;
        object_xdecref(item_at(items, i));
    }
    PyMem_Free(ptr(items));
}

impl list_clear_slot(op: ptr[PyObject]) -> i32 {
    list_clear(op);
    return i32(0);
}

impl list_ass_slice_items(
    a: ptr[PyObject], ilow: i64, ihigh: i64, v: ptr[PyObject]
) -> i32 {
    v_as_sf = NULL;
    n: i64 = 0;
    vitem = no_items();
    if v {
        v_as_sf = PySequence_Fast(v, ptr[u8]("can only assign an iterable"));
        if not v_as_sf {
            return i32(-1);
        }
        n = object_size(v_as_sf);
        vitem = fast_items(v_as_sf);
    }
    size = object_size(a);
    low = ilow;
    high = ihigh;
    if low < 0 {
        low = 0;
    } elif low > size {
        low = size;
    }
    if high < low {
        high = low;
    } elif high > size {
        high = size;
    }
    norig = high - low;
    d = n - norig;
    if size + d == 0 {
        object_xdecref(v_as_sf);
        list_clear(a);
        return i32(0);
    }
    item = list_items(a);

    recycle = no_items();
    if norig > 0 {
        recycle = items_new(norig);
        if not recycle {
            PyErr_NoMemory();
            object_xdecref(v_as_sf);
            return i32(-1);
        }
        jacpy_memory_copy(ptr(recycle), ptr(item + low), norig * 8);
    }
    failed = False;
    if d < 0 {
        tail = (size - high) * 8;
        jacpy_memory_move(ptr(item + (high + d)), ptr(item + high), tail);
        if list_resize(a, size + d) < 0 {
            jacpy_memory_move(ptr(item + high), ptr(item + (high + d)), tail);
            jacpy_memory_copy(ptr(item + low), ptr(recycle), norig * 8);
            failed = True;
        } else {
            item = list_items(a);
        }
    } elif d > 0 {
        if list_resize(a, size + d) < 0 {
            failed = True;
        } else {
            item = list_items(a);
            jacpy_memory_move(
                ptr(item + (high + d)), ptr(item + high), (size - high) * 8
            );
        }
    }
    if not failed {
        for k in range(n) {
            set_item_at(item, low + k, object_xnew_ref(item_at(vitem, k)));
        }
        k = norig - 1;
        while k >= 0 {
            object_xdecref(item_at(recycle, k));
            k -= 1;
        }
    }
    if recycle {
        PyMem_Free(ptr(recycle));
    }
    object_xdecref(v_as_sf);
    return i32(-1) if failed else i32(0);
}

impl list_ass_slice(a: ptr[PyObject], ilow: i64, ihigh: i64, v: ptr[PyObject]) -> i32 {
    if a == v {
        copy = list_slice(a, 0, object_size(a));
        if not copy {
            return i32(-1);
        }
        result = list_ass_slice_items(a, ilow, ihigh, copy);
        object_decref(copy);
        return result;
    }
    return list_ass_slice_items(a, ilow, ihigh, v);
}

impl list_inplace_repeat_items(op: ptr[PyObject], n: i64) -> i32 {
    input_size = object_size(op);
    if input_size == 0 or n == 1 {
        return i32(0);
    }
    if n < 1 {
        list_clear(op);
        return i32(0);
    }
    if input_size > PY_SSIZE_T_MAX // n {
        PyErr_NoMemory();
        return i32(-1);
    }
    output_size = input_size * n;
    if list_resize(op, output_size) < 0 {
        return i32(-1);
    }
    items = list_items(op);
    for j in range(input_size) {
        refcnt_add(item_at(items, j), n - 1);
    }
    memory_repeat(items, output_size, input_size);
    return i32(0);
}

impl list_inplace_repeat(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    if list_inplace_repeat_items(op, n) < 0 {
        return NULL;
    }
    return object_new_ref(op);
}

impl list_ass_item(op: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32 {
    size = object_size(op);
    if not valid_index(i, size) {
        PyErr_SetString(PyExc_IndexError, "list assignment index out of range");
        return i32(-1);
    }
    items = list_items(op);
    old = item_at(items, i);
    if not v {
        jacpy_memory_move(ptr(items + i), ptr(items + (i + 1)), (size - 1 - i) * 8);
        set_size(op, size - 1);
    } else {
        set_item_at(items, i, object_new_ref(v));
    }
    object_decref(old);
    return i32(0);
}

impl list_insert(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs != 2 and _PyArg_CheckPositional("insert", nargs, 2, 2) == 0 {
        return NULL;
    }
    index = index_argument(args.view(1)[0]);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    if ins1(op, index, (args + 1).view(1)[0]) == 0 {
        return object_new_ref(Py_None);
    }
    return NULL;
}

impl py_list_clear(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    list_clear(op);
    return object_new_ref(Py_None);
}

impl list_copy(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return list_slice(op, 0, object_size(op));
}

impl list_append(op: ptr[PyObject], object: ptr[PyObject]) -> ptr[PyObject] {
    if append_take_ref(op, object_new_ref(object)) < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl list_extend_fast(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32 {
    n = object_size(iterable);
    if n == 0 {
        return i32(0);
    }
    m = object_size(op);
    if not list_items(op) {
        if list_preallocate_exact(op, n) < 0 {
            return i32(-1);
        }
        set_size(op, n);
    } elif list_resize(op, m + n) < 0 {
        return i32(-1);
    }
    src = fast_items(iterable);
    dest = list_items(op) + m;
    for i in range(n) {
        set_item_at(dest, i, object_new_ref(item_at(src, i)));
    }
    return i32(0);
}

impl list_extend_iter(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32 {
    it = PyObject_GetIter(iterable);
    if not it {
        return i32(-1);
    }
    iternext = object_type(it).view(1)[0].tp_iternext;

    n = PyObject_LengthHint(iterable, 8);
    if n < 0 {
        object_decref(it);
        return i32(-1);
    }
    m = object_size(op);
    failed = False;

    if m <= PY_SSIZE_T_MAX - n {
        if not list_items(op) {
            failed = n != 0 and list_preallocate_exact(op, n) < 0;
        } elif list_resize(op, m + n) < 0 {
            failed = True;
        } else {
            set_size(op, m);
        }
    }
    while not failed {
        item = iternext(it);
        if not item {
            if PyErr_Occurred() {
                if PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
                    PyErr_Clear();
                } else {
                    failed = True;
                }
            }
            break;
        }
        length = object_size(op);
        if length < list_allocated(op) {
            set_item_at(list_items(op), length, item);
            set_size(op, length + 1);
        } elif _PyList_AppendTakeRefListResize(op, item) < 0 {
            failed = True;
        }
    }

    if not failed
        and object_size(op) < list_allocated(op)
        and list_resize(op, object_size(op)) < 0 {
        failed = True;
    }
    object_decref(it);
    return i32(-1) if failed else i32(0);
}

impl list_extend_sequence(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32 {
    seq = PySequence_Fast(iterable, ptr[u8]("argument must be iterable"));
    if not seq {
        return i32(-1);
    }
    result = list_extend_fast(op, seq);
    object_decref(seq);
    return result;
}

impl list_extend_set(op: ptr[PyObject], other: ptr[PyObject]) -> i32 {
    m = object_size(op);
    n = ptr[i64](ptr[u8](other) + PySetObject_USED).view(1)[0];
    r = m + n;
    if r == 0 {
        return i32(0);
    }
    if list_resize(op, r) < 0 {
        return i32(-1);
    }
    setpos: i64 = 0;
    hash: i64 = 0;
    key: ptr[PyObject] = NULL;
    dest = list_items(op) + m;
    while _PySet_NextEntryRef(other, &mut setpos, &mut key, &mut hash) != 0 {
        dest.view(1)[0] = key;
        dest = dest + 1;
    }
    set_size(op, r);
    return i32(0);
}

impl dict_used(dict: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](dict) + PyDictObject_USED).view(1)[0];
}

impl view_dict(view: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](view) + _PyDictViewObject_DICT).view(1)[0];
}

impl list_extend_dict(op: ptr[PyObject], dict: ptr[PyObject], which_item: i64) -> i32 {
    m = object_size(op);
    n = dict_used(dict);
    r = m + n;
    if r == 0 {
        return i32(0);
    }
    if list_resize(op, r) < 0 {
        return i32(-1);
    }
    dest = list_items(op) + m;
    pos: i64 = 0;
    key: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    while PyDict_Next(dict, &mut pos, &mut key, &mut value) != 0 {
        dest.view(1)[0] = object_new_ref(value if which_item == 1 else key);
        dest = dest + 1;
    }
    set_size(op, r);
    return i32(0);
}

impl list_extend_dictitems(op: ptr[PyObject], dict: ptr[PyObject]) -> i32 {
    m = object_size(op);
    n = dict_used(dict);
    r = m + n;
    if r == 0 {
        return i32(0);
    }
    if list_resize(op, r) < 0 {
        return i32(-1);
    }
    dest = list_items(op) + m;
    pos: i64 = 0;
    i: i64 = 0;
    key: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    while PyDict_Next(dict, &mut pos, &mut key, &mut value) != 0 {
        item = PyTuple_Pack(2, key, value);
        if not item {
            set_size(op, m + i);
            return i32(-1);
        }
        dest.view(1)[0] = item;
        dest = dest + 1;
        i += 1;
    }
    set_size(op, r);
    return i32(0);
}

impl list_extend_any(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32 {
    if op == iterable {
        return list_inplace_repeat_items(op, 2);
    }
    type = object_type(iterable);
    if type == addressof(PyList_Type)
        or type == type_of_object(addressof(PyTuple_Type)) {
        return list_extend_sequence(op, iterable);
    }
    if type == type_of_object(addressof(PySet_Type))
        or type == type_of_object(addressof(PyFrozenSet_Type)) {
        return list_extend_set(op, iterable);
    }
    if type == type_of_object(addressof(PyDict_Type)) {
        return list_extend_dict(op, iterable, 0);
    }
    if type == addressof(PyDictKeys_Type) {
        return list_extend_dict(op, view_dict(iterable), 0);
    }
    if type == addressof(PyDictValues_Type) {
        return list_extend_dict(op, view_dict(iterable), 1);
    }
    if type == addressof(PyDictItems_Type) {
        return list_extend_dictitems(op, view_dict(iterable));
    }
    return list_extend_iter(op, iterable);
}

impl list_extend(op: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
    if list_extend_any(op, iterable) < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl list_inplace_concat(op: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if list_extend_any(op, other) < 0 {
        return NULL;
    }
    return object_new_ref(op);
}

impl list_pop(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional("pop", nargs, 0, 1) == 0 {
        return NULL;
    }
    index: i64 = -1;
    if nargs >= 1 {
        index = index_argument(args.view(1)[0]);
        if index == -1 and PyErr_Occurred() {
            return NULL;
        }
    }
    size = object_size(op);
    if size == 0 {
        PyErr_SetString(PyExc_IndexError, "pop from empty list");
        return NULL;
    }
    if index < 0 {
        index += size;
    }
    if not valid_index(index, size) {
        PyErr_SetString(PyExc_IndexError, "pop index out of range");
        return NULL;
    }
    items = list_items(op);
    v = item_at(items, index);
    size_after_pop = size - 1;
    status = i32(0);
    if size_after_pop == 0 {
        object_incref(v);
        list_clear(op);
    } else {
        if size_after_pop - index > 0 {
            jacpy_memory_move(
                ptr(items + index),
                ptr(items + (index + 1)),
                (size_after_pop - index) * 8
            );
        }
        status = list_resize(op, size_after_pop);
    }
    if status >= 0 {
        return v;
    }

    jacpy_memory_move(
        ptr(items + (index + 1)), ptr(items + index), (size_after_pop - index) * 8
    );
    set_item_at(items, index, v);
    return NULL;
}

impl reverse_items(items: ptr[ptr[PyObject]], n: i64) {
    lo = 0;
    hi = n - 1;
    while lo < hi {
        t = item_at(items, lo);
        set_item_at(items, lo, item_at(items, hi));
        set_item_at(items, hi, t);
        lo += 1;
        hi -= 1;
    }
}

impl pending_keys(ms: MergeState, i: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]]((ms.pending + i * PENDING_WORDS).view(1)[0]);
}

impl pending_values(ms: MergeState, i: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]]((ms.pending + (i * PENDING_WORDS + 1)).view(1)[0]);
}

impl pending_len(ms: MergeState, i: i64) -> i64 {
    return (ms.pending + (i * PENDING_WORDS + 2)).view(1)[0];
}

impl pending_power(ms: MergeState, i: i64) -> i64 {
    return (ms.pending + (i * PENDING_WORDS + 3)).view(1)[0];
}

impl set_pending(
    ms: MergeState,
    i: i64,
    keys: ptr[ptr[PyObject]],
    values: ptr[ptr[PyObject]],
    length: i64
) {
    record = ms.pending + i * PENDING_WORDS;
    record.view(1)[0] = int(keys);
    (record + 1).view(1)[0] = int(values);
    (record + 2).view(1)[0] = length;
}

impl set_pending_len(ms: MergeState, i: i64, length: i64) {
    (ms.pending + (i * PENDING_WORDS + 2)).view(1)[0] = length;
}

impl set_pending_power(ms: MergeState, i: i64, power: i64) {
    (ms.pending + (i * PENDING_WORDS + 3)).view(1)[0] = power;
}

impl compact_value(op: ptr[PyObject]) -> i64 {
    tag = ptr[u64](ptr[u8](op) + PyLongObject_TAG).view(1)[0];
    sign = 1 - i64.wrap(tag & _PyLong_SIGN_MASK);
    return sign * i64(ptr[u32](ptr[u8](op) + PyLongObject_DIGIT).view(1)[0]);
}

impl long_is_compact(op: ptr[PyObject]) -> bool {
    tag = ptr[u64](ptr[u8](op) + PyLongObject_TAG).view(1)[0];
    return tag < (u64(2) << _PyLong_NON_SIZE_BITS);
}

impl unicode_length(op: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](op) + PyASCIIObject_LENGTH).view(1)[0];
}

impl unsafe_latin_compare(v: ptr[PyObject], w: ptr[PyObject]) -> i32 {
    vlen = unicode_length(v);
    wlen = unicode_length(w);
    res = memcmp(jacpy_unicode_data(v), jacpy_unicode_data(w), u64(min(vlen, wlen)));
    if res != 0 {
        return i32(1) if res < 0 else i32(0);
    }
    return i32(1) if vlen < wlen else i32(0);
}

impl unsafe_object_compare(ms: MergeState, v: ptr[PyObject], w: ptr[PyObject]) -> i32 {
    key_type = ms.key_type;
    if int(object_type(v).view(1)[0].tp_richcompare)
        != int(key_type.view(1)[0].tp_richcompare) {
        return PyObject_RichCompareBool(v, w, Py_LT);
    }
    res_obj = key_type.view(1)[0].tp_richcompare(v, w, Py_LT);
    if res_obj == Py_NotImplemented {
        object_decref(res_obj);
        return PyObject_RichCompareBool(v, w, Py_LT);
    }
    if not res_obj {
        return i32(-1);
    }
    res = i32(0);
    if res_obj == py_true() {
        res = i32(1);
    } elif res_obj != py_false() {
        res = PyObject_IsTrue(res_obj);
    }
    object_decref(res_obj);
    return res;
}

impl unsafe_tuple_compare(ms: MergeState, v: ptr[PyObject], w: ptr[PyObject]) -> i32 {
    vlen = object_size(v);
    wlen = object_size(w);
    vitems = tuple_items(v);
    witems = tuple_items(w);
    i = 0;
    while i < vlen and i < wlen {
        k = PyObject_RichCompareBool(item_at(vitems, i), item_at(witems, i), Py_EQ);
        if k < 0 {
            return i32(-1);
        }
        if k == 0 {
            break;
        }
        i += 1;
    }
    if i >= vlen or i >= wlen {
        return i32(1) if vlen < wlen else i32(0);
    }
    if i == 0 {
        return compare_with(
            ms, ms.tuple_elem_compare, item_at(vitems, 0), item_at(witems, 0)
        );
    }
    return PyObject_RichCompareBool(item_at(vitems, i), item_at(witems, i), Py_LT);
}

impl compare_with(
    ms: MergeState, mode: i64, v: ptr[PyObject], w: ptr[PyObject]
) -> i32 {
    if mode == COMPARE_LONG {
        return i32(1) if compact_value(v) < compact_value(w) else i32(0);
    }
    if mode == COMPARE_FLOAT {
        if ptr[PyFloatObject](v).view(1)[0].ob_fval
            < ptr[PyFloatObject](w).view(1)[0].ob_fval {
            return i32(1);
        }
        return i32(0);
    }
    if mode == COMPARE_LATIN {
        return unsafe_latin_compare(v, w);
    }
    if mode == COMPARE_OBJECT {
        return unsafe_object_compare(ms, v, w);
    }
    if mode == COMPARE_TUPLE {
        return unsafe_tuple_compare(ms, v, w);
    }
    return PyObject_RichCompareBool(v, w, Py_LT);
}

impl islt(ms: MergeState, x: ptr[PyObject], y: ptr[PyObject]) -> i32 {
    return compare_with(ms, ms.key_compare, x, y);
}

impl slice_copy(
    dk: ptr[ptr[PyObject]],
    dv: ptr[ptr[PyObject]],
    i: i64,
    sk: ptr[ptr[PyObject]],
    sv: ptr[ptr[PyObject]],
    j: i64,
    has_values: bool
) {
    set_item_at(dk, i, item_at(sk, j));
    if has_values {
        set_item_at(dv, i, item_at(sv, j));
    }
}

impl slice_memcpy(
    dk: ptr[ptr[PyObject]],
    dv: ptr[ptr[PyObject]],
    i: i64,
    sk: ptr[ptr[PyObject]],
    sv: ptr[ptr[PyObject]],
    j: i64,
    n: i64,
    has_values: bool
) {
    jacpy_memory_copy(ptr(dk + i), ptr(sk + j), n * 8);
    if has_values {
        jacpy_memory_copy(ptr(dv + i), ptr(sv + j), n * 8);
    }
}

impl slice_memmove(
    dk: ptr[ptr[PyObject]],
    dv: ptr[ptr[PyObject]],
    i: i64,
    sk: ptr[ptr[PyObject]],
    sv: ptr[ptr[PyObject]],
    j: i64,
    n: i64,
    has_values: bool
) {
    jacpy_memory_move(ptr(dk + i), ptr(sk + j), n * 8);
    if has_values {
        jacpy_memory_move(ptr(dv + i), ptr(sv + j), n * 8);
    }
}

impl slice_reverse(
    keys: ptr[ptr[PyObject]], values: ptr[ptr[PyObject]], n: i64, has_values: bool
) {
    reverse_items(keys, n);
    if has_values {
        reverse_items(values, n);
    }
}

impl binarysort(
    ms: MergeState,
    keys: ptr[ptr[PyObject]],
    values: ptr[ptr[PyObject]],
    n: i64,
    ok: i64
) -> i32 {
    start = ok if ok > 0 else 1;
    while start < n {
        lo = 0;
        hi = start;
        pivot = item_at(keys, start);
        while lo < hi {
            mid = (lo + hi) >> 1;
            k = islt(ms, pivot, item_at(keys, mid));
            if k < 0 {
                return i32(-1);
            }
            if k != 0 {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }

        m = start;
        while m > lo {
            set_item_at(keys, m, item_at(keys, m - 1));
            m -= 1;
        }
        set_item_at(keys, lo, pivot);
        if ms.has_values {
            vpivot = item_at(values, start);
            m = start;
            while m > lo {
                set_item_at(values, m, item_at(values, m - 1));
                m -= 1;
            }
            set_item_at(values, lo, vpivot);
        }
        start += 1;
    }
    return i32(0);
}

impl count_run(
    ms: MergeState,
    keys: ptr[ptr[PyObject]],
    values: ptr[ptr[PyObject]],
    nremaining: i64
) -> i64 {
    hv = ms.has_values;

    n = 1;
    while n < nremaining {
        k = islt(ms, item_at(keys, n), item_at(keys, n - 1));
        if k < 0 {
            return -1;
        }
        if k != 0 {
            break;
        }
        n += 1;
    }
    if n == nremaining {
        return n;
    }

    if n > 1 {
        k = islt(ms, item_at(keys, 0), item_at(keys, n - 1));
        if k < 0 {
            return -1;
        }
        if k != 0 {
            return n;
        }
        slice_reverse(keys, values, n, hv);
    }
    n += 1;
    neq = 0;
    while n < nremaining {
        k = islt(ms, item_at(keys, n), item_at(keys, n - 1));
        if k < 0 {
            return -1;
        }
        if k != 0 {
            if neq != 0 {
                neq += 1;
                slice_reverse(keys + (n - neq), values + (n - neq), neq, hv);
                neq = 0;
            }
        } else {
            k = islt(ms, item_at(keys, n - 1), item_at(keys, n));
            if k < 0 {
                return -1;
            }
            if k != 0 {
                break;
            }
            neq += 1;
        }
        n += 1;
    }
    if neq != 0 {
        neq += 1;
        slice_reverse(keys + (n - neq), values + (n - neq), neq, hv);
    }
    slice_reverse(keys, values, n, hv);

    while n < nremaining {
        k = islt(ms, item_at(keys, n), item_at(keys, n - 1));
        if k < 0 {
            return -1;
        }
        if k != 0 {
            break;
        }
        n += 1;
    }
    return n;
}

impl gallop_left(
    ms: MergeState, key: ptr[PyObject], a: ptr[ptr[PyObject]], n: i64, hint: i64
) -> i64 {
    lastofs = 0;
    ofs = 1;
    k = islt(ms, item_at(a, hint), key);
    if k < 0 {
        return -1;
    }
    if k != 0 {
        maxofs = n - hint;
        while ofs < maxofs {
            k = islt(ms, item_at(a, hint + ofs), key);
            if k < 0 {
                return -1;
            }
            if k == 0 {
                break;
            }
            lastofs = ofs;
            ofs = (ofs << 1) + 1;
        }
        if ofs > maxofs {
            ofs = maxofs;
        }
        lastofs += hint;
        ofs += hint;
    } else {
        maxofs = hint + 1;
        while ofs < maxofs {
            k = islt(ms, item_at(a, hint - ofs), key);
            if k < 0 {
                return -1;
            }
            if k != 0 {
                break;
            }
            lastofs = ofs;
            ofs = (ofs << 1) + 1;
        }
        if ofs > maxofs {
            ofs = maxofs;
        }
        last = lastofs;
        lastofs = hint - ofs;
        ofs = hint - last;
    }

    lastofs += 1;
    while lastofs < ofs {
        m = lastofs + ((ofs - lastofs) >> 1);
        k = islt(ms, item_at(a, m), key);
        if k < 0 {
            return -1;
        }
        if k != 0 {
            lastofs = m + 1;
        } else {
            ofs = m;
        }
    }
    return ofs;
}

impl gallop_right(
    ms: MergeState, key: ptr[PyObject], a: ptr[ptr[PyObject]], n: i64, hint: i64
) -> i64 {
    lastofs = 0;
    ofs = 1;
    k = islt(ms, key, item_at(a, hint));
    if k < 0 {
        return -1;
    }
    if k != 0 {
        maxofs = hint + 1;
        while ofs < maxofs {
            k = islt(ms, key, item_at(a, hint - ofs));
            if k < 0 {
                return -1;
            }
            if k == 0 {
                break;
            }
            lastofs = ofs;
            ofs = (ofs << 1) + 1;
        }
        if ofs > maxofs {
            ofs = maxofs;
        }
        last = lastofs;
        lastofs = hint - ofs;
        ofs = hint - last;
    } else {
        maxofs = n - hint;
        while ofs < maxofs {
            k = islt(ms, key, item_at(a, hint + ofs));
            if k < 0 {
                return -1;
            }
            if k != 0 {
                break;
            }
            lastofs = ofs;
            ofs = (ofs << 1) + 1;
        }
        if ofs > maxofs {
            ofs = maxofs;
        }
        lastofs += hint;
        ofs += hint;
    }
    lastofs += 1;
    while lastofs < ofs {
        m = lastofs + ((ofs - lastofs) >> 1);
        k = islt(ms, key, item_at(a, m));
        if k < 0 {
            return -1;
        }
        if k != 0 {
            ofs = m;
        } else {
            lastofs = m + 1;
        }
    }
    return ofs;
}

impl merge_freemem(ms: MergeState) {
    if ms.a_keys {
        PyMem_Free(ptr(ms.a_keys));
        ms.a_keys = no_items();
        ms.a_values = no_items();
        ms.alloced = 0;
    }
}

impl merge_getmem(ms: MergeState, need: i64) -> i32 {
    if need <= ms.alloced {
        return i32(0);
    }
    multiplier = 2 if ms.has_values else 1;

    merge_freemem(ms);
    if need > PY_SSIZE_T_MAX // 8 // multiplier {
        PyErr_NoMemory();
        return i32(-1);
    }
    keys = items_new(multiplier * need);
    if not keys {
        PyErr_NoMemory();
        return i32(-1);
    }
    ms.a_keys = keys;
    ms.alloced = need;
    if ms.has_values {
        ms.a_values = keys + need;
    }
    return i32(0);
}

impl merge_lo(
    ms: MergeState,
    a_keys: ptr[ptr[PyObject]],
    a_values: ptr[ptr[PyObject]],
    na_in: i64,
    b_keys: ptr[ptr[PyObject]],
    b_values: ptr[ptr[PyObject]],
    nb_in: i64
) -> i64 {
    hv = ms.has_values;
    na = na_in;
    nb = nb_in;
    k: i64 = 0;
    if merge_getmem(ms, na) < 0 {
        return -1;
    }
    slice_memcpy(ms.a_keys, ms.a_values, 0, a_keys, a_values, 0, na, hv);
    dk = a_keys;
    dv = a_values;
    ak = ms.a_keys;
    av = ms.a_values;
    bk = b_keys;
    bv = b_values;
    slice_copy(dk, dv, 0, bk, bv, 0, hv);
    dk = dk + 1;
    dv = dv + 1;
    bk = bk + 1;
    bv = bv + 1;
    nb -= 1;
    outcome = MERGE_RUN;
    if nb == 0 {
        outcome = MERGE_SUCCEED;
    } elif na == 1 {
        outcome = MERGE_COPY_REST;
    }
    min_gallop = ms.min_gallop;
    while outcome == MERGE_RUN {
        acount = 0;
        bcount = 0;

        while True {
            k = islt(ms, bk.view(1)[0], ak.view(1)[0]);
            if k < 0 {
                outcome = MERGE_FAIL;
                break;
            }
            if k != 0 {
                slice_copy(dk, dv, 0, bk, bv, 0, hv);
                dk = dk + 1;
                dv = dv + 1;
                bk = bk + 1;
                bv = bv + 1;
                bcount += 1;
                acount = 0;
                nb -= 1;
                if nb == 0 {
                    outcome = MERGE_SUCCEED;
                    break;
                }
                if bcount >= min_gallop {
                    break;
                }
            } else {
                slice_copy(dk, dv, 0, ak, av, 0, hv);
                dk = dk + 1;
                dv = dv + 1;
                ak = ak + 1;
                av = av + 1;
                acount += 1;
                bcount = 0;
                na -= 1;
                if na == 1 {
                    outcome = MERGE_COPY_REST;
                    break;
                }
                if acount >= min_gallop {
                    break;
                }
            }
        }
        if outcome != MERGE_RUN {
            break;
        }

        min_gallop += 1;
        while True {
            if min_gallop > 1 {
                min_gallop -= 1;
            }
            ms.min_gallop = min_gallop;
            k = gallop_right(ms, bk.view(1)[0], ak, na, 0);
            acount = k;
            if k != 0 {
                if k < 0 {
                    outcome = MERGE_FAIL;
                    break;
                }
                slice_memcpy(dk, dv, 0, ak, av, 0, k, hv);
                dk = dk + k;
                dv = dv + k;
                ak = ak + k;
                av = av + k;
                na -= k;
                if na == 1 {
                    outcome = MERGE_COPY_REST;
                    break;
                }

                if na == 0 {
                    outcome = MERGE_SUCCEED;
                    break;
                }
            }
            slice_copy(dk, dv, 0, bk, bv, 0, hv);
            dk = dk + 1;
            dv = dv + 1;
            bk = bk + 1;
            bv = bv + 1;
            nb -= 1;
            if nb == 0 {
                outcome = MERGE_SUCCEED;
                break;
            }
            k = gallop_left(ms, ak.view(1)[0], bk, nb, 0);
            bcount = k;
            if k != 0 {
                if k < 0 {
                    outcome = MERGE_FAIL;
                    break;
                }
                slice_memmove(dk, dv, 0, bk, bv, 0, k, hv);
                dk = dk + k;
                dv = dv + k;
                bk = bk + k;
                bv = bv + k;
                nb -= k;
                if nb == 0 {
                    outcome = MERGE_SUCCEED;
                    break;
                }
            }
            slice_copy(dk, dv, 0, ak, av, 0, hv);
            dk = dk + 1;
            dv = dv + 1;
            ak = ak + 1;
            av = av + 1;
            na -= 1;
            if na == 1 {
                outcome = MERGE_COPY_REST;
                break;
            }
            if acount < MIN_GALLOP and bcount < MIN_GALLOP {
                break;
            }
        }
        if outcome != MERGE_RUN {
            break;
        }

        min_gallop += 1;
        ms.min_gallop = min_gallop;
    }
    if outcome == MERGE_COPY_REST {
        slice_memmove(dk, dv, 0, bk, bv, 0, nb, hv);
        slice_copy(dk, dv, nb, ak, av, 0, hv);
        return 0;
    }
    if na != 0 {
        slice_memcpy(dk, dv, 0, ak, av, 0, na, hv);
    }
    return 0 if outcome == MERGE_SUCCEED else -1;
}

impl merge_hi(
    ms: MergeState,
    a_keys: ptr[ptr[PyObject]],
    a_values: ptr[ptr[PyObject]],
    na_in: i64,
    b_keys: ptr[ptr[PyObject]],
    b_values: ptr[ptr[PyObject]],
    nb_in: i64
) -> i64 {
    hv = ms.has_values;
    na = na_in;
    nb = nb_in;
    k: i64 = 0;
    if merge_getmem(ms, nb) < 0 {
        return -1;
    }
    dk = b_keys + (nb - 1);
    dv = b_values + (nb - 1);
    slice_memcpy(ms.a_keys, ms.a_values, 0, b_keys, b_values, 0, nb, hv);
    base_ak = a_keys;
    base_bk = ms.a_keys;
    base_bv = ms.a_values;
    bk = ms.a_keys + (nb - 1);
    bv = ms.a_values + (nb - 1);
    ak = a_keys + (na - 1);
    av = a_values + (na - 1);
    slice_copy(dk, dv, 0, ak, av, 0, hv);
    dk = dk - 1;
    dv = dv - 1;
    ak = ak - 1;
    av = av - 1;
    na -= 1;
    outcome = MERGE_RUN;
    if na == 0 {
        outcome = MERGE_SUCCEED;
    } elif nb == 1 {
        outcome = MERGE_COPY_REST;
    }
    min_gallop = ms.min_gallop;
    while outcome == MERGE_RUN {
        acount = 0;
        bcount = 0;
        while True {
            k = islt(ms, bk.view(1)[0], ak.view(1)[0]);
            if k < 0 {
                outcome = MERGE_FAIL;
                break;
            }
            if k != 0 {
                slice_copy(dk, dv, 0, ak, av, 0, hv);
                dk = dk - 1;
                dv = dv - 1;
                ak = ak - 1;
                av = av - 1;
                acount += 1;
                bcount = 0;
                na -= 1;
                if na == 0 {
                    outcome = MERGE_SUCCEED;
                    break;
                }
                if acount >= min_gallop {
                    break;
                }
            } else {
                slice_copy(dk, dv, 0, bk, bv, 0, hv);
                dk = dk - 1;
                dv = dv - 1;
                bk = bk - 1;
                bv = bv - 1;
                bcount += 1;
                acount = 0;
                nb -= 1;
                if nb == 1 {
                    outcome = MERGE_COPY_REST;
                    break;
                }
                if bcount >= min_gallop {
                    break;
                }
            }
        }
        if outcome != MERGE_RUN {
            break;
        }
        min_gallop += 1;
        while True {
            if min_gallop > 1 {
                min_gallop -= 1;
            }
            ms.min_gallop = min_gallop;
            k = gallop_right(ms, bk.view(1)[0], base_ak, na, na - 1);
            if k < 0 {
                outcome = MERGE_FAIL;
                break;
            }
            k = na - k;
            acount = k;
            if k != 0 {
                dk = dk - k;
                dv = dv - k;
                ak = ak - k;
                av = av - k;
                slice_memmove(dk, dv, 1, ak, av, 1, k, hv);
                na -= k;
                if na == 0 {
                    outcome = MERGE_SUCCEED;
                    break;
                }
            }
            slice_copy(dk, dv, 0, bk, bv, 0, hv);
            dk = dk - 1;
            dv = dv - 1;
            bk = bk - 1;
            bv = bv - 1;
            nb -= 1;
            if nb == 1 {
                outcome = MERGE_COPY_REST;
                break;
            }
            k = gallop_left(ms, ak.view(1)[0], base_bk, nb, nb - 1);
            if k < 0 {
                outcome = MERGE_FAIL;
                break;
            }
            k = nb - k;
            bcount = k;
            if k != 0 {
                dk = dk - k;
                dv = dv - k;
                bk = bk - k;
                bv = bv - k;
                slice_memcpy(dk, dv, 1, bk, bv, 1, k, hv);
                nb -= k;
                if nb == 1 {
                    outcome = MERGE_COPY_REST;
                    break;
                }

                if nb == 0 {
                    outcome = MERGE_SUCCEED;
                    break;
                }
            }
            slice_copy(dk, dv, 0, ak, av, 0, hv);
            dk = dk - 1;
            dv = dv - 1;
            ak = ak - 1;
            av = av - 1;
            na -= 1;
            if na == 0 {
                outcome = MERGE_SUCCEED;
                break;
            }
            if acount < MIN_GALLOP and bcount < MIN_GALLOP {
                break;
            }
        }
        if outcome != MERGE_RUN {
            break;
        }
        min_gallop += 1;
        ms.min_gallop = min_gallop;
    }
    if outcome == MERGE_COPY_REST {
        slice_memmove(dk, dv, 1 - na, ak, av, 1 - na, na, hv);
        dk = dk - na;
        dv = dv - na;
        slice_copy(dk, dv, 0, bk, bv, 0, hv);
        return 0;
    }
    if nb != 0 {
        slice_memcpy(dk, dv, -(nb - 1), base_bk, base_bv, 0, nb, hv);
    }
    return 0 if outcome == MERGE_SUCCEED else -1;
}

impl merge_at(ms: MergeState, i: i64) -> i64 {
    a_keys = pending_keys(ms, i);
    a_values = pending_values(ms, i);
    na = pending_len(ms, i);
    b_keys = pending_keys(ms, i + 1);
    b_values = pending_values(ms, i + 1);
    nb = pending_len(ms, i + 1);

    set_pending_len(ms, i, na + nb);
    if i == ms.n - 3 {
        set_pending(
            ms,
            i + 1,
            pending_keys(ms, i + 2),
            pending_values(ms, i + 2),
            pending_len(ms, i + 2)
        );
        set_pending_power(ms, i + 1, pending_power(ms, i + 2));
    }
    ms.n -= 1;

    k = gallop_right(ms, b_keys.view(1)[0], a_keys, na, 0);
    if k < 0 {
        return -1;
    }
    a_keys = a_keys + k;
    a_values = a_values + k;
    na -= k;
    if na == 0 {
        return 0;
    }

    nb = gallop_left(ms, (a_keys + (na - 1)).view(1)[0], b_keys, nb, nb - 1);
    if nb <= 0 {
        return nb;
    }
    if na <= nb {
        return merge_lo(ms, a_keys, a_values, na, b_keys, b_values, nb);
    }
    return merge_hi(ms, a_keys, a_values, na, b_keys, b_values, nb);
}

impl powerloop(s1: i64, n1: i64, n2: i64, n: i64) -> i64 {
    result = 0;
    a = 2 * s1 + n1;
    b = a + n1 + n2;
    while True {
        result += 1;
        if a >= n {
            a -= n;
            b -= n;
        } elif b >= n {
            break;
        }
        a = a << 1;
        b = b << 1;
    }
    return result;
}

impl found_new_run(ms: MergeState, n2: i64) -> i32 {
    if ms.n != 0 {
        last = ms.n - 1;
        s1 = (int(pending_keys(ms, last)) - int(ms.basekeys)) >> 3;
        n1 = pending_len(ms, last);
        power = powerloop(s1, n1, n2, ms.listlen);
        while ms.n > 1 and pending_power(ms, ms.n - 2) > power {
            if merge_at(ms, ms.n - 2) < 0 {
                return i32(-1);
            }
        }
        set_pending_power(ms, ms.n - 1, power);
    }
    return i32(0);
}

impl merge_force_collapse(ms: MergeState) -> i32 {
    while ms.n > 1 {
        n = ms.n - 2;
        if n > 0 and pending_len(ms, n - 1) < pending_len(ms, n + 1) {
            n -= 1;
        }
        if merge_at(ms, n) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

impl merge_compute_minrun(n: i64) -> i64 {
    r = 0;
    m = n;
    while m >= MAX_MINRUN {
        r = r | (m & 1);
        m = m >> 1;
    }
    return m + r;
}

impl choose_compares(ms: MergeState, keys: ptr[ptr[PyObject]], n: i64) {
    tuple_type = type_of_object(addressof(PyTuple_Type));
    long_type = type_of_object(addressof(PyLong_Type));
    unicode_type = type_of_object(addressof(PyUnicode_Type));
    first = item_at(keys, 0);
    keys_are_in_tuples = object_type(first) == tuple_type and object_size(first) > 0;
    key_type = object_type(tuple_get_item(first, 0))
        if keys_are_in_tuples
        else object_type(first);
    keys_are_all_same_type = True;
    strings_are_latin = True;
    ints_are_bounded = True;
    for i in range(n) {
        candidate = item_at(keys, i);
        if keys_are_in_tuples
            and not (
                object_type(candidate) == tuple_type and object_size(candidate) != 0
            ) {
            keys_are_in_tuples = False;
            keys_are_all_same_type = False;
            break;
        }

        key = tuple_get_item(candidate, 0) if keys_are_in_tuples else candidate;
        if object_type(key) != key_type {
            keys_are_all_same_type = False;

            if not keys_are_in_tuples {
                break;
            }
        }
        if keys_are_all_same_type {
            if key_type == long_type
                and ints_are_bounded
                and not long_is_compact(key) {
                ints_are_bounded = False;
            } elif key_type == unicode_type
                and strings_are_latin
                and jacpy_unicode_kind(key) != 1 {
                strings_are_latin = False;
            }
        }
    }
    ms.key_type = key_type;
    if keys_are_all_same_type {
        if key_type == unicode_type and strings_are_latin {
            ms.key_compare = COMPARE_LATIN;
        } elif key_type == long_type and ints_are_bounded {
            ms.key_compare = COMPARE_LONG;
        } elif key_type == type_of_object(addressof(PyFloat_Type)) {
            ms.key_compare = COMPARE_FLOAT;
        } elif int(key_type.view(1)[0].tp_richcompare) != 0 {
            ms.key_compare = COMPARE_OBJECT;
        } else {
            ms.key_compare = COMPARE_SAFE;
        }
    } else {
        ms.key_compare = COMPARE_SAFE;
    }
    if keys_are_in_tuples {
        ms.tuple_elem_compare = COMPARE_SAFE
            if key_type == tuple_type
            else ms.key_compare;
        ms.key_compare = COMPARE_TUPLE;
    }
}

impl merge_sort(
    ms: MergeState, lo_keys: ptr[ptr[PyObject]], lo_values: ptr[ptr[PyObject]], n: i64
) -> i32 {
    keys = lo_keys;
    values = lo_values;
    nremaining = n;
    minrun = merge_compute_minrun(nremaining);
    while nremaining > 0 {
        run = count_run(ms, keys, values, nremaining);
        if run < 0 {
            return i32(-1);
        }
        if run < minrun {
            force = nremaining if nremaining <= minrun else minrun;
            if binarysort(ms, keys, values, force, run) < 0 {
                return i32(-1);
            }
            run = force;
        }

        if ms.n == 0 and run == nremaining {
            return i32(0);
        }
        if not ms.pending {
            ms.pending = ptr[i64](
                PyMem_Malloc(u64(MAX_MERGE_PENDING * PENDING_WORDS * 8))
            );
            if not ms.pending {
                PyErr_NoMemory();
                return i32(-1);
            }
        }
        if found_new_run(ms, run) < 0 {
            return i32(-1);
        }

        set_pending(ms, ms.n, keys, values, run);
        ms.n += 1;
        keys = keys + run;
        values = values + run;
        nremaining -= run;
    }
    return merge_force_collapse(ms);
}

impl list_sort_impl(
    op: ptr[PyObject], keyfunc_in: ptr[PyObject], reverse: i32
) -> ptr[PyObject] {
    keyfunc = NULL if keyfunc_in == Py_None else keyfunc_in;

    saved_ob_size = object_size(op);
    saved_ob_item = list_items(op);
    saved_allocated = list_allocated(op);
    set_size(op, 0);
    set_items(op, no_items());

    set_allocated(op, -1);
    result = NULL;
    keys = no_items();
    keyfunc_failed = False;
    lo_keys = saved_ob_item;
    lo_values = no_items();
    if keyfunc {
        keys = items_new(saved_ob_size);
        if not keys {
            PyErr_NoMemory();
            keyfunc_failed = True;
        } else {
            for i in range(saved_ob_size) {
                key = PyObject_CallOneArg(keyfunc, item_at(saved_ob_item, i));
                if not key {
                    j = i - 1;
                    while j >= 0 {
                        object_decref(item_at(keys, j));
                        j -= 1;
                    }
                    PyMem_Free(ptr(keys));
                    keyfunc_failed = True;
                    break;
                }
                set_item_at(keys, i, key);
            }
        }
        lo_keys = keys;
        lo_values = saved_ob_item;
    }
    if not keyfunc_failed {
        ms = MergeState(
            listlen=saved_ob_size, basekeys=lo_keys, has_values=keyfunc != NULL
        );
        if saved_ob_size > 1 {
            choose_compares(ms, lo_keys, saved_ob_size);
        }
        status = i32(0);
        if saved_ob_size >= 2 {
            if reverse != 0 {
                if keyfunc {
                    reverse_items(keys, saved_ob_size);
                }
                reverse_items(saved_ob_item, saved_ob_size);
            }
            status = merge_sort(ms, lo_keys, lo_values, saved_ob_size);
        }
        if status == 0 {
            result = Py_None;
        }
        if keyfunc {
            for i in range(saved_ob_size) {
                object_decref(item_at(keys, i));
            }
            PyMem_Free(ptr(keys));
        }
        if list_allocated(op) != -1 and result {
            PyErr_SetString(PyExc_ValueError, "list modified during sort");
            result = NULL;
        }
        if reverse != 0 and saved_ob_size > 1 {
            reverse_items(saved_ob_item, saved_ob_size);
        }
        merge_freemem(ms);
        if ms.pending {
            PyMem_Free(ptr(ms.pending));
        }
    }

    final_ob_item = list_items(op);
    i = object_size(op);
    set_size(op, saved_ob_size);
    set_items(op, saved_ob_item);
    set_allocated(op, saved_allocated);
    if final_ob_item {
        while i > 0 {
            i -= 1;
            object_xdecref(item_at(final_ob_item, i));
        }
        PyMem_Free(ptr(final_ob_item));
    }
    return object_xnew_ref(result);
}

impl list_sort_bound(args: BoundArguments) -> ptr[PyObject] {
    reverse = i32(0);
    if args.values[1] {
        reverse = PyObject_IsTrue(args.values[1]);
        if reverse < 0 {
            return NULL;
        }
    }
    return list_sort_impl(args.context, args.values[0], reverse);
}

impl list_sort(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 0 and not kwnames {
        return list_sort_impl(op, NULL, i32(0));
    }
    return invoke_vector(
        list_sort_signature, args, nargs, kwnames, list_sort_bound, op
    );
}

impl list_reverse(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    if object_size(op) > 1 {
        reverse_items(list_items(op), object_size(op));
    }
    return object_new_ref(Py_None);
}

impl list_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3) and _PyArg_CheckPositional("index", nargs, 1, 3) == 0 {
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
    if start < 0 {
        start += object_size(op);
        if start < 0 {
            start = 0;
        }
    }
    if stop < 0 {
        stop += object_size(op);
        if stop < 0 {
            stop = 0;
        }
    }
    i = start;
    while i < stop {
        found = list_get_item_ref(op, i);
        if not found {
            break;
        }
        cmp = PyObject_RichCompareBool(found, value, Py_EQ);
        object_decref(found);
        if cmp > 0 {
            return PyLong_FromSsize_t(i);
        }
        if cmp < 0 {
            return NULL;
        }
        i += 1;
    }
    PyErr_SetString(PyExc_ValueError, "list.index(x): x not in list");
    return NULL;
}

impl list_count(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    count: i64 = 0;
    i = 0;
    while True {
        found = list_get_item_ref(op, i);
        if not found {
            break;
        }
        i += 1;
        if found == value {
            count += 1;
            object_decref(found);
            continue;
        }
        cmp = PyObject_RichCompareBool(found, value, Py_EQ);
        object_decref(found);
        if cmp > 0 {
            count += 1;
        } elif cmp < 0 {
            return NULL;
        }
    }
    return PyLong_FromSsize_t(count);
}

impl list_remove(op: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    i = 0;
    while i < object_size(op) {
        found = object_new_ref(item_at(list_items(op), i));
        cmp = PyObject_RichCompareBool(found, value, Py_EQ);
        object_decref(found);
        if cmp > 0 {
            if list_ass_slice_items(op, i, i + 1, NULL) == 0 {
                return object_new_ref(Py_None);
            }
            return NULL;
        }
        if cmp < 0 {
            return NULL;
        }
        i += 1;
    }
    PyErr_SetString(PyExc_ValueError, "list.remove(x): x not in list");
    return NULL;
}

impl list_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    items = list_items(op);
    i = object_size(op);
    while i > 0 {
        i -= 1;
        status = visit_reference(item_at(items, i), visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

impl list_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not list_check(v) or not list_check(w) {
        return object_new_ref(Py_NotImplemented);
    }
    if object_size(v) != object_size(w) and (op == Py_EQ or op == Py_NE) {
        return object_new_ref(py_false() if op == Py_EQ else py_true());
    }

    i = 0;
    while i < object_size(v) and i < object_size(w) {
        vitem = item_at(list_items(v), i);
        witem = item_at(list_items(w), i);
        if vitem != witem {
            object_incref(vitem);
            object_incref(witem);
            k = PyObject_RichCompareBool(vitem, witem, Py_EQ);
            object_decref(vitem);
            object_decref(witem);
            if k < 0 {
                return NULL;
            }
            if k == 0 {
                break;
            }
        }
        i += 1;
    }
    if i >= object_size(v) or i >= object_size(w) {
        return rich_compare_values(object_size(v), object_size(w), op);
    }
    if op == Py_EQ {
        return object_new_ref(py_false());
    }
    if op == Py_NE {
        return object_new_ref(py_true());
    }
    vitem = item_at(list_items(v), i);
    witem = item_at(list_items(w), i);
    object_incref(vitem);
    object_incref(witem);
    result = PyObject_RichCompare(vitem, witem, op);
    object_decref(vitem);
    object_decref(witem);
    return result;
}

impl list___init___impl(op: ptr[PyObject], iterable: ptr[PyObject]) -> i32 {
    if list_items(op) {
        list_clear(op);
    }
    if iterable and list_extend_any(op, iterable) < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl list___init__(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    base = addressof(PyList_Type);
    if (
        object_is_type(op, base)
        or int(object_type(op).view(1)[0].tp_new) == int(base.view(1)[0].tp_new)
    )
        and kwargs
        and _PyArg_NoKeywords("list", kwargs) == 0 {
        return i32(-1);
    }
    nargs = object_size(args);
    if nargs > 1 and _PyArg_CheckPositional("list", nargs, 0, 1) == 0 {
        return i32(-1);
    }
    iterable = tuple_get_item(args, 0) if nargs >= 1 else NULL;
    return list___init___impl(op, iterable);
}

impl list_vectorcall(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames and _PyArg_NoKwnames("list", kwnames) == 0 {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if nargs > 1 and _PyArg_CheckPositional("list", nargs, 0, 1) == 0 {
        return NULL;
    }
    op = PyType_GenericAlloc(type, 0);
    if not op {
        return NULL;
    }
    if nargs != 0 and list___init___impl(op, args.view(1)[0]) != 0 {
        object_decref(op);
        return NULL;
    }
    return op;
}

impl list___sizeof__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    size = object_type(op).view(1)[0].tp_basicsize + list_allocated(op) * 8;
    return PyLong_FromSize_t(u64(size));
}

impl list_slice_step(
    a: ptr[PyObject], start: i64, step: i64, length: i64
) -> ptr[PyObject] {
    np = list_new_prealloc(length);
    if not np {
        return NULL;
    }
    src = list_items(a);
    dest = list_items(np);
    cur = start;
    for i in range(length) {
        set_item_at(dest, i, object_new_ref(item_at(src, cur)));
        cur = wrapping_add(cur, step);
    }
    set_size(np, length);
    return np;
}

impl list_slice_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    start: i64 = 0;
    stop: i64 = 0;
    step: i64 = 0;
    if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < 0 {
        return NULL;
    }
    length = PySlice_AdjustIndices(object_size(op), &mut start, &mut stop, step);
    if length <= 0 {
        return PyList_New(0);
    }
    if step == 1 {
        return list_slice(op, start, stop);
    }
    return list_slice_step(op, start, step, length);
}

impl slice_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, type_of_object(addressof(PySlice_Type)));
}

impl list_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        if i < 0 {
            i += object_size(op);
        }
        return list_item(op, i);
    }
    if slice_check(item) {
        return list_slice_subscript(op, item);
    }
    PyErr_Format(
        PyExc_TypeError,
        "list indices must be integers or slices, not %.200s",
        object_type(item).view(1)[0].tp_name
    );
    return NULL;
}

impl list_delete_extended(
    op: ptr[PyObject], start_in: i64, stop_in: i64, step_in: i64, slicelength: i64
) -> i32 {
    start = start_in;
    stop = stop_in;
    step = step_in;
    if step < 0 {
        stop = start + 1;
        start = stop + step * (slicelength - 1) - 1;
        step = -step;
    }
    garbage = items_new(slicelength);
    if not garbage {
        PyErr_NoMemory();
        return i32(-1);
    }

    items = list_items(op);
    size = object_size(op);
    usize = u64.wrap(size);
    ustep = u64.wrap(step);
    cur = u64.wrap(start);
    i = 0;
    while cur < u64.wrap(stop) {
        lim = step - 1;
        set_item_at(garbage, i, item_at(items, i64.wrap(cur)));
        if wrapping_add(cur, ustep) >= usize {
            lim = size - i64.wrap(cur) - 1;
        }
        jacpy_memory_move(
            ptr(items + (i64.wrap(cur) - i)), ptr(items + (i64.wrap(cur) + 1)), lim * 8
        );
        cur = wrapping_add(cur, ustep);
        i += 1;
    }
    cur = wrapping_add(u64.wrap(start), wrapping_mul(u64.wrap(slicelength), ustep));
    if cur < usize {
        tail = i64.wrap(cur);
        jacpy_memory_move(
            ptr(items + (tail - slicelength)), ptr(items + tail), (size - tail) * 8
        );
    }
    set_size(op, size - slicelength);
    res = list_resize(op, object_size(op));
    for j in range(slicelength) {
        object_decref(item_at(garbage, j));
    }
    PyMem_Free(ptr(garbage));
    return res;
}

impl list_assign_extended(
    op: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    start: i64 = 0;
    stop: i64 = 0;
    step: i64 = 0;
    if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < 0 {
        return i32(-1);
    }
    if not value {
        slicelength = PySlice_AdjustIndices(
            object_size(op), &mut start, &mut stop, step
        );

        if (step < 0 and start < stop) or (step > 0 and start > stop) {
            stop = start;
        }
        if step == 1 {
            return list_ass_slice_items(op, start, stop, value);
        }
        if slicelength <= 0 {
            return i32(0);
        }
        return list_delete_extended(op, start, stop, step, slicelength);
    }

    seq = NULL;
    if op == value {
        seq = list_slice(value, 0, object_size(value));
    } else {
        seq = PySequence_Fast(value, ptr[u8]("must assign iterable to extended slice"));
    }
    if not seq {
        return i32(-1);
    }
    slicelength = PySlice_AdjustIndices(object_size(op), &mut start, &mut stop, step);
    if (step < 0 and start < stop) or (step > 0 and start > stop) {
        stop = start;
    }
    if step == 1 {
        res = list_ass_slice_items(op, start, stop, seq);
        object_decref(seq);
        return res;
    }
    if object_size(seq) != slicelength {
        PyErr_Format(
            PyExc_ValueError,
            "attempt to assign sequence of size %zd to extended slice of size %zd",
            object_size(seq),
            slicelength
        );
        object_decref(seq);
        return i32(-1);
    }
    if slicelength == 0 {
        object_decref(seq);
        return i32(0);
    }
    garbage = items_new(slicelength);
    if not garbage {
        object_decref(seq);
        PyErr_NoMemory();
        return i32(-1);
    }
    selfitems = list_items(op);
    seqitems = fast_items(seq);
    cur = start;
    for i in range(slicelength) {
        set_item_at(garbage, i, item_at(selfitems, cur));
        set_item_at(selfitems, cur, object_new_ref(item_at(seqitems, i)));
        cur = wrapping_add(cur, step);
    }
    for i in range(slicelength) {
        object_decref(item_at(garbage, i));
    }
    PyMem_Free(ptr(garbage));
    object_decref(seq);
    return i32(0);
}

impl list_ass_subscript(
    op: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        if i < 0 {
            i += object_size(op);
        }
        return list_ass_item(op, i, value);
    }
    if slice_check(item) {
        return list_assign_extended(op, item, value);
    }
    PyErr_Format(
        PyExc_TypeError,
        "list indices must be integers or slices, not %.200s",
        object_type(item).view(1)[0].tp_name
    );
    return i32(-1);
}

impl list_iter(seq: ptr[PyObject]) -> ptr[PyObject] {
    if not list_check(seq) {
        PyErr_BadInternalCall();
        return NULL;
    }
    op = freelist_pop(_Py_freelists_LIST_ITERS);
    if not op {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyListIter_Type)));
        if not op {
            return NULL;
        }
    }
    it = listiter_of(op);
    it.view(1)[0].it_index = 0;
    it.view(1)[0].it_seq = list_of(object_new_ref(seq));
    object_gc_track(op);
    return op;
}

impl listiter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(ptr[PyObject](listiter_of(op).view(1)[0].it_seq));
    if not freelist_push(_Py_freelists_LIST_ITERS, op, Py_list_iters_MAXFREELIST) {
        PyObject_GC_Del(ptr(op));
    }
}

impl listiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(
        ptr[PyObject](listiter_of(op).view(1)[0].it_seq), visitor, arg
    );
}

impl listiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = listiter_of(op);
    index = it.view(1)[0].it_index;
    if index < 0 {
        return NULL;
    }
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    item = list_get_item_ref(seq, index);
    if not item {
        it.view(1)[0].it_index = -1;
        it.view(1)[0].it_seq = ptr[PyListObject]();
        object_decref(seq);
        return NULL;
    }
    it.view(1)[0].it_index = index + 1;
    return item;
}

impl listiter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    it = listiter_of(op);
    index = it.view(1)[0].it_index;
    if index >= 0 {
        length = object_size(ptr[PyObject](it.view(1)[0].it_seq)) - index;
        if length >= 0 {
            return PyLong_FromSsize_t(length);
        }
    }
    return PyLong_FromSsize_t(0);
}

impl listiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return listiter_reduce_general(op, True);
}

impl listiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    it = listiter_of(op);
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    if seq {
        if index < -1 {
            index = -1;
        } elif index > object_size(seq) {
            index = object_size(seq);
        }
        it.view(1)[0].it_index = index;
    }
    return object_new_ref(Py_None);
}

impl list___reversed__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    result = _PyObject_GC_New(ptr[PyObject](addressof(PyListRevIter_Type)));
    if not result {
        return NULL;
    }
    it = listiter_of(result);
    it.view(1)[0].it_index = object_size(op) - 1;
    it.view(1)[0].it_seq = list_of(object_new_ref(op));
    object_gc_track(result);
    return result;
}

impl listreviter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(ptr[PyObject](listiter_of(op).view(1)[0].it_seq));
    PyObject_GC_Del(ptr(op));
}

impl listreviter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(
        ptr[PyObject](listiter_of(op).view(1)[0].it_seq), visitor, arg
    );
}

impl listreviter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = listiter_of(op);
    index = it.view(1)[0].it_index;
    if index < 0 {
        return NULL;
    }
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    item = list_get_item_ref(seq, index);
    if item {
        it.view(1)[0].it_index = index - 1;
        return item;
    }
    it.view(1)[0].it_index = -1;
    it.view(1)[0].it_seq = ptr[PyListObject]();
    object_decref(seq);
    return NULL;
}

impl listreviter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    it = listiter_of(op);
    length = it.view(1)[0].it_index + 1;
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    if not seq or object_size(seq) < length {
        length = 0;
    }
    return PyLong_FromSsize_t(length);
}

impl listreviter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return listiter_reduce_general(op, False);
}

impl listreviter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    it = listiter_of(op);
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    seq = ptr[PyObject](it.view(1)[0].it_seq);
    if seq {
        if index < -1 {
            index = -1;
        } elif index > object_size(seq) - 1 {
            index = object_size(seq) - 1;
        }
        it.view(1)[0].it_index = index;
    }
    return object_new_ref(Py_None);
}

impl listiter_reduce_general(op: ptr[PyObject], forward: bool) -> ptr[PyObject] {
    iter = eval_builtin("iter" if forward else "reversed");
    it = listiter_of(op);
    index = it.view(1)[0].it_index;
    if index >= 0 {
        return Py_BuildValue("N(O)n", iter, ptr[PyObject](it.view(1)[0].it_seq), index);
    }
    empty = PyList_New(0);
    if not empty {
        object_xdecref(iter);
        return NULL;
    }
    return Py_BuildValue("N(N)", iter, empty);
}
