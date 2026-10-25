import from c {
    def memmove(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  glob module_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(_ctypes_mod_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob _ctypesmodule: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_ctypes"),
             m_doc=ptr[u8]("Create and manipulate C compatible data types in Python."),
             m_size=SIZEOF_CTYPES_STATE,
             m_methods=addressof(_ctypes_module_methods),
             m_slots=addressof(module_slots)
         );
}

glob CDataType_token = ClassToken(),
     CType_Type_token = ClassToken(),
     PyCData_token = ClassToken(),
     PyCPointerType_token = ClassToken(),
     PyCSimpleType_token = ClassToken(),
     Simple_token = ClassToken(),
     c_char_p_token = ClassToken(),
     c_void_p_token = ClassToken(),
     c_wchar_p_token = ClassToken();

def set_class_tokens;

def subclass_clinic_state_PyCData_Type(
    receiver: ptr[PyObject], value: ptr[PyObject], fname: str, label: str
);

def create_type(
    mod: ptr[PyObject],
    spec: ptr[PyType_Spec],
    meta: ptr[PyTypeObject],
    base: ptr[PyObject]
) -> ptr[PyTypeObject];

def mod_add_type(mod: ptr[PyObject], tp: ptr[PyTypeObject]) -> bool;

def _ctypes_add_types(mod: ptr[PyObject]) -> i32;

def _ctypes_add_objects(mod: ptr[PyObject]) -> i32;

def _ctypes_mod_exec(mod: ptr[PyObject]) -> i32;

def module_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def clear_slot(slot: ptr[ptr[PyObject]]);

def module_clear(module: ptr[PyObject]) -> i32;

def module_free(module: ptr);

impl set_class_tokens {
    metaclass = ptr(addressof(pyctype_type_spec));
    CDataType_token.handle = metaclass;
    CType_Type_token.handle = metaclass;
    PyCPointerType_token.handle = metaclass;
    PyCSimpleType_token.handle = metaclass;
    simple_metaclass = ptr(addressof(pycsimple_type_spec));
    c_char_p_token.handle = simple_metaclass;
    c_void_p_token.handle = simple_metaclass;
    c_wchar_p_token.handle = simple_metaclass;
    cdata = ptr(addressof(pycdata_spec));
    PyCData_token.handle = cdata;
    Simple_token.handle = cdata;
}

impl subclass_clinic_state_PyCData_Type(
    receiver: ptr[PyObject], value: ptr[PyObject], fname: str, label: str
) {
    st = get_module_state(receiver);
    if not object_type_check(value, st.view(1)[0].PyCData_Type) {
        bad_argument(fname, label, "_ctypes._CData", value);
    }
}

impl create_type(
    mod: ptr[PyObject],
    spec: ptr[PyType_Spec],
    meta: ptr[PyTypeObject],
    base: ptr[PyObject]
) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](
        PyType_FromMetaclass(ptr[PyObject](meta), mod, spec, base)
    );
}

impl mod_add_type(mod: ptr[PyObject], tp: ptr[PyTypeObject]) -> bool {
    return bool(tp) and PyModule_AddType(mod, ptr[PyObject](tp)) >= 0;
}

impl _ctypes_add_types(mod: ptr[PyObject]) -> i32 {
    st = get_module_state(mod);
    s = st.view(1);
    no_meta = ptr[PyTypeObject]();

    s[0].PyCArg_Type = create_type(mod, addressof(carg_spec), no_meta, NULL);
    if not s[0].PyCArg_Type {
        return i32(-1);
    }
    s[0].PyCThunk_Type = create_type(mod, addressof(cthunk_spec), no_meta, NULL);
    if not s[0].PyCThunk_Type {
        return i32(-1);
    }
    s[0].PyCData_Type = create_type(mod, addressof(pycdata_spec), no_meta, NULL);
    if not s[0].PyCData_Type {
        return i32(-1);
    }

    s[0].PyCType_Type = create_type(
        mod,
        addressof(pyctype_type_spec),
        no_meta,
        ptr[PyObject](addressof(PyType_Type))
    );
    if not s[0].PyCType_Type {
        return i32(-1);
    }

    ctype = ptr[PyObject](s[0].PyCType_Type);
    s[0].PyCStructType_Type = create_type(
        mod, addressof(pycstruct_type_spec), no_meta, ctype
    );
    if not s[0].PyCStructType_Type {
        return i32(-1);
    }
    s[0].UnionType_Type = create_type(mod, addressof(union_type_spec), no_meta, ctype);
    if not s[0].UnionType_Type {
        return i32(-1);
    }
    s[0].PyCPointerType_Type = create_type(
        mod, addressof(pycpointer_type_spec), no_meta, ctype
    );
    if not s[0].PyCPointerType_Type {
        return i32(-1);
    }
    s[0].PyCArrayType_Type = create_type(
        mod, addressof(pycarray_type_spec), no_meta, ctype
    );
    if not s[0].PyCArrayType_Type {
        return i32(-1);
    }
    s[0].PyCSimpleType_Type = create_type(
        mod, addressof(pycsimple_type_spec), no_meta, ctype
    );
    if not s[0].PyCSimpleType_Type {
        return i32(-1);
    }
    s[0].PyCFuncPtrType_Type = create_type(
        mod, addressof(pycfuncptr_type_spec), no_meta, ctype
    );
    if not s[0].PyCFuncPtrType_Type {
        return i32(-1);
    }

    cdata = ptr[PyObject](s[0].PyCData_Type);
    s[0].Struct_Type = create_type(
        mod, addressof(pycstruct_spec), s[0].PyCStructType_Type, cdata
    );
    if not mod_add_type(mod, s[0].Struct_Type) {
        return i32(-1);
    }
    s[0].Union_Type = create_type(
        mod, addressof(pycunion_spec), s[0].UnionType_Type, cdata
    );
    if not mod_add_type(mod, s[0].Union_Type) {
        return i32(-1);
    }
    s[0].PyCPointer_Type = create_type(
        mod, addressof(pycpointer_spec), s[0].PyCPointerType_Type, cdata
    );
    if not mod_add_type(mod, s[0].PyCPointer_Type) {
        return i32(-1);
    }
    s[0].PyCArray_Type = create_type(
        mod, addressof(pycarray_spec), s[0].PyCArrayType_Type, cdata
    );
    if not mod_add_type(mod, s[0].PyCArray_Type) {
        return i32(-1);
    }
    s[0].Simple_Type = create_type(
        mod, addressof(pycsimple_spec), s[0].PyCSimpleType_Type, cdata
    );
    if not mod_add_type(mod, s[0].Simple_Type) {
        return i32(-1);
    }
    s[0].PyCFuncPtr_Type = create_type(
        mod, addressof(pycfuncptr_spec), s[0].PyCFuncPtrType_Type, cdata
    );
    if not mod_add_type(mod, s[0].PyCFuncPtr_Type) {
        return i32(-1);
    }

    s[0].PyCField_Type = create_type(mod, addressof(cfield_spec), no_meta, NULL);
    if not mod_add_type(mod, s[0].PyCField_Type) {
        return i32(-1);
    }

    s[0].DictRemover_Type = create_type(
        mod, addressof(dictremover_spec), no_meta, NULL
    );
    if not s[0].DictRemover_Type {
        return i32(-1);
    }
    s[0].StructParam_Type = create_type(
        mod, addressof(structparam_spec), no_meta, NULL
    );
    if not s[0].StructParam_Type {
        return i32(-1);
    }
    return i32(0);
}

impl _ctypes_add_objects(mod: ptr[PyObject]) -> i32 {
    st = get_module_state(mod);
    if PyModule_Add(
        mod, ptr[u8]("FUNCFLAG_CDECL"), PyLong_FromLong(i64(FUNCFLAG_CDECL))
    )
        < 0
        or PyModule_Add(
            mod, ptr[u8]("FUNCFLAG_USE_ERRNO"), PyLong_FromLong(i64(FUNCFLAG_USE_ERRNO))
        )
            < 0
        or PyModule_Add(
            mod,
            ptr[u8]("FUNCFLAG_USE_LASTERROR"),
            PyLong_FromLong(i64(FUNCFLAG_USE_LASTERROR))
        )
            < 0
        or PyModule_Add(
            mod, ptr[u8]("FUNCFLAG_PYTHONAPI"), PyLong_FromLong(i64(FUNCFLAG_PYTHONAPI))
        )
            < 0
        or PyModule_Add(
            mod, ptr[u8]("__version__"), PyUnicode_FromString(ptr[u8]("1.1.0"))
        )
            < 0 {
        return i32(-1);
    }
    if PyModule_Add(mod, ptr[u8]("_memmove_addr"), PyLong_FromVoidPtr(ptr(memmove))) < 0
        or PyModule_Add(mod, ptr[u8]("_memset_addr"), PyLong_FromVoidPtr(ptr(memset)))
            < 0
        or PyModule_Add(
            mod, ptr[u8]("_string_at_addr"), PyLong_FromVoidPtr(ptr(string_at))
        )
            < 0
        or PyModule_Add(mod, ptr[u8]("_cast_addr"), PyLong_FromVoidPtr(ptr(cast))) < 0
        or PyModule_Add(
            mod, ptr[u8]("_wstring_at_addr"), PyLong_FromVoidPtr(ptr(wstring_at))
        )
            < 0
        or PyModule_Add(
            mod, ptr[u8]("_memoryview_at_addr"), PyLong_FromVoidPtr(ptr(memoryview_at))
        )
            < 0 {
        return i32(-1);
    }
    if PyModule_Add(mod, ptr[u8]("RTLD_LOCAL"), PyLong_FromLong(i64(RTLD_LOCAL))) < 0
        or PyModule_Add(mod, ptr[u8]("RTLD_GLOBAL"), PyLong_FromLong(i64(RTLD_GLOBAL)))
            < 0
        or PyModule_Add(
            mod, ptr[u8]("CTYPES_MAX_ARGCOUNT"), PyLong_FromLong(CTYPES_MAX_ARGCOUNT)
        )
            < 0
        or PyModule_Add(
            mod, ptr[u8]("ArgumentError"), object_new_ref(st.view(1)[0].PyExc_ArgError)
        )
            < 0
        or PyModule_Add(mod, ptr[u8]("SIZEOF_TIME_T"), PyLong_FromSsize_t(8)) < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl _ctypes_mod_exec(mod: ptr[PyObject]) -> i32 {
    codeloc = ptr[ptr](PyMem_Calloc(1, 8));
    if not codeloc {
        PyErr_NoMemory();
        return i32(-1);
    }
    closure = Py_ffi_closure_alloc(8, codeloc);
    PyMem_Free(ptr(codeloc));
    if not closure {
        PyErr_NoMemory();
        return i32(-1);
    }
    Py_ffi_closure_free(closure);

    _ctypes_init_fielddesc();

    st = get_module_state(mod);
    s = st.view(1);
    s[0]._unpickle = PyObject_GetAttrString(mod, ptr[u8]("_unpickle"));
    if not s[0]._unpickle {
        return i32(-1);
    }

    s[0].PyExc_ArgError = PyErr_NewException(
        ptr[u8]("ctypes.ArgumentError"), NULL, NULL
    );
    if not s[0].PyExc_ArgError {
        return i32(-1);
    }

    s[0].array_cache = PyDict_New();
    if not s[0].array_cache {
        return i32(-1);
    }

    s[0].swapped_suffix = PyUnicode_InternFromString(ptr[u8]("_be"));
    if not s[0].swapped_suffix {
        return i32(-1);
    }

    s[0].error_object_name = PyUnicode_InternFromString(ptr[u8]("ctypes.error_object"));
    if not s[0].error_object_name {
        return i32(-1);
    }

    if _ctypes_add_types(mod) < 0 {
        return i32(-1);
    }

    if _ctypes_add_objects(mod) < 0 {
        return i32(-1);
    }
    return i32(0);
}

impl module_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    slots = ptr[ptr[PyObject]](get_module_state(module));
    index = 19;
    while index < 24 + 19 {
        slot = index % 24;
        if slot != 5 {
            status = visit_reference((slots + slot).view(1)[0], visitor, arg);
            if status != 0 {
                return status;
            }
        }
        index += 1;
    }
    return visit_reference((slots + 5).view(1)[0], visitor, arg);
}

impl clear_slot(slot: ptr[ptr[PyObject]]) {
    old = slot.view(1)[0];
    if old {
        slot.view(1)[0] = NULL;
        object_decref(old);
    }
}

impl module_clear(module: ptr[PyObject]) -> i32 {
    st = get_module_state(module);

    slots = ptr[ptr[PyObject]](st);
    for index in range(19, 24) {
        clear_slot(slots + index);
    }
    for index in range(0, 5) {
        clear_slot(slots + index);
    }
    for index in range(6, 19) {
        clear_slot(slots + index);
    }
    clear_slot(slots + 5);
    return i32(0);
}

impl module_free(module: ptr) {
    module_clear(ptr[PyObject](module));
}
