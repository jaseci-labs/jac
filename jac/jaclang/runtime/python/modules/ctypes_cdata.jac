import from c {
    def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memmove(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def strchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];  def dlsym(handle: ptr, symbol: str) -> ptr;  def dlerror -> ptr[
        u8
    ];  def PyCData_FromBaseObj(
        st: ptr[ctypes_state],
        type: ptr[PyObject],
        base: ptr[PyObject],
        index: i64,
        adr: ptr[u8]
    ) -> ptr[PyObject] {
        (res, info) = PyStgInfo_FromType(st, type);
        if res < 0 {
            return NULL;
        }
        if not info {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
            return NULL;
        }

        stginfo_set_dict_final(info);
        tp = ptr[PyTypeObject](type);
        cmem = ptr[CDataObject](tp.view(1)[0].tp_alloc(tp, 0));
        if not cmem {
            return NULL;
        }
        cmem.view(1)[0].b_length = info.view(1)[0].length;
        cmem.view(1)[0].b_size = info.view(1)[0].size;
        if base {
            cmem.view(1)[0].b_ptr = adr;
            cmem.view(1)[0].b_needsfree = 0;
            cmem.view(1)[0].b_base = ptr[CDataObject](object_new_ref(base));
            cmem.view(1)[0].b_index = index;
        } else {
            if PyCData_MallocBuffer(cmem, info) == -1 {
                object_decref(ptr[PyObject](cmem));
                return NULL;
            }
            memcpy(ptr(cmem.view(1)[0].b_ptr), ptr(adr), u64(info.view(1)[0].size));
            cmem.view(1)[0].b_index = index;
        }
        return ptr[PyObject](cmem);
    }  def PyCData_AtAddress(
        st: ptr[ctypes_state], type: ptr[PyObject], buf: ptr
    ) -> ptr[PyObject] {
        address = i64(int(buf));
        if PySys_Audit(ptr[u8]("ctypes.cdata"), ptr[u8]("n"), address) < 0 {
            return NULL;
        }

        (res, info) = PyStgInfo_FromType(st, type);
        if res < 0 {
            return NULL;
        }
        if not info {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
            return NULL;
        }

        stginfo_set_dict_final(info);

        tp = ptr[PyTypeObject](type);
        pd = ptr[CDataObject](tp.view(1)[0].tp_alloc(tp, 0));
        if not pd {
            return NULL;
        }
        pd.view(1)[0].b_ptr = ptr[u8](buf);
        pd.view(1)[0].b_length = info.view(1)[0].length;
        pd.view(1)[0].b_size = info.view(1)[0].size;
        return ptr[PyObject](pd);
    }  def _ctypes_simple_instance(st: ptr[ctypes_state], obj_: ptr[PyObject]) -> i32 {
        type = ptr[PyTypeObject](obj_);
        if PyCSimpleTypeObject_Check(st, obj_) {
            if type.view(1)[0].tp_base != st.view(1)[0].Simple_Type {
                return 1;
            }
            return 0;
        }
        return 0;
    }  def PyCData_get(
        st: ptr[ctypes_state],
        type: ptr[PyObject],
        getfunc: ptr,
        src: ptr[PyObject],
        index: i64,
        size: i64,
        adr: ptr[u8]
    ) -> ptr[PyObject] {
        if getfunc {
            return call_getfunc(getfunc, ptr(adr), size);
        }
        (res, info) = PyStgInfo_FromType(st, type);
        if res < 0 {
            return NULL;
        }
        if info {
            info_getfunc = info.view(1)[0].getfunc;
            if info_getfunc {
                if _ctypes_simple_instance(st, type) == 0 {
                    return call_getfunc(info_getfunc, ptr(adr), size);
                }
            }
        }
        return PyCData_FromBaseObj(st, type, src, index, adr);
    }  def PyCData_set(
        st: ptr[ctypes_state],
        dst: ptr[PyObject],
        type: ptr[PyObject],
        setfunc: ptr,
        value: ptr[PyObject],
        index: i64,
        size: i64,
        adr: ptr[u8]
    ) -> i32 {
        mem = ptr[CDataObject](dst);

        if not CDataObject_Check(st, dst) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("not a ctype instance"));
            return -1;
        }

        result = _PyCData_set(st, mem, type, setfunc, value, size, adr);
        if not result {
            return -1;
        }

        return KeepRef(mem, index, result);
    }  glob:priv PyCData_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("_b_base_"),
                 type_=_Py_T_OBJECT,
                 offset=CDATA_B_BASE,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the base object")
             ),
             PyMemberDef(
                 name=ptr[u8]("_b_needsfree_"),
                 type_=Py_T_INT,
                 offset=CDATA_B_NEEDSFREE,
                 flags=Py_READONLY,
                 doc=ptr[u8]("whether the object owns the memory or not")
             ),
             PyMemberDef(
                 name=ptr[u8]("_objects"),
                 type_=_Py_T_OBJECT,
                 offset=CDATA_B_OBJECTS,
                 flags=Py_READONLY,
                 doc=ptr[u8]("internal objects tree (NEVER CHANGE THIS OBJECT!)")
             ),
             PyMemberDef()
         ]; glob pycsimple_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("metatype for the PyCSimpleType Objects")
             ),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(PyCSimpleType_init)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob pycsimple_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.PyCSimpleType"),
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycsimple_type_slots)
         ); glob pycfuncptr_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("metatype for C function pointers")
             ),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(PyCFuncPtrType_init)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob pycfuncptr_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.PyCFuncPtrType"),
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycfuncptr_type_slots)
         ); glob pycdata_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(PyCData_dealloc)),
             PyType_Slot(slot=Py_tp_hash, pfunc=ptr(PyCData_nohash)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("XXX to be provided")),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(PyCData_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(PyCData_clear)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(PyCData_members))),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(PyCData_NewGetBuffer)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob pycdata_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes._CData"),
             basicsize=i32(SIZEOF_CDATAOBJECT),
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
             ),
             slots=addressof(pycdata_slots)
         );
}

glob FUNCPTR_CONVERTERS: Final[i64] = 112,
     FUNCPTR_ARGTYPES: Final[i64] = 120,
     FUNCPTR_RESTYPE: Final[i64] = 128,
     FUNCPTR_CHECKER: Final[i64] = 136,
     FUNCPTR_ERRCHECK: Final[i64] = 144,
     CODE_P: Final[u8] = 80,
     CODE_X: Final[u8] = 88,
     CODE_O: Final[u8] = 79,
     CODE_Z: Final[u8] = 90,
     CODE_s: Final[u8] = 115,
     CODE_z: Final[u8] = 122;

def funcptr_field(self_: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]];

def set_stginfo_ffi_type_pointer(stginfo: ptr[StgInfo], fmt: ptr[fielddesc]) -> i32;

def CreateSwappedType(
    st: ptr[ctypes_state],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject],
    proto: ptr[PyObject],
    fmt: ptr[fielddesc]
) -> ptr[PyObject];

def PyCSimpleType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject];

def PyCSimpleType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def PyCSimpleType_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def converters_from_argtypes(
    st: ptr[ctypes_state], ob: ptr[PyObject]
) -> ptr[PyObject];

def make_funcptrtype_dict(
    st: ptr[ctypes_state], attrdict: ptr[PyObject], stginfo: ptr[StgInfo]
) -> i32;

def PyCFuncPtrType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject];

def PyCFuncPtrType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def PyCData_GetContainer(self_: ptr[CDataObject]) -> ptr[CDataObject];

def GetKeepedObjects(target: ptr[CDataObject]) -> ptr[PyObject];

def unique_key(target: ptr[CDataObject], index: i64) -> ptr[PyObject];

def KeepRef_lock_held(
    target: ptr[CDataObject], index: i64, keep: ptr[PyObject]
) -> i32;

def KeepRef(target: ptr[CDataObject], index: i64, keep: ptr[PyObject]) -> i32;

def PyCData_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def PyCData_clear(op: ptr[PyObject]) -> i32;

def PyCData_dealloc(self_: ptr[PyObject]);

def PyCData_item_type(st: ptr[ctypes_state], type: ptr[PyObject]) -> ptr[PyObject];

def PyCData_NewGetBuffer(
    myself: ptr[PyObject], view: ptr[Py_buffer], flags: i32
) -> i32;

def PyCData_nohash(self_: ptr[PyObject]) -> i64;

def _ctypes_PyCData___reduce___impl(
    myself: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def _ctypes_PyCData___setstate___impl(
    myself: ptr[PyObject], dct: ptr[PyObject], data: ptr[u8], data_length: i64
) -> ptr[PyObject];

def _ctypes_PyCData___ctypes_from_outparam___impl(
    self_: ptr[PyObject]
) -> ptr[PyObject];

def PyCData_MallocBuffer(obj_: ptr[CDataObject], info: ptr[StgInfo]) -> i32;

def _PyCData_set(
    st: ptr[ctypes_state],
    dst: ptr[CDataObject],
    type: ptr[PyObject],
    setfunc: ptr,
    value: ptr[PyObject],
    size: i64,
    adr: ptr[u8]
) -> ptr[PyObject];

def GenericPyCData_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def generic_pycdata_new(
    st: ptr[ctypes_state],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject]
) -> ptr[PyObject];

def atomic_xsetref(field: ptr[ptr[PyObject]], value: ptr[PyObject]);

def atomic_xgetref(obj_: ptr[PyObject], field: ptr[ptr[PyObject]]) -> ptr[PyObject];

def _ctypes_CFuncPtr_errcheck_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def _ctypes_CFuncPtr_errcheck_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _ctypes_CFuncPtr_restype_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def _ctypes_CFuncPtr_restype_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _ctypes_CFuncPtr_argtypes_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def _ctypes_CFuncPtr_argtypes_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _check_outarg_type(st: ptr[ctypes_state], arg: ptr[PyObject], index: i64) -> i32;

def _validate_paramflags(
    st: ptr[ctypes_state],
    type: ptr[PyTypeObject],
    paramflags: ptr[PyObject],
    argtypes: ptr[PyObject]
) -> i32;

def _get_name(obj_: ptr[PyObject]) -> tuple[i32, ptr[u8]];

def PyCFuncPtr_FromDll(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def PyCFuncPtr_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

impl funcptr_field(self_: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](self_) + offset);
}

impl set_stginfo_ffi_type_pointer(stginfo: ptr[StgInfo], fmt: ptr[fielddesc]) -> i32 {
    src = fmt.view(1)[0].pffi_type;
    dst = stginfo_ffi_type(stginfo);
    if not src.view(1)[0].elements {
        memcpy(ptr(dst), ptr(src), u64(SIZEOF_FFI_TYPE));
    } else {
        els_size = u64(2 * 8);
        dst.view(1)[0].size = src.view(1)[0].size;
        dst.view(1)[0].alignment = src.view(1)[0].alignment;
        dst.view(1)[0].type = src.view(1)[0].type;
        els = ptr[ptr[ffi_type]](PyMem_Malloc(els_size));
        dst.view(1)[0].elements = els;
        if not els {
            PyErr_NoMemory();
            return -1;
        }
        memcpy(ptr(els), ptr(src.view(1)[0].elements), els_size);
    }
    return 0;
}

impl CreateSwappedType(
    st: ptr[ctypes_state],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject],
    proto: ptr[PyObject],
    fmt: ptr[fielddesc]
) -> ptr[PyObject] {
    name = tuple_get_item(args, 0);
    nargs = object_size(args);

    swapped_args = PyTuple_New(nargs);
    if not swapped_args {
        return NULL;
    }

    newname = PyUnicode_Concat(name, st.view(1)[0].swapped_suffix);
    if not newname {
        object_decref(swapped_args);
        return NULL;
    }

    tuple_set_item(swapped_args, 0, newname);
    i: i64 = 1;
    while i < nargs {
        v = tuple_get_item(args, i);
        object_incref(v);
        tuple_set_item(swapped_args, i, v);
        i += 1;
    }

    type_type = ptr[PyTypeObject](addressof(PyType_Type));
    result = type_type.view(1)[0].tp_new(type, swapped_args, kwds);
    object_decref(swapped_args);
    if not result {
        return NULL;
    }

    stginfo = PyStgInfo_Init(st, ptr[PyTypeObject](result));
    if not stginfo {
        object_decref(result);
        return NULL;
    }
    if set_stginfo_ffi_type_pointer(stginfo, fmt) != 0 {
        object_decref(result);
        return NULL;
    }
    pffi = fmt.view(1)[0].pffi_type;
    stginfo.view(1)[0].align = i64(pffi.view(1)[0].alignment);
    stginfo.view(1)[0].length = 0;
    stginfo.view(1)[0].size = i64(pffi.view(1)[0].size);
    stginfo.view(1)[0].setfunc = fmt.view(1)[0].setfunc_swapped;
    stginfo.view(1)[0].getfunc = fmt.view(1)[0].getfunc_swapped;

    stginfo.view(1)[0].proto = object_new_ref(proto);

    return result;
}

impl PyCSimpleType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject] {
    (res, info) = PyStgInfo_FromObject(st, ptr[PyObject](self_));
    if res < 0 {
        return ptr[PyCArgObject]();
    }

    fmt = PyUnicode_AsUTF8(info.view(1)[0].proto);

    fd = _ctypes_get_fielddesc(fmt);

    parg = PyCArgObject_new(st);
    if not parg {
        return ptr[PyCArgObject]();
    }

    parg.view(1)[0].tag = fmt.view(1)[0];
    parg.view(1)[0].pffi_type = fd.view(1)[0].pffi_type;
    parg.view(1)[0].obj_ = object_new_ref(ptr[PyObject](self_));
    memcpy(
        ptr(carg_value_address(parg)),
        ptr(self_.view(1)[0].b_ptr),
        u64(self_.view(1)[0].b_size)
    );
    return parg;
}

impl PyCSimpleType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    type_type = ptr[PyTypeObject](addressof(PyType_Type));
    if type_type.view(1)[0].tp_init(self_, args, kwds) < 0 {
        return -1;
    }
    proto = NULL;
    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID__type_), &mut proto) < 0 {
        return -1;
    }
    if not proto {
        PyErr_SetString(
            PyExc_AttributeError, ptr[u8]("class must define a '_type_' attribute")
        );
        return -1;
    }
    proto_len: i64 = 0;
    proto_str = ptr[u8]();
    if unicode_check(proto) {
        proto_str = PyUnicode_AsUTF8AndSize(proto, &mut proto_len);
        if not proto_str {
            object_decref(proto);
            return -1;
        }
    } else {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("class must define a '_type_' string attribute")
        );
        object_decref(proto);
        return -1;
    }
    if proto_len != 1 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8](
                "class must define a '_type_' attribute which must be a string of length 1"
            )
        );
        object_decref(proto);
        return -1;
    }
    fmt = _ctypes_get_fielddesc(proto_str);
    if not fmt {
        PyErr_Format(
            PyExc_AttributeError,
            ptr[u8](
                "class must define a '_type_' attribute which must be\na single character string containing one of the\nsupported types: '%s'."
            ),
            _ctypes_get_simple_type_chars()
        );
        object_decref(proto);
        return -1;
    }

    st = get_module_state_by_def(object_type(self_));
    stginfo = PyStgInfo_Init(st, ptr[PyTypeObject](self_));
    if not stginfo {
        object_decref(proto);
        return -1;
    }
    if set_stginfo_ffi_type_pointer(stginfo, fmt) != 0 {
        object_decref(proto);
        return -1;
    }
    pffi = fmt.view(1)[0].pffi_type;
    stginfo.view(1)[0].align = i64(pffi.view(1)[0].alignment);
    stginfo.view(1)[0].length = 0;
    stginfo.view(1)[0].size = i64(pffi.view(1)[0].size);
    stginfo.view(1)[0].setfunc = fmt.view(1)[0].setfunc;
    stginfo.view(1)[0].getfunc = fmt.view(1)[0].getfunc;
    code = proto_str.view(1)[0];
    stginfo.view(1)[0].format_ = _ctypes_alloc_format_string_for_type(code, 0);
    if not stginfo.view(1)[0].format_ {
        object_decref(proto);
        return -1;
    }

    stginfo.view(1)[0].paramfunc = ptr(PyCSimpleType_paramfunc);

    stginfo.view(1)[0].proto = proto;

    if ptr[PyTypeObject](self_).view(1)[0].tp_base == st.view(1)[0].Simple_Type {
        tables = addressof(ctypes_clinic_tables);
        ml = ptr[PyMethodDef]();
        if code == CODE_z {
            ml = tables.view(1)[0].c_char_p_methods;
            stginfo.view(1)[0].flags = stginfo.view(1)[0].flags | TYPEFLAG_ISPOINTER;
        } elif code == CODE_Z {
            ml = tables.view(1)[0].c_wchar_p_methods;
            stginfo.view(1)[0].flags = stginfo.view(1)[0].flags | TYPEFLAG_ISPOINTER;
        } elif code == CODE_P {
            ml = tables.view(1)[0].c_void_p_methods;
            stginfo.view(1)[0].flags = stginfo.view(1)[0].flags | TYPEFLAG_ISPOINTER;
        } elif code == CODE_s or code == CODE_X or code == CODE_O {
            stginfo.view(1)[0].flags = stginfo.view(1)[0].flags | TYPEFLAG_ISPOINTER;
        }

        if ml {
            meth = PyDescr_NewClassMethod(ptr[PyTypeObject](self_), ml);
            if not meth {
                return -1;
            }
            name = PyUnicode_InternFromString(ml.view(1)[0].ml_name);
            if not name {
                object_decref(meth);
                return -1;
            }
            x = PyDict_SetItem(ptr[PyTypeObject](self_).view(1)[0].tp_dict, name, meth);
            object_decref(name);
            object_decref(meth);
            if x == -1 {
                return -1;
            }
        }
    }

    type = object_type(self_);
    if type == st.view(1)[0].PyCSimpleType_Type
        and int(fmt.view(1)[0].setfunc_swapped) != 0
        and int(fmt.view(1)[0].getfunc_swapped) != 0 {
        swapped = CreateSwappedType(st, type, args, kwds, proto, fmt);
        if not swapped {
            return -1;
        }
        (sw_res, sw_info) = PyStgInfo_FromType(st, swapped);
        if sw_res < 0 {
            object_decref(swapped);
            return -1;
        }
        PyObject_SetAttrString(self_, ptr[u8]("__ctype_be__"), swapped);
        PyObject_SetAttrString(self_, ptr[u8]("__ctype_le__"), self_);
        PyObject_SetAttrString(swapped, ptr[u8]("__ctype_le__"), self_);
        PyObject_SetAttrString(swapped, ptr[u8]("__ctype_be__"), swapped);

        sw_info.view(1)[0].format_ = _ctypes_alloc_format_string(
            ptr[u8](">"), stginfo.view(1)[0].format_ + 1
        );
        object_decref(swapped);
        if PyErr_Occurred() {
            return -1;
        }
    }

    return 0;
}

impl PyCSimpleType_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    res = PyObject_IsInstance(value, type);
    if res == -1 {
        return NULL;
    }
    if res != 0 {
        return object_new_ref(value);
    }

    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    (status, info) = PyStgInfo_FromType(st, type);
    if status < 0 {
        return NULL;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
        return NULL;
    }

    fmt = PyUnicode_AsUTF8(info.view(1)[0].proto);

    fd = _ctypes_get_fielddesc(fmt);

    parg = PyCArgObject_new(st);
    if not parg {
        return NULL;
    }

    parg.view(1)[0].tag = fmt.view(1)[0];
    parg.view(1)[0].pffi_type = fd.view(1)[0].pffi_type;
    parg.view(1)[0].obj_ = call_setfunc(
        fd.view(1)[0].setfunc,
        ptr(carg_value_address(parg)),
        value,
        info.view(1)[0].size
    );
    if parg.view(1)[0].obj_ {
        return ptr[PyObject](parg);
    }
    exc = PyErr_GetRaisedException();
    object_decref(ptr[PyObject](parg));

    as_parameter = NULL;
    if PyObject_GetOptionalAttr(value, py_id(_Py_ID__as_parameter_), &mut as_parameter)
        < 0 {
        object_xdecref(exc);
        return NULL;
    }
    if as_parameter {
        if Py_EnterRecursiveCall(ptr[u8](" while processing _as_parameter_")) != 0 {
            object_decref(as_parameter);
            object_xdecref(exc);
            return NULL;
        }
        result = PyCSimpleType_from_param_impl(type, cls, as_parameter);
        object_decref(as_parameter);
        object_xdecref(exc);
        Py_LeaveRecursiveCall();
        return result;
    }
    if exc {
        PyErr_SetRaisedException(exc);
    } else {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("wrong type"));
    }
    return NULL;
}

impl converters_from_argtypes(
    st: ptr[ctypes_state], ob: ptr[PyObject]
) -> ptr[PyObject] {
    seq = PySequence_Tuple(ob);
    if not seq {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("_argtypes_ must be a sequence of types")
        );
        return NULL;
    }

    nArgs = object_size(seq);
    if nArgs > CTYPES_MAX_ARGCOUNT {
        object_decref(seq);
        PyErr_Format(
            st.view(1)[0].PyExc_ArgError,
            ptr[u8]("_argtypes_ has too many arguments (%zi), maximum is %i"),
            nArgs,
            i32(CTYPES_MAX_ARGCOUNT)
        );
        return NULL;
    }

    converters = PyTuple_New(nArgs);
    if not converters {
        object_decref(seq);
        return NULL;
    }

    i: i64 = 0;
    while i < nArgs {
        tp = tuple_get_item(seq, i);
        cnv = NULL;
        if PyObject_GetOptionalAttr(tp, py_id(_Py_ID_from_param), &mut cnv) <= 0 {
            object_decref(converters);
            object_decref(seq);
            if not PyErr_Occurred() {
                item_number = i + 1;
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("item %zd in _argtypes_ has no from_param method"),
                    item_number
                );
            }
            return NULL;
        }
        tuple_set_item(converters, i, cnv);
        i += 1;
    }
    object_decref(seq);
    return converters;
}

impl make_funcptrtype_dict(
    st: ptr[ctypes_state], attrdict: ptr[PyObject], stginfo: ptr[StgInfo]
) -> i32 {
    pointer_desc = _ctypes_get_fielddesc(ptr[u8]("P"));
    pointer_ffi = pointer_desc.view(1)[0].pffi_type;
    stginfo.view(1)[0].align = i64(pointer_ffi.view(1)[0].alignment);
    stginfo.view(1)[0].length = 1;
    stginfo.view(1)[0].size = 8;
    stginfo.view(1)[0].setfunc = ptr();
    stginfo.view(1)[0].getfunc = ptr();
    memcpy(
        ptr(stginfo_ffi_type(stginfo)),
        ptr(addressof(ffi_type_pointer)),
        u64(SIZEOF_FFI_TYPE)
    );

    ob = NULL;
    if PyDict_GetItemRef(attrdict, py_id(_Py_ID__flags_), &mut ob) < 0 {
        return -1;
    }
    if not ob or not long_check(ob) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("class must define _flags_ which must be an integer")
        );
        object_xdecref(ob);
        return -1;
    }
    stginfo.view(1)[0].flags = i32.wrap(
        PyLong_AsUnsignedLongMask(ob) | u64(TYPEFLAG_ISPOINTER)
    );
    object_decref(ob);

    ob = NULL;
    if PyDict_GetItemRef(attrdict, py_id(_Py_ID__argtypes_), &mut ob) < 0 {
        return -1;
    }
    if ob {
        converters = converters_from_argtypes(st, ob);
        if not converters {
            object_decref(ob);
            return -1;
        }
        stginfo.view(1)[0].argtypes = ob;
        stginfo.view(1)[0].converters = converters;
    }

    ob = NULL;
    if PyDict_GetItemRef(attrdict, py_id(_Py_ID__restype_), &mut ob) < 0 {
        return -1;
    }
    if ob {
        (res, info) = PyStgInfo_FromType(st, ob);
        if res < 0 {
            object_decref(ob);
            return -1;
        }
        if ob != Py_None and not info and PyCallable_Check(ob) == 0 {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("_restype_ must be a type, a callable, or None")
            );
            object_decref(ob);
            return -1;
        }
        stginfo.view(1)[0].restype = ob;
        checker = NULL;
        status = PyObject_GetOptionalAttr(
            ob, py_id(_Py_ID__check_retval_), &mut checker
        );
        stginfo.view(1)[0].checker = checker;
        if status < 0 {
            return -1;
        }
    }
    return 0;
}

impl PyCFuncPtrType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject] {
    parg = PyCArgObject_new(st);
    if not parg {
        return ptr[PyCArgObject]();
    }

    parg.view(1)[0].tag = CODE_P;
    parg.view(1)[0].pffi_type = addressof(ffi_type_pointer);
    parg.view(1)[0].obj_ = object_new_ref(ptr[PyObject](self_));
    ptr[ptr](carg_value_address(parg)).view(1)[0] = ptr[ptr](
        self_.view(1)[0].b_ptr
    ).view(
        1
    )[0];
    return parg;
}

impl PyCFuncPtrType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    attrdict = PyType_GetDict(self_);
    if not attrdict {
        return -1;
    }

    st = get_module_state_by_def(object_type(self_));
    stginfo = PyStgInfo_Init(st, ptr[PyTypeObject](self_));
    if not stginfo {
        object_decref(attrdict);
        return -1;
    }

    stginfo.view(1)[0].paramfunc = ptr(PyCFuncPtrType_paramfunc);

    stginfo.view(1)[0].format_ = _ctypes_alloc_format_string(ptr[u8](), ptr[u8]("X{}"));
    if not stginfo.view(1)[0].format_ {
        object_decref(attrdict);
        return -1;
    }
    stginfo.view(1)[0].flags = stginfo.view(1)[0].flags | TYPEFLAG_ISPOINTER;

    if make_funcptrtype_dict(st, attrdict, stginfo) < 0 {
        object_decref(attrdict);
        return -1;
    }

    object_decref(attrdict);
    return 0;
}

impl PyCData_GetContainer(self_: ptr[CDataObject]) -> ptr[CDataObject] {
    cur = self_;
    while cur.view(1)[0].b_base {
        cur = cur.view(1)[0].b_base;
    }
    if not cur.view(1)[0].b_objects {
        if cur.view(1)[0].b_length != 0 {
            objects = PyDict_New();
            cur.view(1)[0].b_objects = objects;
            if not objects {
                return ptr[CDataObject]();
            }
        } else {
            cur.view(1)[0].b_objects = object_new_ref(Py_None);
        }
    }
    return cur;
}

impl GetKeepedObjects(target: ptr[CDataObject]) -> ptr[PyObject] {
    container = PyCData_GetContainer(target);
    if not container {
        return NULL;
    }
    return container.view(1)[0].b_objects;
}

impl unique_key(target: ptr[CDataObject], index: i64) -> ptr[PyObject] {
    string = ptr[u8](PyMem_Malloc(u64(256)));
    if not string {
        return PyErr_NoMemory();
    }
    used = i64(PyOS_snprintf(string, u64(256), ptr[u8]("%x"), i32.wrap(index)));
    cur = target;
    while cur.view(1)[0].b_base {
        bytes_left = 256 - used - 1;

        if bytes_left < 16 {
            PyMem_Free(ptr(string));
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("ctypes object structure too deep")
            );
            return NULL;
        }
        used += i64(
            PyOS_snprintf(
                string + used,
                u64(256 - used),
                ptr[u8](":%x"),
                i32.wrap(cur.view(1)[0].b_index)
            )
        );
        cur = cur.view(1)[0].b_base;
    }
    result = PyUnicode_FromStringAndSize(string, used);
    PyMem_Free(ptr(string));
    return result;
}

impl KeepRef_lock_held(
    target: ptr[CDataObject], index: i64, keep: ptr[PyObject]
) -> i32 {
    if keep == Py_None {
        object_decref(Py_None);
        return 0;
    }
    ob = PyCData_GetContainer(target);
    if not ob {
        object_decref(keep);
        return -1;
    }
    objects = ob.view(1)[0].b_objects;
    if not objects or not dict_check_exact(objects) {
        ob.view(1)[0].b_objects = keep;
        object_xdecref(objects);
        return 0;
    }
    key = unique_key(target, index);
    if not key {
        object_decref(keep);
        return -1;
    }
    result = PyDict_SetItem(objects, key, keep);
    object_decref(key);
    object_decref(keep);
    return result;
}

impl KeepRef(target: ptr[CDataObject], index: i64, keep: ptr[PyObject]) -> i32 {
    return KeepRef_lock_held(target, index, keep);
}

impl PyCData_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = ptr[CDataObject](op);
    vret = visit_reference(self_.view(1)[0].b_objects, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](self_.view(1)[0].b_base), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl PyCData_clear(op: ptr[PyObject]) -> i32 {
    self_ = ptr[CDataObject](op);
    objects = self_.view(1)[0].b_objects;
    self_.view(1)[0].b_objects = NULL;
    object_xdecref(objects);
    if self_.view(1)[0].b_needsfree != 0 and _CDataObject_HasExternalBuffer(self_) {
        PyMem_Free(ptr(self_.view(1)[0].b_ptr));
    }
    self_.view(1)[0].b_ptr = ptr[u8]();
    base = self_.view(1)[0].b_base;
    self_.view(1)[0].b_base = ptr[CDataObject]();
    object_xdecref(ptr[PyObject](base));
    return 0;
}

impl PyCData_dealloc(self_: ptr[PyObject]) {
    type = object_type(self_);
    PyObject_GC_UnTrack(ptr(self_));
    PyCData_clear(self_);
    type.view(1)[0].tp_free(ptr(self_));
    object_decref(ptr[PyObject](type));
}

impl PyCData_item_type(st: ptr[ctypes_state], type: ptr[PyObject]) -> ptr[PyObject] {
    if PyCArrayTypeObject_Check(st, type) {
        (res, stg_info) = PyStgInfo_FromType(st, type);
        if res < 0 {
            return NULL;
        }
        elem_type = stg_info.view(1)[0].proto;
        return PyCData_item_type(st, elem_type);
    }
    return type;
}

impl PyCData_NewGetBuffer(
    myself: ptr[PyObject], view: ptr[Py_buffer], flags: i32
) -> i32 {
    self_ = ptr[CDataObject](myself);

    st = get_module_state_by_def(object_type(ptr[PyObject](object_type(myself))));
    (res, info) = PyStgInfo_FromObject(st, myself);
    if res < 0 {
        return -1;
    }

    item_type = PyCData_item_type(st, ptr[PyObject](object_type(myself)));
    if not item_type {
        return 0;
    }

    if not view {
        return 0;
    }

    (item_res, item_info) = PyStgInfo_FromType(st, item_type);
    if item_res < 0 {
        return -1;
    }

    format_ = info.view(1)[0].format_;
    if not format_ {
        format_ = ptr[u8]("B");
    }
    view.view(1)[0].buf = ptr(self_.view(1)[0].b_ptr);
    view.view(1)[0].owner = object_new_ref(myself);
    view.view(1)[0].length = self_.view(1)[0].b_size;
    view.view(1)[0].readonly = 0;
    view.view(1)[0].format_ = format_;
    view.view(1)[0].ndim = info.view(1)[0].ndim;
    view.view(1)[0].shape = info.view(1)[0].shape;
    view.view(1)[0].itemsize = item_info.view(1)[0].size;
    view.view(1)[0].strides = ptr[i64]();
    view.view(1)[0].suboffsets = ptr[i64]();
    view.view(1)[0].internal = ptr();
    return 0;
}

impl PyCData_nohash(self_: ptr[PyObject]) -> i64 {
    PyErr_SetString(PyExc_TypeError, ptr[u8]("unhashable type"));
    return -1;
}

impl _ctypes_PyCData___reduce___impl(
    myself: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[CDataObject](myself);

    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    (res, info) = PyStgInfo_FromObject(st, myself);
    if res < 0 {
        return NULL;
    }

    if (info.view(1)[0].flags & (TYPEFLAG_ISPOINTER | TYPEFLAG_HASPOINTER)) != 0 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("ctypes objects containing pointers cannot be pickled")
        );
        return NULL;
    }
    dct = PyObject_GetAttrString(myself, ptr[u8]("__dict__"));
    if not dct {
        return NULL;
    }
    bytes_obj = PyBytes_FromStringAndSize(
        self_.view(1)[0].b_ptr, self_.view(1)[0].b_size
    );
    return Py_BuildValue(
        ptr[u8]("O(O(NN))"),
        st.view(1)[0]._unpickle,
        ptr[PyObject](object_type(myself)),
        dct,
        bytes_obj
    );
}

impl _ctypes_PyCData___setstate___impl(
    myself: ptr[PyObject], dct: ptr[PyObject], data: ptr[u8], data_length: i64
) -> ptr[PyObject] {
    self_ = ptr[CDataObject](myself);

    length = data_length;
    if length > self_.view(1)[0].b_size {
        length = self_.view(1)[0].b_size;
    }
    memmove(ptr(self_.view(1)[0].b_ptr), ptr(data), u64(length));
    mydict = PyObject_GetAttrString(myself, ptr[u8]("__dict__"));
    if not mydict {
        return NULL;
    }
    if not dict_check(mydict) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.200s.__dict__ must be a dictionary, not %.200s"),
            object_type(myself).view(1)[0].tp_name,
            object_type(mydict).view(1)[0].tp_name
        );
        object_decref(mydict);
        return NULL;
    }
    res = PyDict_Update(mydict, dct);
    object_decref(mydict);
    if res == -1 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl _ctypes_PyCData___ctypes_from_outparam___impl(
    self_: ptr[PyObject]
) -> ptr[PyObject] {
    return object_new_ref(self_);
}

impl PyCData_MallocBuffer(obj_: ptr[CDataObject], info: ptr[StgInfo]) -> i32 {
    size = info.view(1)[0].size;
    if u64.wrap(size) <= u64(SIZEOF_VALUE_UNION) {
        obj_.view(1)[0].b_ptr = cdata_value_address(obj_);
        obj_.view(1)[0].b_needsfree = 1;
    } else {
        obj_.view(1)[0].b_ptr = ptr[u8](PyMem_Malloc(u64.wrap(size)));
        if not obj_.view(1)[0].b_ptr {
            PyErr_NoMemory();
            return -1;
        }
        obj_.view(1)[0].b_needsfree = 1;
        memset(ptr(obj_.view(1)[0].b_ptr), 0, u64.wrap(size));
    }
    obj_.view(1)[0].b_size = size;
    return 0;
}

impl _PyCData_set(
    st: ptr[ctypes_state],
    dst: ptr[CDataObject],
    type: ptr[PyObject],
    setfunc: ptr,
    value: ptr[PyObject],
    size: i64,
    adr: ptr[u8]
) -> ptr[PyObject] {
    if setfunc {
        return call_setfunc(setfunc, ptr(adr), value, size);
    }
    if not CDataObject_Check(st, value) {
        (res, info) = PyStgInfo_FromType(st, type);
        if res < 0 {
            return NULL;
        }
        if info {
            info_setfunc = info.view(1)[0].setfunc;
            if info_setfunc {
                return call_setfunc(info_setfunc, ptr(adr), value, size);
            }
        }

        if tuple_check(value) {
            ob = PyObject_CallObject(type, value);
            if not ob {
                _ctypes_extend_error(
                    PyExc_RuntimeError,
                    PyUnicode_FromFormat(
                        "(%s) ", ptr[PyTypeObject](type).view(1)[0].tp_name
                    )
                );
                return NULL;
            }
            result = _PyCData_set(st, dst, type, setfunc, ob, size, adr);
            object_decref(ob);
            return result;
        } elif value == Py_None and PyCPointerTypeObject_Check(st, type) {
            ptr[ptr](adr).view(1)[0] = ptr();
            return object_new_ref(Py_None);
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("expected %s instance, got %s"),
                ptr[PyTypeObject](type).view(1)[0].tp_name,
                object_type(value).view(1)[0].tp_name
            );
            return NULL;
        }
    }
    src = ptr[CDataObject](value);

    err = PyObject_IsInstance(value, type);
    if err == -1 {
        return NULL;
    }
    if err != 0 {
        memcpy(ptr(adr), ptr(src.view(1)[0].b_ptr), u64(size));
        kept = GetKeepedObjects(src);
        if not kept {
            return NULL;
        }
        return object_new_ref(kept);
    }

    if PyCPointerTypeObject_Check(st, type) and ArrayObject_Check(st, value) {
        (res1, p1) = PyStgInfo_FromObject(st, value);
        if res1 < 0 {
            return NULL;
        }

        (res2, p2) = PyStgInfo_FromType(st, type);
        if res2 < 0 {
            return NULL;
        }

        if p1.view(1)[0].proto != p2.view(1)[0].proto {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("incompatible types, %s instance instead of %s instance"),
                object_type(value).view(1)[0].tp_name,
                ptr[PyTypeObject](type).view(1)[0].tp_name
            );
            return NULL;
        }
        ptr[ptr](adr).view(1)[0] = ptr(src.view(1)[0].b_ptr);

        keep = GetKeepedObjects(src);
        if not keep {
            return NULL;
        }

        return PyTuple_Pack(i64(2), keep, value);
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("incompatible types, %s instance instead of %s instance"),
        object_type(value).view(1)[0].tp_name,
        ptr[PyTypeObject](type).view(1)[0].tp_name
    );
    return NULL;
}

impl GenericPyCData_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    st = get_module_state_by_def(object_type(ptr[PyObject](type)));
    return generic_pycdata_new(st, type, args, kwds);
}

impl generic_pycdata_new(
    st: ptr[ctypes_state],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kwds: ptr[PyObject]
) -> ptr[PyObject] {
    (res, info) = PyStgInfo_FromType(st, ptr[PyObject](type));
    if res < 0 {
        return NULL;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
        return NULL;
    }

    stginfo_set_dict_final(info);

    obj_ = ptr[CDataObject](type.view(1)[0].tp_alloc(type, 0));
    if not obj_ {
        return NULL;
    }

    obj_.view(1)[0].b_base = ptr[CDataObject]();
    obj_.view(1)[0].b_index = 0;
    obj_.view(1)[0].b_objects = NULL;
    obj_.view(1)[0].b_length = info.view(1)[0].length;

    if PyCData_MallocBuffer(obj_, info) == -1 {
        object_decref(ptr[PyObject](obj_));
        return NULL;
    }
    return ptr[PyObject](obj_);
}

impl atomic_xsetref(field: ptr[ptr[PyObject]], value: ptr[PyObject]) {
    old = field.view(1)[0];
    field.view(1)[0] = value;
    object_xdecref(old);
}

impl atomic_xgetref(obj_: ptr[PyObject], field: ptr[ptr[PyObject]]) -> ptr[PyObject] {
    return object_xnewref(field.view(1)[0]);
}

impl _ctypes_CFuncPtr_errcheck_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if value and PyCallable_Check(value) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("the errcheck attribute must be callable")
        );
        return -1;
    }
    object_xincref(value);
    atomic_xsetref(funcptr_field(self_, FUNCPTR_ERRCHECK), value);
    return 0;
}

impl _ctypes_CFuncPtr_errcheck_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    errcheck = ptr[PyCFuncPtrObject](self_).view(1)[0].errcheck;
    if errcheck {
        return object_new_ref(errcheck);
    }
    return object_new_ref(Py_None);
}

impl _ctypes_CFuncPtr_restype_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not value {
        atomic_xsetref(funcptr_field(self_, FUNCPTR_RESTYPE), NULL);
        atomic_xsetref(funcptr_field(self_, FUNCPTR_CHECKER), NULL);
        return 0;
    }
    st = get_module_state_by_def(object_type(ptr[PyObject](object_type(self_))));
    (res, info) = PyStgInfo_FromType(st, value);
    if res < 0 {
        return -1;
    }
    if value != Py_None and not info and PyCallable_Check(value) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("restype must be a type, a callable, or None")
        );
        return -1;
    }
    checker = NULL;
    if PyObject_GetOptionalAttr(value, py_id(_Py_ID__check_retval_), &mut checker)
        < 0 {
        return -1;
    }
    object_incref(value);
    atomic_xsetref(funcptr_field(self_, FUNCPTR_CHECKER), checker);
    atomic_xsetref(funcptr_field(self_, FUNCPTR_RESTYPE), value);
    return 0;
}

impl _ctypes_CFuncPtr_restype_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    restype = ptr[PyCFuncPtrObject](self_).view(1)[0].restype;
    if restype {
        return object_new_ref(restype);
    }
    st = get_module_state_by_def(object_type(ptr[PyObject](object_type(self_))));
    (res, info) = PyStgInfo_FromObject(st, self_);
    if res < 0 {
        return NULL;
    }

    if info.view(1)[0].restype {
        return object_new_ref(info.view(1)[0].restype);
    }
    return object_new_ref(Py_None);
}

impl _ctypes_CFuncPtr_argtypes_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not value or value == Py_None {
        atomic_xsetref(funcptr_field(self_, FUNCPTR_ARGTYPES), NULL);
        atomic_xsetref(funcptr_field(self_, FUNCPTR_CONVERTERS), NULL);
    } else {
        type = object_type(self_);
        st = get_module_state_by_def(object_type(ptr[PyObject](type)));
        converters = converters_from_argtypes(st, value);
        if not converters {
            return -1;
        }
        paramflags = ptr[PyCFuncPtrObject](self_).view(1)[0].paramflags;
        if _validate_paramflags(st, type, paramflags, value) == 0 {
            object_decref(converters);
            return -1;
        }
        atomic_xsetref(funcptr_field(self_, FUNCPTR_CONVERTERS), converters);
        object_incref(value);
        atomic_xsetref(funcptr_field(self_, FUNCPTR_ARGTYPES), value);
    }
    return 0;
}

impl _ctypes_CFuncPtr_argtypes_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    argtypes = ptr[PyCFuncPtrObject](self_).view(1)[0].argtypes;
    if argtypes {
        return object_new_ref(argtypes);
    }
    st = get_module_state_by_def(object_type(ptr[PyObject](object_type(self_))));
    (res, info) = PyStgInfo_FromObject(st, self_);
    if res < 0 {
        return NULL;
    }

    if info.view(1)[0].argtypes {
        return object_new_ref(info.view(1)[0].argtypes);
    }
    return object_new_ref(Py_None);
}

impl _check_outarg_type(st: ptr[ctypes_state], arg: ptr[PyObject], index: i64) -> i32 {
    if PyCPointerTypeObject_Check(st, arg) {
        return 1;
    }
    if PyCArrayTypeObject_Check(st, arg) {
        return 1;
    }
    (res, info) = PyStgInfo_FromType(st, arg);
    if res < 0 {
        return -1;
    }

    if info and unicode_check(info.view(1)[0].proto) {
        code = PyUnicode_AsUTF8(info.view(1)[0].proto).view(1)[0];
        if strchr(ptr[u8]("PzZ"), i32(code)) {
            return 1;
        }
    }

    type_name = object_type(arg).view(1)[0].tp_name;
    if type_check(arg) {
        type_name = ptr[PyTypeObject](arg).view(1)[0].tp_name;
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("'out' parameter %d must be a pointer type, not %s"),
        i32.wrap(index),
        type_name
    );
    return 0;
}

impl _validate_paramflags(
    st: ptr[ctypes_state],
    type: ptr[PyTypeObject],
    paramflags: ptr[PyObject],
    argtypes: ptr[PyObject]
) -> i32 {
    (res, info) = PyStgInfo_FromType(st, ptr[PyObject](type));
    if res < 0 {
        return -1;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
        return 0;
    }
    types = argtypes;
    if not types {
        types = info.view(1)[0].argtypes;
    }

    if not paramflags or not types {
        return 1;
    }

    if not tuple_check(paramflags) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("paramflags must be a tuple or None"));
        return 0;
    }

    length = object_size(paramflags);
    if length != object_size(types) {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("paramflags must have the same length as argtypes")
        );
        return 0;
    }

    i: i64 = 0;
    while i < length {
        item = tuple_get_item(paramflags, i);

        flag: i32 = 0;
        name = Py_None;
        parsed = False;
        if tuple_check(item) {
            nitems = object_size(item);
            if nitems >= 1 and nitems <= 3 {
                flag = PyLong_AsInt(tuple_get_item(item, 0));
                if flag != -1 or not PyErr_Occurred() {
                    parsed = True;
                    if nitems >= 2 {
                        name = tuple_get_item(item, 1);
                    }
                }
            }
        }
        if not parsed or not (name == Py_None or unicode_check(name)) {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8](
                    "paramflags must be a sequence of (int [,string [,value]]) tuples"
                )
            );
            return 0;
        }
        typ = tuple_get_item(types, i);
        kind = flag & (PARAMFLAG_FIN | PARAMFLAG_FOUT | PARAMFLAG_FLCID);
        if kind == 0
            or kind == PARAMFLAG_FIN
            or kind == (PARAMFLAG_FIN | PARAMFLAG_FLCID)
            or kind == (PARAMFLAG_FIN | PARAMFLAG_FOUT) {
            i += 1;
            continue;
        }
        if kind == PARAMFLAG_FOUT {
            if _check_outarg_type(st, typ, i + 1) == 0 {
                return 0;
            }
            i += 1;
            continue;
        }
        PyErr_Format(
            PyExc_TypeError, ptr[u8]("paramflag value %d not supported"), flag
        );
        return 0;
    }
    return 1;
}

impl _get_name(obj_: ptr[PyObject]) -> tuple[i32, ptr[u8]] {
    if bytes_check(obj_) {
        name = PyBytes_AsString(obj_);
        if name {
            return (i32(1), name);
        }
        return (i32(0), name);
    }
    if unicode_check(obj_) {
        text = PyUnicode_AsUTF8(obj_);
        if text {
            return (i32(1), text);
        }
        return (i32(0), text);
    }
    PyErr_SetString(
        PyExc_TypeError,
        ptr[u8]("function name must be string, bytes object or integer")
    );
    return (i32(0), ptr[u8]());
}

impl PyCFuncPtr_FromDll(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = object_size(args);
    if nargs < 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("function takes at least 1 argument (%zd given)"),
            nargs
        );
        return NULL;
    }
    if nargs > 2 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("function takes at most 2 arguments (%zd given)"),
            nargs
        );
        return NULL;
    }
    paramflags = NULL;
    if nargs > 1 {
        paramflags = tuple_get_item(args, 1);
    }
    if paramflags == Py_None {
        paramflags = NULL;
    }

    ftuple = PySequence_Tuple(tuple_get_item(args, 0));
    if not ftuple {
        return NULL;
    }

    if object_size(ftuple) != 2 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("illegal func_spec argument"));
        object_decref(ftuple);
        return NULL;
    }
    (named, name) = _get_name(tuple_get_item(ftuple, 0));
    if named == 0 {
        object_decref(ftuple);
        return NULL;
    }
    dll = tuple_get_item(ftuple, 1);

    if PySys_Audit(ptr[u8]("ctypes.dlsym"), ptr[u8]("Os"), dll, name) < 0 {
        object_decref(ftuple);
        return NULL;
    }

    obj_ = PyObject_GetAttrString(dll, ptr[u8]("_handle"));
    if not obj_ {
        object_decref(ftuple);
        return NULL;
    }
    if not long_check(obj_) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("the _handle attribute of the second argument must be an integer")
        );
        object_decref(ftuple);
        object_decref(obj_);
        return NULL;
    }
    handle = PyLong_AsVoidPtr(obj_);
    object_decref(obj_);
    if PyErr_Occurred() {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("could not convert the _handle attribute to a pointer")
        );
        object_decref(ftuple);
        return NULL;
    }

    name_obj = PyUnicode_FromString(name);
    if not name_obj {
        object_decref(ftuple);
        return NULL;
    }
    symbol = text_value(name_obj);
    object_decref(name_obj);

    dlerror();
    address = dlsym(handle, symbol);

    if not address {
        dlerr = dlerror();
        if dlerr {
            _PyErr_SetLocaleString(PyExc_AttributeError, dlerr);
            object_decref(ftuple);
            return NULL;
        }
        PyErr_Format(PyExc_AttributeError, ptr[u8]("function '%s' not found"), name);
        object_decref(ftuple);
        return NULL;
    }
    st = get_module_state_by_def(object_type(ptr[PyObject](type)));
    if _validate_paramflags(st, type, paramflags, NULL) == 0 {
        object_decref(ftuple);
        return NULL;
    }

    self_ = ptr[PyCFuncPtrObject](generic_pycdata_new(st, type, args, kwds));
    if not self_ {
        object_decref(ftuple);
        return NULL;
    }

    self_.view(1)[0].paramflags = object_xnewref(paramflags);

    ptr[ptr](self_.view(1)[0].b_ptr).view(1)[0] = address;
    object_incref(dll);
    object_decref(ftuple);
    if KeepRef(ptr[CDataObject](self_), 0, dll) == -1 {
        object_decref(ptr[PyObject](self_));
        return NULL;
    }

    self_.view(1)[0].callable = object_new_ref(ptr[PyObject](self_));
    return ptr[PyObject](self_);
}

impl PyCFuncPtr_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = object_size(args);
    if nargs == 0 {
        return GenericPyCData_new(type, args, kwds);
    }

    first = tuple_get_item(args, 0);
    if tuple_check(first) {
        return PyCFuncPtr_FromDll(type, args, kwds);
    }

    if nargs == 1 and long_check(first) {
        address = PyLong_AsVoidPtr(first);
        if not address and PyErr_Occurred() {
            return NULL;
        }
        ob = ptr[CDataObject](GenericPyCData_new(type, args, kwds));
        if not ob {
            return NULL;
        }
        ptr[ptr](ob.view(1)[0].b_ptr).view(1)[0] = address;
        return ptr[PyObject](ob);
    }

    if nargs != 1 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("function takes exactly 1 argument (%zd given)"),
            nargs
        );
        return NULL;
    }
    callable = first;
    if PyCallable_Check(callable) == 0 {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("argument must be callable or integer function address")
        );
        return NULL;
    }

    st = get_module_state_by_def(object_type(ptr[PyObject](type)));
    (res, info) = PyStgInfo_FromType(st, ptr[PyObject](type));
    if res < 0 {
        return NULL;
    }

    if not info {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("cannot construct instance of this class: no argtypes")
        );
        return NULL;
    }
    if not info.view(1)[0].argtypes {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("cannot construct instance of this class: no argtypes")
        );
        return NULL;
    }

    thunk = _ctypes_alloc_callback(
        st,
        callable,
        info.view(1)[0].argtypes,
        info.view(1)[0].restype,
        info.view(1)[0].flags
    );
    if not thunk {
        return NULL;
    }

    self_ = ptr[PyCFuncPtrObject](generic_pycdata_new(st, type, args, kwds));
    if not self_ {
        object_decref(ptr[PyObject](thunk));
        return NULL;
    }

    self_.view(1)[0].callable = object_new_ref(callable);

    self_.view(1)[0].thunk = thunk;
    ptr[ptr](self_.view(1)[0].b_ptr).view(1)[0] = thunk.view(1)[0].pcl_exec;

    object_incref(ptr[PyObject](thunk));
    if KeepRef(ptr[CDataObject](self_), 0, ptr[PyObject](thunk)) == -1 {
        object_decref(ptr[PyObject](self_));
        return NULL;
    }
    return ptr[PyObject](self_);
}
