import from c {
    obj DictRemoverObject {
        has ob_base: _object,
            key: ptr[PyObject],
            dct: ptr[PyObject];
    }  obj StructParamObject {
        has ob_base: _object,
            ptr_: ptr,
            keep: ptr[PyObject];
    }  obj CTypeTraverseCall {
        has call: Callable[[ptr[PyObject], ptr, ptr], i32] = 0;
    }  def strlen(text: ptr[u8]) -> u64;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memmove(target: ptr, source: ptr, size: u64) -> ptr;  def dlsym(
        handle: ptr, symbol: str
    ) -> ptr;  def dlerror -> ptr[u8];  def PyDict_SetItemProxy(
        st: ptr[ctypes_state],
        dct: ptr[PyObject],
        key: ptr[PyObject],
        item: ptr[PyObject]
    ) -> i32 {
        obj_ = PyObject_CallNoArgs(ptr[PyObject](st.view(1)[0].DictRemover_Type));
        if not obj_ {
            return -1;
        }
        remover = ptr[DictRemoverObject](obj_);
        remover.view(1)[0].key = object_new_ref(key);
        remover.view(1)[0].dct = object_new_ref(dct);
        proxy = PyWeakref_NewProxy(item, obj_);
        object_decref(obj_);
        if not proxy {
            return -1;
        }
        result = PyDict_SetItem(dct, key, proxy);
        object_decref(proxy);
        return result;
    }  def ctype_clear_stginfo(info: ptr[StgInfo]) {
        old = info.view(1)[0].proto;
        info.view(1)[0].proto = NULL;
        object_xdecref(old);
        old = info.view(1)[0].argtypes;
        info.view(1)[0].argtypes = NULL;
        object_xdecref(old);
        old = info.view(1)[0].converters;
        info.view(1)[0].converters = NULL;
        object_xdecref(old);
        old = info.view(1)[0].restype;
        info.view(1)[0].restype = NULL;
        object_xdecref(old);
        old = info.view(1)[0].checker;
        info.view(1)[0].checker = NULL;
        object_xdecref(old);
        old = info.view(1)[0].pointer_type;
        info.view(1)[0].pointer_type = NULL;
        object_xdecref(old);

        old = info.view(1)[0].module;
        info.view(1)[0].module = NULL;
        object_xdecref(old);
    }  def ctype_free_stginfo_members(info: ptr[StgInfo]) {
        ftype = stginfo_ffi_type(info);
        PyMem_Free(ptr(ftype.view(1)[0].elements));
        ftype.view(1)[0].elements = ptr[ptr[ffi_type]]();
        PyMem_Free(ptr(info.view(1)[0].format_));
        info.view(1)[0].format_ = ptr[u8]();
        PyMem_Free(ptr(info.view(1)[0].shape));
        info.view(1)[0].shape = ptr[i64]();
        ctype_clear_stginfo(info);
    }
}

glob:priv PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF,
     SIZEOF_VOID_P: Final[i64] = 8,
     SIZEOF_WCHAR_T: Final[i64] = 4;

def _string_param(
    st: ptr[ctypes_state], fmt: ptr[u8], tag: u8, value: ptr[PyObject], size: i64
) -> ptr[PyObject];

def _points_at_fielddesc(
    st: ptr[ctypes_state], value: ptr[PyObject], fmt: ptr[u8]
) -> tuple[i32, bool];

def _PyDict_GetItemProxy(
    dct: ptr[PyObject], key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def _ctypes_alloc_format_string_for_type(code: u8, big_endian: i32) -> ptr[u8];

def _ctypes_alloc_format_string(prefix: ptr[u8], suffix: ptr[u8]) -> ptr[u8];

def _ctypes_alloc_format_string_with_shape(
    ndim: i32, shape: ptr[i64], prefix: ptr[u8], suffix: ptr[u8]
) -> ptr[u8];

def _ctypes_CType_Type___sizeof___impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def CDataType_from_address_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def CDataType_from_buffer_impl(
    type: ptr[PyObject], cls: ptr[PyObject], obj_: ptr[PyObject], offset: i64
) -> ptr[PyObject];

def CDataType_from_buffer_copy_impl(
    type: ptr[PyObject], cls: ptr[PyObject], buffer: BufferArgument, offset: i64
) -> ptr[PyObject];

def CDataType_in_dll_impl(
    type: ptr[PyObject], cls: ptr[PyObject], dll: ptr[PyObject], name: str
) -> ptr[PyObject];

def CDataType_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def PyCPointerType_set_type_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def PyCPointerType_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def _ctypes_PyCArrayType_Type_raw_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def _ctypes_PyCArrayType_Type_raw_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _ctypes_PyCArrayType_Type_value_get_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _ctypes_PyCArrayType_Type_value_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def c_wchar_p_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def c_char_p_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def c_void_p_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def _DictRemover_traverse(myself: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def _DictRemover_clear(myself: ptr[PyObject]) -> i32;

def _DictRemover_dealloc(myself: ptr[PyObject]);

def _DictRemover_call(
    myself: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject];

impl _PyDict_GetItemProxy(
    dct: ptr[PyObject], key: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    result: ptr[PyObject] = NULL;
    rc = PyDict_GetItemRef(dct, key, &mut result);
    item = result;
    if item and weakref_check_proxy(item) {
        rc = PyWeakref_GetRef(item, &mut result);
        object_decref(item);
    }
    return (rc, result);
}

impl _ctypes_alloc_format_string_for_type(code: u8, big_endian: i32) -> ptr[u8] {
    pep_code: u8 = code;
    if code == 105 {
        pep_code = 105;
    } elif code == 73 {
        pep_code = 73;
    } elif code == 108 {
        pep_code = 113;
    } elif code == 76 {
        pep_code = 81;
    } elif code == 63 {
        pep_code = 63;
    }
    result = ptr[u8](PyMem_Malloc(3));
    if not result {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    if big_endian != 0 {
        result.view(3)[0] = 62;
    } else {
        result.view(3)[0] = 60;
    }
    result.view(3)[1] = pep_code;
    result.view(3)[2] = 0;
    return result;
}

impl _ctypes_alloc_format_string(prefix: ptr[u8], suffix: ptr[u8]) -> ptr[u8] {
    if not suffix {
        return ptr[u8]();
    }
    suffix_len = strlen(suffix);
    prefix_len: u64 = 0;
    if prefix {
        prefix_len = strlen(prefix);
    }
    result = ptr[u8](PyMem_Malloc(prefix_len + suffix_len + 1));
    if not result {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    if prefix {
        memcpy(ptr(result), ptr(prefix), prefix_len);
    }
    memcpy(ptr(result + i64(prefix_len)), ptr(suffix), suffix_len + 1);
    return result;
}

impl _ctypes_alloc_format_string_with_shape(
    ndim: i32, shape: ptr[i64], prefix: ptr[u8], suffix: ptr[u8]
) -> ptr[u8] {
    prefix_len: i64 = 32 * i64(ndim) + 3;
    if prefix {
        prefix_len += i64(strlen(prefix));
    }
    new_prefix = ptr[u8](PyMem_Malloc(u64(prefix_len)));
    if not new_prefix {
        PyErr_NoMemory();
        return ptr[u8]();
    }
    pos: i64 = 0;
    new_prefix.view(1)[0] = 0;
    if prefix {
        pos = i64(strlen(prefix));
        memcpy(ptr(new_prefix), ptr(prefix), u64(pos + 1));
    }
    if ndim > 0 {
        (new_prefix + pos).view(2)[0] = 40;
        (new_prefix + pos).view(2)[1] = 0;
        pos += 1;
        k: i32 = 0;
        while k < ndim {
            written: i32 = 0;
            if k < ndim - 1 {
                written = PyOS_snprintf(
                    new_prefix + pos,
                    u64(prefix_len - pos),
                    ptr[u8]("%zd,"),
                    (shape + i64(k)).view(1)[0]
                );
            } else {
                written = PyOS_snprintf(
                    new_prefix + pos,
                    u64(prefix_len - pos),
                    ptr[u8]("%zd)"),
                    (shape + i64(k)).view(1)[0]
                );
            }
            pos += i64(written);
            k += 1;
        }
    }
    result = _ctypes_alloc_format_string(new_prefix, suffix);
    PyMem_Free(ptr(new_prefix));
    return result;
}

def StructParam_traverse(myself: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def StructParam_clear(myself: ptr[PyObject]) -> i32;

def StructParam_dealloc(myself: ptr[PyObject]);

def CType_Type_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def CType_Type_clear(self_: ptr[PyObject]) -> i32;

def CType_Type_dealloc(self_: ptr[PyObject]);

impl _ctypes_CType_Type___sizeof___impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    tp = object_type(self_);
    size: i64 = tp.view(1)[0].tp_basicsize;
    size += tp.view(1)[0].tp_itemsize * object_size(self_);
    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    (res, info) = PyStgInfo_FromType(st, self_);
    if res < 0 {
        return NULL;
    }
    if info {
        if info.view(1)[0].format_ {
            size += i64(strlen(info.view(1)[0].format_)) + 1;
        }
        if stginfo_ffi_type(info).view(1)[0].elements {
            size += (info.view(1)[0].length + 1) * SIZEOF_VOID_P;
        }
        size += i64(info.view(1)[0].ndim) * 8;
    }
    return PyLong_FromSsize_t(size);
}

def ctype_get_pointer_type(self_: ptr[PyObject], ignored: ptr) -> ptr[PyObject];

def ctype_set_pointer_type(
    self_: ptr[PyObject], tp: ptr[PyObject], ignored: ptr
) -> i32;

def CType_Type_repeat(self_: ptr[PyObject], length: i64) -> ptr[PyObject];

def StructUnionType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject];

def StructUnionType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], isStruct: i32
) -> i32;

def PyCStructType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

def UnionType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

impl CDataType_from_address_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if not long_check(value) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("integer expected"));
        return NULL;
    }
    buf = PyLong_AsVoidPtr(value);
    if PyErr_Occurred() {
        return NULL;
    }
    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    return PyCData_AtAddress(st, type, buf);
}

impl CDataType_from_buffer_impl(
    type: ptr[PyObject], cls: ptr[PyObject], obj_: ptr[PyObject], offset: i64
) -> ptr[PyObject] {
    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    (res, info) = PyStgInfo_FromType(st, type);
    if res < 0 {
        return NULL;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
        return NULL;
    }
    mv = PyMemoryView_FromObject(obj_);
    if not mv {
        return NULL;
    }
    buffer = ptr[Py_buffer](ptr[u8](mv) + PyMemoryViewObject_VIEW);
    if buffer.view(1)[0].readonly != 0 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("underlying buffer is not writable"));
        object_decref(mv);
        return NULL;
    }
    if PyBuffer_IsContiguous(buffer, 67) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("underlying buffer is not C contiguous")
        );
        object_decref(mv);
        return NULL;
    }
    if offset < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("offset cannot be negative"));
        object_decref(mv);
        return NULL;
    }
    buf_len = buffer.view(1)[0].length;
    if info.view(1)[0].size > buf_len - offset {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Buffer size too small (%zd instead of at least %zd bytes)"),
            buf_len,
            info.view(1)[0].size + offset
        );
        object_decref(mv);
        return NULL;
    }
    buf_addr = i64(int(buffer.view(1)[0].buf));
    if PySys_Audit(
        ptr[u8]("ctypes.cdata/buffer"), ptr[u8]("nnn"), buf_addr, buf_len, offset
    )
        < 0 {
        object_decref(mv);
        return NULL;
    }
    result = PyCData_AtAddress(st, type, ptr(ptr[u8](buffer.view(1)[0].buf) + offset));
    if not result {
        object_decref(mv);
        return NULL;
    }
    if KeepRef(ptr[CDataObject](result), -1, mv) == -1 {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl CDataType_from_buffer_copy_impl(
    type: ptr[PyObject], cls: ptr[PyObject], buffer: BufferArgument, offset: i64
) -> ptr[PyObject] {
    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    (res, info) = PyStgInfo_FromType(st, type);
    if res < 0 {
        return NULL;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
        return NULL;
    }
    if offset < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("offset cannot be negative"));
        return NULL;
    }
    view = buffer.view;
    buf_len = view.view(1)[0].length;
    if info.view(1)[0].size > buf_len - offset {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Buffer size too small (%zd instead of at least %zd bytes)"),
            buf_len,
            info.view(1)[0].size + offset
        );
        return NULL;
    }
    buf_addr = i64(int(view.view(1)[0].buf));
    if PySys_Audit(
        ptr[u8]("ctypes.cdata/buffer"), ptr[u8]("nnn"), buf_addr, buf_len, offset
    )
        < 0 {
        return NULL;
    }
    result = generic_pycdata_new(st, ptr[PyTypeObject](type), NULL, NULL);
    if result {
        memcpy(
            ptr(ptr[CDataObject](result).view(1)[0].b_ptr),
            ptr(ptr[u8](view.view(1)[0].buf) + offset),
            u64(info.view(1)[0].size)
        );
    }
    return result;
}

impl CDataType_in_dll_impl(
    type: ptr[PyObject], cls: ptr[PyObject], dll: ptr[PyObject], name: str
) -> ptr[PyObject] {
    name_obj = jacpy_unicode_from_text(name);
    if not name_obj {
        return NULL;
    }
    if PySys_Audit(ptr[u8]("ctypes.dlsym"), ptr[u8]("OO"), dll, name_obj) < 0 {
        object_decref(name_obj);
        return NULL;
    }
    obj_ = PyObject_GetAttrString(dll, ptr[u8]("_handle"));
    if not obj_ {
        object_decref(name_obj);
        return NULL;
    }
    if not long_check(obj_) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("the _handle attribute of the second argument must be an integer")
        );
        object_decref(obj_);
        object_decref(name_obj);
        return NULL;
    }
    handle = PyLong_AsVoidPtr(obj_);
    object_decref(obj_);
    if PyErr_Occurred() {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("could not convert the _handle attribute to a pointer")
        );
        object_decref(name_obj);
        return NULL;
    }

    dlerror();
    address = dlsym(handle, name);
    if address {
        object_decref(name_obj);
        st = get_module_state_by_def(object_type(type));
        return PyCData_AtAddress(st, type, address);
    }
    dlerr = dlerror();
    if dlerr {
        _PyErr_SetLocaleString(PyExc_ValueError, dlerr);
        object_decref(name_obj);
        return NULL;
    }
    PyErr_Format(PyExc_ValueError, ptr[u8]("symbol '%U' not found"), name_obj);
    object_decref(name_obj);
    return NULL;
}

impl CDataType_from_param_impl(
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
    if PyCArg_CheckExact(st, value) {
        p = ptr[PyCArgObject](value);
        ob = p.view(1)[0].obj_;
        (ires, info) = PyStgInfo_FromType(st, type);
        if ires < 0 {
            return NULL;
        }

        if info and ob {
            res = PyObject_IsInstance(ob, info.view(1)[0].proto);
            if res == -1 {
                return NULL;
            }
            if res != 0 {
                return object_new_ref(value);
            }
        }
        ob_name: ptr[u8] = ptr[u8]("???");
        if ob {
            ob_name = object_type(ob).view(1)[0].tp_name;
        }
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("expected %s instance instead of pointer to %s"),
            ptr[PyTypeObject](type).view(1)[0].tp_name,
            ob_name
        );
        return NULL;
    }
    as_parameter: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(value, py_id(_Py_ID__as_parameter_), &mut as_parameter)
        < 0 {
        return NULL;
    }
    if as_parameter {
        if Py_EnterRecursiveCall(ptr[u8](" while processing _as_parameter_")) != 0 {
            object_decref(as_parameter);
            return NULL;
        }
        result = CDataType_from_param_impl(type, cls, as_parameter);
        object_decref(as_parameter);
        Py_LeaveRecursiveCall();
        return result;
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("expected %s instance instead of %s"),
        ptr[PyTypeObject](type).view(1)[0].tp_name,
        object_type(value).view(1)[0].tp_name
    );
    return NULL;
}

def _structunion_setattro(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], is_struct: i32
) -> i32;

def PyCStructType_setattro(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def UnionType_setattro(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def PyCPointerType_SetProto(
    st: ptr[ctypes_state],
    self_: ptr[PyObject],
    stginfo: ptr[StgInfo],
    proto: ptr[PyObject]
) -> i32;

def PyCPointerType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject];

def PyCPointerType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

impl PyCPointerType_set_type_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    (res, info) = PyStgInfo_FromType(st, self_);
    if res < 0 {
        return NULL;
    }
    if not info {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
        return NULL;
    }
    if PyCPointerType_SetProto(st, self_, info, type) < 0 {
        return NULL;
    }
    if PyObject_SetAttr(self_, py_id(_Py_ID__type_), type) < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl PyCPointerType_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if value == Py_None {
        return object_new_ref(value);
    }
    st = get_module_state_by_class(ptr[PyTypeObject](cls));
    (res, typeinfo) = PyStgInfo_FromType(st, type);
    if res < 0 {
        return NULL;
    }
    if not typeinfo {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("abstract class"));
        return NULL;
    }

    if not typeinfo.view(1)[0].proto {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("cannot convert argument: POINTER _type_ type is not set")
        );
        return NULL;
    }
    inst = PyObject_IsInstance(value, typeinfo.view(1)[0].proto);
    if inst == 1 {
        object_incref(value);
        return _byref(st, value);
    }
    if inst == -1 {
        return NULL;
    }
    if PointerObject_Check(st, value) or ArrayObject_Check(st, value) {
        (vres, v) = PyStgInfo_FromObject(st, value);
        if vres < 0 {
            return NULL;
        }
        ret = PyObject_IsSubclass(v.view(1)[0].proto, typeinfo.view(1)[0].proto);
        if ret < 0 {
            return NULL;
        }
        if ret != 0 {
            return object_new_ref(value);
        }
    }
    return CDataType_from_param_impl(type, cls, value);
}

impl _ctypes_PyCArrayType_Type_raw_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not value {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("cannot delete attribute"));
        return -1;
    }
    cdata = ptr[CDataObject](self_);
    view = ptr[Py_buffer](PyMem_Calloc(1, u64(Py_buffer_SIZE)));
    if not view {
        PyErr_NoMemory();
        return -1;
    }
    if PyObject_GetBuffer(value, view, PyBUF_SIMPLE) < 0 {
        PyMem_Free(ptr(view));
        return -1;
    }
    size = view.view(1)[0].length;
    if size > cdata.view(1)[0].b_size {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("byte string too long"));
        PyBuffer_Release(view);
        PyMem_Free(ptr(view));
        return -1;
    }
    memcpy(ptr(cdata.view(1)[0].b_ptr), view.view(1)[0].buf, u64(size));
    PyBuffer_Release(view);
    PyMem_Free(ptr(view));
    return 0;
}

impl _ctypes_PyCArrayType_Type_raw_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    cdata = ptr[CDataObject](self_);
    return PyBytes_FromStringAndSize(cdata.view(1)[0].b_ptr, cdata.view(1)[0].b_size);
}

impl _ctypes_PyCArrayType_Type_value_get_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    cdata = ptr[CDataObject](self_);
    p = cdata.view(1)[0].b_ptr;
    b_size = cdata.view(1)[0].b_size;
    i: i64 = 0;
    while i < b_size {
        if (p + i).view(1)[0] == 0 {
            break;
        }
        i += 1;
    }
    return PyBytes_FromStringAndSize(p, i);
}

impl _ctypes_PyCArrayType_Type_value_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("can't delete attribute"));
        return -1;
    }
    if not bytes_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("bytes expected instead of %s instance"),
            object_type(value).view(1)[0].tp_name
        );
        return -1;
    }
    object_incref(value);
    cdata = ptr[CDataObject](self_);
    size = object_size(value);
    if size > cdata.view(1)[0].b_size {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("byte string too long"));
        object_decref(value);
        return -1;
    }
    memcpy(
        ptr(cdata.view(1)[0].b_ptr),
        ptr(ptr[u8](value) + PyBytesObject_OB_SVAL),
        u64(size)
    );
    if size < cdata.view(1)[0].b_size {
        (cdata.view(1)[0].b_ptr + size).view(1)[0] = 0;
    }
    object_decref(value);
    return 0;
}

def WCharArray_get_value_lock_held(op: ptr[PyObject]) -> ptr[PyObject];

def WCharArray_get_value(op: ptr[PyObject], ignored: ptr) -> ptr[PyObject];

def WCharArray_set_value_lock_held(op: ptr[PyObject], value: ptr[PyObject]) -> i32;

def WCharArray_set_value(op: ptr[PyObject], value: ptr[PyObject], ignored: ptr) -> i32;

def add_getset(type: ptr[PyTypeObject], gsp: ptr[PyGetSetDef]) -> i32;

def PyCArrayType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject];

def PyCArrayType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32;

impl _string_param(
    st: ptr[ctypes_state], fmt: ptr[u8], tag: u8, value: ptr[PyObject], size: i64
) -> ptr[PyObject] {
    fd = _ctypes_get_fielddesc(fmt);
    parg = PyCArgObject_new(st);
    if not parg {
        return NULL;
    }
    parg.view(1)[0].pffi_type = addressof(ffi_type_pointer);
    parg.view(1)[0].tag = tag;
    parg.view(1)[0].obj_ = call_setfunc(
        fd.view(1)[0].setfunc, ptr(carg_value_address(parg)), value, size
    );
    if not parg.view(1)[0].obj_ {
        object_decref(ptr[PyObject](parg));
        return NULL;
    }
    return ptr[PyObject](parg);
}

impl _points_at_fielddesc(
    st: ptr[ctypes_state], value: ptr[PyObject], fmt: ptr[u8]
) -> tuple[i32, bool] {
    wanted = int(_ctypes_get_fielddesc(fmt).view(1)[0].setfunc);
    if ArrayObject_Check(st, value) or PointerObject_Check(st, value) {
        (res, it) = PyStgInfo_FromObject(st, value);
        if res < 0 {
            return (i32(-1), False);
        }
        info = ptr[StgInfo]();
        if it and it.view(1)[0].proto {
            (pres, pinfo) = PyStgInfo_FromType(st, it.view(1)[0].proto);
            if pres < 0 {
                return (i32(-1), False);
            }
            info = pinfo;
        }
        if info and int(info.view(1)[0].setfunc) == wanted {
            return (i32(0), True);
        }
    }
    if PyCArg_CheckExact(st, value) {
        a = ptr[PyCArgObject](value);
        (ares, ainfo) = PyStgInfo_FromObject(st, a.view(1)[0].obj_);
        if ares < 0 {
            return (i32(-1), False);
        }
        if ainfo and int(ainfo.view(1)[0].setfunc) == wanted {
            return (i32(0), True);
        }
    }
    return (i32(0), False);
}

impl c_wchar_p_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if value == Py_None {
        return object_new_ref(Py_None);
    }
    st = get_module_state_by_class(ptr[PyTypeObject](cls).view(1)[0].tp_base);
    if unicode_check(value) {
        return _string_param(st, ptr[u8]("Z"), 90, value, 0);
    }
    res = PyObject_IsInstance(value, type);
    if res == -1 {
        return NULL;
    }
    if res != 0 {
        return object_new_ref(value);
    }

    (status, matched) = _points_at_fielddesc(st, value, ptr[u8]("u"));
    if status < 0 {
        return NULL;
    }
    if matched {
        return object_new_ref(value);
    }
    as_parameter: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(value, py_id(_Py_ID__as_parameter_), &mut as_parameter)
        < 0 {
        return NULL;
    }
    if as_parameter {
        if Py_EnterRecursiveCall(ptr[u8](" while processing _as_parameter_")) != 0 {
            object_decref(as_parameter);
            return NULL;
        }
        result = c_wchar_p_from_param_impl(type, cls, as_parameter);
        object_decref(as_parameter);
        Py_LeaveRecursiveCall();
        return result;
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("'%.200s' object cannot be interpreted as ctypes.c_wchar_p"),
        object_type(value).view(1)[0].tp_name
    );
    return NULL;
}

impl c_char_p_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if value == Py_None {
        return object_new_ref(Py_None);
    }
    st = get_module_state_by_class(ptr[PyTypeObject](cls).view(1)[0].tp_base);
    if bytes_check(value) {
        return _string_param(st, ptr[u8]("z"), 122, value, 0);
    }
    res = PyObject_IsInstance(value, type);
    if res == -1 {
        return NULL;
    }
    if res != 0 {
        return object_new_ref(value);
    }

    (status, matched) = _points_at_fielddesc(st, value, ptr[u8]("c"));
    if status < 0 {
        return NULL;
    }
    if matched {
        return object_new_ref(value);
    }
    as_parameter: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(value, py_id(_Py_ID__as_parameter_), &mut as_parameter)
        < 0 {
        return NULL;
    }
    if as_parameter {
        if Py_EnterRecursiveCall(ptr[u8](" while processing _as_parameter_")) != 0 {
            object_decref(as_parameter);
            return NULL;
        }
        result = c_char_p_from_param_impl(type, cls, as_parameter);
        object_decref(as_parameter);
        Py_LeaveRecursiveCall();
        return result;
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("'%.200s' object cannot be interpreted as ctypes.c_char_p"),
        object_type(value).view(1)[0].tp_name
    );
    return NULL;
}

impl c_void_p_from_param_impl(
    type: ptr[PyObject], cls: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if value == Py_None {
        return object_new_ref(Py_None);
    }
    st = get_module_state_by_class(ptr[PyTypeObject](cls).view(1)[0].tp_base);

    if long_check(value) {
        return _string_param(st, ptr[u8]("P"), 80, value, SIZEOF_VOID_P);
    }

    if bytes_check(value) {
        return _string_param(st, ptr[u8]("z"), 122, value, 0);
    }

    if unicode_check(value) {
        return _string_param(st, ptr[u8]("Z"), 90, value, 0);
    }

    res = PyObject_IsInstance(value, type);
    if res == -1 {
        return NULL;
    }
    if res != 0 {
        return object_new_ref(value);
    }

    if ArrayObject_Check(st, value) or PointerObject_Check(st, value) {
        return object_new_ref(value);
    }

    if PyCArg_CheckExact(st, value) {
        a = ptr[PyCArgObject](value);
        if a.view(1)[0].tag == 80 {
            return object_new_ref(value);
        }
    }

    if PyCFuncPtrObject_Check(st, value) {
        func = ptr[PyCFuncPtrObject](value);
        parg = PyCArgObject_new(st);
        if not parg {
            return NULL;
        }
        parg.view(1)[0].pffi_type = addressof(ffi_type_pointer);
        parg.view(1)[0].tag = 80;
        object_incref(value);

        ptr[ptr](carg_value_address(parg)).view(1)[0] = ptr[ptr](
            func.view(1)[0].b_ptr
        ).view(
            1
        )[0];
        parg.view(1)[0].obj_ = value;
        return ptr[PyObject](parg);
    }

    (sres, stgi) = PyStgInfo_FromObject(st, value);
    if sres < 0 {
        return NULL;
    }
    if stgi
        and CDataObject_Check(st, value)
        and stgi.view(1)[0].proto
        and unicode_check(stgi.view(1)[0].proto) {
        code = PyUnicode_AsUTF8(stgi.view(1)[0].proto).view(1)[0];
        if code == 122 or code == 90 {
            sparg = PyCArgObject_new(st);
            if not sparg {
                return NULL;
            }
            sparg.view(1)[0].pffi_type = addressof(ffi_type_pointer);
            sparg.view(1)[0].tag = 90;
            sparg.view(1)[0].obj_ = object_new_ref(value);

            ptr[ptr](carg_value_address(sparg)).view(1)[0] = ptr[ptr](
                ptr[CDataObject](value).view(1)[0].b_ptr
            ).view(
                1
            )[0];
            return ptr[PyObject](sparg);
        }
    }
    as_parameter: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(value, py_id(_Py_ID__as_parameter_), &mut as_parameter)
        < 0 {
        return NULL;
    }
    if as_parameter {
        if Py_EnterRecursiveCall(ptr[u8](" while processing _as_parameter_")) != 0 {
            object_decref(as_parameter);
            return NULL;
        }
        result = c_void_p_from_param_impl(type, cls, as_parameter);
        object_decref(as_parameter);
        Py_LeaveRecursiveCall();
        return result;
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("'%.200s' object cannot be interpreted as ctypes.c_void_p"),
        object_type(value).view(1)[0].tp_name
    );
    return NULL;
}

import from c {
    glob:priv dictremover_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(_DictRemover_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(_DictRemover_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(_DictRemover_clear)),
             PyType_Slot(slot=Py_tp_call, pfunc=ptr(_DictRemover_call)),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("deletes a key from a dictionary")
             ),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         structparam_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(StructParam_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(StructParam_clear)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(StructParam_dealloc)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         ctype_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__pointer_type__"),
                 get=ctype_get_pointer_type,
                 set=ctype_set_pointer_type,
                 doc=ptr[u8]("pointer type"),
                 closure=ptr()
             ),
             PyGetSetDef()
         ],
         WCharArray_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("value"),
                 get=WCharArray_get_value,
                 set=WCharArray_set_value,
                 doc=ptr[u8]("string value"),
                 closure=ptr()
             ),
             PyGetSetDef()
         ]; glob dictremover_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.DictRemover"),
             basicsize=32,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(dictremover_slots)
         ),
         structparam_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.StructParam_Type"),
             basicsize=32,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
             ),
             slots=addressof(structparam_slots)
         ),
         pyctype_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(CType_Type_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(CType_Type_clear)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(CType_Type_dealloc)),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(ctype_getsets))),
             PyType_Slot(slot=Py_sq_repeat, pfunc=ptr(CType_Type_repeat)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pyctype_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.CType_Type"),
             basicsize=i32(-SIZEOF_STGINFO),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
             ),
             slots=addressof(pyctype_type_slots)
         ),
         pycstruct_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_setattro, pfunc=ptr(PyCStructType_setattro)),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("metatype for the CData Objects")
             ),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(PyCStructType_init)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycstruct_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.PyCStructType"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycstruct_type_slots)
         ),
         union_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_setattro, pfunc=ptr(UnionType_setattro)),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("metatype for the Union Objects")
             ),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(UnionType_init)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         union_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.UnionType"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(union_type_slots)
         ),
         pycpointer_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("metatype for the Pointer Objects")
             ),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(PyCPointerType_init)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycpointer_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.PyCPointerType"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycpointer_type_slots)
         ),
         pycarray_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_doc, pfunc=ptr[u8]("metatype for the Array Objects")
             ),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(PyCArrayType_init)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         pycarray_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_ctypes.PyCArrayType"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(pycarray_type_slots)
         );
}

impl _DictRemover_traverse(myself: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = ptr[DictRemoverObject](myself);
    status = visit_reference(ptr[PyObject](object_type(myself)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_.view(1)[0].key, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_.view(1)[0].dct, visitor, arg);
    if status != 0 {
        return status;
    }
    return 0;
}

impl _DictRemover_clear(myself: ptr[PyObject]) -> i32 {
    self_ = ptr[DictRemoverObject](myself);
    old = self_.view(1)[0].key;
    self_.view(1)[0].key = NULL;
    object_xdecref(old);
    old = self_.view(1)[0].dct;
    self_.view(1)[0].dct = NULL;
    object_xdecref(old);
    return 0;
}

impl _DictRemover_dealloc(myself: ptr[PyObject]) {
    tp = object_type(myself);
    PyObject_GC_UnTrack(ptr(myself));
    _DictRemover_clear(myself);
    tp.view(1)[0].tp_free(ptr(myself));
    object_decref(ptr[PyObject](tp));
}

impl _DictRemover_call(
    myself: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[DictRemoverObject](myself);
    if self_.view(1)[0].key and self_.view(1)[0].dct {
        if PyDict_DelItem(self_.view(1)[0].dct, self_.view(1)[0].key) == -1 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while calling _ctypes.DictRemover")
            );
        }
        old = self_.view(1)[0].key;
        self_.view(1)[0].key = NULL;
        object_xdecref(old);
        old = self_.view(1)[0].dct;
        self_.view(1)[0].dct = NULL;
        object_xdecref(old);
    }
    return object_new_ref(Py_None);
}

impl StructParam_traverse(myself: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = ptr[StructParamObject](myself);
    status = visit_reference(ptr[PyObject](object_type(myself)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_.view(1)[0].keep, visitor, arg);
    if status != 0 {
        return status;
    }
    return 0;
}

impl StructParam_clear(myself: ptr[PyObject]) -> i32 {
    self_ = ptr[StructParamObject](myself);
    old = self_.view(1)[0].keep;
    self_.view(1)[0].keep = NULL;
    object_xdecref(old);
    return 0;
}

impl StructParam_dealloc(myself: ptr[PyObject]) {
    self_ = ptr[StructParamObject](myself);
    tp = object_type(myself);
    PyObject_GC_UnTrack(ptr(myself));
    StructParam_clear(myself);
    PyMem_Free(self_.view(1)[0].ptr_);
    tp.view(1)[0].tp_free(ptr(myself));
    object_decref(ptr[PyObject](tp));
}

impl CType_Type_traverse(self_: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    info = _PyStgInfo_FromType_NoState(self_);
    if not info {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while calling ctypes traverse function %R"),
            self_
        );
    }
    if info {
        status = visit_reference(info.view(1)[0].proto, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(info.view(1)[0].argtypes, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(info.view(1)[0].converters, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(info.view(1)[0].restype, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(info.view(1)[0].checker, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(info.view(1)[0].pointer_type, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(info.view(1)[0].module, visitor, arg);
        if status != 0 {
            return status;
        }
    }
    tstatus = visit_reference(ptr[PyObject](object_type(self_)), visitor, arg);
    if tstatus != 0 {
        return tstatus;
    }
    calls = ptr[CTypeTraverseCall](
        __thread_local_block("jac_ctypes_type_traverse_slot", 8)
    );
    calls.view(1)[0].call = int(addressof(PyType_Type).view(1)[0].tp_traverse);
    return calls.view(1)[0].call(self_, visitor, arg);
}

impl CType_Type_clear(self_: ptr[PyObject]) -> i32 {
    info = _PyStgInfo_FromType_NoState(self_);
    if not info {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while clearing ctypes %R"), self_
        );
    }
    if info {
        ctype_clear_stginfo(info);
    }
    return addressof(PyType_Type).view(1)[0].tp_clear(self_);
}

impl CType_Type_dealloc(self_: ptr[PyObject]) {
    info = _PyStgInfo_FromType_NoState(self_);
    if not info {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while deallocating ctypes %R"), self_
        );
    }
    if info {
        ctype_free_stginfo_members(info);
    }
    tp = object_type(self_);
    addressof(PyType_Type).view(1)[0].tp_dealloc(self_);
    object_decref(ptr[PyObject](tp));
}

impl ctype_get_pointer_type(self_: ptr[PyObject], ignored: ptr) -> ptr[PyObject] {
    st = get_module_state_by_def(object_type(self_));
    (res, info) = PyStgInfo_FromType(st, self_);
    if res < 0 {
        return NULL;
    }
    if not info {
        PyErr_Format(PyExc_TypeError, ptr[u8]("%R must have storage info"), self_);
        return NULL;
    }
    if info.view(1)[0].pointer_type {
        return object_new_ref(info.view(1)[0].pointer_type);
    }
    PyErr_Format(
        PyExc_AttributeError, ptr[u8]("%R has no attribute '__pointer_type__'"), self_
    );
    return NULL;
}

impl ctype_set_pointer_type(
    self_: ptr[PyObject], tp: ptr[PyObject], ignored: ptr
) -> i32 {
    st = get_module_state_by_def(object_type(self_));
    (res, info) = PyStgInfo_FromType(st, self_);
    if res < 0 {
        return -1;
    }
    if not info {
        PyErr_Format(PyExc_TypeError, ptr[u8]("%R must have storage info"), self_);
        return -1;
    }
    old = info.view(1)[0].pointer_type;
    info.view(1)[0].pointer_type = object_xnewref(tp);
    object_xdecref(old);
    return 0;
}

impl CType_Type_repeat(self_: ptr[PyObject], length: i64) -> ptr[PyObject] {
    if length < 0 {
        return PyErr_Format(
            PyExc_ValueError, ptr[u8]("Array length must be >= 0, not %zd"), length
        );
    }
    st = get_module_state_by_def(object_type(self_));
    return PyCArrayType_from_ctype(st, self_, length);
}

impl StructUnionType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject] {
    obj_: ptr[PyObject] = NULL;
    p: ptr = ptr();
    b_size = self_.view(1)[0].b_size;
    if b_size > SIZEOF_VOID_P or b_size < 0 {
        p = PyMem_Malloc(u64.wrap(b_size));
        if not p {
            return ptr[PyCArgObject]();
        }
        memcpy(p, ptr(self_.view(1)[0].b_ptr), u64.wrap(b_size));

        tp = st.view(1)[0].StructParam_Type;
        obj_ = tp.view(1)[0].tp_alloc(tp, 0);
        if not obj_ {
            PyMem_Free(p);
            return ptr[PyCArgObject]();
        }
        struct_param = ptr[StructParamObject](obj_);
        struct_param.view(1)[0].ptr_ = p;
        struct_param.view(1)[0].keep = object_new_ref(ptr[PyObject](self_));
    } else {
        p = ptr(self_.view(1)[0].b_ptr);
        obj_ = object_new_ref(ptr[PyObject](self_));
    }
    parg = PyCArgObject_new(st);
    if not parg {
        object_decref(obj_);
        return ptr[PyCArgObject]();
    }
    (res, stginfo) = PyStgInfo_FromObject(st, ptr[PyObject](self_));
    if res < 0 {
        object_decref(obj_);
        return ptr[PyCArgObject]();
    }
    parg.view(1)[0].tag = 86;
    parg.view(1)[0].pffi_type = stginfo_ffi_type(stginfo);
    ptr[ptr](carg_value_address(parg)).view(1)[0] = p;
    parg.view(1)[0].size = b_size;
    parg.view(1)[0].obj_ = obj_;
    return parg;
}

impl StructUnionType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], isStruct: i32
) -> i32 {
    attrdict = PyType_GetDict(self_);
    if not attrdict {
        return -1;
    }

    r = PyDict_Contains(attrdict, py_id(_Py_ID__abstract_));
    if r > 0 {
        object_decref(attrdict);
        return 0;
    }
    if r < 0 {
        object_decref(attrdict);
        return -1;
    }
    st = get_module_state_by_def(object_type(self_));
    info = PyStgInfo_Init(st, ptr[PyTypeObject](self_));
    if not info {
        object_decref(attrdict);
        return -1;
    }
    info.view(1)[0].format_ = _ctypes_alloc_format_string(ptr[u8](), ptr[u8]("B"));
    if not info.view(1)[0].format_ {
        object_decref(attrdict);
        return -1;
    }
    info.view(1)[0].paramfunc = ptr(StructUnionType_paramfunc);
    fields: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(attrdict, py_id(_Py_ID__fields_), &mut fields) < 0 {
        object_decref(attrdict);
        return -1;
    }
    object_decref(attrdict);
    if fields {
        if PyObject_SetAttr(self_, py_id(_Py_ID__fields_), fields) < 0 {
            object_decref(fields);
            return -1;
        }
        object_decref(fields);
        return 0;
    }
    (bres, baseinfo) = PyStgInfo_FromType(
        st, ptr[PyObject](ptr[PyTypeObject](self_).view(1)[0].tp_base)
    );
    if bres < 0 {
        return -1;
    }
    if not baseinfo {
        return 0;
    }

    ret = PyCStgInfo_clone(info, baseinfo);
    if ret >= 0 {
        stginfo_set_dict_final_lock_held(baseinfo);
    }
    return ret;
}

impl PyCStructType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    return StructUnionType_init(self_, args, kwds, 1);
}

impl UnionType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    return StructUnionType_init(self_, args, kwds, 0);
}

impl _structunion_setattro(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], is_struct: i32
) -> i32 {
    if unicode_check(key)
        and _PyUnicode_EqualToASCIIString(key, ptr[u8]("_fields_")) != 0 {
        if PyCStructUnionType_update_stginfo(self_, value, is_struct) < 0 {
            return -1;
        }
    }
    return addressof(PyType_Type).view(1)[0].tp_setattro(self_, key, value);
}

impl PyCStructType_setattro(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    return _structunion_setattro(self_, key, value, 1);
}

impl UnionType_setattro(
    self_: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    return _structunion_setattro(self_, key, value, 0);
}

impl PyCPointerType_SetProto(
    st: ptr[ctypes_state],
    self_: ptr[PyObject],
    stginfo: ptr[StgInfo],
    proto: ptr[PyObject]
) -> i32 {
    if not proto or not type_check(proto) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("_type_ must be a type"));
        return -1;
    }
    (res, info) = PyStgInfo_FromType(st, proto);
    if res < 0 {
        return -1;
    }
    if not info {
        PyErr_Format(PyExc_TypeError, ptr[u8]("%R must have storage info"), proto);
        return -1;
    }
    old = stginfo.view(1)[0].proto;
    stginfo.view(1)[0].proto = object_new_ref(proto);
    object_xdecref(old);
    if not info.view(1)[0].pointer_type {
        old = info.view(1)[0].pointer_type;
        info.view(1)[0].pointer_type = object_new_ref(self_);
        object_xdecref(old);
    }
    return 0;
}

impl PyCPointerType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject] {
    parg = PyCArgObject_new(st);
    if not parg {
        return ptr[PyCArgObject]();
    }
    parg.view(1)[0].tag = 80;
    parg.view(1)[0].pffi_type = addressof(ffi_type_pointer);
    parg.view(1)[0].obj_ = object_new_ref(ptr[PyObject](self_));
    ptr[ptr](carg_value_address(parg)).view(1)[0] = ptr[ptr](
        self_.view(1)[0].b_ptr
    ).view(
        1
    )[0];
    return parg;
}

impl PyCPointerType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    typedict = PyTuple_GetItem(args, 2);
    if not typedict {
        return -1;
    }

    st = get_module_state_by_def(object_type(self_));
    stginfo = PyStgInfo_Init(st, ptr[PyTypeObject](self_));
    if not stginfo {
        return -1;
    }
    stginfo.view(1)[0].size = SIZEOF_VOID_P;
    pdesc = _ctypes_get_fielddesc(ptr[u8]("P"));
    stginfo.view(1)[0].align = i64(pdesc.view(1)[0].pffi_type.view(1)[0].alignment);
    stginfo.view(1)[0].length = 1;
    memcpy(
        ptr(stginfo_ffi_type(stginfo)),
        ptr(addressof(ffi_type_pointer)),
        u64(SIZEOF_FFI_TYPE)
    );
    stginfo.view(1)[0].paramfunc = ptr(PyCPointerType_paramfunc);
    stginfo.view(1)[0].flags = stginfo.view(1)[0].flags | TYPEFLAG_ISPOINTER;
    proto: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(typedict, py_id(_Py_ID__type_), &mut proto) < 0 {
        return -1;
    }
    if proto {
        if PyCPointerType_SetProto(st, self_, stginfo, proto) < 0 {
            object_decref(proto);
            return -1;
        }
        (res, iteminfo) = PyStgInfo_FromType(st, proto);
        if res < 0 {
            object_decref(proto);
            return -1;
        }

        current_format: ptr[u8] = ptr[u8]("B");
        if iteminfo.view(1)[0].format_ {
            current_format = iteminfo.view(1)[0].format_;
        }
        if iteminfo.view(1)[0].shape {
            stginfo.view(1)[0].format_ = _ctypes_alloc_format_string_with_shape(
                iteminfo.view(1)[0].ndim,
                iteminfo.view(1)[0].shape,
                ptr[u8]("&"),
                current_format
            );
        } else {
            stginfo.view(1)[0].format_ = _ctypes_alloc_format_string(
                ptr[u8]("&"), current_format
            );
        }
        object_decref(proto);
        if not stginfo.view(1)[0].format_ {
            return -1;
        }
    }
    return 0;
}

impl WCharArray_get_value_lock_held(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = ptr[CDataObject](op);
    p = ptr[i32](self_.view(1)[0].b_ptr);
    count = self_.view(1)[0].b_size // SIZEOF_WCHAR_T;
    i: i64 = 0;
    while i < count {
        if (p + i).view(1)[0] == 0 {
            break;
        }
        i += 1;
    }
    return PyUnicode_FromWideChar(ptr[i32](self_.view(1)[0].b_ptr), i);
}

impl WCharArray_get_value(op: ptr[PyObject], ignored: ptr) -> ptr[PyObject] {
    return WCharArray_get_value_lock_held(op);
}

impl WCharArray_set_value_lock_held(op: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    self_ = ptr[CDataObject](op);
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("can't delete attribute"));
        return -1;
    }
    if not unicode_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("unicode string expected instead of %s instance"),
            object_type(value).view(1)[0].tp_name
        );
        return -1;
    }
    size = self_.view(1)[0].b_size // SIZEOF_WCHAR_T;

    length = PyUnicode_AsWideChar(value, ptr[i32](), 0);
    if length < 0 {
        return -1;
    }
    if length - 1 > size {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("string too long"));
        return -1;
    }
    rc = PyUnicode_AsWideChar(value, ptr[i32](self_.view(1)[0].b_ptr), size);
    if rc < 0 {
        return -1;
    }
    return 0;
}

impl WCharArray_set_value(
    op: ptr[PyObject], value: ptr[PyObject], ignored: ptr
) -> i32 {
    return WCharArray_set_value_lock_held(op, value);
}

impl add_getset(type: ptr[PyTypeObject], gsp: ptr[PyGetSetDef]) -> i32 {
    dct = type.view(1)[0].tp_dict;
    cur = gsp;
    while cur.view(1)[0].name {
        descr = PyDescr_NewGetSet(type, cur);
        if not descr {
            return -1;
        }
        if PyDict_SetItemString(dct, cur.view(1)[0].name, descr) < 0 {
            object_decref(descr);
            return -1;
        }
        object_decref(descr);
        cur = cur + 1;
    }
    return 0;
}

impl PyCArrayType_paramfunc(
    st: ptr[ctypes_state], self_: ptr[CDataObject]
) -> ptr[PyCArgObject] {
    p = PyCArgObject_new(st);
    if not p {
        return ptr[PyCArgObject]();
    }
    p.view(1)[0].tag = 80;
    p.view(1)[0].pffi_type = addressof(ffi_type_pointer);
    ptr[ptr](carg_value_address(p)).view(1)[0] = ptr(self_.view(1)[0].b_ptr);
    p.view(1)[0].obj_ = object_new_ref(ptr[PyObject](self_));
    return p;
}

impl PyCArrayType_init(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    length_attr: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID__length_), &mut length_attr) < 0 {
        return -1;
    }
    if not length_attr {
        PyErr_SetString(
            PyExc_AttributeError, ptr[u8]("class must define a '_length_' attribute")
        );
        return -1;
    }
    if not long_check(length_attr) {
        object_decref(length_attr);
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("The '_length_' attribute must be an integer")
        );
        return -1;
    }
    if long_is_negative(length_attr) {
        object_decref(length_attr);
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("The '_length_' attribute must not be negative")
        );
        return -1;
    }
    length = PyLong_AsSsize_t(length_attr);
    object_decref(length_attr);
    if length == -1 and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
            PyErr_SetString(
                PyExc_OverflowError, ptr[u8]("The '_length_' attribute is too large")
            );
        }
        return -1;
    }
    type_attr: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID__type_), &mut type_attr) < 0 {
        return -1;
    }
    if not type_attr {
        PyErr_SetString(
            PyExc_AttributeError, ptr[u8]("class must define a '_type_' attribute")
        );
        return -1;
    }
    st = get_module_state_by_def(object_type(self_));
    stginfo = PyStgInfo_Init(st, ptr[PyTypeObject](self_));
    if not stginfo {
        object_decref(type_attr);
        return -1;
    }
    (res, iteminfo) = PyStgInfo_FromType(st, type_attr);
    if res < 0 {
        object_decref(type_attr);
        return -1;
    }
    if not iteminfo {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("_type_ must have storage info"));
        object_decref(type_attr);
        return -1;
    }
    stginfo.view(1)[0].format_ = _ctypes_alloc_format_string(
        ptr[u8](), iteminfo.view(1)[0].format_
    );
    if not stginfo.view(1)[0].format_ {
        object_decref(type_attr);
        return -1;
    }
    ndim = iteminfo.view(1)[0].ndim + 1;
    stginfo.view(1)[0].ndim = ndim;
    shape = ptr[i64](PyMem_Malloc(u64(8 * i64(ndim))));
    stginfo.view(1)[0].shape = shape;
    if not shape {
        PyErr_NoMemory();
        object_decref(type_attr);
        return -1;
    }
    shape.view(1)[0] = length;
    if ndim > 1 {
        memmove(ptr(shape + 1), ptr(iteminfo.view(1)[0].shape), u64(8 * i64(ndim - 1)));
    }
    itemsize = iteminfo.view(1)[0].size;
    if itemsize != 0 and length > PY_SSIZE_T_MAX // itemsize {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("array too large"));
        object_decref(type_attr);
        return -1;
    }
    itemalign = iteminfo.view(1)[0].align;
    if (iteminfo.view(1)[0].flags & (TYPEFLAG_ISPOINTER | TYPEFLAG_HASPOINTER)) != 0 {
        stginfo.view(1)[0].flags = stginfo.view(1)[0].flags | TYPEFLAG_HASPOINTER;
    }
    stginfo.view(1)[0].size = itemsize * length;
    stginfo.view(1)[0].align = itemalign;
    stginfo.view(1)[0].length = length;

    stginfo.view(1)[0].proto = type_attr;
    stginfo.view(1)[0].paramfunc = ptr(PyCArrayType_paramfunc);

    memcpy(
        ptr(stginfo_ffi_type(stginfo)),
        ptr(addressof(ffi_type_pointer)),
        u64(SIZEOF_FFI_TYPE)
    );

    item_getfunc = int(iteminfo.view(1)[0].getfunc);
    cdesc = _ctypes_get_fielddesc(ptr[u8]("c"));
    udesc = _ctypes_get_fielddesc(ptr[u8]("u"));
    if item_getfunc == int(cdesc.view(1)[0].getfunc) {
        char_getsets = addressof(ctypes_clinic_tables).view(1)[0].CharArray_getsets;
        if add_getset(ptr[PyTypeObject](self_), char_getsets) == -1 {
            return -1;
        }
    } elif item_getfunc == int(udesc.view(1)[0].getfunc) {
        wchar_getsets = ptr[PyGetSetDef](addressof(WCharArray_getsets));
        if add_getset(ptr[PyTypeObject](self_), wchar_getsets) == -1 {
            return -1;
        }
    }
    return 0;
}
