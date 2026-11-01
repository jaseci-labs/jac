import from c {
    obj ffi_type {
        has size: u64,
            alignment: u16,
            type: u16,
            elements: ptr[ptr[ffi_type]];
    }  obj ffi_cif {
        has abi: i32,
            nargs: u32,
            arg_types: ptr[ptr[ffi_type]],
            rtype: ptr[ffi_type],
            bytes_: u32,
            flags: u32,
            extra: u32,
            extra_pad: u32;
    }  glob ffi_type_void: ffi_type,
         ffi_type_uint8: ffi_type,
         ffi_type_sint8: ffi_type,
         ffi_type_uint16: ffi_type,
         ffi_type_sint16: ffi_type,
         ffi_type_uint32: ffi_type,
         ffi_type_sint32: ffi_type,
         ffi_type_uint64: ffi_type,
         ffi_type_sint64: ffi_type,
         ffi_type_float: ffi_type,
         ffi_type_double: ffi_type,
         ffi_type_pointer: ffi_type,
         ffi_type_complex_float: ffi_type,
         ffi_type_complex_double: ffi_type; def ffi_prep_cif(
        cif: ptr[ffi_cif],
        abi: i32,
        nargs: u32,
        rtype: ptr[ffi_type],
        atypes: ptr[ptr[ffi_type]]
    ) -> i32;  def ffi_prep_cif_var(
        cif: ptr[ffi_cif],
        abi: i32,
        nfixedargs: u32,
        ntotalargs: u32,
        rtype: ptr[ffi_type],
        atypes: ptr[ptr[ffi_type]]
    ) -> i32;  def ffi_call(
        cif: ptr[ffi_cif], fn: ptr, rvalue: ptr, avalue: ptr[ptr]
    );  def ffi_closure_alloc(size: u64, code: ptr[ptr]) -> ptr;  def ffi_closure_free(
        closure: ptr
    );  def ffi_prep_closure_loc(
        closure: ptr, cif: ptr[ffi_cif], fun: ptr, user_data: ptr, codeloc: ptr
    ) -> i32;  obj ctypes_state {
        has DictRemover_Type: ptr[PyTypeObject],
            PyCArg_Type: ptr[PyTypeObject],
            PyCField_Type: ptr[PyTypeObject],
            PyCThunk_Type: ptr[PyTypeObject],
            StructParam_Type: ptr[PyTypeObject],
            PyCType_Type: ptr[PyTypeObject],
            PyCStructType_Type: ptr[PyTypeObject],
            UnionType_Type: ptr[PyTypeObject],
            PyCPointerType_Type: ptr[PyTypeObject],
            PyCArrayType_Type: ptr[PyTypeObject],
            PyCSimpleType_Type: ptr[PyTypeObject],
            PyCFuncPtrType_Type: ptr[PyTypeObject],
            PyCData_Type: ptr[PyTypeObject],
            Struct_Type: ptr[PyTypeObject],
            Union_Type: ptr[PyTypeObject],
            PyCArray_Type: ptr[PyTypeObject],
            Simple_Type: ptr[PyTypeObject],
            PyCPointer_Type: ptr[PyTypeObject],
            PyCFuncPtr_Type: ptr[PyTypeObject],
            _unpickle: ptr[PyObject],
            array_cache: ptr[PyObject],
            error_object_name: ptr[PyObject],
            PyExc_ArgError: ptr[PyObject],
            swapped_suffix: ptr[PyObject];
    }  obj cdata_value {
        has w0: u64,
            w1: u64;
    }  obj CDataObject {
        has ob_base: _object,
            b_ptr: ptr[u8],
            b_needsfree: i32,
            b_base: ptr[CDataObject],
            b_size: i64,
            b_length: i64,
            b_index: i64,
            b_objects: ptr[PyObject],
            b_value_pad: u64,
            b_value: cdata_value;
    }  obj PyCFuncPtrObject {
        has ob_base: _object,
            b_ptr: ptr[u8],
            b_needsfree: i32,
            b_base: ptr[CDataObject],
            b_size: i64,
            b_length: i64,
            b_index: i64,
            b_objects: ptr[PyObject],
            b_value_pad: u64,
            b_value: cdata_value,
            thunk: ptr[CThunkObject],
            callable: ptr[PyObject],
            converters: ptr[PyObject],
            argtypes: ptr[PyObject],
            restype: ptr[PyObject],
            checker: ptr[PyObject],
            errcheck: ptr[PyObject],
            paramflags: ptr[PyObject];
    }  obj CThunkObject {
        has ob_base: PyVarObject,
            pcl_write: ptr,
            pcl_exec: ptr,
            cif: ffi_cif,
            flags: i32,
            converters: ptr[PyObject],
            callable: ptr[PyObject],
            restype: ptr[PyObject],
            setfunc: ptr,
            ffi_restype: ptr[ffi_type],
            atypes: ptr[ffi_type];
    }  obj fielddesc {
        has code: u8,
            pffi_type: ptr[ffi_type],
            setfunc: ptr,
            getfunc: ptr,
            setfunc_swapped: ptr,
            getfunc_swapped: ptr;
    }  obj CFieldObject {
        has ob_base: _object,
            byte_offset: i64,
            byte_size: i64,
            index: i64,
            proto: ptr[PyObject],
            getfunc: ptr,
            setfunc: ptr,
            anonymous: u8,
            bitfield_size: u8,
            bit_offset: u8,
            name: ptr[PyObject];
    }  obj StgInfo {
        has initialized: i32,
            size: i64,
            align: i64,
            length: i64,
            ffi_type_pointer: ffi_type,
            proto: ptr[PyObject],
            setfunc: ptr,
            getfunc: ptr,
            paramfunc: ptr,
            argtypes: ptr[PyObject],
            converters: ptr[PyObject],
            restype: ptr[PyObject],
            checker: ptr[PyObject],
            pointer_type: ptr[PyObject],
            module: ptr[PyObject],
            flags: i32,
            dict_final: u8,
            format_: ptr[u8],
            ndim: i32,
            shape: ptr[i64];
    }  obj carg_value {
        has w0: u64,
            w1: u64,
            w2: u64,
            w3: u64;
    }  obj PyCArgObject {
        has ob_base: _object,
            pffi_type: ptr[ffi_type],
            tag: u8,
            value: carg_value,
            obj_: ptr[PyObject],
            size: i64;
    }  obj basespec {
        has base: ptr[CDataObject],
            index: i64,
            adr: ptr[u8];
    }  obj CtypesCalls {
        has getfunc: Callable[[ptr, i64], ptr[PyObject]],
            setfunc: Callable[[ptr, ptr[PyObject], i64], ptr[PyObject]],
            paramfunc:
                Callable[[ptr[ctypes_state], ptr[CDataObject]], ptr[PyCArgObject]];
    }  obj ClinicTables {
        has c_void_p_methods: ptr[PyMethodDef],
            c_char_p_methods: ptr[PyMethodDef],
            c_wchar_p_methods: ptr[PyMethodDef],
            CharArray_getsets: ptr[PyGetSetDef];
    }  glob ctypes_clinic_tables: ClinicTables = ClinicTables(
             c_void_p_methods=ptr[PyMethodDef](),
             c_char_p_methods=ptr[PyMethodDef](),
             c_wchar_p_methods=ptr[PyMethodDef](),
             CharArray_getsets=ptr[PyGetSetDef]()
         );
}


glob FUNCFLAG_STDCALL: Final[i32] = 0x0,
     FUNCFLAG_CDECL: Final[i32] = 0x1,
     FUNCFLAG_HRESULT: Final[i32] = 0x2,
     FUNCFLAG_PYTHONAPI: Final[i32] = 0x4,
     FUNCFLAG_USE_ERRNO: Final[i32] = 0x8,
     FUNCFLAG_USE_LASTERROR: Final[i32] = 0x10,
     TYPEFLAG_ISPOINTER: Final[i32] = 0x100,
     TYPEFLAG_HASPOINTER: Final[i32] = 0x200,
     PARAMFLAG_FIN: Final[i32] = 0x1,
     PARAMFLAG_FOUT: Final[i32] = 0x2,
     PARAMFLAG_FLCID: Final[i32] = 0x4,
     CTYPES_MAX_ARGCOUNT: Final[i64] = 1024,
     Py_FFI_COMPLEX_AVAILABLE: Final[bool] = True,
     FFI_OK: Final[i32] = 0,
     FFI_BAD_TYPEDEF: Final[i32] = 1,
     FFI_BAD_ABI: Final[i32] = 2,
     FFI_BAD_ARGTYPE: Final[i32] = 3,
     FFI_TYPE_VOID: Final[u16] = 0,
     FFI_TYPE_INT: Final[u16] = 1,
     FFI_TYPE_FLOAT: Final[u16] = 2,
     FFI_TYPE_DOUBLE: Final[u16] = 3,
     FFI_TYPE_UINT8: Final[u16] = 5,
     FFI_TYPE_SINT8: Final[u16] = 6,
     FFI_TYPE_UINT16: Final[u16] = 7,
     FFI_TYPE_SINT16: Final[u16] = 8,
     FFI_TYPE_UINT32: Final[u16] = 9,
     FFI_TYPE_SINT32: Final[u16] = 10,
     FFI_TYPE_UINT64: Final[u16] = 11,
     FFI_TYPE_SINT64: Final[u16] = 12,
     FFI_TYPE_STRUCT: Final[u16] = 13,
     FFI_TYPE_POINTER: Final[u16] = 14,
     FFI_TYPE_COMPLEX: Final[u16] = 15,
     SIZEOF_FFI_TYPE: Final[i64] = 24,
     SIZEOF_FFI_CIF: Final[i64] = 40,
     SIZEOF_FFI_CLOSURE: Final[i64] = 64,
     SIZEOF_CTYPES_STATE: Final[i64] = 192,
     SIZEOF_CDATAOBJECT: Final[i64] = 96,
     SIZEOF_PYCFUNCPTROBJECT: Final[i64] = 160,
     SIZEOF_CTHUNKOBJECT: Final[i64] = 136,
     SIZEOF_FIELDDESC: Final[i64] = 48,
     SIZEOF_CFIELDOBJECT: Final[i64] = 80,
     SIZEOF_STGINFO: Final[i64] = 168,
     SIZEOF_PYCARGOBJECT: Final[i64] = 80,
     SIZEOF_VALUE_UNION: Final[i64] = 16,
     SIZEOF_RESULT_UNION: Final[i64] = 32,
     CDATA_B_PTR: Final[i64] = 16,
     CDATA_B_NEEDSFREE: Final[i64] = 24,
     CDATA_B_BASE: Final[i64] = 32,
     CDATA_B_SIZE: Final[i64] = 40,
     CDATA_B_LENGTH: Final[i64] = 48,
     CDATA_B_INDEX: Final[i64] = 56,
     CDATA_B_OBJECTS: Final[i64] = 64,
     CDATA_B_VALUE: Final[i64] = 80,
     CTHUNK_PCL_EXEC: Final[i64] = 32,
     CTHUNK_CIF: Final[i64] = 40,
     CTHUNK_ATYPES: Final[i64] = 128,
     CFIELD_BYTE_OFFSET: Final[i64] = 16,
     CFIELD_BYTE_SIZE: Final[i64] = 24,
     CFIELD_INDEX: Final[i64] = 32,
     CFIELD_PROTO: Final[i64] = 40,
     CFIELD_BIT_OFFSET: Final[i64] = 66,
     CFIELD_NAME: Final[i64] = 72,
     STGINFO_FFI_TYPE_POINTER: Final[i64] = 32,
     PYCARG_VALUE: Final[i64] = 32,
     PYCARG_OBJ: Final[i64] = 64;

def cdata_value_address(self_: ptr[CDataObject]) -> ptr[u8];

def _CDataObject_HasExternalBuffer(v: ptr[CDataObject]) -> bool;

def carg_value_address(self_: ptr[PyCArgObject]) -> ptr[u8];

def thunk_atypes(self_: ptr[CThunkObject]) -> ptr[ptr[ffi_type]];

def thunk_cif(self_: ptr[CThunkObject]) -> ptr[ffi_cif];

def stginfo_ffi_type(info: ptr[StgInfo]) -> ptr[ffi_type];

def call_getfunc(getfunc: ptr, adr: ptr, size: i64) -> ptr[PyObject];

def call_setfunc(
    setfunc: ptr, adr: ptr, value: ptr[PyObject], size: i64
) -> ptr[PyObject];

def call_paramfunc(
    paramfunc: ptr, st: ptr[ctypes_state], obj_: ptr[CDataObject]
) -> ptr[PyCArgObject];

def get_module_state(module: ptr[PyObject]) -> ptr[ctypes_state];

def get_module_state_by_class(cls: ptr[PyTypeObject]) -> ptr[ctypes_state];

def get_module_state_by_def(cls: ptr[PyTypeObject]) -> ptr[ctypes_state];

def CDataObject_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def CDataObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCSimpleTypeObject_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCSimpleTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCArrayTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def ArrayObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PointerObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCPointerTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCFuncPtrObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCFuncPtrTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCStructTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def PyCArg_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def CThunk_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool;

def _stginfo_from_type(
    state: ptr[ctypes_state], type: ptr[PyTypeObject]
) -> tuple[i32, ptr[StgInfo]];

def PyStgInfo_FromType(
    state: ptr[ctypes_state], type: ptr[PyObject]
) -> tuple[i32, ptr[StgInfo]];

def PyStgInfo_FromObject(
    state: ptr[ctypes_state], obj_: ptr[PyObject]
) -> tuple[i32, ptr[StgInfo]];

def PyStgInfo_FromAny(
    state: ptr[ctypes_state], obj_: ptr[PyObject]
) -> tuple[i32, ptr[StgInfo]];

def _PyStgInfo_FromType_NoState(type: ptr[PyObject]) -> ptr[StgInfo];

def PyStgInfo_Init(state: ptr[ctypes_state], type: ptr[PyTypeObject]) -> ptr[StgInfo];

def stginfo_get_dict_final(info: ptr[StgInfo]) -> u8;

def stginfo_set_dict_final_lock_held(info: ptr[StgInfo]);

def stginfo_set_dict_final(info: ptr[StgInfo]);

impl cdata_value_address(self_: ptr[CDataObject]) -> ptr[u8] {
    return ptr[u8](self_) + CDATA_B_VALUE;
}

impl _CDataObject_HasExternalBuffer(v: ptr[CDataObject]) -> bool {
    return v.view(1)[0].b_ptr != cdata_value_address(v);
}

impl carg_value_address(self_: ptr[PyCArgObject]) -> ptr[u8] {
    return ptr[u8](self_) + PYCARG_VALUE;
}

impl thunk_atypes(self_: ptr[CThunkObject]) -> ptr[ptr[ffi_type]] {
    return ptr[ptr[ffi_type]](ptr[u8](self_) + CTHUNK_ATYPES);
}

impl thunk_cif(self_: ptr[CThunkObject]) -> ptr[ffi_cif] {
    return ptr[ffi_cif](ptr[u8](self_) + CTHUNK_CIF);
}

impl stginfo_ffi_type(info: ptr[StgInfo]) -> ptr[ffi_type] {
    return ptr[ffi_type](ptr[u8](info) + STGINFO_FFI_TYPE_POINTER);
}

impl call_getfunc(getfunc: ptr, adr: ptr, size: i64) -> ptr[PyObject] {
    calls = ptr[CtypesCalls](__thread_local_block("jac_ctypes_call_slot", 24));
    calls.view(1)[0].getfunc = int(getfunc);
    return calls.view(1)[0].getfunc(adr, size);
}

impl call_setfunc(
    setfunc: ptr, adr: ptr, value: ptr[PyObject], size: i64
) -> ptr[PyObject] {
    calls = ptr[CtypesCalls](__thread_local_block("jac_ctypes_call_slot", 24));
    calls.view(1)[0].setfunc = int(setfunc);
    return calls.view(1)[0].setfunc(adr, value, size);
}

impl call_paramfunc(
    paramfunc: ptr, st: ptr[ctypes_state], obj_: ptr[CDataObject]
) -> ptr[PyCArgObject] {
    calls = ptr[CtypesCalls](__thread_local_block("jac_ctypes_call_slot", 24));
    calls.view(1)[0].paramfunc = int(paramfunc);
    return calls.view(1)[0].paramfunc(st, obj_);
}

impl get_module_state(module: ptr[PyObject]) -> ptr[ctypes_state] {
    return ptr[ctypes_state](PyModule_GetState(module));
}

impl get_module_state_by_class(cls: ptr[PyTypeObject]) -> ptr[ctypes_state] {
    return ptr[ctypes_state](PyType_GetModuleState(cls));
}

impl get_module_state_by_def(cls: ptr[PyTypeObject]) -> ptr[ctypes_state] {
    mod = PyType_GetModuleByDef(cls, ptr[PyModuleDef](addressof(_ctypesmodule)));
    return get_module_state(mod);
}

impl CDataObject_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type(v) == st.view(1)[0].PyCData_Type;
}

impl CDataObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCData_Type);
}

impl PyCSimpleTypeObject_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type(v) == st.view(1)[0].PyCSimpleType_Type;
}

impl PyCSimpleTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCSimpleType_Type);
}

impl PyCArrayTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCArrayType_Type);
}

impl ArrayObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCArray_Type);
}

impl PointerObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCPointer_Type);
}

impl PyCPointerTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCPointerType_Type);
}

impl PyCFuncPtrObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCFuncPtr_Type);
}

impl PyCFuncPtrTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCFuncPtrType_Type);
}

impl PyCStructTypeObject_Check(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type_check(v, st.view(1)[0].PyCStructType_Type);
}

impl PyCArg_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type(v) == st.view(1)[0].PyCArg_Type;
}

impl CThunk_CheckExact(st: ptr[ctypes_state], v: ptr[PyObject]) -> bool {
    return object_type(v) == st.view(1)[0].PyCThunk_Type;
}

impl _stginfo_from_type(
    state: ptr[ctypes_state], type: ptr[PyTypeObject]
) -> tuple[i32, ptr[StgInfo]] {
    if PyObject_IsInstance(
        ptr[PyObject](type), ptr[PyObject](state.view(1)[0].PyCType_Type)
    )
        == 0 {
        return (i32(0), ptr[StgInfo]());
    }
    info = ptr[StgInfo](
        PyObject_GetTypeData(ptr[PyObject](type), state.view(1)[0].PyCType_Type)
    );
    if info.view(1)[0].initialized == 0 {
        return (i32(0), ptr[StgInfo]());
    }
    return (i32(1), info);
}

impl PyStgInfo_FromType(
    state: ptr[ctypes_state], type: ptr[PyObject]
) -> tuple[i32, ptr[StgInfo]] {
    return _stginfo_from_type(state, ptr[PyTypeObject](type));
}

impl PyStgInfo_FromObject(
    state: ptr[ctypes_state], obj_: ptr[PyObject]
) -> tuple[i32, ptr[StgInfo]] {
    return _stginfo_from_type(state, object_type(obj_));
}

impl PyStgInfo_FromAny(
    state: ptr[ctypes_state], obj_: ptr[PyObject]
) -> tuple[i32, ptr[StgInfo]] {
    if type_check(obj_) {
        return _stginfo_from_type(state, ptr[PyTypeObject](obj_));
    }
    return _stginfo_from_type(state, object_type(obj_));
}

impl _PyStgInfo_FromType_NoState(type: ptr[PyObject]) -> ptr[StgInfo] {
    found: ptr[PyObject] = NULL;
    if PyType_GetBaseByToken(
        ptr[PyObject](object_type(type)), ptr(addressof(pyctype_type_spec)), &mut found
    )
        < 0 {
        return ptr[StgInfo]();
    }
    if not found {
        return ptr[StgInfo]();
    }
    object_decref(found);
    return ptr[StgInfo](PyObject_GetTypeData(type, ptr[PyTypeObject](found)));
}

impl PyStgInfo_Init(state: ptr[ctypes_state], type: ptr[PyTypeObject]) -> ptr[StgInfo] {
    if PyObject_IsInstance(
        ptr[PyObject](type), ptr[PyObject](state.view(1)[0].PyCType_Type)
    )
        == 0 {
        PyErr_Format(
            PyExc_SystemError,
            ptr[u8]("'%s' is not a ctypes class."),
            type.view(1)[0].tp_name
        );
        return ptr[StgInfo]();
    }
    info = ptr[StgInfo](
        PyObject_GetTypeData(ptr[PyObject](type), state.view(1)[0].PyCType_Type)
    );
    if info.view(1)[0].initialized != 0 {
        PyErr_Format(
            PyExc_SystemError,
            ptr[u8]("StgInfo of '%s' is already initialized."),
            type.view(1)[0].tp_name
        );
        return ptr[StgInfo]();
    }
    module = PyType_GetModule(ptr[PyObject](state.view(1)[0].PyCType_Type));
    if not module {
        return ptr[StgInfo]();
    }
    info.view(1)[0].pointer_type = NULL;
    info.view(1)[0].module = object_new_ref(module);
    info.view(1)[0].initialized = 1;
    return info;
}

impl stginfo_get_dict_final(info: ptr[StgInfo]) -> u8 {
    return info.view(1)[0].dict_final;
}

impl stginfo_set_dict_final_lock_held(info: ptr[StgInfo]) {
    info.view(1)[0].dict_final = 1;
}

impl stginfo_set_dict_final(info: ptr[StgInfo]) {
    if stginfo_get_dict_final(info) == 1 {
        return;
    }
    stginfo_set_dict_final_lock_held(info);
}
