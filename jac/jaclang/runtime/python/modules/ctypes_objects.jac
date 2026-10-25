import from c {
    def strlen(text: ptr[u8]) -> u64;  def wcslen(s: ptr[i32]) -> u64;  def strchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def PyCArrayType_from_ctype(
        st: ptr[ctypes_state], itemtype: ptr[PyObject], length: i64
    ) -> ptr[PyObject] {
        len_obj = PyLong_FromSsize_t(length);
        if not len_obj {
            return NULL;
        }
        key = PyTuple_Pack(2, itemtype, len_obj);
        object_decref(len_obj);
        if not key {
            return NULL;
        }

        (found, result) = _PyDict_GetItemProxy(st.view(1)[0].array_cache, key);
        if found != 0 {
            object_decref(key);
            return result;
        }

        if not type_check(itemtype) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("Expected a type object"));
            object_decref(key);
            return NULL;
        }
        name = ptr[u8](PyMem_Malloc(256));
        if not name {
            object_decref(key);
            PyErr_NoMemory();
            return NULL;
        }
        PyOS_snprintf(
            name,
            256,
            ptr[u8]("%.200s_Array_%ld"),
            ptr[PyTypeObject](itemtype).view(1)[0].tp_name,
            length
        );
        created = PyObject_CallFunction(
            ptr[PyObject](st.view(1)[0].PyCArrayType_Type),
            "s(O){s:n,s:O}",
            name,
            ptr[PyObject](st.view(1)[0].PyCArray_Type),
            ptr[u8]("_length_"),
            length,
            ptr[u8]("_type_"),
            itemtype
        );
        PyMem_Free(ptr(name));
        if not created {
            object_decref(key);
            return NULL;
        }
        if PyDict_SetItemProxy(st, st.view(1)[0].array_cache, key, created) < 0 {
            object_decref(key);
            object_decref(created);
            return NULL;
        }
        object_decref(key);
        return created;
    }
}

glob:priv Py_CONSTANT_EMPTY_BYTES: Final[u32] = 8,
     PYCFUNCPTR_CONVERTERS: Final[i64] = 112,
     PYCFUNCPTR_ARGTYPES: Final[i64] = 120,
     PYCFUNCPTR_RESTYPE: Final[i64] = 128,
     PYCFUNCPTR_CHECKER: Final[i64] = 136,
     PYCFUNCPTR_ERRCHECK: Final[i64] = 144;

def funcptr_field(self_: ptr[PyCFuncPtrObject], offset: i64) -> ptr[ptr[PyObject]];

def trunc_div(a: i64, b: i64) -> i64;

def list_store(lst: ptr[PyObject], index: i64, item: ptr[PyObject]);

def instance_state(op: ptr[PyObject]) -> ptr[ctypes_state];

def _byref(st: ptr[ctypes_state], obj_: ptr[PyObject]) -> ptr[PyObject];

def _get_arg(
    index: i64,
    name: ptr[PyObject],
    defval: ptr[PyObject],
    inargs: ptr[PyObject],
    kwds: ptr[PyObject]
) -> tuple[ptr[PyObject], i64];

def _callargs_error(callargs: ptr[PyObject]) -> tuple[ptr[PyObject], u32, u32, u32];

def _build_callargs(
    st: ptr[ctypes_state],
    self_: ptr[PyCFuncPtrObject],
    argtypes: ptr[PyObject],
    inargs: ptr[PyObject],
    kwds: ptr[PyObject]
) -> tuple[ptr[PyObject], u32, u32, u32];

def _build_result(
    result: ptr[PyObject],
    callargs: ptr[PyObject],
    outmask: u32,
    inoutmask: u32,
    numretvals: u32
) -> ptr[PyObject];

def _call_with_callargs(
    st: ptr[ctypes_state],
    op: ptr[PyObject],
    info: ptr[StgInfo],
    pProc: ptr,
    callargs: ptr[PyObject],
    outmask: u32,
    inoutmask: u32,
    numretvals: u32,
    restype: ptr[PyObject],
    converters: ptr[PyObject],
    checker: ptr[PyObject],
    errcheck: ptr[PyObject]
) -> ptr[PyObject];

def PyCFuncPtr_call(
    op: ptr[PyObject], inargs: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def PyCFuncPtr_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def PyCFuncPtr_clear(op: ptr[PyObject]) -> i32;

def PyCFuncPtr_dealloc(self_: ptr[PyObject]);

def PyCFuncPtr_repr(op: ptr[PyObject]) -> ptr[PyObject];

def PyCFuncPtr_bool(op: ptr[PyObject]) -> i32;

def _init_pos_args(
    self_: ptr[PyObject],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject],
    index: i64
) -> i64;

def Struct_init(self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32;

def Array_init(self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]) -> i32;

def Array_item_lock_held(myself: ptr[PyObject], index: i64) -> ptr[PyObject];

def Array_item(myself: ptr[PyObject], index: i64) -> ptr[PyObject];

def Array_subscript_lock_held(
    myself: ptr[PyObject], item: ptr[PyObject]
) -> ptr[PyObject];

def Array_subscript(myself: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def Array_ass_item_lock_held(
    myself: ptr[PyObject], index: i64, value: ptr[PyObject]
) -> i32;

def Array_ass_item(myself: ptr[PyObject], index: i64, value: ptr[PyObject]) -> i32;

def Array_ass_subscript_lock_held(
    myself: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def Array_ass_subscript(
    myself: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def Array_length(myself: ptr[PyObject]) -> i64;

def _ctypes_Simple_value_set_impl(self_: ptr[PyObject], value: ptr[PyObject]) -> i32;

def Simple_init(self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]) -> i32;

def _ctypes_Simple_value_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def Simple_from_outparm_impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def Simple_bool(op: ptr[PyObject]) -> i32;

def Simple_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def Pointer_item_lock_held(myself: ptr[PyObject], index: i64) -> ptr[PyObject];

def Pointer_item(self_: ptr[PyObject], index: i64) -> ptr[PyObject];

def Pointer_ass_item_lock_held(
    myself: ptr[PyObject], index: i64, value: ptr[PyObject]
) -> i32;

def Pointer_ass_item(self_: ptr[PyObject], index: i64, value: ptr[PyObject]) -> i32;

def Pointer_get_contents_lock_held(
    self_: ptr[PyObject], closure: ptr
) -> ptr[PyObject];

def Pointer_get_contents(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def Pointer_set_contents_lock_held(
    op: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32;

def Pointer_set_contents(op: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32;

def Pointer_init(self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]) -> i32;

def Pointer_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject];

def copy_pointer_to_list_lock_held(
    myself: ptr[PyObject], np: ptr[PyObject], length: i64, start: i64, step: i64
) -> i32;

def Pointer_subscript(myself: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def Pointer_bool(self_: ptr[PyObject]) -> i32;

def string_at(ptr_: ptr[u8], size: i32) -> ptr[PyObject];

def cast_check_pointertype(st: ptr[ctypes_state], arg: ptr[PyObject]) -> i32;

def cast_lock_held(
    ptr_: ptr, src: ptr[PyObject], ctype: ptr[PyObject]
) -> ptr[PyObject];

def cast(ptr_: ptr, src: ptr[PyObject], ctype: ptr[PyObject]) -> ptr[PyObject];

def wstring_at(ptr_: ptr[i32], size: i32) -> ptr[PyObject];

def memoryview_at(ptr_: ptr, size: i64, readonly: i32) -> ptr[PyObject];

import from c {
    glob:priv Pointer_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("contents"),
                 get=Pointer_get_contents,
                 set=Pointer_set_contents,
                 doc=ptr[u8]("the object this pointer points to (read-write)"),
                 closure=ptr()
             ),
             PyGetSetDef()
         ],
         Array_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8]("Arrays are generic over the type of their elements")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         pycstruct_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("Structure base class")),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(Struct_init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(GenericPyCData_new)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(PyCData_NewGetBuffer)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycunion_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("Union base class")),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(Struct_init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(GenericPyCData_new)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(PyCData_NewGetBuffer)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycarray_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "Abstract base class for arrays.\n"
                     "\n"
                     "The recommended way to create concrete array types is by multiplying any\n"
                     "ctypes data type with a non-negative integer. Alternatively, you can subclass\n"
                     "this type and define _length_ and _type_ class variables. Array elements can\n"
                     "be read and written using standard subscript and slice accesses for slice\n"
                     "reads, the resulting object is not itself an Array."
                 )
             ),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(Array_methods))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(Array_init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(GenericPyCData_new)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(PyCData_NewGetBuffer)),
             PyType_Slot(slot=Py_sq_length, pfunc=ptr(Array_length)),
             PyType_Slot(slot=Py_sq_item, pfunc=ptr(Array_item)),
             PyType_Slot(slot=Py_sq_ass_item, pfunc=ptr(Array_ass_item)),
             PyType_Slot(slot=Py_mp_length, pfunc=ptr(Array_length)),
             PyType_Slot(slot=Py_mp_subscript, pfunc=ptr(Array_subscript)),
             PyType_Slot(slot=Py_mp_ass_subscript, pfunc=ptr(Array_ass_subscript)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycpointer_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("XXX to be provided")),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(Pointer_getsets))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(Pointer_init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(Pointer_new)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(PyCData_NewGetBuffer)),
             PyType_Slot(slot=Py_nb_bool, pfunc=ptr(Pointer_bool)),
             PyType_Slot(slot=Py_mp_subscript, pfunc=ptr(Pointer_subscript)),
             PyType_Slot(slot=Py_sq_item, pfunc=ptr(Pointer_item)),
             PyType_Slot(slot=Py_sq_ass_item, pfunc=ptr(Pointer_ass_item)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob pycfuncptr_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(PyCFuncPtr_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(PyCFuncPtr_repr)),
             PyType_Slot(slot=Py_tp_call, pfunc=ptr(PyCFuncPtr_call)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("Function Pointer")),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(PyCFuncPtr_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(PyCFuncPtr_clear)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(PyCFuncPtr_new)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(PyCData_NewGetBuffer)),
             PyType_Slot(slot=Py_nb_bool, pfunc=ptr(PyCFuncPtr_bool)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycfuncptr_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.CFuncPtr"),
             basicsize=i32(SIZEOF_PYCFUNCPTROBJECT),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycfuncptr_slots)
         ),
         pycstruct_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.Structure"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycstruct_slots)
         ),
         pycunion_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.Union"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycunion_slots)
         ),
         pycarray_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.Array"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycarray_slots)
         ),
         pycsimple_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(Simple_repr)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("XXX to be provided")),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(Simple_init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(GenericPyCData_new)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(PyCData_NewGetBuffer)),
             PyType_Slot(slot=Py_nb_bool, pfunc=ptr(Simple_bool)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycsimple_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes._SimpleCData"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycsimple_slots)
         ),
         pycpointer_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes._Pointer"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycpointer_slots)
         );
}

impl funcptr_field(self_: ptr[PyCFuncPtrObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](self_) + offset);
}

impl trunc_div(a: i64, b: i64) -> i64 {
    q = a // b;
    if a % b != 0 and (a < 0) != (b < 0) {
        q += 1;
    }
    return q;
}

impl list_store(lst: ptr[PyObject], index: i64, item: ptr[PyObject]) {
    (ptr[PyListObject](lst).view(1)[0].ob_item + index).view(1)[0] = item;
}

impl instance_state(op: ptr[PyObject]) -> ptr[ctypes_state] {
    return get_module_state_by_def(object_type(ptr[PyObject](object_type(op))));
}

impl _byref(st: ptr[ctypes_state], obj_: ptr[PyObject]) -> ptr[PyObject] {
    if not CDataObject_Check(st, obj_) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("expected CData instance"));
        return NULL;
    }

    parg = PyCArgObject_new(st);
    if not parg {
        object_decref(obj_);
        return NULL;
    }

    parg.view(1)[0].tag = 80;
    parg.view(1)[0].pffi_type = addressof(ffi_type_pointer);
    parg.view(1)[0].obj_ = obj_;
    ptr[ptr[u8]](carg_value_address(parg)).view(1)[0] = ptr[CDataObject](obj_).view(1)[
        0
    ].b_ptr;
    return ptr[PyObject](parg);
}

impl _get_arg(
    index: i64,
    name: ptr[PyObject],
    defval: ptr[PyObject],
    inargs: ptr[PyObject],
    kwds: ptr[PyObject]
) -> tuple[ptr[PyObject], i64] {
    if index < object_size(inargs) {
        v = tuple_get_item(inargs, index);
        return (object_new_ref(v), index + 1);
    }
    if kwds and name {
        found: ptr[PyObject] = NULL;
        if PyDict_GetItemRef(kwds, name, &mut found) < 0 {
            return (NULL, index);
        }
        if found {
            return (found, index + 1);
        }
    }
    if defval {
        return (object_new_ref(defval), index);
    }

    if name {
        PyErr_Format(PyExc_TypeError, ptr[u8]("required argument '%S' missing"), name);
    } else {
        PyErr_Format(PyExc_TypeError, ptr[u8]("not enough arguments"));
    }
    return (NULL, index);
}

impl _callargs_error(callargs: ptr[PyObject]) -> tuple[ptr[PyObject], u32, u32, u32] {
    object_decref(callargs);
    return (NULL, u32(0), u32(0), u32(0));
}

impl _build_callargs(
    st: ptr[ctypes_state],
    self_: ptr[PyCFuncPtrObject],
    argtypes: ptr[PyObject],
    inargs: ptr[PyObject],
    kwds: ptr[PyObject]
) -> tuple[ptr[PyObject], u32, u32, u32] {
    paramflags = self_.view(1)[0].paramflags;
    outmask: u32 = 0;
    inoutmask: u32 = 0;
    numretvals: u32 = 0;

    if not argtypes or not paramflags or object_size(argtypes) == 0 {
        return (object_new_ref(inargs), outmask, inoutmask, numretvals);
    }

    length = object_size(argtypes);
    callargs = PyTuple_New(length);
    if not callargs {
        return (NULL, outmask, inoutmask, numretvals);
    }

    inargs_index: i64 = 0;
    i: i64 = 0;
    while i < length {
        item = tuple_get_item(paramflags, i);

        tsize = object_size(item);
        flag = u32.wrap(PyLong_AsUnsignedLongMask(tuple_get_item(item, 0)));
        name: ptr[PyObject] = NULL;
        if tsize > 1 {
            name = tuple_get_item(item, 1);
        }
        defval: ptr[PyObject] = NULL;
        if tsize > 2 {
            defval = tuple_get_item(item, 2);
        }
        bit = u32(1) << u32(i & 31);
        kind = i32(flag & u32(PARAMFLAG_FIN | PARAMFLAG_FOUT | PARAMFLAG_FLCID));

        if kind == (PARAMFLAG_FIN | PARAMFLAG_FLCID) {
            if not defval {
                defval = long_zero();
            }
            object_incref(defval);
            tuple_set_item(callargs, i, defval);
        } elif kind == (PARAMFLAG_FIN | PARAMFLAG_FOUT)
            or kind == 0
            or kind == PARAMFLAG_FIN {
            if kind == (PARAMFLAG_FIN | PARAMFLAG_FOUT) {
                inoutmask |= bit;
                numretvals += 1;
            }
            (ob, next_index) = _get_arg(inargs_index, name, defval, inargs, kwds);
            inargs_index = next_index;
            if not ob {
                return _callargs_error(callargs);
            }
            tuple_set_item(callargs, i, ob);
        } elif kind == PARAMFLAG_FOUT {
            if defval {
                object_incref(defval);
                tuple_set_item(callargs, i, defval);
                outmask |= bit;
                numretvals += 1;
            } else {
                argtype = tuple_get_item(argtypes, i);
                (res, info) = PyStgInfo_FromType(st, argtype);
                if res < 0 {
                    return _callargs_error(callargs);
                }
                if not info {
                    PyErr_Format(
                        PyExc_RuntimeError, ptr[u8]("NULL stginfo unexpected")
                    );
                    return _callargs_error(callargs);
                }
                if unicode_check(info.view(1)[0].proto) {
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8]("%s 'out' parameter must be passed as default value"),
                        ptr[PyTypeObject](argtype).view(1)[0].tp_name
                    );
                    return _callargs_error(callargs);
                }
                created: ptr[PyObject] = NULL;
                if PyCArrayTypeObject_Check(st, argtype) {
                    created = PyObject_CallNoArgs(argtype);
                } else {
                    created = PyObject_CallNoArgs(info.view(1)[0].proto);
                }
                if not created {
                    return _callargs_error(callargs);
                }
                tuple_set_item(callargs, i, created);
                outmask |= bit;
                numretvals += 1;
            }
        } else {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("paramflag %u not yet implemented"), flag
            );
            return _callargs_error(callargs);
        }
        i += 1;
    }

    actual_args = object_size(inargs);
    if kwds {
        actual_args += PyDict_Size(kwds);
    }
    if actual_args != inargs_index {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("call takes exactly %d arguments (%zd given)"),
            i32(inargs_index),
            actual_args
        );
        return _callargs_error(callargs);
    }
    return (callargs, outmask, inoutmask, numretvals);
}

impl _build_result(
    result: ptr[PyObject],
    callargs: ptr[PyObject],
    outmask: u32,
    inoutmask: u32,
    numretvals: u32
) -> ptr[PyObject] {
    if not callargs {
        return result;
    }
    if not result or numretvals == 0 {
        object_decref(callargs);
        return result;
    }
    object_decref(result);

    tup: ptr[PyObject] = NULL;
    if numretvals > 1 {
        tup = PyTuple_New(i64(numretvals));
        if not tup {
            object_decref(callargs);
            return NULL;
        }
    }

    index: u32 = 0;
    i: u32 = 0;
    while i < 32 {
        bit = u32(1) << i;
        if (bit & inoutmask) != 0 {
            v = tuple_get_item(callargs, i64(i));
            object_incref(v);
            if numretvals == 1 {
                object_decref(callargs);
                return v;
            }
            tuple_set_item(tup, i64(index), v);
            index += 1;
        } elif (bit & outmask) != 0 {
            outv = PyObject_CallMethodObjArgs(
                tuple_get_item(callargs, i64(i)),
                py_id(_Py_ID___ctypes_from_outparam__),
                NULL
            );
            if not outv or numretvals == 1 {
                object_xdecref(tup);
                object_decref(callargs);
                return outv;
            }
            tuple_set_item(tup, i64(index), outv);
            index += 1;
        }
        if index == numretvals {
            break;
        }
        i += 1;
    }

    object_decref(callargs);
    return tup;
}

impl _call_with_callargs(
    st: ptr[ctypes_state],
    op: ptr[PyObject],
    info: ptr[StgInfo],
    pProc: ptr,
    callargs: ptr[PyObject],
    outmask: u32,
    inoutmask: u32,
    numretvals: u32,
    restype: ptr[PyObject],
    converters: ptr[PyObject],
    checker: ptr[PyObject],
    errcheck: ptr[PyObject]
) -> ptr[PyObject] {
    if converters {
        required = i32(object_size(converters));
        actual = i32(object_size(callargs));
        plural = ptr[u8]("s");
        if required == 1 {
            plural = ptr[u8]("");
        }

        if (info.view(1)[0].flags & FUNCFLAG_CDECL) == FUNCFLAG_CDECL {
            if required > actual {
                object_decref(callargs);
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("this function takes at least %d argument%s (%d given)"),
                    required,
                    plural,
                    actual
                );
                return NULL;
            }
        } elif required != actual {
            object_decref(callargs);
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("this function takes %d argument%s (%d given)"),
                required,
                plural,
                actual
            );
            return NULL;
        }
    }

    result = _ctypes_callproc(
        st, pProc, callargs, info.view(1)[0].flags, converters, restype, checker
    );

    if result and errcheck {
        v = PyObject_CallFunctionObjArgs(errcheck, result, op, callargs, NULL);

        if not v or v != callargs {
            object_decref(result);
            object_decref(callargs);
            return v;
        }
        object_decref(v);
    }
    return _build_result(result, callargs, outmask, inoutmask, numretvals);
}

impl PyCFuncPtr_call(
    op: ptr[PyObject], inargs: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[PyCFuncPtrObject](op);
    st = instance_state(op);
    (status, info) = PyStgInfo_FromObject(st, op);
    if status < 0 {
        return NULL;
    }

    restype = atomic_xgetref(op, funcptr_field(self_, PYCFUNCPTR_RESTYPE));
    if not restype {
        restype = object_xnewref(info.view(1)[0].restype);
    }
    converters = atomic_xgetref(op, funcptr_field(self_, PYCFUNCPTR_CONVERTERS));
    if not converters {
        converters = object_xnewref(info.view(1)[0].converters);
    }
    checker = atomic_xgetref(op, funcptr_field(self_, PYCFUNCPTR_CHECKER));
    if not checker {
        checker = object_xnewref(info.view(1)[0].checker);
    }
    argtypes = atomic_xgetref(op, funcptr_field(self_, PYCFUNCPTR_ARGTYPES));
    if not argtypes {
        argtypes = object_xnewref(info.view(1)[0].argtypes);
    }

    errcheck = atomic_xgetref(op, funcptr_field(self_, PYCFUNCPTR_ERRCHECK));

    pProc = ptr[ptr](self_.view(1)[0].b_ptr).view(1)[0];
    ret: ptr[PyObject] = NULL;
    (callargs, outmask, inoutmask, numretvals) = _build_callargs(
        st, self_, argtypes, inargs, kwds
    );
    if callargs {
        ret = _call_with_callargs(
            st,
            op,
            info,
            pProc,
            callargs,
            outmask,
            inoutmask,
            numretvals,
            restype,
            converters,
            checker,
            errcheck
        );
    }
    object_xdecref(restype);
    object_xdecref(converters);
    object_xdecref(checker);
    object_xdecref(argtypes);
    object_xdecref(errcheck);
    return ret;
}

impl PyCFuncPtr_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    s = ptr[PyCFuncPtrObject](op).view(1);
    status = visit_reference(s[0].callable, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(s[0].restype, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(s[0].checker, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(s[0].errcheck, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(s[0].argtypes, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(s[0].converters, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(s[0].paramflags, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(ptr[PyObject](s[0].thunk), visitor, arg);
    if status != 0 {
        return status;
    }
    return PyCData_traverse(op, visitor, arg);
}

impl PyCFuncPtr_clear(op: ptr[PyObject]) -> i32 {
    s = ptr[PyCFuncPtrObject](op).view(1);
    old = s[0].callable;
    s[0].callable = NULL;
    object_xdecref(old);
    old = s[0].restype;
    s[0].restype = NULL;
    object_xdecref(old);
    old = s[0].checker;
    s[0].checker = NULL;
    object_xdecref(old);
    old = s[0].errcheck;
    s[0].errcheck = NULL;
    object_xdecref(old);
    old = s[0].argtypes;
    s[0].argtypes = NULL;
    object_xdecref(old);
    old = s[0].converters;
    s[0].converters = NULL;
    object_xdecref(old);
    old = s[0].paramflags;
    s[0].paramflags = NULL;
    object_xdecref(old);
    old = ptr[PyObject](s[0].thunk);
    s[0].thunk = ptr[CThunkObject]();
    object_xdecref(old);
    return PyCData_clear(op);
}

impl PyCFuncPtr_dealloc(self_: ptr[PyObject]) {
    PyObject_GC_UnTrack(ptr(self_));
    PyCFuncPtr_clear(self_);
    type = object_type(self_);
    type.view(1)[0].tp_free(ptr(self_));
    object_decref(ptr[PyObject](type));
}

impl PyCFuncPtr_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<%s object at %p>", object_type(op).view(1)[0].tp_name, op
    );
}

impl PyCFuncPtr_bool(op: ptr[PyObject]) -> i32 {
    deref = ptr[ptr](ptr[CDataObject](op).view(1)[0].b_ptr).view(1)[0];
    if deref {
        return 1;
    }
    return 0;
}

impl _init_pos_args(
    self_: ptr[PyObject],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject],
    index: i64
) -> i64 {
    st = get_module_state_by_def(object_type(ptr[PyObject](type)));
    base = type.view(1)[0].tp_base;
    (base_status, baseinfo) = PyStgInfo_FromType(st, ptr[PyObject](base));
    if base_status < 0 {
        return -1;
    }
    next_index = index;
    if baseinfo {
        next_index = _init_pos_args(self_, base, args, kwds, next_index);
        if next_index == -1 {
            return -1;
        }
    }

    (status, info) = PyStgInfo_FromType(st, ptr[PyObject](type));
    if status < 0 {
        return -1;
    }

    attrdict = PyType_GetDict(ptr[PyObject](type));
    fields = PyDict_GetItemWithError(attrdict, py_id(_Py_ID__fields_));
    object_decref(attrdict);
    if not fields {
        if PyErr_Occurred() {
            return -1;
        }
        return next_index;
    }

    i = next_index;
    while i < info.view(1)[0].length and i < object_size(args) {
        pair = PySequence_GetItem(fields, i - next_index);
        if not pair {
            return -1;
        }
        name = PySequence_GetItem(pair, 0);
        if not name {
            object_decref(pair);
            return -1;
        }
        val = tuple_get_item(args, i);
        if kwds {
            res = PyDict_Contains(kwds, name);
            if res != 0 {
                if res > 0 {
                    PyErr_Format(
                        PyExc_TypeError, ptr[u8]("duplicate values for field %R"), name
                    );
                }
                object_decref(pair);
                object_decref(name);
                return -1;
            }
        }

        set_res = PyObject_SetAttr(self_, name, val);
        object_decref(pair);
        object_decref(name);
        if set_res == -1 {
            return -1;
        }
        i += 1;
    }
    return info.view(1)[0].length;
}

impl Struct_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    if not tuple_check(args) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("args not a tuple?"));
        return -1;
    }
    if object_size(args) != 0 {
        res = _init_pos_args(self_, object_type(self_), args, kwds, 0);
        if res == -1 {
            return -1;
        }
        if res < object_size(args) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("too many initializers"));
            return -1;
        }
    }

    if kwds {
        key: ptr[PyObject] = NULL;
        value: ptr[PyObject] = NULL;
        pos: i64 = 0;
        while PyDict_Next(kwds, &mut pos, &mut key, &mut value) != 0 {
            if PyObject_SetAttr(self_, key, value) == -1 {
                return -1;
            }
        }
    }
    return 0;
}

impl Array_init(self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]) -> i32 {
    if not tuple_check(args) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("args not a tuple?"));
        return -1;
    }
    n = object_size(args);
    i: i64 = 0;
    while i < n {
        v = tuple_get_item(args, i);
        if PySequence_SetItem(self_, i, v) == -1 {
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl Array_item_lock_held(myself: ptr[PyObject], index: i64) -> ptr[PyObject] {
    self_ = ptr[CDataObject](myself);
    if index < 0 or index >= self_.view(1)[0].b_length {
        PyErr_SetString(PyExc_IndexError, ptr[u8]("invalid index"));
        return NULL;
    }

    st = instance_state(myself);
    (status, stginfo) = PyStgInfo_FromObject(st, myself);
    if status < 0 {
        return NULL;
    }

    size = stginfo.view(1)[0].size // stginfo.view(1)[0].length;
    offset = index * size;

    return PyCData_get(
        st,
        stginfo.view(1)[0].proto,
        stginfo.view(1)[0].getfunc,
        myself,
        index,
        size,
        self_.view(1)[0].b_ptr + offset
    );
}

impl Array_item(myself: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return Array_item_lock_held(myself, index);
}

impl Array_subscript_lock_held(
    myself: ptr[PyObject], item: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[CDataObject](myself);

    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        if i < 0 {
            i += self_.view(1)[0].b_length;
        }
        return Array_item_lock_held(myself, i);
    } elif object_type(item) == ptr[PyTypeObject](addressof(PySlice_Type)) {
        start: i64 = 0;
        stop: i64 = 0;
        step: i64 = 0;
        if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < 0 {
            return NULL;
        }
        slicelen = PySlice_AdjustIndices(
            self_.view(1)[0].b_length, &mut start, &mut stop, step
        );
        st = instance_state(myself);
        (status, stginfo) = PyStgInfo_FromObject(st, myself);
        if status < 0 {
            return NULL;
        }
        proto = stginfo.view(1)[0].proto;
        (item_status, iteminfo) = PyStgInfo_FromType(st, proto);
        if item_status < 0 {
            return NULL;
        }
        item_getfunc = int(iteminfo.view(1)[0].getfunc);
        if item_getfunc
            == int(_ctypes_get_fielddesc(ptr[u8]("c")).view(1)[0].getfunc) {
            bp = self_.view(1)[0].b_ptr;
            if slicelen <= 0 {
                return Py_GetConstant(Py_CONSTANT_EMPTY_BYTES);
            }
            if step == 1 {
                return PyBytes_FromStringAndSize(bp + start, slicelen);
            }
            dest = ptr[u8](PyMem_Malloc(u64(slicelen)));
            if not dest {
                return PyErr_NoMemory();
            }
            cur = start;
            n: i64 = 0;
            while n < slicelen {
                (dest + n).view(1)[0] = (bp + cur).view(1)[0];
                cur = wrapping_add(cur, step);
                n += 1;
            }
            np = PyBytes_FromStringAndSize(dest, slicelen);
            PyMem_Free(ptr(dest));
            return np;
        }
        if item_getfunc
            == int(_ctypes_get_fielddesc(ptr[u8]("u")).view(1)[0].getfunc) {
            wp = ptr[i32](self_.view(1)[0].b_ptr);
            if slicelen <= 0 {
                return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
            }
            if step == 1 {
                return PyUnicode_FromWideChar(wp + start, slicelen);
            }
            wdest = ptr[i32](PyMem_Malloc(u64(slicelen) * 4));
            if not wdest {
                PyErr_NoMemory();
                return NULL;
            }
            wcur = start;
            wn: i64 = 0;
            while wn < slicelen {
                (wdest + wn).view(1)[0] = (wp + wcur).view(1)[0];
                wcur = wrapping_add(wcur, step);
                wn += 1;
            }
            wnp = PyUnicode_FromWideChar(wdest, slicelen);
            PyMem_Free(ptr(wdest));
            return wnp;
        }
        lnp = PyList_New(slicelen);
        if not lnp {
            return NULL;
        }
        lcur = start;
        ln: i64 = 0;
        while ln < slicelen {
            v = Array_item_lock_held(myself, lcur);
            if not v {
                object_decref(lnp);
                return NULL;
            }
            list_store(lnp, ln, v);
            lcur = wrapping_add(lcur, step);
            ln += 1;
        }
        return lnp;
    }
    PyErr_SetString(PyExc_TypeError, ptr[u8]("indices must be integers"));
    return NULL;
}

impl Array_subscript(myself: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    return Array_subscript_lock_held(myself, item);
}

impl Array_ass_item_lock_held(
    myself: ptr[PyObject], index: i64, value: ptr[PyObject]
) -> i32 {
    self_ = ptr[CDataObject](myself);
    if not value {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("Array does not support item deletion")
        );
        return -1;
    }

    st = instance_state(myself);
    (status, stginfo) = PyStgInfo_FromObject(st, myself);
    if status < 0 {
        return -1;
    }

    if index < 0 or index >= stginfo.view(1)[0].length {
        PyErr_SetString(PyExc_IndexError, ptr[u8]("invalid index"));
        return -1;
    }
    size = stginfo.view(1)[0].size // stginfo.view(1)[0].length;
    offset = index * size;
    adr = self_.view(1)[0].b_ptr + offset;

    return PyCData_set(
        st,
        myself,
        stginfo.view(1)[0].proto,
        stginfo.view(1)[0].setfunc,
        value,
        index,
        size,
        adr
    );
}

impl Array_ass_item(myself: ptr[PyObject], index: i64, value: ptr[PyObject]) -> i32 {
    return Array_ass_item_lock_held(myself, index, value);
}

impl Array_ass_subscript_lock_held(
    myself: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    self_ = ptr[CDataObject](myself);

    if not value {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("Array does not support item deletion")
        );
        return -1;
    }

    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return -1;
        }
        if i < 0 {
            i += self_.view(1)[0].b_length;
        }
        return Array_ass_item_lock_held(myself, i, value);
    } elif object_type(item) == ptr[PyTypeObject](addressof(PySlice_Type)) {
        start: i64 = 0;
        stop: i64 = 0;
        step: i64 = 0;
        if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < 0 {
            return -1;
        }
        slicelen = PySlice_AdjustIndices(
            self_.view(1)[0].b_length, &mut start, &mut stop, step
        );
        if (step < 0 and start < stop) or (step > 0 and start > stop) {
            stop = start;
        }
        otherlen = PySequence_Length(value);
        if otherlen != slicelen {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("Can only assign sequence of same size")
            );
            return -1;
        }
        cur = start;
        n: i64 = 0;
        while n < otherlen {
            elem = PySequence_GetItem(value, n);
            if not elem {
                return -1;
            }
            result = Array_ass_item_lock_held(myself, cur, elem);
            object_decref(elem);
            if result == -1 {
                return -1;
            }
            cur = wrapping_add(cur, step);
            n += 1;
        }
        return 0;
    }
    PyErr_SetString(PyExc_TypeError, ptr[u8]("indices must be integer"));
    return -1;
}

impl Array_ass_subscript(
    myself: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    return Array_ass_subscript_lock_held(myself, item, value);
}

impl Array_length(myself: ptr[PyObject]) -> i64 {
    return ptr[CDataObject](myself).view(1)[0].b_length;
}

impl _ctypes_Simple_value_set_impl(self_: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("can't delete attribute"));
        return -1;
    }

    st = instance_state(self_);
    (status, info) = PyStgInfo_FromObject(st, self_);
    if status < 0 {
        return -1;
    }

    cdata = ptr[CDataObject](self_);
    result = call_setfunc(
        info.view(1)[0].setfunc,
        ptr(cdata.view(1)[0].b_ptr),
        value,
        info.view(1)[0].size
    );
    if not result {
        return -1;
    }

    return KeepRef(cdata, 0, result);
}

impl Simple_init(self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]) -> i32 {
    value: ptr[PyObject] = NULL;
    if PyArg_UnpackTuple(args, ptr[u8]("__init__"), 0, 1, &mut value) == 0 {
        return -1;
    }
    if value {
        return _ctypes_Simple_value_set_impl(self_, value);
    }
    return 0;
}

impl _ctypes_Simple_value_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    st = instance_state(self_);
    (status, info) = PyStgInfo_FromObject(st, self_);
    if status < 0 {
        return NULL;
    }

    cdata = ptr[CDataObject](self_);
    return call_getfunc(
        info.view(1)[0].getfunc, ptr(cdata.view(1)[0].b_ptr), cdata.view(1)[0].b_size
    );
}

impl Simple_from_outparm_impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    if _ctypes_simple_instance(st, ptr[PyObject](object_type(self_))) != 0 {
        return object_new_ref(self_);
    }

    return _ctypes_Simple_value_get_impl(self_);
}

impl Simple_bool(op: ptr[PyObject]) -> i32 {
    self_ = ptr[CDataObject](op);
    bp = self_.view(1)[0].b_ptr;
    size = self_.view(1)[0].b_size;
    i: i64 = 0;
    while i < size {
        if (bp + i).view(1)[0] != 0 {
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl Simple_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    st = instance_state(self_);
    tp = object_type(self_);

    if tp.view(1)[0].tp_base != st.view(1)[0].Simple_Type {
        return PyUnicode_FromFormat("<%s object at %p>", tp.view(1)[0].tp_name, self_);
    }

    val = _ctypes_Simple_value_get_impl(self_);
    if not val {
        return NULL;
    }

    result = PyUnicode_FromFormat("%s(%R)", tp.view(1)[0].tp_name, val);
    object_decref(val);
    return result;
}

impl Pointer_item_lock_held(myself: ptr[PyObject], index: i64) -> ptr[PyObject] {
    self_ = ptr[CDataObject](myself);
    deref = ptr[ptr[u8]](self_.view(1)[0].b_ptr).view(1)[0];

    if not deref {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("NULL pointer access"));
        return NULL;
    }

    st = instance_state(myself);
    (status, stginfo) = PyStgInfo_FromObject(st, myself);
    if status < 0 {
        return NULL;
    }

    proto = stginfo.view(1)[0].proto;
    (item_status, iteminfo) = PyStgInfo_FromType(st, proto);
    if item_status < 0 {
        return NULL;
    }

    size = iteminfo.view(1)[0].size;
    offset = wrapping_mul(index, iteminfo.view(1)[0].size);

    return PyCData_get(
        st, proto, stginfo.view(1)[0].getfunc, myself, index, size, deref + offset
    );
}

impl Pointer_item(self_: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return Pointer_item_lock_held(self_, index);
}

impl Pointer_ass_item_lock_held(
    myself: ptr[PyObject], index: i64, value: ptr[PyObject]
) -> i32 {
    self_ = ptr[CDataObject](myself);

    if not value {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("Pointer does not support item deletion")
        );
        return -1;
    }

    deref = ptr[ptr[u8]](self_.view(1)[0].b_ptr).view(1)[0];
    if not deref {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("NULL pointer access"));
        return -1;
    }

    st = instance_state(myself);
    (status, stginfo) = PyStgInfo_FromObject(st, myself);
    if status < 0 {
        return -1;
    }

    proto = stginfo.view(1)[0].proto;
    (item_status, iteminfo) = PyStgInfo_FromType(st, proto);
    if item_status < 0 {
        return -1;
    }

    size = iteminfo.view(1)[0].size;
    offset = wrapping_mul(index, iteminfo.view(1)[0].size);

    return PyCData_set(
        st,
        myself,
        proto,
        stginfo.view(1)[0].setfunc,
        value,
        index,
        size,
        deref + offset
    );
}

impl Pointer_ass_item(self_: ptr[PyObject], index: i64, value: ptr[PyObject]) -> i32 {
    return Pointer_ass_item_lock_held(self_, index, value);
}

impl Pointer_get_contents_lock_held(
    self_: ptr[PyObject], closure: ptr
) -> ptr[PyObject] {
    deref = ptr[ptr[u8]](ptr[CDataObject](self_).view(1)[0].b_ptr).view(1)[0];
    if not deref {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("NULL pointer access"));
        return NULL;
    }

    st = instance_state(self_);
    (status, stginfo) = PyStgInfo_FromObject(st, self_);
    if status < 0 {
        return NULL;
    }

    return PyCData_FromBaseObj(st, stginfo.view(1)[0].proto, self_, 0, deref);
}

impl Pointer_get_contents(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return Pointer_get_contents_lock_held(self_, closure);
}

impl Pointer_set_contents_lock_held(
    op: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32 {
    self_ = ptr[CDataObject](op);

    if not value {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("Pointer does not support item deletion")
        );
        return -1;
    }
    st = instance_state(op);
    (status, stginfo) = PyStgInfo_FromObject(st, op);
    if status < 0 {
        return -1;
    }

    proto = stginfo.view(1)[0].proto;
    if not CDataObject_Check(st, value) {
        res = PyObject_IsInstance(value, proto);
        if res == -1 {
            return -1;
        }
        if res == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("expected %s instead of %s"),
                ptr[PyTypeObject](proto).view(1)[0].tp_name,
                object_type(value).view(1)[0].tp_name
            );
            return -1;
        }
    }

    dst = ptr[CDataObject](value);
    ptr[ptr[u8]](self_.view(1)[0].b_ptr).view(1)[0] = dst.view(1)[0].b_ptr;

    object_incref(value);
    if KeepRef(self_, 1, value) == -1 {
        return -1;
    }

    keep = GetKeepedObjects(dst);
    if not keep {
        return -1;
    }

    object_incref(keep);
    return KeepRef(self_, 0, keep);
}

impl Pointer_set_contents(
    op: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32 {
    return Pointer_set_contents_lock_held(op, value, closure);
}

impl Pointer_init(self_: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]) -> i32 {
    value: ptr[PyObject] = NULL;
    if PyArg_UnpackTuple(args, ptr[u8]("POINTER"), 0, 1, &mut value) == 0 {
        return -1;
    }
    if not value {
        return 0;
    }
    return Pointer_set_contents(self_, value, ptr());
}

impl Pointer_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    st = get_module_state_by_def(object_type(ptr[PyObject](type)));
    (status, info) = PyStgInfo_FromType(st, ptr[PyObject](type));
    if status < 0 {
        return NULL;
    }
    if not info or not info.view(1)[0].proto {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("Cannot create instance: has no _type_")
        );
        return NULL;
    }
    return generic_pycdata_new(st, type, args, kw);
}

impl copy_pointer_to_list_lock_held(
    myself: ptr[PyObject], np: ptr[PyObject], length: i64, start: i64, step: i64
) -> i32 {
    cur = start;
    i: i64 = 0;
    while i < length {
        v = Pointer_item_lock_held(myself, cur);
        if not v {
            return -1;
        }
        list_store(np, i, v);
        cur = wrapping_add(cur, step);
        i += 1;
    }
    return 0;
}

impl Pointer_subscript(myself: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    self_ = ptr[CDataObject](myself);
    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        return Pointer_item(myself, i);
    } elif object_type(item) == ptr[PyTypeObject](addressof(PySlice_Type)) {
        slice = ptr[PySliceObject](item).view(1);
        start: i64 = 0;
        stop: i64 = 0;
        step: i64 = 1;
        if slice[0].step != Py_None {
            step = PyNumber_AsSsize_t(slice[0].step, PyExc_ValueError);
            if step == -1 and PyErr_Occurred() {
                return NULL;
            }
            if step == 0 {
                PyErr_SetString(PyExc_ValueError, ptr[u8]("slice step cannot be zero"));
                return NULL;
            }
        }
        if slice[0].start == Py_None {
            if step < 0 {
                PyErr_SetString(
                    PyExc_ValueError, ptr[u8]("slice start is required for step < 0")
                );
                return NULL;
            }
            start = 0;
        } else {
            start = PyNumber_AsSsize_t(slice[0].start, PyExc_ValueError);
            if start == -1 and PyErr_Occurred() {
                return NULL;
            }
        }
        if slice[0].stop == Py_None {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("slice stop is required"));
            return NULL;
        }
        stop = PyNumber_AsSsize_t(slice[0].stop, PyExc_ValueError);
        if stop == -1 and PyErr_Occurred() {
            return NULL;
        }
        length: i64 = 0;
        if (step > 0 and start > stop) or (step < 0 and start < stop) {
            length = 0;
        } elif step > 0 {
            length = trunc_div(wrapping_sub(wrapping_sub(stop, start), 1), step) + 1;
        } else {
            length = trunc_div(wrapping_add(wrapping_sub(stop, start), 1), step) + 1;
        }
        st = instance_state(myself);
        (status, stginfo) = PyStgInfo_FromObject(st, myself);
        if status < 0 {
            return NULL;
        }
        proto = stginfo.view(1)[0].proto;
        (item_status, iteminfo) = PyStgInfo_FromType(st, proto);
        if item_status < 0 {
            return NULL;
        }
        item_getfunc = int(iteminfo.view(1)[0].getfunc);
        if item_getfunc
            == int(_ctypes_get_fielddesc(ptr[u8]("c")).view(1)[0].getfunc) {
            if length <= 0 {
                return Py_GetConstant(Py_CONSTANT_EMPTY_BYTES);
            }
            if step == 1 {
                bp = ptr[ptr[u8]](self_.view(1)[0].b_ptr).view(1)[0];
                return PyBytes_FromStringAndSize(bp + start, length);
            }
            dest = ptr[u8](PyMem_Malloc(u64(length)));
            if not dest {
                return PyErr_NoMemory();
            }
            src = ptr[ptr[u8]](self_.view(1)[0].b_ptr).view(1)[0];
            cur = start;
            n: i64 = 0;
            while n < length {
                (dest + n).view(1)[0] = (src + cur).view(1)[0];
                cur = wrapping_add(cur, step);
                n += 1;
            }
            np = PyBytes_FromStringAndSize(dest, length);
            PyMem_Free(ptr(dest));
            return np;
        }
        if item_getfunc
            == int(_ctypes_get_fielddesc(ptr[u8]("u")).view(1)[0].getfunc) {
            if length <= 0 {
                return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
            }
            if step == 1 {
                wp = ptr[ptr[i32]](self_.view(1)[0].b_ptr).view(1)[0];
                return PyUnicode_FromWideChar(wp + start, length);
            }
            wdest = ptr[i32](PyMem_Malloc(u64(length) * 4));
            if not wdest {
                return PyErr_NoMemory();
            }
            wsrc = ptr[ptr[i32]](self_.view(1)[0].b_ptr).view(1)[0];
            wcur = start;
            wn: i64 = 0;
            while wn < length {
                (wdest + wn).view(1)[0] = (wsrc + wcur).view(1)[0];
                wcur = wrapping_add(wcur, step);
                wn += 1;
            }
            wnp = PyUnicode_FromWideChar(wdest, length);
            PyMem_Free(ptr(wdest));
            return wnp;
        }
        lnp = PyList_New(length);
        if not lnp {
            return NULL;
        }
        if copy_pointer_to_list_lock_held(myself, lnp, length, start, step) < 0 {
            object_decref(lnp);
            return NULL;
        }
        return lnp;
    }
    PyErr_SetString(PyExc_TypeError, ptr[u8]("Pointer indices must be integer"));
    return NULL;
}

impl Pointer_bool(self_: ptr[PyObject]) -> i32 {
    deref = ptr[ptr](ptr[CDataObject](self_).view(1)[0].b_ptr).view(1)[0];
    if deref {
        return 1;
    }
    return 0;
}

impl string_at(ptr_: ptr[u8], size: i32) -> ptr[PyObject] {
    if PySys_Audit("ctypes.string_at", "ni", i64(int(ptr_)), size) < 0 {
        return NULL;
    }
    if size == -1 {
        return PyBytes_FromStringAndSize(ptr_, i64(strlen(ptr_)));
    }
    return PyBytes_FromStringAndSize(ptr_, i64(size));
}

impl cast_check_pointertype(st: ptr[ctypes_state], arg: ptr[PyObject]) -> i32 {
    if PyCPointerTypeObject_Check(st, arg) {
        return 1;
    }
    if PyCFuncPtrTypeObject_Check(st, arg) {
        return 1;
    }
    (status, info) = PyStgInfo_FromType(st, arg);
    if status < 0 {
        return 0;
    }
    if info and info.view(1)[0].proto {
        proto = info.view(1)[0].proto;
        if unicode_check(proto) {
            code = PyUnicode_AsUTF8(proto).view(1)[0];
            if strchr(ptr[u8]("sPzUZXO"), i32(code)) {
                return 1;
            }
        }
    }
    tp_name = object_type(arg).view(1)[0].tp_name;
    if type_check(arg) {
        tp_name = ptr[PyTypeObject](arg).view(1)[0].tp_name;
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("cast() argument 2 must be a pointer type, not %s"),
        tp_name
    );
    return 0;
}

impl cast_lock_held(
    ptr_: ptr, src: ptr[PyObject], ctype: ptr[PyObject]
) -> ptr[PyObject] {
    mod = PyType_GetModuleByDef(
        object_type(ctype), ptr[PyModuleDef](addressof(_ctypesmodule))
    );
    if not mod {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("cast() argument 2 must be a pointer type")
        );
        return NULL;
    }
    st = get_module_state(mod);

    if cast_check_pointertype(st, ctype) == 0 {
        return NULL;
    }
    result = ptr[CDataObject](PyObject_CallNoArgs(ctype));
    if not result {
        return NULL;
    }

    if CDataObject_Check(st, src) {
        source = ptr[CDataObject](src);

        container = PyCData_GetContainer(source);
        if not container {
            object_decref(ptr[PyObject](result));
            return NULL;
        }

        if source.view(1)[0].b_objects == Py_None {
            object_decref(Py_None);
            source.view(1)[0].b_objects = PyDict_New();
            if not source.view(1)[0].b_objects {
                object_decref(ptr[PyObject](result));
                return NULL;
            }
        }
        result.view(1)[0].b_objects = object_xnewref(source.view(1)[0].b_objects);
        objects = result.view(1)[0].b_objects;
        if objects and dict_check_exact(objects) {
            index = PyLong_FromVoidPtr(ptr(src));
            if not index {
                object_decref(ptr[PyObject](result));
                return NULL;
            }
            rc = PyDict_SetItem(objects, index, src);
            object_decref(index);
            if rc == -1 {
                object_decref(ptr[PyObject](result));
                return NULL;
            }
        }
    }

    ptr[ptr](result.view(1)[0].b_ptr).view(1)[0] = ptr_;
    return ptr[PyObject](result);
}

impl cast(ptr_: ptr, src: ptr[PyObject], ctype: ptr[PyObject]) -> ptr[PyObject] {
    return cast_lock_held(ptr_, src, ctype);
}

impl wstring_at(ptr_: ptr[i32], size: i32) -> ptr[PyObject] {
    ssize = i64(size);
    if PySys_Audit("ctypes.wstring_at", "nn", i64(int(ptr_)), ssize) < 0 {
        return NULL;
    }
    if ssize == -1 {
        ssize = i64(wcslen(ptr_));
    }
    return PyUnicode_FromWideChar(ptr_, ssize);
}

impl memoryview_at(ptr_: ptr, size: i64, readonly: i32) -> ptr[PyObject] {
    if PySys_Audit("ctypes.memoryview_at", "nni", i64(int(ptr_)), size, readonly) < 0 {
        return NULL;
    }
    if size < 0 {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("memoryview_at: size is negative (or overflowed): %zd"),
            size
        );
        return NULL;
    }
    flags = PyBUF_WRITE;
    if readonly != 0 {
        flags = PyBUF_READ;
    }
    return PyMemoryView_FromMemory(ptr[u8](ptr_), size, flags);
}
