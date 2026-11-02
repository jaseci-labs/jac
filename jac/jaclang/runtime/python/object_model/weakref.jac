import from c {
    glob PyType_Type: PyTypeObject,
         PyExc_ReferenceError: ptr[PyObject]; def PyNumber_Power(
        v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
    ) -> ptr[PyObject];  def PyNumber_InPlacePower(
        v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_Length(o: ptr[PyObject]) -> i64;  def _PyStaticType_GetState(
        interp: ptr, type: ptr[PyTypeObject]
    ) -> ptr[u8];  def _PyObject_LookupSpecial(
        self: ptr[PyObject], attr: ptr[PyObject]
    ) -> ptr[PyObject];  def PyErr_FormatUnraisable(format: ptr[u8], *args: any);  glob:
        priv weakref_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__callback__"),
                 type_=_Py_T_OBJECT,
                 offset=PyWeakReference_CALLBACK,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         weakref_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "Weakrefs are generic over the type of the referenced object."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         proxy_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__bytes__"),
                 ml_meth=ptr(proxy_bytes),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(proxy_reversed),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         proxy_as_number: PyNumberMethods = PyNumberMethods(
             nb_add=proxy_add,
             nb_subtract=proxy_sub,
             nb_multiply=proxy_mul,
             nb_remainder=proxy_mod,
             nb_divmod=proxy_divmod,
             nb_power=proxy_pow,
             nb_negative=proxy_neg,
             nb_positive=proxy_pos,
             nb_absolute=proxy_abs,
             nb_bool=proxy_bool,
             nb_invert=proxy_invert,
             nb_lshift=proxy_lshift,
             nb_rshift=proxy_rshift,
             nb_and=proxy_and,
             nb_xor=proxy_xor,
             nb_or=proxy_or,
             nb_int=proxy_int,
             nb_float=proxy_float,
             nb_inplace_add=proxy_iadd,
             nb_inplace_subtract=proxy_isub,
             nb_inplace_multiply=proxy_imul,
             nb_inplace_remainder=proxy_imod,
             nb_inplace_power=proxy_ipow,
             nb_inplace_lshift=proxy_ilshift,
             nb_inplace_rshift=proxy_irshift,
             nb_inplace_and=proxy_iand,
             nb_inplace_xor=proxy_ixor,
             nb_inplace_or=proxy_ior,
             nb_floor_divide=proxy_floor_div,
             nb_true_divide=proxy_true_div,
             nb_inplace_floor_divide=proxy_ifloor_div,
             nb_inplace_true_divide=proxy_itrue_div,
             nb_index=proxy_index,
             nb_matrix_multiply=proxy_matmul,
             nb_inplace_matrix_multiply=proxy_imatmul
         ),
         proxy_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=proxy_length, sq_contains=proxy_contains
         ),
         proxy_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=proxy_length,
             mp_subscript=proxy_getitem,
             mp_ass_subscript=proxy_setitem
         ); glob _PyWeakref_RefType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("weakref.ReferenceType"),
             tp_basicsize=PyWeakReference_SIZE,
             tp_dealloc=weakref_dealloc,
             tp_vectorcall_offset=PyWeakReference_VECTORCALL,
             tp_call=PyVectorcall_Call,
             tp_repr=weakref_repr,
             tp_hash=weakref_hash,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_HAVE_VECTORCALL
                 | Py_TPFLAGS_BASETYPE,
             tp_traverse=gc_traverse,
             tp_clear=gc_clear,
             tp_richcompare=weakref_richcompare,
             tp_methods=addressof(weakref_methods),
             tp_members=addressof(weakref_members),
             tp_init=weakref___init__,
             tp_alloc=PyType_GenericAlloc,
             tp_new=weakref___new__,
             tp_free=PyObject_GC_Del
         ),
         _PyWeakref_ProxyType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("weakref.ProxyType"),
             tp_basicsize=PyWeakReference_SIZE,
             tp_dealloc=proxy_dealloc,
             tp_repr=proxy_repr,
             tp_as_number=addressof(proxy_as_number),
             tp_as_sequence=addressof(proxy_as_sequence),
             tp_as_mapping=addressof(proxy_as_mapping),
             tp_str=proxy_str,
             tp_getattro=proxy_getattr,
             tp_setattro=proxy_setattr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=gc_traverse,
             tp_clear=gc_clear,
             tp_richcompare=proxy_richcompare,
             tp_iter=proxy_iter,
             tp_iternext=proxy_iternext,
             tp_methods=addressof(proxy_methods)
         ),
         _PyWeakref_CallableProxyType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("weakref.CallableProxyType"),
             tp_basicsize=PyWeakReference_SIZE,
             tp_dealloc=proxy_dealloc,
             tp_repr=proxy_repr,
             tp_as_number=addressof(proxy_as_number),
             tp_as_sequence=addressof(proxy_as_sequence),
             tp_as_mapping=addressof(proxy_as_mapping),
             tp_call=proxy_call,
             tp_str=proxy_str,
             tp_getattro=proxy_getattr,
             tp_setattro=proxy_setattr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=gc_traverse,
             tp_clear=gc_clear,
             tp_richcompare=proxy_richcompare,
             tp_iter=proxy_iter,
             tp_iternext=proxy_iternext
         );
}

def ref_of(op: ptr[PyObject]) -> ptr[PyWeakReference];

def no_ref -> ptr[PyWeakReference];

def ref_type -> ptr[PyTypeObject];

def proxy_type -> ptr[PyTypeObject];

def callable_proxy_type -> ptr[PyTypeObject];

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

def weakref_check(op: ptr[PyObject]) -> bool;

def weakref_check_ref_exact(op: ptr[PyObject]) -> bool;

def weakref_check_proxy(op: ptr[PyObject]) -> bool;

def supports_weakrefs(type: ptr[PyTypeObject]) -> bool;

def weakrefs_listptr(op: ptr[PyObject]) -> ptr[ptr[PyWeakReference]];

def listptr_from_offset(op: ptr[PyObject]) -> ptr[ptr[PyWeakReference]];

def try_incref(op: ptr[PyObject]) -> bool;

def weakref_get_ref(op: ptr[PyObject]) -> ptr[PyObject];

def weakref_is_dead(op: ptr[PyObject]) -> bool;

def init_weakref(r: ptr[PyWeakReference], ob: ptr[PyObject], callback: ptr[PyObject]);

def clear_weakref_lock_held(
    r: ptr[PyWeakReference], take_callback: bool
) -> ptr[PyObject];

def clear_weakref(op: ptr[PyObject]);

import from c {
    def _PyWeakref_GetWeakrefCount(ob: ptr[PyObject]) -> i64 {
        if not supports_weakrefs(object_type(ob)) {
            return 0;
        }
        count: i64 = 0;
        head = weakrefs_listptr(ob).view(1)[0];
        while head {
            count += 1;
            head = head.view(1)[0].wr_next;
        }
        return count;
    }  def _PyWeakref_ClearRef(r: ptr[PyWeakReference]) {
        clear_weakref_lock_held(r, False);
    }  def PyWeakref_NewRef(
        ob: ptr[PyObject], callback: ptr[PyObject]
    ) -> ptr[PyObject] {
        return ptr[PyObject](get_or_create_weakref(ref_type(), ob, callback));
    }  def PyWeakref_NewProxy(
        ob: ptr[PyObject], callback: ptr[PyObject]
    ) -> ptr[PyObject] {
        type = proxy_type();
        if PyCallable_Check(ob) != 0 {
            type = callable_proxy_type();
        }
        return ptr[PyObject](get_or_create_weakref(type, ob, callback));
    }  def PyWeakref_IsDead(r: ptr[PyObject]) -> i32 {
        if not r {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        if not weakref_check(r) {
            PyErr_Format(PyExc_TypeError, ptr[u8]("expected a weakref, got %T"), r);
            return i32(-1);
        }
        return i32(1) if weakref_is_dead(r) else i32(0);
    }  def PyWeakref_GetRef(r: ptr[PyObject], pobj: ptr[ptr[PyObject]]) -> i32 {
        if not r {
            pobj.view(1)[0] = NULL;
            PyErr_BadInternalCall();
            return i32(-1);
        }
        if not weakref_check(r) {
            pobj.view(1)[0] = NULL;
            PyErr_SetString(PyExc_TypeError, ptr[u8]("expected a weakref"));
            return i32(-1);
        }
        ob = weakref_get_ref(r);
        pobj.view(1)[0] = ob;
        return i32(1) if ob else i32(0);
    }  def PyWeakref_GetObject(r: ptr[PyObject]) -> ptr[PyObject] {
        if not r or not weakref_check(r) {
            PyErr_BadInternalCall();
            return NULL;
        }
        ob = weakref_get_ref(r);
        if not ob {
            return Py_None;
        }
        object_decref(ob);
        return ob;
    }  def PyObject_ClearWeakRefs(object: ptr[PyObject]) {
        if not object
            or not supports_weakrefs(object_type(object))
            or object_refcount(object) != 0 {
            PyErr_BadInternalCall();
            return;
        }
        list = weakrefs_listptr(object);
        if not list.view(1)[0] {
            return;
        }

        while list.view(1)[0] and is_basic_ref_or_proxy(list.view(1)[0]) {
            clear_weakref_lock_held(list.view(1)[0], True);
        }
        num_weakrefs = _PyWeakref_GetWeakrefCount(object);
        if num_weakrefs == 0 {
            return;
        }
        exc = PyErr_GetRaisedException();
        tuple = PyTuple_New(num_weakrefs * 2);
        if not tuple {
            _PyWeakref_ClearWeakRefsNoCallbacks(object);
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing object weakrefs")
            );
            PyErr_SetRaisedException(exc);
            return;
        }

        num_items: i64 = 0;
        while list.view(1)[0] {
            cur = list.view(1)[0];
            callback = clear_weakref_lock_held(cur, True);
            if try_incref(ptr[PyObject](cur)) {
                tuple_set_item(tuple, num_items, ptr[PyObject](cur));
                tuple_set_item(tuple, num_items + 1, callback);
                num_items += 2;
            } else {
                object_xdecref(callback);
            }
        }
        i: i64 = 0;
        while i < num_items {
            callback = tuple_get_item(tuple, i + 1);
            if callback {
                handle_callback(tuple_get_item(tuple, i), callback);
            }
            i += 2;
        }
        object_decref(tuple);
        PyErr_SetRaisedException(exc);
    }  def PyUnstable_Object_ClearWeakRefsNoCallbacks(ob: ptr[PyObject]) {
        if supports_weakrefs(object_type(ob)) {
            _PyWeakref_ClearWeakRefsNoCallbacks(ob);
        }
    }  def _PyStaticType_ClearWeakRefs(interp: ptr, type: ptr[PyTypeObject]) {
        state = _PyStaticType_GetState(interp, type);
        list = ptr[ptr[PyWeakReference]](state + managed_static_type_state_TP_WEAKLIST);
        while list.view(1)[0] {
            _PyWeakref_ClearRef(list.view(1)[0]);
        }
    }  def _PyWeakref_ClearWeakRefsNoCallbacks(ob: ptr[PyObject]) {
        list = listptr_from_offset(ob);
        while list.view(1)[0] {
            _PyWeakref_ClearRef(list.view(1)[0]);
        }
    }  def _PyWeakref_IsDead(weakref: ptr[PyObject]) -> i32 {
        return i32(1) if weakref_is_dead(weakref) else i32(0);
    }
}

def handle_callback(r: ptr[PyObject], callback: ptr[PyObject]);

def weakref_dealloc(op: ptr[PyObject]);

def gc_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def gc_clear(op: ptr[PyObject]) -> i32;

def weakref_vectorcall(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def weakref_hash(op: ptr[PyObject]) -> i64;

def weakref_repr(op: ptr[PyObject]) -> ptr[PyObject];

def weakref_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject];

def basic_ref(head: ptr[PyWeakReference]) -> ptr[PyWeakReference];

def basic_proxy(head_in: ptr[PyWeakReference]) -> ptr[PyWeakReference];

def insert_after(newref: ptr[PyWeakReference], prev: ptr[PyWeakReference]);

def insert_head(newref: ptr[PyWeakReference], list: ptr[ptr[PyWeakReference]]);

def try_reuse_basic_ref(
    list: ptr[PyWeakReference], type: ptr[PyTypeObject], callback: ptr[PyObject]
) -> ptr[PyWeakReference];

def is_basic_ref(r: ptr[PyWeakReference]) -> bool;

def is_basic_proxy(r: ptr[PyWeakReference]) -> bool;

def is_basic_ref_or_proxy(r: ptr[PyWeakReference]) -> bool;

def insert_weakref(newref: ptr[PyWeakReference], list: ptr[ptr[PyWeakReference]]);

def allocate_weakref(
    type: ptr[PyTypeObject], ob: ptr[PyObject], callback: ptr[PyObject]
) -> ptr[PyWeakReference];

def get_or_create_weakref(
    type: ptr[PyTypeObject], ob: ptr[PyObject], callback_in: ptr[PyObject]
) -> ptr[PyWeakReference];

def unpack_weakref_args(args: ptr[PyObject], funcname: str) -> bool;

def weakref___new__(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def weakref___init__(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def proxy_check_ref(ob: ptr[PyObject]) -> bool;

def unwrap(o: ptr[PyObject]) -> ptr[PyObject];

def wrap_binary(
    x_in: ptr[PyObject], y_in: ptr[PyObject], generic: i64
) -> ptr[PyObject];

def wrap_ternary(
    proxy: ptr[PyObject], v_in: ptr[PyObject], w_in: ptr[PyObject], inplace: bool
) -> ptr[PyObject];

def wrap_unary(proxy: ptr[PyObject], generic: i64) -> ptr[PyObject];

glob:priv OP_GETATTR: i64 = 0,
     OP_ADD: i64 = 1,
     OP_SUB: i64 = 2,
     OP_MUL: i64 = 3,
     OP_FLOOR_DIV: i64 = 4,
     OP_TRUE_DIV: i64 = 5,
     OP_MOD: i64 = 6,
     OP_DIVMOD: i64 = 7,
     OP_LSHIFT: i64 = 8,
     OP_RSHIFT: i64 = 9,
     OP_AND: i64 = 10,
     OP_XOR: i64 = 11,
     OP_OR: i64 = 12,
     OP_IADD: i64 = 13,
     OP_ISUB: i64 = 14,
     OP_IMUL: i64 = 15,
     OP_IFLOOR_DIV: i64 = 16,
     OP_ITRUE_DIV: i64 = 17,
     OP_IMOD: i64 = 18,
     OP_ILSHIFT: i64 = 19,
     OP_IRSHIFT: i64 = 20,
     OP_IAND: i64 = 21,
     OP_IXOR: i64 = 22,
     OP_IOR: i64 = 23,
     OP_MATMUL: i64 = 24,
     OP_IMATMUL: i64 = 25,
     OP_GETITEM: i64 = 26,
     UOP_STR: i64 = 0,
     UOP_NEG: i64 = 1,
     UOP_POS: i64 = 2,
     UOP_ABS: i64 = 3,
     UOP_INVERT: i64 = 4,
     UOP_INT: i64 = 5,
     UOP_FLOAT: i64 = 6,
     UOP_INDEX: i64 = 7;

def binary_operation(op: i64, x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def unary_operation(op: i64, x: ptr[PyObject]) -> ptr[PyObject];

def proxy_getattr(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_str(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_call(
    proxy: ptr[PyObject], v_in: ptr[PyObject], w_in: ptr[PyObject]
) -> ptr[PyObject];

def proxy_repr(proxy: ptr[PyObject]) -> ptr[PyObject];

def proxy_setattr(
    proxy: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def proxy_richcompare(
    proxy: ptr[PyObject], v_in: ptr[PyObject], op: i32
) -> ptr[PyObject];

def proxy_add(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_sub(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_mul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_floor_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_true_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_mod(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_divmod(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_pow(x: ptr[PyObject], y: ptr[PyObject], z: ptr[PyObject]) -> ptr[PyObject];

def proxy_neg(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_pos(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_abs(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_invert(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_lshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_rshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_and(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_xor(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_or(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_int(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_float(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_iadd(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_isub(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_imul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_ifloor_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_itrue_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_imod(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_ipow(x: ptr[PyObject], y: ptr[PyObject], z: ptr[PyObject]) -> ptr[PyObject];

def proxy_ilshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_irshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_iand(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_ixor(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_ior(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_index(x: ptr[PyObject]) -> ptr[PyObject];

def proxy_matmul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_imatmul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_bool(proxy: ptr[PyObject]) -> i32;

def proxy_dealloc(op: ptr[PyObject]);

def proxy_contains(proxy: ptr[PyObject], value: ptr[PyObject]) -> i32;

def proxy_length(proxy: ptr[PyObject]) -> i64;

def proxy_getitem(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject];

def proxy_setitem(
    proxy: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def proxy_iter(proxy: ptr[PyObject]) -> ptr[PyObject];

def proxy_iternext(proxy: ptr[PyObject]) -> ptr[PyObject];

def proxy_call_method(proxy: ptr[PyObject], name: str) -> ptr[PyObject];

def proxy_bytes(proxy: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def proxy_reversed(proxy: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

impl ref_of(op: ptr[PyObject]) -> ptr[PyWeakReference] {
    return ptr[PyWeakReference](op);
}

impl no_ref -> ptr[PyWeakReference] {
    return ptr[PyWeakReference]();
}

impl ref_type -> ptr[PyTypeObject] {
    return addressof(_PyWeakref_RefType);
}

impl proxy_type -> ptr[PyTypeObject] {
    return addressof(_PyWeakref_ProxyType);
}

impl callable_proxy_type -> ptr[PyTypeObject] {
    return addressof(_PyWeakref_CallableProxyType);
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl weakref_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ref_type()) or weakref_check_proxy(op);
}

impl weakref_check_ref_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ref_type());
}

impl weakref_check_proxy(op: ptr[PyObject]) -> bool {
    return object_is_type(op, proxy_type())
        or object_is_type(op, callable_proxy_type());
}

impl supports_weakrefs(type: ptr[PyTypeObject]) -> bool {
    return type.view(1)[0].tp_weaklistoffset != 0;
}

impl weakrefs_listptr(op: ptr[PyObject]) -> ptr[ptr[PyWeakReference]] {
    if type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS)
        and type_has_feature(ptr[PyTypeObject](op), _Py_TPFLAGS_STATIC_BUILTIN) {
        state = _PyStaticType_GetState(current_interp(), ptr[PyTypeObject](op));
        return ptr[ptr[PyWeakReference]](state + managed_static_type_state_TP_WEAKLIST);
    }
    return listptr_from_offset(op);
}

impl listptr_from_offset(op: ptr[PyObject]) -> ptr[ptr[PyWeakReference]] {
    return ptr[ptr[PyWeakReference]](
        ptr[u8](op) + object_type(op).view(1)[0].tp_weaklistoffset
    );
}

impl try_incref(op: ptr[PyObject]) -> bool {
    if object_refcount(op) > 0 {
        object_incref(op);
        return True;
    }
    return False;
}

impl weakref_get_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    ob = ref_of(op).view(1)[0].wr_object;
    if ob == Py_None {
        return NULL;
    }
    if try_incref(ob) {
        return ob;
    }
    return NULL;
}

impl weakref_is_dead(op: ptr[PyObject]) -> bool {
    ob = ref_of(op).view(1)[0].wr_object;
    return ob == Py_None or object_refcount(ob) == 0;
}

impl init_weakref(r: ptr[PyWeakReference], ob: ptr[PyObject], callback: ptr[PyObject]) {
    r.view(1)[0].hash = -1;
    r.view(1)[0].wr_object = ob;
    r.view(1)[0].wr_prev = no_ref();
    r.view(1)[0].wr_next = no_ref();
    r.view(1)[0].wr_callback = object_xnew_ref(callback);
    r.view(1)[0].vectorcall = weakref_vectorcall;
}

impl clear_weakref_lock_held(
    r: ptr[PyWeakReference], take_callback: bool
) -> ptr[PyObject] {
    ob = r.view(1)[0].wr_object;
    if ob != Py_None {
        list = weakrefs_listptr(ob);
        if list.view(1)[0] == r {
            list.view(1)[0] = r.view(1)[0].wr_next;
        }
        r.view(1)[0].wr_object = Py_None;
        prev = r.view(1)[0].wr_prev;
        next = r.view(1)[0].wr_next;
        if prev {
            prev.view(1)[0].wr_next = next;
        }
        if next {
            next.view(1)[0].wr_prev = prev;
        }
        r.view(1)[0].wr_prev = no_ref();
        r.view(1)[0].wr_next = no_ref();
    }
    callback = NULL;
    if take_callback {
        callback = r.view(1)[0].wr_callback;
        r.view(1)[0].wr_callback = NULL;
    }
    return callback;
}

impl clear_weakref(op: ptr[PyObject]) {
    object_xdecref(clear_weakref_lock_held(ref_of(op), True));
}

impl handle_callback(r: ptr[PyObject], callback: ptr[PyObject]) {
    cbresult = PyObject_CallOneArg(callback, r);
    if not cbresult {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while calling weakref callback %R"), callback
        );
    } else {
        object_decref(cbresult);
    }
}

impl weakref_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    clear_weakref(op);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

impl gc_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ref_of(op).view(1)[0].wr_callback, visitor, arg);
}

impl gc_clear(op: ptr[PyObject]) -> i32 {
    object_xdecref(clear_weakref_lock_held(ref_of(op), True));
    return i32(0);
}

impl weakref_vectorcall(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames and _PyArg_NoKwnames(ptr[u8]("weakref"), kwnames) == 0 {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if nargs != 0 and _PyArg_CheckPositional(ptr[u8]("weakref"), nargs, 0, 0) == 0 {
        return NULL;
    }
    ob = weakref_get_ref(op);
    if not ob {
        return object_new_ref(Py_None);
    }
    return ob;
}

impl weakref_hash(op: ptr[PyObject]) -> i64 {
    r = ref_of(op);
    if r.view(1)[0].hash != -1 {
        return r.view(1)[0].hash;
    }
    ob = weakref_get_ref(op);
    if not ob {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("weak object has gone away"));
        return -1;
    }
    r.view(1)[0].hash = PyObject_Hash(ob);
    object_decref(ob);
    return r.view(1)[0].hash;
}

impl weakref_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    ob = weakref_get_ref(op);
    if not ob {
        return PyUnicode_FromFormat("<weakref at %p; dead>", op);
    }
    key = PyUnicode_InternFromString(ptr[u8]("__name__"));
    name = NULL;
    if key {
        name = _PyObject_LookupSpecial(ob, key);
        object_decref(key);
    } else {
        PyErr_Clear();
    }
    repr = NULL;
    if not name
        or not type_has_feature(object_type(name), Py_TPFLAGS_UNICODE_SUBCLASS) {
        repr = PyUnicode_FromFormat("<weakref at %p; to '%T' at %p>", op, ob, ob);
    } else {
        repr = PyUnicode_FromFormat(
            "<weakref at %p; to '%T' at %p (%U)>", op, ob, ob, name
        );
    }
    object_decref(ob);
    object_xdecref(name);
    return repr;
}

impl weakref_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if (op != Py_EQ and op != Py_NE) or not weakref_check(a) or not weakref_check(b) {
        return object_new_ref(Py_NotImplemented);
    }
    ob = weakref_get_ref(a);
    other_obj = weakref_get_ref(b);
    if not ob or not other_obj {
        object_xdecref(ob);
        object_xdecref(other_obj);
        equal = a == b;
        if op == Py_NE {
            equal = not equal;
        }
        return object_new_ref(py_true() if equal else py_false());
    }
    result = PyObject_RichCompare(ob, other_obj, op);
    object_decref(ob);
    object_decref(other_obj);
    return result;
}

impl basic_ref(head: ptr[PyWeakReference]) -> ptr[PyWeakReference] {
    if head
        and not head.view(1)[0].wr_callback
        and weakref_check_ref_exact(ptr[PyObject](head)) {
        return head;
    }
    return no_ref();
}

impl basic_proxy(head_in: ptr[PyWeakReference]) -> ptr[PyWeakReference] {
    head = head_in;
    if head and not head.view(1)[0].wr_callback {
        if weakref_check_ref_exact(ptr[PyObject](head)) {
            head = head.view(1)[0].wr_next;
        }
        if head
            and not head.view(1)[0].wr_callback
            and weakref_check_proxy(ptr[PyObject](head)) {
            return head;
        }
    }
    return no_ref();
}

impl insert_after(newref: ptr[PyWeakReference], prev: ptr[PyWeakReference]) {
    next = prev.view(1)[0].wr_next;
    newref.view(1)[0].wr_prev = prev;
    newref.view(1)[0].wr_next = next;
    if next {
        next.view(1)[0].wr_prev = newref;
    }
    prev.view(1)[0].wr_next = newref;
}

impl insert_head(newref: ptr[PyWeakReference], list: ptr[ptr[PyWeakReference]]) {
    next = list.view(1)[0];
    newref.view(1)[0].wr_prev = no_ref();
    newref.view(1)[0].wr_next = next;
    if next {
        next.view(1)[0].wr_prev = newref;
    }
    list.view(1)[0] = newref;
}

impl try_reuse_basic_ref(
    list: ptr[PyWeakReference], type: ptr[PyTypeObject], callback: ptr[PyObject]
) -> ptr[PyWeakReference] {
    if callback {
        return no_ref();
    }
    cand = no_ref();
    if type == ref_type() {
        cand = basic_ref(list);
    }
    if type == proxy_type() or type == callable_proxy_type() {
        cand = basic_proxy(list);
    }
    if cand and try_incref(ptr[PyObject](cand)) {
        return cand;
    }
    return no_ref();
}

impl is_basic_ref(r: ptr[PyWeakReference]) -> bool {
    return not r.view(1)[0].wr_callback and weakref_check_ref_exact(ptr[PyObject](r));
}

impl is_basic_proxy(r: ptr[PyWeakReference]) -> bool {
    return not r.view(1)[0].wr_callback and weakref_check_proxy(ptr[PyObject](r));
}

impl is_basic_ref_or_proxy(r: ptr[PyWeakReference]) -> bool {
    return is_basic_ref(r) or is_basic_proxy(r);
}

impl insert_weakref(newref: ptr[PyWeakReference], list: ptr[ptr[PyWeakReference]]) {
    head = list.view(1)[0];
    r = basic_ref(head);
    proxy = basic_proxy(head);
    prev = no_ref();
    if is_basic_ref(newref) {
        prev = no_ref();
    } elif is_basic_proxy(newref) {
        prev = r;
    } else {
        prev = r if not proxy else proxy;
    }
    if not prev {
        insert_head(newref, list);
    } else {
        insert_after(newref, prev);
    }
}

impl allocate_weakref(
    type: ptr[PyTypeObject], ob: ptr[PyObject], callback: ptr[PyObject]
) -> ptr[PyWeakReference] {
    newref = ptr[PyWeakReference](type.view(1)[0].tp_alloc(type, 0));
    if not newref {
        return no_ref();
    }
    init_weakref(newref, ob, callback);
    return newref;
}

impl get_or_create_weakref(
    type: ptr[PyTypeObject], ob: ptr[PyObject], callback_in: ptr[PyObject]
) -> ptr[PyWeakReference] {
    if not supports_weakrefs(object_type(ob)) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("cannot create weak reference to '%s' object"),
            object_type(ob).view(1)[0].tp_name
        );
        return no_ref();
    }
    callback = NULL if callback_in == Py_None else callback_in;
    list = weakrefs_listptr(ob);
    if type == ref_type() or type == proxy_type() or type == callable_proxy_type() {
        reused = try_reuse_basic_ref(list.view(1)[0], type, callback);
        if reused {
            return reused;
        }
    }
    newref = allocate_weakref(type, ob, callback);
    if not newref {
        return no_ref();
    }
    insert_weakref(newref, list);
    return newref;
}

impl unpack_weakref_args(args: ptr[PyObject], funcname: str) -> bool {
    nargs = object_size(args);
    if nargs < 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%s expected at least 1 argument, got %zd"),
            funcname,
            nargs
        );
        return False;
    }
    if nargs > 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%s expected at most 2 arguments, got %zd"),
            funcname,
            nargs
        );
        return False;
    }
    return True;
}

impl weakref___new__(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not unpack_weakref_args(args, "__new__") {
        return NULL;
    }
    callback = tuple_get_item(args, 1) if object_size(args) == 2 else NULL;
    return ptr[PyObject](
        get_or_create_weakref(type, tuple_get_item(args, 0), callback)
    );
}

impl weakref___init__(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    if kwargs and _PyArg_NoKeywords(ptr[u8]("ref"), kwargs) == 0 {
        return i32(-1);
    }
    return i32(0) if unpack_weakref_args(args, "__init__") else i32(-1);
}

impl proxy_check_ref(ob: ptr[PyObject]) -> bool {
    if not ob {
        PyErr_SetString(
            PyExc_ReferenceError, ptr[u8]("weakly-referenced object no longer exists")
        );
        return False;
    }
    return True;
}

impl unwrap(o: ptr[PyObject]) -> ptr[PyObject] {
    if weakref_check_proxy(o) {
        ob = weakref_get_ref(o);
        if not proxy_check_ref(ob) {
            return NULL;
        }
        return ob;
    }
    return object_new_ref(o);
}

impl wrap_binary(
    x_in: ptr[PyObject], y_in: ptr[PyObject], generic: i64
) -> ptr[PyObject] {
    x = unwrap(x_in);
    if not x {
        return NULL;
    }
    y = unwrap(y_in);
    if not y {
        object_decref(x);
        return NULL;
    }
    res = binary_operation(generic, x, y);
    object_decref(x);
    object_decref(y);
    return res;
}

impl wrap_ternary(
    proxy: ptr[PyObject], v_in: ptr[PyObject], w_in: ptr[PyObject], inplace: bool
) -> ptr[PyObject] {
    x = unwrap(proxy);
    if not x {
        return NULL;
    }
    v = unwrap(v_in);
    if not v {
        object_decref(x);
        return NULL;
    }
    w = NULL;
    if w_in {
        w = unwrap(w_in);
        if not w {
            object_decref(x);
            object_decref(v);
            return NULL;
        }
    }
    res = PyNumber_InPlacePower(x, v, w) if inplace else PyNumber_Power(x, v, w);
    object_decref(x);
    object_decref(v);
    object_xdecref(w);
    return res;
}

impl wrap_unary(proxy: ptr[PyObject], generic: i64) -> ptr[PyObject] {
    x = unwrap(proxy);
    if not x {
        return NULL;
    }
    res = unary_operation(generic, x);
    object_decref(x);
    return res;
}

impl binary_operation(op: i64, x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    if op == OP_GETATTR {
        return PyObject_GetAttr(x, y);
    }
    if op == OP_ADD {
        return PyNumber_Add(x, y);
    }
    if op == OP_SUB {
        return PyNumber_Subtract(x, y);
    }
    if op == OP_MUL {
        return PyNumber_Multiply(x, y);
    }
    if op == OP_FLOOR_DIV {
        return PyNumber_FloorDivide(x, y);
    }
    if op == OP_TRUE_DIV {
        return PyNumber_TrueDivide(x, y);
    }
    if op == OP_MOD {
        return PyNumber_Remainder(x, y);
    }
    if op == OP_DIVMOD {
        return PyNumber_Divmod(x, y);
    }
    if op == OP_LSHIFT {
        return PyNumber_Lshift(x, y);
    }
    if op == OP_RSHIFT {
        return PyNumber_Rshift(x, y);
    }
    if op == OP_AND {
        return PyNumber_And(x, y);
    }
    if op == OP_XOR {
        return PyNumber_Xor(x, y);
    }
    if op == OP_OR {
        return PyNumber_Or(x, y);
    }
    if op == OP_IADD {
        return PyNumber_InPlaceAdd(x, y);
    }
    if op == OP_ISUB {
        return PyNumber_InPlaceSubtract(x, y);
    }
    if op == OP_IMUL {
        return PyNumber_InPlaceMultiply(x, y);
    }
    if op == OP_IFLOOR_DIV {
        return PyNumber_InPlaceFloorDivide(x, y);
    }
    if op == OP_ITRUE_DIV {
        return PyNumber_InPlaceTrueDivide(x, y);
    }
    if op == OP_IMOD {
        return PyNumber_InPlaceRemainder(x, y);
    }
    if op == OP_ILSHIFT {
        return PyNumber_InPlaceLshift(x, y);
    }
    if op == OP_IRSHIFT {
        return PyNumber_InPlaceRshift(x, y);
    }
    if op == OP_IAND {
        return PyNumber_InPlaceAnd(x, y);
    }
    if op == OP_IXOR {
        return PyNumber_InPlaceXor(x, y);
    }
    if op == OP_IOR {
        return PyNumber_InPlaceOr(x, y);
    }
    if op == OP_MATMUL {
        return PyNumber_MatrixMultiply(x, y);
    }
    if op == OP_IMATMUL {
        return PyNumber_InPlaceMatrixMultiply(x, y);
    }
    return PyObject_GetItem(x, y);
}

impl unary_operation(op: i64, x: ptr[PyObject]) -> ptr[PyObject] {
    if op == UOP_STR {
        return PyObject_Str(x);
    }
    if op == UOP_NEG {
        return PyNumber_Negative(x);
    }
    if op == UOP_POS {
        return PyNumber_Positive(x);
    }
    if op == UOP_ABS {
        return PyNumber_Absolute(x);
    }
    if op == UOP_INVERT {
        return PyNumber_Invert(x);
    }
    if op == UOP_INT {
        return PyNumber_Long(x);
    }
    if op == UOP_FLOAT {
        return PyNumber_Float(x);
    }
    return PyNumber_Index(x);
}

impl proxy_getattr(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_GETATTR);
}

impl proxy_str(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_STR);
}

impl proxy_call(
    proxy: ptr[PyObject], v_in: ptr[PyObject], w_in: ptr[PyObject]
) -> ptr[PyObject] {
    x = unwrap(proxy);
    if not x {
        return NULL;
    }
    v = unwrap(v_in);
    if not v {
        object_decref(x);
        return NULL;
    }
    w = NULL;
    if w_in {
        w = unwrap(w_in);
        if not w {
            object_decref(x);
            object_decref(v);
            return NULL;
        }
    }
    res = PyObject_Call(x, v, w);
    object_decref(x);
    object_decref(v);
    object_xdecref(w);
    return res;
}

impl proxy_repr(proxy: ptr[PyObject]) -> ptr[PyObject] {
    ob = weakref_get_ref(proxy);
    if ob {
        repr = PyUnicode_FromFormat("<weakproxy at %p; to '%T' at %p>", proxy, ob, ob);
        object_decref(ob);
        return repr;
    }
    return PyUnicode_FromFormat("<weakproxy at %p; dead>", proxy);
}

impl proxy_setattr(
    proxy: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    ob = weakref_get_ref(proxy);
    if not proxy_check_ref(ob) {
        return i32(-1);
    }
    res = PyObject_SetAttr(ob, name, value);
    object_decref(ob);
    return res;
}

impl proxy_richcompare(
    proxy: ptr[PyObject], v_in: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    x = unwrap(proxy);
    if not x {
        return NULL;
    }
    v = unwrap(v_in);
    if not v {
        object_decref(x);
        return NULL;
    }
    res = PyObject_RichCompare(x, v, op);
    object_decref(x);
    object_decref(v);
    return res;
}

impl proxy_add(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_ADD);
}

impl proxy_sub(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_SUB);
}

impl proxy_mul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_MUL);
}

impl proxy_floor_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_FLOOR_DIV);
}

impl proxy_true_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_TRUE_DIV);
}

impl proxy_mod(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_MOD);
}

impl proxy_divmod(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_DIVMOD);
}

impl proxy_pow(x: ptr[PyObject], y: ptr[PyObject], z: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_ternary(x, y, z, False);
}

impl proxy_neg(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_NEG);
}

impl proxy_pos(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_POS);
}

impl proxy_abs(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_ABS);
}

impl proxy_invert(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_INVERT);
}

impl proxy_lshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_LSHIFT);
}

impl proxy_rshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_RSHIFT);
}

impl proxy_and(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_AND);
}

impl proxy_xor(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_XOR);
}

impl proxy_or(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_OR);
}

impl proxy_int(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_INT);
}

impl proxy_float(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_FLOAT);
}

impl proxy_iadd(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IADD);
}

impl proxy_isub(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_ISUB);
}

impl proxy_imul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IMUL);
}

impl proxy_ifloor_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IFLOOR_DIV);
}

impl proxy_itrue_div(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_ITRUE_DIV);
}

impl proxy_imod(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IMOD);
}

impl proxy_ipow(x: ptr[PyObject], y: ptr[PyObject], z: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_ternary(x, y, z, True);
}

impl proxy_ilshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_ILSHIFT);
}

impl proxy_irshift(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IRSHIFT);
}

impl proxy_iand(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IAND);
}

impl proxy_ixor(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IXOR);
}

impl proxy_ior(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IOR);
}

impl proxy_index(x: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_unary(x, UOP_INDEX);
}

impl proxy_matmul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_MATMUL);
}

impl proxy_imatmul(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_IMATMUL);
}

impl proxy_bool(proxy: ptr[PyObject]) -> i32 {
    o = weakref_get_ref(proxy);
    if not proxy_check_ref(o) {
        return i32(-1);
    }
    res = PyObject_IsTrue(o);
    object_decref(o);
    return res;
}

impl proxy_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    clear_weakref(op);
    PyObject_GC_Del(ptr(op));
}

impl proxy_contains(proxy: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    ob = weakref_get_ref(proxy);
    if not proxy_check_ref(ob) {
        return i32(-1);
    }
    res = PySequence_Contains(ob, value);
    object_decref(ob);
    return res;
}

impl proxy_length(proxy: ptr[PyObject]) -> i64 {
    ob = weakref_get_ref(proxy);
    if not proxy_check_ref(ob) {
        return -1;
    }
    res = PyObject_Length(ob);
    object_decref(ob);
    return res;
}

impl proxy_getitem(x: ptr[PyObject], y: ptr[PyObject]) -> ptr[PyObject] {
    return wrap_binary(x, y, OP_GETITEM);
}

impl proxy_setitem(
    proxy: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    ob = weakref_get_ref(proxy);
    if not proxy_check_ref(ob) {
        return i32(-1);
    }
    res = PyObject_DelItem(ob, key) if not value else PyObject_SetItem(ob, key, value);
    object_decref(ob);
    return res;
}

impl proxy_iter(proxy: ptr[PyObject]) -> ptr[PyObject] {
    ob = weakref_get_ref(proxy);
    if not proxy_check_ref(ob) {
        return NULL;
    }
    res = PyObject_GetIter(ob);
    object_decref(ob);
    return res;
}

impl proxy_iternext(proxy: ptr[PyObject]) -> ptr[PyObject] {
    ob = weakref_get_ref(proxy);
    if not proxy_check_ref(ob) {
        return NULL;
    }
    if PyIter_Check(ob) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("Weakref proxy referenced a non-iterator '%.200s' object"),
            object_type(ob).view(1)[0].tp_name
        );
        object_decref(ob);
        return NULL;
    }
    res = PyIter_Next(ob);
    object_decref(ob);
    return res;
}

impl proxy_call_method(proxy: ptr[PyObject], name: str) -> ptr[PyObject] {
    ob = unwrap(proxy);
    if not ob {
        return NULL;
    }

    method = jacpy_object_getattr_text(ob, name);
    object_decref(ob);
    if not method {
        return NULL;
    }
    res = PyObject_CallNoArgs(method);
    object_decref(method);
    return res;
}

impl proxy_bytes(proxy: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return proxy_call_method(proxy, "__bytes__");
}

impl proxy_reversed(proxy: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return proxy_call_method(proxy, "__reversed__");
}
