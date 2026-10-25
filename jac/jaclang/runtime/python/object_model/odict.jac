import from c {
    glob PyType_Type: PyTypeObject; def PyObject_Length(o: ptr[PyObject]) -> i64;  def _PyErr_ChainExceptions1(
        exc: ptr[PyObject]
    );  def _PyObject_GetState(ob: ptr[PyObject]) -> ptr[PyObject];  def PyObject_GenericSetDict(
        ob: ptr[PyObject], value: ptr[PyObject], context: ptr
    ) -> i32;  def PyObject_GenericGetDict(
        ob: ptr[PyObject], context: ptr
    ) -> ptr[PyObject];  def _PyDict_SetItem_KnownHash_LockHeld(
        mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], hash: i64
    ) -> i32;  def _PyDict_DelItem_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64
    ) -> i32;  def _PyDict_DelItem_KnownHash_LockHeld(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64
    ) -> i32;  def _PyDict_Pop_KnownHash(
        mp: ptr[PyObject], key: ptr[PyObject], hash: i64, result: ptr[ptr[PyObject]]
    ) -> i32;  def _PyDict_Clear_LockHeld(op: ptr[PyObject]);  def _PyDict_SizeOf_LockHeld(
        mp: ptr[PyObject]
    ) -> i64;  def _PyDict_FromKeys(
        cls: ptr[PyObject], iterable: ptr[PyObject], value: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyDictView_New(
        dict: ptr[PyObject], type: ptr[PyTypeObject]
    ) -> ptr[PyObject];  glob:priv items_key: ptr[PyObject] = ptr[PyObject](),
         keys_name: ptr[PyObject] = ptr[PyObject](),
         odict_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_ass_subscript=odict_mp_ass_sub
         ),
         odict_as_number: PyNumberMethods = PyNumberMethods(
             nb_or=odict_or, nb_inplace_or=odict_inplace_or
         ),
         odict_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("fromkeys"),
                 ml_meth=ptr(odict_fromkeys),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS | METH_CLASS,
                 ml_doc=ptr[u8](
                     "fromkeys($type, /, iterable, value=None)\n--\n\n"
                     "Create a new ordered dictionary with keys from iterable and values set to value."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(odict___sizeof__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__sizeof__($self, /)\n--\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(odict___reduce__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__reduce__($self, /)\n--\n\nReturn state information for pickling"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setdefault"),
                 ml_meth=ptr(odict_setdefault),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "setdefault($self, /, key, default=None)\n--\n\n"
                     "Insert key with a value of default if key is not in the dictionary.\n\n"
                     "Return the value for key if key is in the dictionary, else default."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("pop"),
                 ml_meth=ptr(odict_pop),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "pop($self, /, key, default=<unrepresentable>)\n--\n\n"
                     "od.pop(key[,default]) -> v, remove specified key and return the corresponding value.\n\n"
                     "If the key is not found, return the default if given; otherwise,\n"
                     "raise a KeyError."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("popitem"),
                 ml_meth=ptr(odict_popitem),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "popitem($self, /, last=True)\n--\n\n"
                     "Remove and return a (key, value) pair from the dictionary.\n\n"
                     "Pairs are returned in LIFO order if last is true or FIFO order if\n"
                     "false."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("keys"),
                 ml_meth=ptr(odictkeys_new),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("values"),
                 ml_meth=ptr(odictvalues_new),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("items"),
                 ml_meth=ptr(odictitems_new),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("update"),
                 ml_meth=ptr(mutablemapping_update),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("clear"),
                 ml_meth=ptr(odict_clear),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "clear($self, /)\n--\n\nRemove all items from ordered dict."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(odict_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("copy($self, /)\n--\n\nA shallow copy of ordered dict.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(odict_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("od.__reversed__() <==> reversed(od)")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("move_to_end"),
                 ml_meth=ptr(odict_move_to_end),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "move_to_end($self, /, key, last=True)\n--\n\n"
                     "Move an existing element to the end (or beginning if last is false).\n\n"
                     "Raise KeyError if the element does not exist."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         odict_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=PyObject_GenericGetDict,
                 set=PyObject_GenericSetDict
             ),
             PyGetSetDef()
         ],
         odictiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(odictiter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         odictkeys_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(odictkeys_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         odictitems_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(odictitems_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         odictvalues_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(odictvalues_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyODict_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("collections.OrderedDict"),
             tp_basicsize=PyODictObject_SIZE,
             tp_dealloc=odict_dealloc,
             tp_repr=odict_repr,
             tp_as_number=addressof(odict_as_number),
             tp_as_mapping=addressof(odict_as_mapping),
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("Dictionary that remembers insertion order"),
             tp_traverse=odict_traverse,
             tp_clear=odict_tp_clear,
             tp_richcompare=odict_richcompare,
             tp_weaklistoffset=PyODictObject_WEAKREFLIST,
             tp_iter=odict_iter,
             tp_methods=addressof(odict_methods),
             tp_getset=addressof(odict_getset),
             tp_base=ptr[PyTypeObject](addressof(PyDict_Type)),
             tp_dictoffset=PyODictObject_INST_DICT,
             tp_init=odict_init,
             tp_alloc=PyType_GenericAlloc
         ),
         PyODictIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("odict_iterator"),
             tp_basicsize=odictiterobject_SIZE,
             tp_dealloc=odictiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=odictiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=odictiter_iternext,
             tp_methods=addressof(odictiter_methods)
         ),
         PyODictKeys_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("odict_keys"),
             tp_iter=odictkeys_iter,
             tp_methods=addressof(odictkeys_methods),
             tp_base=ptr[PyTypeObject](addressof(PyDictKeys_Type))
         ),
         PyODictItems_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("odict_items"),
             tp_iter=odictitems_iter,
             tp_methods=addressof(odictitems_methods),
             tp_base=ptr[PyTypeObject](addressof(PyDictItems_Type))
         ),
         PyODictValues_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("odict_values"),
             tp_iter=odictvalues_iter,
             tp_methods=addressof(odictvalues_methods),
             tp_base=ptr[PyTypeObject](addressof(PyDictValues_Type))
         );
}

glob:priv DKIX_EMPTY: i64 = -1,
     ITER_REVERSED: i32 = 1,
     ITER_KEYS: i32 = 2,
     ITER_VALUES: i32 = 4,
     ITER_ITEMS: i32 = 6,
     fromkeys_signature = CallSignature(
         "fromkeys", ["iterable", "value"], 1, 2, 0, parser=PARSE_KEYWORDS
     ),
     setdefault_signature = CallSignature(
         "setdefault", ["key", "default"], 1, 2, 0, parser=PARSE_KEYWORDS
     ),
     pop_signature = CallSignature(
         "pop", ["key", "default"], 1, 2, 0, parser=PARSE_KEYWORDS
     ),
     popitem_signature = CallSignature(
         "popitem", ["last"], 0, 1, 0, parser=PARSE_KEYWORDS
     ),
     move_to_end_signature = CallSignature(
         "move_to_end", ["key", "last"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

def od_of(op: ptr[PyObject]) -> ptr[PyODictObject];

def od_first(op: ptr[PyObject]) -> ptr[_ODictNode];

def od_last(op: ptr[PyObject]) -> ptr[_ODictNode];

def set_first(op: ptr[PyObject], link: ptr[_ODictNode]);

def set_last(op: ptr[PyObject], link: ptr[_ODictNode]);

def node_next(link: ptr[_ODictNode]) -> ptr[_ODictNode];

def node_prev(link: ptr[_ODictNode]) -> ptr[_ODictNode];

def node_key(link: ptr[_ODictNode]) -> ptr[PyObject];

def fast_nodes(op: ptr[PyObject]) -> ptr[ptr[_ODictNode]];

def bump_state(op: ptr[PyObject]);

def odict_check(op: ptr[PyObject]) -> bool;

def odict_check_exact(op: ptr[PyObject]) -> bool;

def get_index_raw(op: ptr[PyObject], key: ptr[PyObject], hash: i64) -> i64;

def odict_resize(op: ptr[PyObject]) -> i32;

def get_index(op: ptr[PyObject], key: ptr[PyObject], hash: i64) -> i64;

def find_node_hash(
    op: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> ptr[_ODictNode];

def find_node(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[_ODictNode];

def add_head(op: ptr[PyObject], link: ptr[_ODictNode]);

def add_tail(op: ptr[PyObject], link: ptr[_ODictNode]);

def add_new_node(op: ptr[PyObject], key: ptr[PyObject], hash: i64) -> i32;

def node_dealloc(link: ptr[_ODictNode]);

def remove_node(op: ptr[PyObject], link: ptr[_ODictNode]);

def clear_node(
    op: ptr[PyObject], node_in: ptr[_ODictNode], key: ptr[PyObject], hash: i64
) -> i32;

def clear_nodes(op: ptr[PyObject]);

def keys_equal(a: ptr[PyObject], b: ptr[PyObject]) -> i32;

def set_item_known_hash(
    op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], hash: i64
) -> i32;

def set_item(op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]) -> i32;

import from c {
    def PyODict_New -> ptr[PyObject] {
        return dict_new(ptr[PyObject](addressof(PyODict_Type)), NULL, NULL);
    }  def PyODict_SetItem(
        od: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i32 {
        return set_item(od, key, value);
    }  def PyODict_DelItem(od: ptr[PyObject], key: ptr[PyObject]) -> i32 {
        hash = PyObject_Hash(key);
        if hash == -1 {
            return i32(-1);
        }
        if clear_node(od, ptr[_ODictNode](), key, hash) < 0 {
            return i32(-1);
        }
        return _PyDict_DelItem_KnownHash_LockHeld(od, key, hash);
    }
}

def odict_mp_ass_sub(od: ptr[PyObject], v: ptr[PyObject], w: ptr[PyObject]) -> i32;

def odict_or(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def odict_inplace_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def odict_fromkeys_bound(args: BoundArguments) -> ptr[PyObject];

def odict_fromkeys(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def odict___sizeof__(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odict___reduce__(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def interned_items -> ptr[PyObject];

def interned_keys -> ptr[PyObject];

def odict_setdefault_bound(args: BoundArguments) -> ptr[PyObject];

def odict_setdefault(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def popkey_hash(
    od: ptr[PyObject], key: ptr[PyObject], failobj: ptr[PyObject], hash: i64
) -> ptr[PyObject];

def odict_pop_bound(args: BoundArguments) -> ptr[PyObject];

def odict_pop(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def bool_argument(value: ptr[PyObject]) -> i32;

def odict_popitem_bound(args: BoundArguments) -> ptr[PyObject];

def odict_popitem(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def odict_clear(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odict_copy(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odict_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odict_move_to_end_bound(args: BoundArguments) -> ptr[PyObject];

def odict_move_to_end(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def odict_dealloc(op: ptr[PyObject]);

def odict_repr(op: ptr[PyObject]) -> ptr[PyObject];

def odict_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def odict_tp_clear(op: ptr[PyObject]) -> i32;

def odict_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject];

def odict_iter(op: ptr[PyObject]) -> ptr[PyObject];

def odict_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def oiter_of(op: ptr[PyObject]) -> ptr[odictiterobject];

def oiter_odict(op: ptr[PyObject]) -> ptr[PyObject];

def oiter_current(op: ptr[PyObject]) -> ptr[PyObject];

def oiter_clear_odict(op: ptr[PyObject]);

def oiter_clear_current(op: ptr[PyObject]);

def odictiter_new(op: ptr[PyObject], kind: i32) -> ptr[PyObject];

def odictiter_dealloc(op: ptr[PyObject]);

def odictiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def odictiter_nextkey(op: ptr[PyObject]) -> ptr[PyObject];

def odictiter_iternext(op: ptr[PyObject]) -> ptr[PyObject];

def odictiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def view_odict(op: ptr[PyObject]) -> ptr[PyObject];

def view_iter(op: ptr[PyObject], kind: i32) -> ptr[PyObject];

def odictkeys_iter(op: ptr[PyObject]) -> ptr[PyObject];

def odictkeys_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odictkeys_new(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odictitems_iter(op: ptr[PyObject]) -> ptr[PyObject];

def odictitems_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odictitems_new(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odictvalues_iter(op: ptr[PyObject]) -> ptr[PyObject];

def odictvalues_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def odictvalues_new(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def mutablemapping_add_pairs(self: ptr[PyObject], pairs: ptr[PyObject]) -> i32;

def mutablemapping_update_arg(self: ptr[PyObject], arg: ptr[PyObject]) -> i32;

def mutablemapping_update(
    self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

impl od_of(op: ptr[PyObject]) -> ptr[PyODictObject] {
    return ptr[PyODictObject](op);
}

impl od_first(op: ptr[PyObject]) -> ptr[_ODictNode] {
    return ptr[_ODictNode](od_of(op).view(1)[0].od_first);
}

impl od_last(op: ptr[PyObject]) -> ptr[_ODictNode] {
    return ptr[_ODictNode](od_of(op).view(1)[0].od_last);
}

impl set_first(op: ptr[PyObject], link: ptr[_ODictNode]) {
    od_of(op).view(1)[0].od_first = ptr[_ODictNode](link);
}

impl set_last(op: ptr[PyObject], link: ptr[_ODictNode]) {
    od_of(op).view(1)[0].od_last = ptr[_ODictNode](link);
}

impl node_next(link: ptr[_ODictNode]) -> ptr[_ODictNode] {
    return ptr[_ODictNode](link.view(1)[0].next);
}

impl node_prev(link: ptr[_ODictNode]) -> ptr[_ODictNode] {
    return ptr[_ODictNode](link.view(1)[0].prev);
}

impl node_key(link: ptr[_ODictNode]) -> ptr[PyObject] {
    return ptr[PyObject](link.view(1)[0].key);
}

impl fast_nodes(op: ptr[PyObject]) -> ptr[ptr[_ODictNode]] {
    return ptr[ptr[_ODictNode]](od_of(op).view(1)[0].od_fast_nodes);
}

impl bump_state(op: ptr[PyObject]) {
    od = od_of(op);
    od.view(1)[0].od_state = od.view(1)[0].od_state + u64(1);
}

impl odict_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(PyODict_Type));
}

impl odict_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyODict_Type));
}

impl get_index_raw(op: ptr[PyObject], key: ptr[PyObject], hash: i64) -> i64 {
    (ix, value) = dict_lookup(op, key, hash);
    if ix == DKIX_EMPTY {
        return dk_nentries(dict_keys_of(op));
    }
    if ix < 0 {
        return -1;
    }
    return ix;
}

impl odict_resize(op: ptr[PyObject]) -> i32 {
    size = 1 << dk_log2_size(dict_keys_of(op));
    table = ptr[ptr[_ODictNode]](PyMem_Malloc(u64(size * 8)));
    if not table {
        PyErr_NoMemory();
        return i32(-1);
    }
    for i in range(size) {
        (table + i).view(1)[0] = ptr[_ODictNode]();
    }
    link = od_first(op);
    while link {
        i = get_index_raw(op, node_key(link), link.view(1)[0].hash);
        if i < 0 {
            PyMem_Free(ptr(table));
            return i32(-1);
        }
        (table + i).view(1)[0] = link;
        link = node_next(link);
    }
    od = od_of(op);
    PyMem_Free(od.view(1)[0].od_fast_nodes);
    od.view(1)[0].od_fast_nodes = ptr[ptr[_ODictNode]](table);
    od.view(1)[0].od_fast_nodes_size = size;
    od.view(1)[0].od_resize_sentinel = ptr(dict_keys_of(op));
    return i32(0);
}

impl get_index(op: ptr[PyObject], key: ptr[PyObject], hash: i64) -> i64 {
    k = dict_keys_of(op);
    od = od_of(op);
    if ptr[u8](od.view(1)[0].od_resize_sentinel) != k
        or od.view(1)[0].od_fast_nodes_size != (1 << dk_log2_size(k)) {
        if odict_resize(op) < 0 {
            return -1;
        }
    }
    return get_index_raw(op, key, hash);
}

impl find_node_hash(
    op: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> ptr[_ODictNode] {
    if not od_first(op) {
        return ptr[_ODictNode]();
    }
    index = get_index(op, key, hash);
    if index < 0 {
        return ptr[_ODictNode]();
    }
    return (fast_nodes(op) + index).view(1)[0];
}

impl find_node(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[_ODictNode] {
    if not od_first(op) {
        return ptr[_ODictNode]();
    }
    hash = PyObject_Hash(key);
    if hash == -1 {
        return ptr[_ODictNode]();
    }
    return find_node_hash(op, key, hash);
}

impl add_head(op: ptr[PyObject], link: ptr[_ODictNode]) {
    link.view(1)[0].prev = ptr[_ODictNode]();
    link.view(1)[0].next = ptr[_ODictNode](od_first(op));
    if not od_first(op) {
        set_last(op, link);
    } else {
        od_first(op).view(1)[0].prev = ptr[_ODictNode](link);
    }
    set_first(op, link);
    bump_state(op);
}

impl add_tail(op: ptr[PyObject], link: ptr[_ODictNode]) {
    link.view(1)[0].prev = ptr[_ODictNode](od_last(op));
    link.view(1)[0].next = ptr[_ODictNode]();
    if not od_last(op) {
        set_first(op, link);
    } else {
        od_last(op).view(1)[0].next = ptr[_ODictNode](link);
    }
    set_last(op, link);
    bump_state(op);
}

impl add_new_node(op: ptr[PyObject], key: ptr[PyObject], hash: i64) -> i32 {
    object_incref(key);
    i = get_index(op, key, hash);
    if i < 0 {
        if not PyErr_Occurred() {
            PyErr_SetObject(PyExc_KeyError, key);
        }
        object_decref(key);
        return i32(-1);
    }
    if (fast_nodes(op) + i).view(1)[0] {
        object_decref(key);
        return i32(0);
    }
    link = ptr[_ODictNode](PyMem_Malloc(u64(_ODictNode_SIZE)));
    if not link {
        object_decref(key);
        PyErr_NoMemory();
        return i32(-1);
    }
    link.view(1)[0].key = ptr[PyObject](key);
    link.view(1)[0].hash = hash;
    add_tail(op, link);
    (fast_nodes(op) + i).view(1)[0] = link;
    return i32(0);
}

impl node_dealloc(link: ptr[_ODictNode]) {
    object_decref(node_key(link));
    PyMem_Free(ptr(link));
}

impl remove_node(op: ptr[PyObject], link: ptr[_ODictNode]) {
    if od_first(op) == link {
        set_first(op, node_next(link));
    } elif node_prev(link) {
        node_prev(link).view(1)[0].next = ptr[_ODictNode](node_next(link));
    }
    if od_last(op) == link {
        set_last(op, node_prev(link));
    } elif node_next(link) {
        node_next(link).view(1)[0].prev = ptr[_ODictNode](node_prev(link));
    }
    link.view(1)[0].prev = ptr[_ODictNode]();
    link.view(1)[0].next = ptr[_ODictNode]();
    bump_state(op);
}

impl clear_node(
    op: ptr[PyObject], node_in: ptr[_ODictNode], key: ptr[PyObject], hash: i64
) -> i32 {
    if not od_first(op) {
        return i32(0);
    }
    i = get_index(op, key, hash);
    if i < 0 {
        return i32(-1) if PyErr_Occurred() else i32(0);
    }
    link = node_in;
    if not link {
        link = (fast_nodes(op) + i).view(1)[0];
    }
    if not link {
        return i32(0);
    }
    (fast_nodes(op) + i).view(1)[0] = ptr[_ODictNode]();
    remove_node(op, link);
    node_dealloc(link);
    return i32(0);
}

impl clear_nodes(op: ptr[PyObject]) {
    od = od_of(op);
    PyMem_Free(od.view(1)[0].od_fast_nodes);
    od.view(1)[0].od_fast_nodes = ptr[ptr[_ODictNode]]();
    od.view(1)[0].od_fast_nodes_size = 0;
    od.view(1)[0].od_resize_sentinel = ptr();
    link = od_first(op);
    set_first(op, ptr[_ODictNode]());
    set_last(op, ptr[_ODictNode]());
    while link {
        next = node_next(link);
        node_dealloc(link);
        link = next;
    }
    bump_state(op);
}

impl keys_equal(a: ptr[PyObject], b: ptr[PyObject]) -> i32 {
    state_a = od_of(a).view(1)[0].od_state;
    state_b = od_of(b).view(1)[0].od_state;
    node_a = od_first(a);
    node_b = od_first(b);
    while True {
        if not node_a and not node_b {
            return i32(1);
        }
        if not node_a or not node_b {
            return i32(0);
        }
        key_a = object_new_ref(node_key(node_a));
        key_b = object_new_ref(node_key(node_b));
        res = PyObject_RichCompareBool(key_a, key_b, Py_EQ);
        object_decref(key_a);
        object_decref(key_b);
        if res < 0 {
            return res;
        }
        if od_of(a).view(1)[0].od_state != state_a
            or od_of(b).view(1)[0].od_state != state_b {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("OrderedDict mutated during iteration")
            );
            return i32(-1);
        }

        if res == 0 {
            return i32(0);
        }
        node_a = node_next(node_a);
        node_b = node_next(node_b);
    }
    return i32(1);
}

impl set_item_known_hash(
    op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], hash: i64
) -> i32 {
    res = _PyDict_SetItem_KnownHash_LockHeld(op, key, value, hash);
    if res == 0 {
        res = add_new_node(op, key, hash);
        if res < 0 {
            exc = PyErr_GetRaisedException();
            _PyDict_DelItem_KnownHash(op, key, hash);
            _PyErr_ChainExceptions1(exc);
        }
    }
    return res;
}

impl set_item(op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    hash = PyObject_Hash(key);
    if hash == -1 {
        return i32(-1);
    }
    return set_item_known_hash(op, key, value, hash);
}

impl odict_mp_ass_sub(od: ptr[PyObject], v: ptr[PyObject], w: ptr[PyObject]) -> i32 {
    if not w {
        return PyODict_DelItem(od, v);
    }
    return PyODict_SetItem(od, v, w);
}

impl odict_or(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    type = object_type(left) if odict_check(left) else object_type(right);
    other = right if odict_check(left) else left;
    if not dict_check(other) {
        return object_new_ref(Py_NotImplemented);
    }
    result = PyObject_CallOneArg(ptr[PyObject](type), left);
    if not result {
        return NULL;
    }
    if mutablemapping_update_arg(result, right) < 0 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl odict_inplace_or(self: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if mutablemapping_update_arg(self, other) < 0 {
        return NULL;
    }
    return object_new_ref(self);
}

impl odict_fromkeys_bound(args: BoundArguments) -> ptr[PyObject] {
    value = args.values[1] if args.values[1] else Py_None;
    return _PyDict_FromKeys(args.context, args.values[0], value);
}

impl odict_fromkeys(
    type: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(
        fromkeys_signature, args, nargs, kwnames, odict_fromkeys_bound, type
    );
}

impl odict___sizeof__(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    res = _PyDict_SizeOf_LockHeld(self);
    res += 8 * od_of(self).view(1)[0].od_fast_nodes_size;
    if od_first(self) {
        res += _ODictNode_SIZE * dict_used(self);
    }
    return PyLong_FromSsize_t(res);
}

impl odict___reduce__(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    state = _PyObject_GetState(od);
    if not state {
        return NULL;
    }
    args = PyTuple_New(0);
    if not args {
        object_decref(state);
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    items = PyObject_CallMethodObjArgs(od, interned_items(), ptr());
    if items {
        items_iter = PyObject_GetIter(items);
        object_decref(items);
        if items_iter {
            result = PyTuple_Pack(
                5, ptr(object_type(od)), args, state, Py_None, items_iter
            );
            object_decref(items_iter);
        }
    }
    object_decref(state);
    object_decref(args);
    return result;
}

impl interned_items -> ptr[PyObject] {
    if not items_key {
        items_key = PyUnicode_InternFromString(ptr[u8]("items"));
    }
    return items_key;
}

impl interned_keys -> ptr[PyObject] {
    if not keys_name {
        keys_name = PyUnicode_InternFromString(ptr[u8]("keys"));
    }
    return keys_name;
}

impl odict_setdefault_bound(args: BoundArguments) -> ptr[PyObject] {
    self = args.context;
    key = args.values[0];
    default_value = args.values[1] if args.values[1] else Py_None;
    if odict_check_exact(self) {
        result = PyDict_GetItemWithError(self, key);
        if result {
            return object_new_ref(result);
        }
        if PyErr_Occurred() {
            return NULL;
        }
        if set_item(self, key, default_value) >= 0 {
            return object_new_ref(default_value);
        }
        return NULL;
    }
    exists = PySequence_Contains(self, key);
    if exists < 0 {
        return NULL;
    }
    if exists != 0 {
        return PyObject_GetItem(self, key);
    }
    if PyObject_SetItem(self, key, default_value) >= 0 {
        return object_new_ref(default_value);
    }
    return NULL;
}

impl odict_setdefault(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(
        setdefault_signature, args, nargs, kwnames, odict_setdefault_bound, self
    );
}

impl popkey_hash(
    od: ptr[PyObject], key: ptr[PyObject], failobj: ptr[PyObject], hash: i64
) -> ptr[PyObject] {
    link = find_node_hash(od, key, hash);
    if link {
        if clear_node(od, link, key, hash) < 0 {
            return NULL;
        }
        slot = ptr[ptr[PyObject]](PyMem_Calloc(1, 8));
        if not slot {
            return PyErr_NoMemory();
        }
        status = _PyDict_Pop_KnownHash(od, key, hash, slot);
        value = slot.view(1)[0];
        PyMem_Free(ptr(slot));
        if status == 0 {
            return object_xnew_ref(failobj);
        }
        return value;
    }
    if PyErr_Occurred() {
        return NULL;
    }
    if failobj {
        return object_new_ref(failobj);
    }
    PyErr_SetObject(PyExc_KeyError, key);
    return NULL;
}

impl odict_pop_bound(args: BoundArguments) -> ptr[PyObject] {
    key = args.values[0];
    hash = PyObject_Hash(key);
    if hash == -1 {
        return NULL;
    }
    return popkey_hash(args.context, key, args.values[1], hash);
}

impl odict_pop(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(pop_signature, args, nargs, kwnames, odict_pop_bound, self);
}

impl bool_argument(value: ptr[PyObject]) -> i32 {
    if not value {
        return i32(1);
    }
    return PyObject_IsTrue(value);
}

impl odict_popitem_bound(args: BoundArguments) -> ptr[PyObject] {
    self = args.context;
    last = bool_argument(args.values[0]);
    if last < 0 {
        return NULL;
    }
    if not od_first(self) {
        PyErr_SetString(PyExc_KeyError, ptr[u8]("dictionary is empty"));
        return NULL;
    }
    link = od_last(self) if last != 0 else od_first(self);
    key = object_new_ref(node_key(link));
    value = popkey_hash(self, key, NULL, link.view(1)[0].hash);
    if not value {
        object_decref(key);
        return NULL;
    }
    item = PyTuple_Pack(2, key, value);
    object_decref(key);
    object_decref(value);
    return item;
}

impl odict_popitem(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(
        popitem_signature, args, nargs, kwnames, odict_popitem_bound, self
    );
}

impl odict_clear(self: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    _PyDict_Clear_LockHeld(self);
    clear_nodes(self);
    return object_new_ref(Py_None);
}

impl odict_copy(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    exact = odict_check_exact(od);
    od_copy = PyODict_New()
        if exact
        else PyObject_CallNoArgs(ptr[PyObject](object_type(od)));
    if not od_copy {
        return NULL;
    }
    link = od_first(od);
    while link {
        key = node_key(link);
        if exact {
            value = PyDict_GetItemWithError(od, key);
            if not value {
                if not PyErr_Occurred() {
                    PyErr_SetObject(PyExc_KeyError, key);
                }
                object_decref(od_copy);
                return NULL;
            }
            if set_item_known_hash(od_copy, key, value, link.view(1)[0].hash) != 0 {
                object_decref(od_copy);
                return NULL;
            }
        } else {
            value = PyObject_GetItem(od, key);
            if not value {
                object_decref(od_copy);
                return NULL;
            }
            res = PyObject_SetItem(od_copy, key, value);
            object_decref(value);
            if res != 0 {
                object_decref(od_copy);
                return NULL;
            }
        }
        link = node_next(link);
    }
    return od_copy;
}

impl odict_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return odictiter_new(op, ITER_KEYS | ITER_REVERSED);
}

impl odict_move_to_end_bound(args: BoundArguments) -> ptr[PyObject] {
    self = args.context;
    key = args.values[0];
    last = bool_argument(args.values[1]);
    if last < 0 {
        return NULL;
    }
    if not od_first(self) {
        PyErr_SetObject(PyExc_KeyError, key);
        return NULL;
    }
    link = od_last(self) if last != 0 else od_first(self);
    if key != node_key(link) {
        link = find_node(self, key);
        if not link {
            if not PyErr_Occurred() {
                PyErr_SetObject(PyExc_KeyError, key);
            }
            return NULL;
        }
        if last != 0 {
            if link != od_last(self) {
                remove_node(self, link);
                add_tail(self, link);
            }
        } elif link != od_first(self) {
            remove_node(self, link);
            add_head(self, link);
        }
    }
    return object_new_ref(Py_None);
}

impl odict_move_to_end(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(
        move_to_end_signature, args, nargs, kwnames, odict_move_to_end_bound, self
    );
}

impl odict_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(op));
    od = od_of(op);
    object_xdecref(ptr[PyObject](od.view(1)[0].od_inst_dict));
    if od.view(1)[0].od_weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    clear_nodes(op);
    dict_dealloc(op);
}

impl odict_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    if dict_used(op) == 0 {
        return PyUnicode_FromFormat(
            "%s()", _PyType_Name(ptr[PyObject](object_type(op)))
        );
    }
    i = Py_ReprEnter(op);
    if i != 0 {
        return PyUnicode_FromString(ptr[u8]("...")) if i > 0 else NULL;
    }
    result: ptr[PyObject] = NULL;
    dcopy = PyDict_Copy(op);
    if dcopy {
        result = PyUnicode_FromFormat(
            "%s(%R)", _PyType_Name(ptr[PyObject](object_type(op))), dcopy
        );
        object_decref(dcopy);
    }
    Py_ReprLeave(op);
    return result;
}

impl odict_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(
        ptr[PyObject](od_of(op).view(1)[0].od_inst_dict), visitor, arg
    );
    if status != 0 {
        return status;
    }
    link = od_first(op);
    while link {
        status = visit_reference(node_key(link), visitor, arg);
        if status != 0 {
            return status;
        }
        link = node_next(link);
    }
    return dict_traverse(op, visitor, arg);
}

impl odict_tp_clear(op: ptr[PyObject]) -> i32 {
    od = od_of(op);
    inst_dict = ptr[PyObject](od.view(1)[0].od_inst_dict);
    od.view(1)[0].od_inst_dict = ptr[PyObject]();
    object_xdecref(inst_dict);
    PyDict_Clear(op);
    clear_nodes(op);
    return i32(0);
}

impl odict_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not odict_check(v) or not dict_check(w) or (op != Py_EQ and op != Py_NE) {
        return object_new_ref(Py_NotImplemented);
    }
    cmp = dict_richcompare(v, w, op);
    if not cmp {
        return NULL;
    }
    if not odict_check(w) {
        return cmp;
    }
    if (op == Py_EQ and cmp == py_false()) or (op == Py_NE and cmp == py_true()) {
        return cmp;
    }
    object_decref(cmp);

    eq = keys_equal(v, w);
    if eq < 0 {
        return NULL;
    }
    return PyBool_FromLong(1 if (eq == 1) == (op == Py_EQ) else 0);
}

impl odict_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    return odictiter_new(op, ITER_KEYS);
}

impl odict_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    length = PyObject_Length(args);
    if length == -1 {
        return i32(-1);
    }
    if length > 1 {
        PyErr_Format(
            PyExc_TypeError, ptr[u8]("expected at most 1 argument, got %zd"), length
        );
        return i32(-1);
    }

    res = mutablemapping_update(self, args, kwds);
    if not res {
        return i32(-1);
    }
    object_decref(res);
    return i32(0);
}

impl oiter_of(op: ptr[PyObject]) -> ptr[odictiterobject] {
    return ptr[odictiterobject](op);
}

impl oiter_odict(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](oiter_of(op).view(1)[0].di_odict);
}

impl oiter_current(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](oiter_of(op).view(1)[0].di_current);
}

impl oiter_clear_odict(op: ptr[PyObject]) {
    old = oiter_odict(op);
    oiter_of(op).view(1)[0].di_odict = ptr[PyODictObject]();
    object_xdecref(old);
}

impl oiter_clear_current(op: ptr[PyObject]) {
    old = oiter_current(op);
    oiter_of(op).view(1)[0].di_current = ptr[PyObject]();
    object_xdecref(old);
}

impl odictiter_new(op: ptr[PyObject], kind: i32) -> ptr[PyObject] {
    di = _PyObject_GC_New(ptr[PyObject](addressof(PyODictIter_Type)));
    if not di {
        return NULL;
    }
    it = oiter_of(di);
    it.view(1)[0].di_result = ptr[PyObject]();
    if (kind & ITER_ITEMS) == ITER_ITEMS {
        result = PyTuple_Pack(2, Py_None, Py_None);
        if not result {
            object_decref(di);
            return NULL;
        }
        it.view(1)[0].di_result = ptr[PyObject](result);
    }
    it.view(1)[0].kind = kind;
    link = od_last(op) if (kind & ITER_REVERSED) != 0 else od_first(op);
    it.view(1)[0].di_current = ptr[PyObject](
        object_new_ref(node_key(link)) if link else NULL
    );
    it.view(1)[0].di_size = dict_used(op);
    it.view(1)[0].di_state = od_of(op).view(1)[0].od_state;
    it.view(1)[0].di_odict = ptr[PyODictObject](object_new_ref(op));
    object_gc_track(di);
    return di;
}

impl odictiter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(oiter_odict(op));
    object_xdecref(oiter_current(op));
    if (oiter_of(op).view(1)[0].kind & ITER_ITEMS) == ITER_ITEMS {
        object_decref(ptr[PyObject](oiter_of(op).view(1)[0].di_result));
    }
    PyObject_GC_Del(ptr(op));
}

impl odictiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(oiter_odict(op), visitor, arg);
    if status == 0 {
        status = visit_reference(oiter_current(op), visitor, arg);
    }
    if status == 0 {
        status = visit_reference(
            ptr[PyObject](oiter_of(op).view(1)[0].di_result), visitor, arg
        );
    }
    return status;
}

impl odictiter_nextkey(op: ptr[PyObject]) -> ptr[PyObject] {
    it = oiter_of(op);
    od = oiter_odict(op);
    if not od {
        return NULL;
    }
    if not oiter_current(op) {
        oiter_clear_odict(op);
        return NULL;
    }
    if od_of(od).view(1)[0].od_state != it.view(1)[0].di_state {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("OrderedDict mutated during iteration")
        );
        oiter_clear_odict(op);
        return NULL;
    }
    if it.view(1)[0].di_size != dict_used(od) {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("OrderedDict changed size during iteration")
        );

        it.view(1)[0].di_size = -1;
        return NULL;
    }
    link = find_node(od, oiter_current(op));
    if not link {
        if not PyErr_Occurred() {
            PyErr_SetObject(PyExc_KeyError, oiter_current(op));
        }

        oiter_clear_current(op);
        return NULL;
    }
    key = oiter_current(op);
    link = node_prev(link)
        if (it.view(1)[0].kind & ITER_REVERSED) != 0
        else node_next(link);
    it.view(1)[0].di_current = ptr[PyObject](
        object_new_ref(node_key(link)) if link else NULL
    );
    return key;
}

impl odictiter_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    it = oiter_of(op);
    key = odictiter_nextkey(op);
    if not key {
        return NULL;
    }
    kind = it.view(1)[0].kind;
    if (kind & ITER_VALUES) == 0 {
        return key;
    }
    hash = hash_fast(key);
    status = i32(-1);
    value: ptr[PyObject] = NULL;
    if hash != -1 {
        (status, value) = get_item_ref_known_hash(oiter_odict(op), key, hash);
    }
    if status != 1 {
        if not PyErr_Occurred() {
            PyErr_SetObject(PyExc_KeyError, key);
        }
        object_decref(key);
        oiter_clear_current(op);
        oiter_clear_odict(op);
        return NULL;
    }
    if (kind & ITER_KEYS) == 0 {
        object_decref(key);
        return value;
    }
    result = ptr[PyObject](it.view(1)[0].di_result);
    if object_refcount(result) == 1 {
        object_incref(result);
        object_decref(tuple_get_item(result, 0));
        object_decref(tuple_get_item(result, 1));

        tuple_recycle(result);
    } else {
        result = PyTuple_New(2);
        if not result {
            object_decref(key);
            object_decref(value);
            oiter_clear_current(op);
            oiter_clear_odict(op);
            return NULL;
        }
    }
    tuple_set_item(result, 0, key);
    tuple_set_item(result, 1, value);
    return result;
}

impl odictiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    it = oiter_of(op);
    tmp = _PyObject_GC_New(ptr[PyObject](addressof(PyODictIter_Type)));
    if not tmp {
        return NULL;
    }
    copy = oiter_of(tmp);
    copy.view(1)[0].kind = it.view(1)[0].kind;
    copy.view(1)[0].di_odict = ptr[PyODictObject](object_xnew_ref(oiter_odict(op)));
    copy.view(1)[0].di_size = it.view(1)[0].di_size;
    copy.view(1)[0].di_state = it.view(1)[0].di_state;
    copy.view(1)[0].di_current = ptr[PyObject](object_xnew_ref(oiter_current(op)));
    copy.view(1)[0].di_result = ptr[PyObject]();
    if (it.view(1)[0].kind & ITER_ITEMS) == ITER_ITEMS {
        result = PyTuple_Pack(2, Py_None, Py_None);
        if not result {
            object_decref(tmp);
            return NULL;
        }
        copy.view(1)[0].di_result = ptr[PyObject](result);
    }
    object_gc_track(tmp);
    list = PySequence_List(tmp);
    object_decref(tmp);
    if not list {
        return NULL;
    }
    iter = eval_builtin("iter");
    if not iter {
        object_decref(list);
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("N(N)"), iter, list);
}

impl view_odict(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](ptr[_PyDictViewObject](op).view(1)[0].dv_dict);
}

impl view_iter(op: ptr[PyObject], kind: i32) -> ptr[PyObject] {
    od = view_odict(op);
    if not od {
        return object_new_ref(Py_None);
    }
    return odictiter_new(od, kind);
}

impl odictkeys_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(op, ITER_KEYS);
}

impl odictkeys_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(op, ITER_KEYS | ITER_REVERSED);
}

impl odictkeys_new(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return _PyDictView_New(od, addressof(PyODictKeys_Type));
}

impl odictitems_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(op, ITER_KEYS | ITER_VALUES);
}

impl odictitems_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(op, ITER_KEYS | ITER_VALUES | ITER_REVERSED);
}

impl odictitems_new(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return _PyDictView_New(od, addressof(PyODictItems_Type));
}

impl odictvalues_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(op, ITER_VALUES);
}

impl odictvalues_reversed(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return view_iter(op, ITER_VALUES | ITER_REVERSED);
}

impl odictvalues_new(od: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return _PyDictView_New(od, addressof(PyODictValues_Type));
}

impl mutablemapping_add_pairs(self: ptr[PyObject], pairs: ptr[PyObject]) -> i32 {
    iterator = PyObject_GetIter(pairs);
    if not iterator {
        return i32(-1);
    }
    PyErr_Clear();
    res = i32(0);
    while True {
        pair = PyIter_Next(iterator);
        if not pair {
            break;
        }
        key: ptr[PyObject] = NULL;
        value: ptr[PyObject] = NULL;
        pair_iterator = PyObject_GetIter(pair);
        if pair_iterator {
            key = PyIter_Next(pair_iterator);
            if not key {
                if not PyErr_Occurred() {
                    PyErr_SetString(
                        PyExc_ValueError, ptr[u8]("need more than 0 values to unpack")
                    );
                }
            } else {
                value = PyIter_Next(pair_iterator);
                if not value {
                    if not PyErr_Occurred() {
                        PyErr_SetString(
                            PyExc_ValueError,
                            ptr[u8]("need more than 1 value to unpack")
                        );
                    }
                } else {
                    unexpected = PyIter_Next(pair_iterator);
                    if unexpected {
                        object_decref(unexpected);
                        PyErr_SetString(
                            PyExc_ValueError,
                            ptr[u8]("too many values to unpack (expected 2)")
                        );
                    } elif not PyErr_Occurred() {
                        res = PyObject_SetItem(self, key, value);
                    }
                }
            }
        }
        object_decref(pair);
        object_xdecref(pair_iterator);
        object_xdecref(key);
        object_xdecref(value);
        if PyErr_Occurred() {
            break;
        }
    }
    object_decref(iterator);
    if res < 0 or PyErr_Occurred() {
        return i32(-1);
    }
    return i32(0);
}

impl mutablemapping_update_arg(self: ptr[PyObject], arg: ptr[PyObject]) -> i32 {
    if dict_check_exact(arg) {
        items = PyDict_Items(arg);
        if not items {
            return i32(-1);
        }
        res = mutablemapping_add_pairs(self, items);
        object_decref(items);
        return res;
    }
    func: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(arg, interned_keys(), &mut func) < 0 {
        return i32(-1);
    }
    if func {
        keys = PyObject_CallNoArgs(func);
        object_decref(func);
        if not keys {
            return i32(-1);
        }
        iterator = PyObject_GetIter(keys);
        object_decref(keys);
        if not iterator {
            return i32(-1);
        }
        res = i32(0);
        while res == 0 {
            key = PyIter_Next(iterator);
            if not key {
                break;
            }
            value = PyObject_GetItem(arg, key);
            if value {
                res = PyObject_SetItem(self, key, value);
                object_decref(value);
            } else {
                res = i32(-1);
            }
            object_decref(key);
        }
        object_decref(iterator);
        if res != 0 or PyErr_Occurred() {
            return i32(-1);
        }
        return i32(0);
    }
    if PyObject_GetOptionalAttr(arg, interned_items(), &mut func) < 0 {
        return i32(-1);
    }
    if func {
        items = PyObject_CallNoArgs(func);
        object_decref(func);
        if not items {
            return i32(-1);
        }
        res = mutablemapping_add_pairs(self, items);
        object_decref(items);
        return res;
    }
    return mutablemapping_add_pairs(self, arg);
}

impl mutablemapping_update(
    self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    length: i64 = 0;
    if args {
        length = object_size(args);
    }
    if length > 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("update() takes at most 1 positional argument (%zd given)"),
            length
        );
        return NULL;
    }
    if length != 0 {
        other = object_new_ref(tuple_get_item(args, 0));
        res = mutablemapping_update_arg(self, other);
        object_decref(other);
        if res < 0 {
            return NULL;
        }
    }
    if kwargs and dict_used(kwargs) != 0 {
        items = PyDict_Items(kwargs);
        if not items {
            return NULL;
        }
        res = mutablemapping_add_pairs(self, items);
        object_decref(items);
        if res == -1 {
            return NULL;
        }
    }
    return object_new_ref(Py_None);
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}
