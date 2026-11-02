import from c {
    def Py_EnterRecursiveCall(where: ptr[u8]) -> i32;  def _PyOS_URandomNonblock(
        buffer: ptr, size: i64
    ) -> i32;  def getpid -> i32;  def fileno(stream: ptr) -> i32;  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        o: ptr[PyObject],
        buf: ptr,
        len: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def PyUnicode_DecodeUTF8(
        s: ptr[u8], size: i64, errors: ptr[u8]
    ) -> ptr[PyObject];  def PyNumber_InPlacePower(
        v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
    ) -> ptr[PyObject];  def PyNumber_Power(
        v: ptr[PyObject], w: ptr[PyObject], z: ptr[PyObject]
    ) -> ptr[PyObject];  def PyUnicode_Split(
        s: ptr[PyObject], sep: ptr[PyObject], maxsplit: i64
    ) -> ptr[PyObject];  def CRYPTO_memcmp(a: ptr, b: ptr, size: u64) -> i32;  def PyThread_allocate_lock -> ptr;  def PyThread_acquire_lock_timed(
        lock: ptr, microseconds: i64, intr_flag: i32
    ) -> i32;  def _PyTime_AsMicroseconds(t: i64, round: i32) -> i64;  def PyEval_SaveThread -> ptr[
        PyThreadState
    ];  def PyType_GetFullyQualifiedName(type: ptr[PyTypeObject]) -> ptr[PyObject];  def PyByteArray_FromStringAndSize(
        bytes_: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyComplex_AsCComplex(op: ptr[PyObject]) -> Py_complex;  def PyComplex_FromCComplex(
        cval: Py_complex
    ) -> ptr[PyObject];  def PyFloat_Pack2(x: f64, data: ptr[u8], le: i32) -> i32;  def PyFloat_Pack4(
        x: f64, data: ptr[u8], le: i32
    ) -> i32;  def PyFloat_Pack8(x: f64, data: ptr[u8], le: i32) -> i32;  def PyFloat_Unpack2(
        data: ptr[u8], le: i32
    ) -> f64;  def PyFloat_Unpack4(data: ptr[u8], le: i32) -> f64;  def PyFloat_Unpack8(
        data: ptr[u8], le: i32
    ) -> f64;  def _PyLong_Lshift(a: ptr[PyObject], shiftby: i64) -> ptr[PyObject];  def _PyLong_Rshift(
        a: ptr[PyObject], shiftby: i64
    ) -> ptr[PyObject];  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: ptr[ptr[PyObject]]
    ) -> i32;  def PyUnicode_InternInPlace(p: ptr[ptr[PyObject]]);  def PySlice_Unpack(
        slice: ptr[PyObject], start: ptr[i64], stop: ptr[i64], step: ptr[i64]
    ) -> i32;  def PySlice_AdjustIndices(
        length: i64, start: ptr[i64], stop: ptr[i64], step: i64
    ) -> i64;  def PyEval_GetBuiltins -> ptr[PyObject];  def PyStructSequence_NewType(
        desc: ptr[PyStructSequence_Desc]
    ) -> ptr[PyObject];  def _PyLong_UnsignedLong_Converter(
        obj_: ptr[PyObject], ptr_: ptr
    ) -> i32;  def PyLong_AsVoidPtr(vv: ptr[PyObject]) -> ptr;  def _PyDict_DelItemIf(
        op: ptr[PyObject], key: ptr[PyObject], predicate: ptr, arg: ptr
    ) -> i32;  def _PyEval_StopTheWorld(interp: ptr[u8]);  def _PyEval_StartTheWorld(
        interp: ptr[u8]
    );  def PyThread_get_thread_native_id -> u64;  def PyObject_GET_WEAKREFS_LISTPTR(
        op: ptr[PyObject]
    ) -> ptr[ptr[PyObject]];  def PyList_Append(
        lst: ptr[PyObject], item: ptr[PyObject]
    ) -> i32;  def PyList_New(size: i64) -> ptr[PyObject];  def _Py_FatalErrorFunc(
        func: ptr[u8], message: ptr[u8]
    );  def _PyUnicode_InternStatic(interp: ptr[u8], p: ptr[ptr[PyObject]]);  def PyUnicode_EqualToUTF8(
        op: ptr[PyObject], text: ptr[u8]
    ) -> i32;  def PyUnicodeWriter_WriteASCII(
        writer: ptr[PyUnicodeWriter], text: ptr[u8], size: i64
    ) -> i32;  def PyObject_GetAttrString(
        op: ptr[PyObject], name: ptr[u8]
    ) -> ptr[PyObject];  def PyObject_SetAttrString(
        op: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32;  def PyModule_AddObjectRef(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32;  def PyModule_Add(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32;  def PyModule_AddIntConstant(
        mod: ptr[PyObject], name: ptr[u8], value: i64
    ) -> i32;  def PyModule_AddStringConstant(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[u8]
    ) -> i32;  def PySys_AuditTuple(event: ptr[u8], args: ptr[PyObject]) -> i32;  def strdup(
        text: ptr[u8]
    ) -> ptr[u8];  def strchr(text: ptr[u8], ch: i32) -> ptr[u8];  def strtok_r(
        text: ptr[u8], delim: ptr[u8], rest: ptr[ptr[u8]]
    ) -> ptr[u8];  def calloc(count: u64, size: u64) -> ptr;  def free(p: ptr);  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memmove(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def dlopen(path: ptr[u8], mode: i32) -> ptr;  def dlsym(
        handle: ptr, name: ptr[u8]
    ) -> ptr;  def log(x: f64) -> f64;  def log2(x: f64) -> f64;  def log10(
        x: f64
    ) -> f64;  def exp(x: f64) -> f64;  def exp2(x: f64) -> f64;  def sin(
        x: f64
    ) -> f64;  def cos(x: f64) -> f64;  def tan(x: f64) -> f64;  def fma(
        x: f64, y: f64, z: f64
    ) -> f64;  def __jac_errno -> ptr[i32];  def __jac_stdio(fd: i32) -> ptr;  def __jac_opendir(
        path: ptr[u8]
    ) -> ptr;  def __jac_readdir(directory: ptr) -> ptr;  def __jac_closedir(
        directory: ptr
    ) -> i32;  def __jac_dirent_name(dirent_entry: ptr) -> ptr[u8];  def __jac_dirent_type(
        dirent_entry: ptr
    ) -> i64;  def __jac_dirent_ino(dirent_entry: ptr) -> u64;  def __jac_dirfd(
        directory: ptr
    ) -> i32;  def __jac_fdopendir(fd: i32) -> ptr;  def __jac_rewinddir(
        directory: ptr
    );  def __jac_stat_record(path: ptr[u8], status: ptr) -> i32;  def __jac_lstat_record(
        path: ptr[u8], status: ptr
    ) -> i32;  def __jac_fstat_record(fd: i32, status: ptr) -> i32;  def __jac_fstatat_record(
        dir_fd: i32, path: ptr[u8], status: ptr, flags: i32
    ) -> i32;  def __jac_statfs_record(path: ptr[u8], buffer: ptr) -> i32;  def __jac_fstatfs_record(
        fd: i32, buffer: ptr
    ) -> i32;  def __jac_cpuid(leaf: u32, subleaf: u32, out: ptr[u32]);  def __jac_system_log(
        type: i32, text: ptr[u8]
    );  def PyImport_ImportModule(name: ptr[u8]) -> ptr[PyObject];  def PyCFunction_NewEx(
        method: ptr[PyMethodDef], receiver: ptr[PyObject], module: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_CallMethod(
        obj_: ptr[PyObject], name: ptr[u8], format: ptr[u8], *args: any
    ) -> ptr[PyObject];  def _PyErr_Print(tstate: ptr[PyThreadState]);  obj LibmTable {
        has log: Callable[[f64], f64],
            log2: Callable[[f64], f64],
            log10: Callable[[f64], f64],
            exp: Callable[[f64], f64],
            exp2: Callable[[f64], f64],
            sin: Callable[[f64], f64],
            cos: Callable[[f64], f64],
            tan: Callable[[f64], f64],
            fma: Callable[[f64, f64, f64], f64];
    }  glob:priv libm_table: LibmTable = LibmTable(),
         libm_ready: i64 = 0,
         apple_log_write_method: PyMethodDef = PyMethodDef(
             ml_name=ptr[u8]("apple_log_write"),
             ml_meth=ptr(apple_log_write_impl),
             ml_flags=1,
             ml_doc=ptr[u8]()
         );
}

glob:priv PYBUF_SIMPLE: Final[i32] = 0,
     WAIT_LOCK: Final[i32] = 1,
     NOWAIT_LOCK: Final[i32] = 0,
     PY_LOCK_ACQUIRED: Final[i32] = 1,
     PY_LOCK_INTR: Final[i32] = 2,
     ROUND_CEILING: Final[i32] = 1,
     PY_LT: Final[i32] = 0,
     ERRNO_EDOM: Final[i32] = 33,
     ERRNO_ERANGE: Final[i32] = 34,
     ASNATIVEBYTES_NATIVE_ENDIAN: Final[i32] = 3,
     ASNATIVEBYTES_UNSIGNED_BUFFER: Final[i32] = 4,
     RTLD_LAZY: Final[i32] = 1,
     LINUX_RTLD_NOLOAD: Final[i32] = 4,
     DARWIN_RTLD_NOLOAD: Final[i32] = 16,
     MAX_SCRIPT_PATH_SIZE: Final[u64] = u64(512);

def items_of_list(lst: ptr[PyObject]) -> ptr[ptr[PyObject]];

def items_of_tuple(tup: ptr[PyObject]) -> ptr[ptr[PyObject]];

def bytes_payload(op: ptr[PyObject]) -> ptr[u8];

def bytearray_payload(op: ptr[PyObject]) -> ptr[u8];

def has_flag(op: ptr[PyObject], flag: u64) -> i64;

def is_exactly(op: ptr[PyObject], type: ptr[PyObject]) -> i64;

def errno_slot -> ptr[i32];

def binary_buffer(value: ptr[PyObject], view: ptr[Py_buffer]) -> bool;

def ascii_buffer(value: ptr[PyObject], view: ptr[Py_buffer]) -> bool;

def text_buffer(value: ptr[PyObject], view: ptr[Py_buffer]) -> bool;

def libm_resolve(system: ptr, name: ptr[u8], fallback: ptr) -> int;

def libm -> ptr[LibmTable];

def dead_weakref(value: ptr[PyObject], unused: ptr) -> i32;

def weakref_check(op: ptr[PyObject]) -> bool;

def weakref_is_dead(op: ptr[PyObject]) -> bool;

def try_incref(op: ptr[PyObject]) -> bool;

def thread_impl(tstate: ptr[PyThreadState]) -> ptr[u8];

def asyncio_add_list(
    head: ptr[llist_node], tasks: ptr[PyObject], node_offset: i64
) -> i64;

def interp_runtime(interp: ptr[u8]) -> ptr[u8];

def interp_first_thread(interp: ptr[u8]) -> ptr[u8];

def thread_next(tstate: ptr[u8]) -> ptr[u8];

def apple_log_write_impl(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def static_strings_end -> i64;

import from c {
    def jacpy_sequence_slot(handle: ptr[PyObject]) -> ptr {
        type = object_type(handle);
        seq = type.view(1)[0].tp_as_sequence;
        if seq and int(seq.view(1)[0].sq_item) != 0 {
            return ptr(int(seq.view(1)[0].sq_item));
        }
        mapping = type.view(1)[0].tp_as_mapping;
        if mapping and int(mapping.view(1)[0].mp_subscript) != 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("%.200s is not a sequence"),
                type.view(1)[0].tp_name
            );
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%.200s' object does not support indexing"),
                type.view(1)[0].tp_name
            );
        }
        return ptr();
    }  def jacpy_less(left: ptr[PyObject], right: ptr[PyObject]) -> i64 {
        return i64(PyObject_RichCompareBool(left, right, PY_LT));
    }  def jacpy_recursion_enter(context: ptr[u8]) -> i64 {
        if Py_EnterRecursiveCall(context) != 0 {
            return -1;
        }
        return 0;
    }  def jacpy_list_size(handle: ptr[PyObject]) -> i64 {
        return object_size(handle);
    }  def jacpy_list_delete(handle: ptr[PyObject], start: i64, end: i64) -> i64 {
        return i64(PyList_SetSlice(handle, start, end, NULL));
    }  def jacpy_list_exchange(
        handle: ptr[PyObject], index: i64, value: ptr[PyObject]
    ) -> ptr[PyObject] {
        old = PyList_GetItem(handle, index);
        if not old {
            return NULL;
        }
        object_incref(value);
        (items_of_list(handle) + index).view(1)[0] = value;
        return old;
    }  def jacpy_list_swap(handle: ptr[PyObject], left: i64, right: i64) {
        items = items_of_list(handle);
        a = (items + left).view(1)[0];
        (items + left).view(1)[0] = (items + right).view(1)[0];
        (items + right).view(1)[0] = a;
    }  def jacpy_comparison_slot(handle: ptr[PyObject]) -> ptr {
        return ptr(int(object_type(handle).view(1)[0].tp_richcompare));
    }  def jacpy_same_type(left: ptr[PyObject], right: ptr[PyObject]) -> i64 {
        return 1 if object_type(left) == object_type(right) else 0;
    }  def jacpy_is_long(handle: ptr[PyObject]) -> i64 {
        return has_flag(handle, Py_TPFLAGS_LONG_SUBCLASS);
    }  def jacpy_long_absolute(handle: ptr[PyObject]) -> ptr[PyObject] {
        type = ptr[PyTypeObject](addressof(PyLong_Type));
        return type.view(1)[0].tp_as_number.view(1)[0].nb_absolute(handle);
    }  def jacpy_hash_unsigned(handle: ptr[PyObject]) -> ptr[PyObject] {
        value = PyObject_Hash(handle);
        if value == -1 {
            return NULL;
        }
        return PyLong_FromSize_t(u64.wrap(value));
    }  def jacpy_long_bytes(handle: ptr[PyObject], size: i64) -> ptr[PyObject] {
        result = PyBytes_FromStringAndSize(ptr[u8](), size);
        if not result {
            return NULL;
        }
        if _PyLong_AsByteArray(handle, bytes_payload(result), u64(size), 1, 0, 1) < 0 {
            object_decref(result);
            return NULL;
        }
        return result;
    }  def jacpy_long_from_bytes(handle: ptr[PyObject]) -> ptr[PyObject] {
        return _PyLong_FromByteArray(
            bytes_payload(handle), u64(object_size(handle)), 1, 0
        );
    }  def jacpy_entropy(size: i64) -> ptr[PyObject] {
        result = PyBytes_FromStringAndSize(ptr[u8](), size);
        if not result {
            return NULL;
        }
        if _PyOS_URandomNonblock(ptr(bytes_payload(result)), size) < 0 {
            object_decref(result);
            return NULL;
        }
        return result;
    }  def jacpy_wall_time -> i64 {
        value: i64 = 0;
        if PyTime_Time(&mut value) < 0 {
            return -1;
        }
        return value;
    }  def jacpy_monotonic_time -> i64 {
        value: i64 = 0;
        if PyTime_Monotonic(&mut value) < 0 {
            return -1;
        }
        return value;
    }  def jacpy_process_id -> i64 {
        return i64(getpid());
    }  def jacpy_is_tuple(handle: ptr[PyObject]) -> i64 {
        return has_flag(handle, Py_TPFLAGS_TUPLE_SUBCLASS);
    }  def jacpy_tuple_item(handle: ptr[PyObject], index: i64) -> ptr[PyObject] {
        item = PyTuple_GetItem(handle, index);
        if item {
            object_incref(item);
        }
        return item;
    }  def jacpy_tuple_items(handle: ptr[PyObject]) -> ptr[ptr[PyObject]] {
        return items_of_tuple(handle);
    }  def jacpy_tuple_set_owned(
        handle: ptr[PyObject], index: i64, value: ptr[PyObject]
    ) -> i64 {
        if not value {
            return -1;
        }
        return i64(PyTuple_SetItem(handle, index, value));
    }  def jacpy_buffer_bytes(view: ptr[Py_buffer]) -> ptr[PyObject] {
        owner = view.view(1)[0].owner;
        if object_is_type(owner, ptr[PyTypeObject](addressof(PyBytes_Type)))
            and int(view.view(1)[0].buf) == int(bytes_payload(owner))
            and view.view(1)[0].length == object_size(owner) {
            return object_new_ref(owner);
        }
        return PyBytes_FromStringAndSize(
            ptr[u8](view.view(1)[0].buf), view.view(1)[0].length
        );
    }  def jacpy_buffer_acquire(value: ptr[PyObject], kind: i64) -> ptr[Py_buffer] {
        view = ptr[Py_buffer](PyMem_Calloc(u64(1), u64(Py_buffer_SIZE)));
        if not view {
            PyErr_NoMemory();
            return ptr[Py_buffer]();
        }
        ok = False;
        if kind == 2 {
            ok = text_buffer(value, view);
        } elif kind == 1 {
            ok = ascii_buffer(value, view);
        } else {
            ok = binary_buffer(value, view);
        }
        if not ok {
            PyMem_Free(ptr(view));
            return ptr[Py_buffer]();
        }
        return view;
    }  def jacpy_buffer_release(value: ptr[Py_buffer]) {
        if not value {
            return;
        }
        PyBuffer_Release(value);
        PyMem_Free(ptr(value));
    }  def jacpy_unicode_ascii(value: ptr[PyObject]) -> i64 {
        return 1 if uo_is_ascii(value) else 0;
    }  def jacpy_set_exception(type_: ptr[PyObject], message: ptr[u8], size: i64) {
        text = PyUnicode_DecodeUTF8(message, size, ptr[u8]("surrogatepass"));
        if text {
            PyErr_SetObject(type_, text);
            object_decref(text);
        }
    }  def jacpy_power(
        a: ptr[PyObject], b: ptr[PyObject], inplace: i64
    ) -> ptr[PyObject] {
        if inplace != 0 {
            return PyNumber_InPlacePower(a, b, Py_None);
        }
        return PyNumber_Power(a, b, Py_None);
    }  def jacpy_is_unicode(a: ptr[PyObject]) -> i64 {
        return has_flag(a, Py_TPFLAGS_UNICODE_SUBCLASS);
    }  def jacpy_unicode_split(a: ptr[PyObject], sep: ptr[PyObject]) -> ptr[PyObject] {
        return PyUnicode_Split(a, sep, -1);
    }  def jacpy_dict_size(a: ptr[PyObject]) -> i64 {
        if a {
            return PyDict_Size(a);
        }
        return 0;
    }  def jacpy_crypto_compare(a: ptr, b: ptr, size: i64) -> i64 {
        return i64(CRYPTO_memcmp(a, b, u64(size)));
    }  def jacpy_lock_new -> ptr {
        lock = PyThread_allocate_lock();
        if not lock {
            PyErr_NoMemory();
            return ptr();
        }
        PyThread_acquire_lock(lock, WAIT_LOCK);
        return lock;
    }  def jacpy_lock_free(handle: ptr) {
        PyThread_acquire_lock(handle, NOWAIT_LOCK);
        PyThread_release_lock(handle);
        PyThread_free_lock(handle);
    }  def jacpy_lock_wait(handle: ptr, timeout_ns: i64) -> i64 {
        timeout_us: i64 = -1;
        if timeout_ns >= 0 {
            timeout_us = _PyTime_AsMicroseconds(timeout_ns, ROUND_CEILING);
        }
        saved = PyEval_SaveThread();
        status = PyThread_acquire_lock_timed(handle, timeout_us, 1);
        PyEval_RestoreThread(saved);
        if status == PY_LOCK_ACQUIRED {
            return 1;
        }
        if status == PY_LOCK_INTR {
            return -1;
        }
        return 0;
    }  def jacpy_timeout_ns(value: ptr[PyObject]) -> i64 {
        timeout: i64 = 0;
        if _PyTime_FromSecondsObject(&mut timeout, value, ROUND_CEILING) < 0 {
            return -1;
        }
        return timeout;
    }  def jacpy_writer_new -> ptr[PyUnicodeWriter] {
        return PyUnicodeWriter_Create(0);
    }  def jacpy_unicode_size(text: ptr[PyObject]) -> i64 {
        return uo_length(text);
    }  def jacpy_unicode_kind(text: ptr[PyObject]) -> i64 {
        return uo_kind(text);
    }  def jacpy_unicode_data(text: ptr[PyObject]) -> ptr {
        return ptr(uo_data(text));
    }  def jacpy_unicode_decode_bytes(
        value: ptr[PyObject], encoding: ptr[u8]
    ) -> ptr[PyObject] {
        return PyUnicode_FromEncodedObject(value, encoding, ptr[u8]("strict"));
    }  def jacpy_dict_default(
        dictionary: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> ptr[PyObject] {
        result = NULL;
        if PyDict_SetDefaultRef(dictionary, key, value, &mut result) < 0 {
            return NULL;
        }
        return result;
    }  def jacpy_is_bool(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyBool_Type));
    }  def jacpy_is_float(value: ptr[PyObject]) -> i64 {
        return 1
            if object_type_check(value, ptr[PyTypeObject](addressof(PyFloat_Type)))
            else 0;
    }  def jacpy_is_dict(value: ptr[PyObject]) -> i64 {
        return has_flag(value, Py_TPFLAGS_DICT_SUBCLASS);
    }  def jacpy_is_exact_dict(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyDict_Type));
    }  def jacpy_long_repr(value: ptr[PyObject]) -> ptr[PyObject] {
        return ptr[PyTypeObject](addressof(PyLong_Type)).view(1)[0].tp_repr(value);
    }  def jacpy_float_repr(value: ptr[PyObject]) -> ptr[PyObject] {
        return ptr[PyTypeObject](addressof(PyFloat_Type)).view(1)[0].tp_repr(value);
    }  def jacpy_type_name(value: ptr[PyObject]) -> ptr[PyObject] {
        return PyUnicode_FromString(object_type(value).view(1)[0].tp_name);
    }  def jacpy_qualified_type_name(value: ptr[PyObject]) -> ptr[PyObject] {
        return PyType_GetFullyQualifiedName(object_type(value));
    }  def jacpy_fast_size(value: ptr[PyObject]) -> i64 {
        return object_size(value);
    }  def jacpy_fast_item(value: ptr[PyObject], index: i64) -> ptr[PyObject] {
        return object_new_ref((fast_items(value) + index).view(1)[0]);
    }  def jacpy_is_exact_long(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyLong_Type));
    }  def jacpy_type_check(value: ptr[PyObject], type_: ptr[PyObject]) -> i64 {
        return 1 if object_type_check(value, ptr[PyTypeObject](type_)) else 0;
    }  def jacpy_dict_get(
        dictionary: ptr[PyObject], key: ptr[PyObject]
    ) -> ptr[PyObject] {
        value = NULL;
        if PyDict_GetItemRef(dictionary, key, &mut value) < 0 {
            return NULL;
        }
        return value;
    }  def jacpy_dict_pop_discard(
        dictionary: ptr[PyObject], key: ptr[PyObject]
    ) -> i64 {
        return i64(PyDict_Pop(dictionary, key, None));
    }  def jacpy_native_size(kind: i64, alignment: i64) -> i64 {
        if kind == 0 or kind == 7 {
            return 1;
        }
        if kind == 1 {
            return 2;
        }
        if kind == 2 or kind == 8 {
            return 4;
        }
        if kind >= 3 and kind <= 9 {
            return 8;
        }
        return 0;
    }  def jacpy_native_little_endian -> i64 {
        return 1;
    }  def jacpy_char_max -> i64 {
        return CHAR_MAX;
    }  def jacpy_memory_zero(address: ptr, size: i64) {
        memset(address, 0, u64(size));
    }  def jacpy_memory_copy(target: ptr, source: ptr, size: i64) {
        memcpy(target, source, u64(size));
    }  def jacpy_memory_move(target: ptr, source: ptr, size: i64) {
        memmove(target, source, u64(size));
    }  def jacpy_bytearray_new(size: i64) -> ptr[PyObject] {
        return PyByteArray_FromStringAndSize(ptr[u8](), size);
    }  def jacpy_bytearray_memory(value: ptr[PyObject]) -> i64 {
        type = ptr[PyTypeObject](addressof(PyByteArray_Type));
        return type.view(1)[0].tp_basicsize
            + ptr[PyByteArrayObject](value).view(1)[0].ob_alloc;
    }  def jacpy_float32_bits(value: f64) -> u64 {
        slot = __alloca(8);
        ptr[f32](slot).view(1)[0] = f32(value);
        return u64(ptr[u32](slot).view(1)[0]);
    }  def jacpy_bytes_from_memory(address: ptr, size: i64) -> ptr[PyObject] {
        return PyBytes_FromStringAndSize(ptr[u8](address), size);
    }  def jacpy_bytes_from_payload(data: ptr[u8], size: i64) -> ptr[PyObject] {
        return PyBytes_FromStringAndSize(data, size);
    }  def jacpy_is_bytes(value: ptr[PyObject]) -> i64 {
        return has_flag(value, Py_TPFLAGS_BYTES_SUBCLASS);
    }  def jacpy_is_bytearray(value: ptr[PyObject]) -> i64 {
        return 1
            if object_type_check(value, ptr[PyTypeObject](addressof(PyByteArray_Type)))
            else 0;
    }  def jacpy_bytes_address(value: ptr[PyObject]) -> ptr {
        if type_has_feature(object_type(value), Py_TPFLAGS_BYTES_SUBCLASS) {
            return ptr(bytes_payload(value));
        }
        return ptr(bytearray_payload(value));
    }  def jacpy_bytes_length(value: ptr[PyObject]) -> i64 {
        return object_size(value);
    }  def jacpy_bytes_copy_to(value: ptr[PyObject], target: ptr[u8], size: i64) {
        memcpy(ptr(target), jacpy_bytes_address(value), u64(size));
    }  def jacpy_complex_value(value: ptr[PyObject]) -> ptr[PyObject] {
        number = PyComplex_AsCComplex(value);
        if PyErr_Occurred() {
            return NULL;
        }
        return PyComplex_FromCComplex(number);
    }  def jacpy_float_pack(value: f64, address: ptr, size: i64, little: i64) -> i64 {
        target = ptr[u8](address);
        if size == 2 {
            return i64(PyFloat_Pack2(value, target, i32(little)));
        }
        if size == 4 {
            return i64(PyFloat_Pack4(value, target, i32(little)));
        }
        return i64(PyFloat_Pack8(value, target, i32(little)));
    }  def jacpy_float_unpack(address: ptr, size: i64, little: i64) -> f64 {
        source = ptr[u8](address);
        if size == 2 {
            return PyFloat_Unpack2(source, i32(little));
        }
        if size == 4 {
            return PyFloat_Unpack4(source, i32(little));
        }
        return PyFloat_Unpack8(source, i32(little));
    }  def jacpy_native_float_store(value: f64, address: ptr, size: i64) {
        if size == 4 {
            ptr[f32](address).view(1)[0] = f32(value);
        } else {
            ptr[f64](address).view(1)[0] = value;
        }
    }  def jacpy_clear_errno {
        errno_slot().view(1)[0] = 0;
    }  def jacpy_math_errno -> i64 {
        code = errno_slot().view(1)[0];
        if code == ERRNO_EDOM {
            return 1;
        }
        if code == ERRNO_ERANGE {
            return 2;
        }
        return 0;
    }  def jacpy_libm_log(value: f64) -> f64 {
        return libm().view(1)[0].log(value);
    }  def jacpy_libm_log2(value: f64) -> f64 {
        return libm().view(1)[0].log2(value);
    }  def jacpy_libm_log10(value: f64) -> f64 {
        return libm().view(1)[0].log10(value);
    }  def jacpy_libm_exp(value: f64) -> f64 {
        return libm().view(1)[0].exp(value);
    }  def jacpy_libm_exp2(value: f64) -> f64 {
        return libm().view(1)[0].exp2(value);
    }  def jacpy_libm_sin(value: f64) -> f64 {
        return libm().view(1)[0].sin(value);
    }  def jacpy_libm_cos(value: f64) -> f64 {
        return libm().view(1)[0].cos(value);
    }  def jacpy_libm_tan(value: f64) -> f64 {
        return libm().view(1)[0].tan(value);
    }  def jacpy_libm_fma(x: f64, y: f64, z: f64) -> f64 {
        return libm().view(1)[0].fma(x, y, z);
    }  def jacpy_dict_repr(value: ptr[PyObject]) -> ptr[PyObject] {
        return ptr[PyTypeObject](addressof(PyDict_Type)).view(1)[0].tp_repr(value);
    }  def jacpy_long_sign(value: ptr[PyObject]) -> i64 {
        sign = ptr[u64](ptr[u8](value) + PyLongObject_TAG).view(1)[0]
            & _PyLong_SIGN_MASK;
        if sign == u64(2) {
            return -1;
        }
        if sign == u64(1) {
            return 0;
        }
        return 1;
    }  def jacpy_long_shift(
        value: ptr[PyObject], count: i64, left: i64
    ) -> ptr[PyObject] {
        if left != 0 {
            return _PyLong_Lshift(value, count);
        }
        return _PyLong_Rshift(value, count);
    }  def jacpy_special_noargs(value: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject] {
        key = PyUnicode_InternFromString(name);
        if not key {
            return NULL;
        }
        method = _PyObject_LookupSpecial(value, key);
        object_decref(key);
        if not method {
            return NULL;
        }
        result = PyObject_CallNoArgs(method);
        object_decref(method);
        return result;
    }  def jacpy_float_bits(value: f64) -> u64 {
        slot = __alloca(8);
        ptr[f64](slot).view(1)[0] = value;
        return ptr[u64](slot).view(1)[0];
    }  def jacpy_float_from_bits(bits: u64) -> f64 {
        slot = __alloca(8);
        ptr[u64](slot).view(1)[0] = bits;
        return ptr[f64](slot).view(1)[0];
    }  def jacpy_is_exact_float(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyFloat_Type));
    }  def jacpy_long_fits_i64(value: ptr[PyObject]) -> i64 {
        overflow: i32 = 0;
        PyLong_AsLongLongAndOverflow(value, &mut overflow);
        return 1 if overflow == 0 else 0;
    }  def jacpy_call_two(
        callable_: ptr[PyObject], a: ptr[PyObject], b: ptr[PyObject]
    ) -> ptr[PyObject] {
        args = ptr[ptr[PyObject]](__alloca(16));
        args.view(1)[0] = a;
        (args + 1).view(1)[0] = b;
        return PyObject_Vectorcall(callable_, args, u64(2), NULL);
    }  def jacpy_object_type(value: ptr[PyObject]) -> ptr[PyObject] {
        return object_new_ref(ptr[PyObject](object_type(value)));
    }  def jacpy_is_exact_unicode(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyUnicode_Type));
    }  def jacpy_is_exact_tuple(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyTuple_Type));
    }  def jacpy_is_exact_list(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyList_Type));
    }  def jacpy_tuple_unique(value: ptr[PyObject]) -> i64 {
        return 1 if object_refcount(value) == 1 else 0;
    }  def jacpy_tuple_exchange(
        value: ptr[PyObject], index: i64, item: ptr[PyObject]
    ) -> ptr[PyObject] {
        slot = items_of_tuple(value) + index;
        old = slot.view(1)[0];
        object_incref(item);
        slot.view(1)[0] = item;
        if not object_gc_is_tracked(value) {
            object_gc_track(value);
        }
        return old;
    }  def jacpy_long_signed_bytes(value: ptr[PyObject], size: i64) -> ptr[PyObject] {
        result = PyBytes_FromStringAndSize(ptr[u8](), size);
        if not result {
            return NULL;
        }
        if _PyLong_AsByteArray(value, bytes_payload(result), u64(size), 1, 1, 1) < 0 {
            object_decref(result);
            return NULL;
        }
        return result;
    }  def jacpy_long_from_signed_bytes(value: ptr[PyObject]) -> ptr[PyObject] {
        return _PyLong_FromByteArray(
            bytes_payload(value), u64(object_size(value)), 1, 1
        );
    }  def jacpy_bytes_decode(
        value: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject] {
        return PyUnicode_Decode(
            bytes_payload(value), object_size(value), encoding, errors
        );
    }  def jacpy_optional_attr(value: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject] {
        result = NULL;
        if PyObject_GetOptionalAttrString(value, name, &mut result) < 0 {
            return NULL;
        }
        return result;
    }  def jacpy_type_new(
        type_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not type_has_feature(object_type(type_), Py_TPFLAGS_TYPE_SUBCLASS) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("NEWOBJ class argument must be a type")
            );
            return NULL;
        }
        if not type_has_feature(object_type(args), Py_TPFLAGS_TUPLE_SUBCLASS) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("NEWOBJ args argument must be a tuple")
            );
            return NULL;
        }
        if kwargs
            and not type_has_feature(object_type(kwargs), Py_TPFLAGS_DICT_SUBCLASS) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("NEWOBJ_EX kwargs argument must be a dict")
            );
            return NULL;
        }
        cls = ptr[PyTypeObject](type_);
        if int(cls.view(1)[0].tp_new) == 0 {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("NEWOBJ class has no __new__"));
            return NULL;
        }
        return cls.view(1)[0].tp_new(cls, args, kwargs);
    }  def jacpy_set_new(iterable: ptr[PyObject], frozen: i64) -> ptr[PyObject] {
        if frozen != 0 {
            return PyFrozenSet_New(iterable);
        }
        return PySet_New(iterable);
    }  def jacpy_is_type(value: ptr[PyObject]) -> i64 {
        return has_flag(value, Py_TPFLAGS_TYPE_SUBCLASS);
    }  def jacpy_bytes_unescape(value: ptr[PyObject]) -> ptr[PyObject] {
        return PyBytes_DecodeEscape(
            ptr(bytes_payload(value)),
            object_size(value),
            ptr[u8]("strict"),
            0,
            ptr[u8]()
        );
    }  def jacpy_mapping_optional_item(
        mapping: ptr[PyObject], key: ptr[PyObject]
    ) -> ptr[PyObject] {
        slot = ptr[ptr[PyObject]](__alloca(8));
        slot.view(1)[0] = NULL;
        if PyMapping_GetOptionalItem(mapping, key, slot) < 0 {
            return NULL;
        }
        return slot.view(1)[0];
    }  def jacpy_exception_context(error: ptr[PyObject], cause: ptr[PyObject]) {
        PyException_SetContext(error, object_new_ref(cause));
    }  def jacpy_unicode_intern(value: ptr[PyObject]) -> ptr[PyObject] {
        slot = ptr[ptr[PyObject]](__alloca(8));
        slot.view(1)[0] = object_new_ref(value);
        PyUnicode_InternInPlace(slot);
        return slot.view(1)[0];
    }  def jacpy_is_slice(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PySlice_Type));
    }  def jacpy_is_code(value: ptr[PyObject]) -> i64 {
        return is_exactly(value, addressof(PyCode_Type));
    }  def jacpy_slice_unpack(value: ptr[PyObject]) -> SliceBounds {
        bounds = ptr[i64](__alloca(24));
        if PySlice_Unpack(value, bounds, bounds + 1, bounds + 2) == 0 {
            return SliceBounds(
                start=bounds.view(1)[0],
                stop=(bounds + 1).view(1)[0],
                step=(bounds + 2).view(1)[0],
                count=0,
                valid=1
            );
        }
        return SliceBounds(start=0, stop=0, step=0, count=0, valid=0);
    }  def jacpy_slice_adjust(length: i64, bounds: SliceBounds) -> SliceBounds {
        ends = ptr[i64](__alloca(16));
        ends.view(1)[0] = bounds.start;
        (ends + 1).view(1)[0] = bounds.stop;
        count = PySlice_AdjustIndices(length, ends, ends + 1, bounds.step);
        return SliceBounds(
            start=ends.view(1)[0],
            stop=(ends + 1).view(1)[0],
            step=bounds.step,
            count=count,
            valid=bounds.valid
        );
    }  def jacpy_builtins -> ptr[PyObject] {
        return object_new_ref(PyEval_GetBuiltins());
    }  def jacpy_fs_text(text: ptr) -> ptr[PyObject] {
        if text {
            return PyUnicode_DecodeFSDefault(text);
        }
        return object_new_ref(Py_None);
    }  def jacpy_cfunction_method(function: ptr[PyObject]) -> ptr[PyMethodDef] {
        return ptr[PyCFunctionObject](function).view(1)[0].m_ml;
    }  def jacpy_cfunction_self(function: ptr[PyObject]) -> ptr[PyObject] {
        return ptr[PyCFunctionObject](function).view(1)[0].m_self;
    }  def jacpy_cfunction_module(function: ptr[PyObject]) -> ptr[PyObject] {
        return ptr[PyCFunctionObject](function).view(1)[0].m_module;
    }  def jacpy_struct_sequence_type(
        name: ptr[u8], doc: ptr[u8], fields: ptr[u8], visible: i64
    ) -> ptr[PyObject] {
        count: u64 = u64(1);
        cursor = fields;
        while cursor.view(1)[0] != u8(0) {
            if cursor.view(1)[0] == u8(10) {
                count += u64(1);
            }
            cursor = cursor + 1;
        }
        names = strdup(fields);
        owned_name = strdup(name);
        owned_doc = strdup(doc);
        table = ptr[PyStructSequence_Field](
            calloc(count + u64(1), u64(PyStructSequence_Field_SIZE))
        );
        desc = ptr[PyStructSequence_Desc](
            calloc(u64(1), u64(PyStructSequence_Desc_SIZE))
        );
        if not names or not owned_name or not owned_doc or not table or not desc {
            free(ptr(names));
            free(ptr(owned_name));
            free(ptr(owned_doc));
            free(ptr(table));
            free(ptr(desc));
            return PyErr_NoMemory();
        }
        index: i64 = 0;
        rest = ptr[ptr[u8]](__alloca(8));
        rest.view(1)[0] = ptr[u8]();
        line = strtok_r(names, ptr[u8]("\n"), rest);
        while line {
            tab = strchr(line, 9);
            field_doc = ptr[u8]();
            if tab {
                tab.view(1)[0] = u8(0);
                if (tab + 1).view(1)[0] != u8(0) {
                    field_doc = tab + 1;
                }
            }
            dirent_entry = table + index;
            dirent_entry.view(1)[0].name = line;
            dirent_entry.view(1)[0].doc = field_doc;
            index += 1;
            line = strtok_r(ptr[u8](), ptr[u8]("\n"), rest);
        }
        desc.view(1)[0].name = owned_name;
        desc.view(1)[0].doc = owned_doc if owned_doc.view(1)[0] != u8(0) else ptr[u8]();
        desc.view(1)[0].fields = table;
        desc.view(1)[0].n_in_sequence = i32(visible);
        return PyStructSequence_NewType(desc);
    }  def jacpy_typing_types -> ptr[ptr[PyObject]] {
        return ptr[ptr[PyObject]](
            current_interp() + PyInterpreterState_CACHED_GENERIC_TYPE
        );
    }  def jacpy_open_code_hook -> ptr[ptr] {
        return ptr[ptr](
            ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_OPEN_CODE_HOOK
        );
    }  def jacpy_open_code_userdata -> ptr[ptr] {
        return ptr[ptr](
            ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_OPEN_CODE_USERDATA
        );
    }  def jacpy_stdio_fileno(stream: i32) -> i32 {
        return fileno(__jac_stdio(stream));
    }  def jacpy_stdio_stream(stream: i32) -> ptr {
        return __jac_stdio(stream);
    }  def jacpy_weakref_list(object_: ptr[PyObject]) -> ptr[PyObject] {
        result = PyList_New(0);
        if not result or object_type(object_).view(1)[0].tp_weaklistoffset == 0 {
            return result;
        }
        current = ptr[PyWeakReference](
            PyObject_GET_WEAKREFS_LISTPTR(object_).view(1)[0]
        );
        while current {
            item = ptr[PyObject](current);
            if try_incref(item) {
                failed = PyList_Append(result, item);
                object_decref(item);
                if failed != 0 {
                    object_decref(result);
                    return NULL;
                }
            }
            current = current.view(1)[0].wr_next;
        }
        return result;
    }  def jacpy_remove_dead_weakref(
        dictionary: ptr[PyObject], key: ptr[PyObject]
    ) -> i64 {
        return i64(_PyDict_DelItemIf(dictionary, key, ptr(dead_weakref), ptr()));
    }  def jacpy_asyncio_running_loop -> ptr[ptr[PyObject]] {
        return ptr[ptr[PyObject]](
            thread_impl(current_tstate()) + _PyThreadStateImpl_ASYNCIO_RUNNING_LOOP
        );
    }  def jacpy_asyncio_running_task -> ptr[ptr[PyObject]] {
        return ptr[ptr[PyObject]](
            thread_impl(current_tstate()) + _PyThreadStateImpl_ASYNCIO_RUNNING_TASK
        );
    }  def jacpy_asyncio_tasks_head -> ptr {
        return ptr(
            thread_impl(current_tstate()) + _PyThreadStateImpl_ASYNCIO_TASKS_HEAD
        );
    }  def jacpy_asyncio_thread_task(loop: ptr[PyObject]) -> ptr[PyObject] {
        ret = Py_None;
        interp = current_interp();
        _PyEval_StopTheWorld(interp);
        head_lock(interp_runtime(interp));
        p = interp_first_thread(interp);
        while p {
            running = ptr[ptr[PyObject]](
                p + _PyThreadStateImpl_ASYNCIO_RUNNING_LOOP
            ).view(
                1
            )[0];
            if running == loop {
                task = ptr[ptr[PyObject]](
                    p + _PyThreadStateImpl_ASYNCIO_RUNNING_TASK
                ).view(
                    1
                )[0];
                if task {
                    ret = task;
                }
                break;
            }
            p = thread_next(p);
        }
        head_unlock(interp_runtime(interp));
        object_incref(ret);
        _PyEval_StartTheWorld(interp);
        return ret;
    }  def jacpy_asyncio_add_tasks(
        tasks: ptr[PyObject], node_offset: i64, all_threads: i64
    ) -> i64 {
        if all_threads == 0 {
            return asyncio_add_list(
                ptr[llist_node](
                    thread_impl(current_tstate())
                        + _PyThreadStateImpl_ASYNCIO_TASKS_HEAD
                ),
                tasks,
                node_offset
            );
        }
        interp = current_interp();
        _PyEval_StopTheWorld(interp);
        ret = asyncio_add_list(
            ptr[llist_node](interp + PyInterpreterState_ASYNCIO_TASKS_HEAD),
            tasks,
            node_offset
        );
        if ret == 0 {
            head_lock(interp_runtime(interp));
            p = interp_first_thread(interp);
            while p {
                if asyncio_add_list(
                    ptr[llist_node](p + _PyThreadStateImpl_ASYNCIO_TASKS_HEAD),
                    tasks,
                    node_offset
                )
                    < 0 {
                    ret = -1;
                    break;
                }
                p = thread_next(p);
            }
            head_unlock(interp_runtime(interp));
        }
        _PyEval_StartTheWorld(interp);
        return ret;
    }  def jacpy_errno -> i64 {
        return i64(errno_slot().view(1)[0]);
    }  def jacpy_set_errno(value: i64) {
        errno_slot().view(1)[0] = i32.wrap(value);
    }  def jacpy_opendir(path: ptr) -> ptr {
        return __jac_opendir(ptr[u8](path));
    }  def jacpy_readdir_name(directory: ptr) -> ptr[u8] {
        dirent_entry = __jac_readdir(directory);
        if not dirent_entry {
            return ptr[u8]();
        }
        return __jac_dirent_name(dirent_entry);
    }  def jacpy_dirfd(directory: ptr) -> i32 {
        return __jac_dirfd(directory);
    }  def jacpy_closedir(directory: ptr) -> i32 {
        return __jac_closedir(directory);
    }  def jacpy_fdopendir(fd: i32) -> ptr {
        return __jac_fdopendir(fd);
    }  def jacpy_rewinddir(directory: ptr) {
        __jac_rewinddir(directory);
    }  def jacpy_readdir_entry(
        directory: ptr, type_: ptr[i64], inode: ptr[u64]
    ) -> ptr[u8] {
        dirent_entry = __jac_readdir(directory);
        if not dirent_entry {
            return ptr[u8]();
        }
        type_.view(1)[0] = __jac_dirent_type(dirent_entry);
        inode.view(1)[0] = __jac_dirent_ino(dirent_entry);
        return __jac_dirent_name(dirent_entry);
    }  def jacpy_stat(path: ptr[u8], status: ptr) -> i32 {
        return __jac_stat_record(path, status);
    }  def jacpy_lstat(path: ptr[u8], status: ptr) -> i32 {
        return __jac_lstat_record(path, status);
    }  def jacpy_fstat(fd: i32, status: ptr) -> i32 {
        return __jac_fstat_record(fd, status);
    }  def jacpy_fstatat(dir_fd: i32, path: ptr[u8], status: ptr, flags: i32) -> i32 {
        return __jac_fstatat_record(dir_fd, path, status, flags);
    }  def jacpy_statfs(path: ptr[u8], buffer: ptr) -> i32 {
        return __jac_statfs_record(path, buffer);
    }  def jacpy_fstatfs(fd: i32, buffer: ptr) -> i32 {
        return __jac_fstatfs_record(fd, buffer);
    }  def jacpy_fork_callbacks(
        interp: ptr[PyInterpreterState], which: i64
    ) -> ptr[ptr[PyObject]] {
        base = ptr[u8](interp);
        if which == 0 {
            return ptr[ptr[PyObject]](base + PyInterpreterState_BEFORE_FORKERS);
        }
        if which == 1 {
            return ptr[ptr[PyObject]](base + PyInterpreterState_AFTER_FORKERS_PARENT);
        }
        return ptr[ptr[PyObject]](base + PyInterpreterState_AFTER_FORKERS_CHILD);
    }  def jacpy_runtime_head_lock {
        head_lock(ptr[u8](addressof(_PyRuntime)));
    }  def jacpy_runtime_head_unlock {
        head_unlock(ptr[u8](addressof(_PyRuntime)));
    }  def jacpy_thread_state_native_id(tstate: ptr[PyThreadState]) {
        ptr[u64](ptr[u8](tstate) + PyThreadState_NATIVE_THREAD_ID).view(1)[0] = PyThread_get_thread_native_id();
    }  def jacpy_thread_state_fork_reset(tstate: ptr[PyThreadState]) {
        base = ptr[u8](tstate);
        ptr[i32](base + PyThreadState_REMOTE_DEBUGGER_PENDING_CALL).view(1)[0] = 0;
        memset(
            ptr(base + PyThreadState_REMOTE_DEBUGGER_SCRIPT_PATH),
            0,
            MAX_SCRIPT_PATH_SIZE
        );
        head = ptr[llist_node](base + _PyThreadStateImpl_ASYNCIO_TASKS_HEAD);
        head.view(1)[0].next = head;
        head.view(1)[0].prev = head;
        ptr[ptr[PyObject]](base + _PyThreadStateImpl_ASYNCIO_RUNNING_LOOP).view(1)[0] = NULL;
        ptr[ptr[PyObject]](base + _PyThreadStateImpl_ASYNCIO_RUNNING_TASK).view(1)[0] = NULL;
    }  def jacpy_interpreter_finalizing -> i64 {
        finalizing = __atomic_load_i64(
            int(current_interp() + PyInterpreterState_FINALIZING), 5
        );
        return 1 if finalizing != 0 else 0;
    }  def jacpy_long_u64_checked(value: ptr[PyObject], out: ptr[u64]) -> i64 {
        bytes_needed = PyLong_AsNativeBytes(
            value,
            ptr(out),
            8,
            ASNATIVEBYTES_NATIVE_ENDIAN | ASNATIVEBYTES_UNSIGNED_BUFFER
        );
        if bytes_needed < 0 {
            return -1;
        }
        return 1 if bytes_needed > 8 else 0;
    }  def jacpy_unsigned_converter(
        value: ptr[PyObject], out: ptr[u64], long_long: i64
    ) -> i64 {
        if long_long != 0 {
            return i64(_PyLong_UnsignedLongLong_Converter(value, ptr(out)));
        }
        result = ptr[u64](__alloca(8));
        result.view(1)[0] = u64(0);
        ok = _PyLong_UnsignedLong_Converter(value, ptr(result));
        out.view(1)[0] = result.view(1)[0];
        return i64(ok);
    }  def jacpy_long_address(value: ptr[PyObject]) -> u64 {
        return u64(int(PyLong_AsVoidPtr(value)));
    }  def jacpy_hacl_simd_features -> i64 {
        if SYS_ARCH_X86_64 == 0 {
            return 0;
        }
        regs = ptr[u32](__alloca(32));
        __jac_cpuid(u32(1), u32(0), regs);
        __jac_cpuid(u32(7), u32(0), regs + 4);
        ecx1 = (regs + 2).view(1)[0];
        edx1 = (regs + 3).view(1)[0];
        ebx7 = (regs + 5).view(1)[0];
        features: i64 = 0;
        if (edx1 & u32(1 << 25)) != u32(0)
            and (edx1 & u32(1 << 26)) != u32(0)
            and (ecx1 & u32(1)) != u32(0)
            and (ecx1 & u32(1 << 19)) != u32(0)
            and (ecx1 & u32(1 << 20)) != u32(0)
            and (edx1 & u32(1 << 15)) != u32(0) {
            features = features | 1;
        }
        if (ecx1 & u32(1 << 28)) != u32(0) and (ebx7 & u32(1 << 5)) != u32(0) {
            features = features | 2;
        }
        return features;
    }  def jacpy_unicode_init_static_strings(interp: ptr[PyInterpreterState]) {
        runtime = ptr[u8](addressof(_PyRuntime));
        slot = ptr[ptr[PyObject]](__alloca(8));
        offset = _PyRuntimeState_GLOBAL_STRINGS;
        end = static_strings_end();
        while offset < end {
            string = ptr[PyObject](runtime + offset);
            length = uo_length(string);
            if length > 0 {
                slot.view(1)[0] = string;
                _PyUnicode_InternStatic(ptr[u8](interp), slot);
            }
            offset += (PyASCIIObject_SIZE + length + 1 + 7) & ~i64(7);
        }
    }  def jacpy_unicode_from_text(text: ptr[u8]) -> ptr[PyObject] {
        return PyUnicode_FromString(text);
    }  def jacpy_unicode_intern_text(text: ptr[u8]) -> ptr[PyObject] {
        return PyUnicode_InternFromString(text);
    }  def jacpy_unicode_equal_text(op: ptr[PyObject], text: ptr[u8]) -> i32 {
        return PyUnicode_EqualToUTF8(op, text);
    }  def jacpy_unicode_writer_write_text(
        writer: ptr[PyUnicodeWriter], text: ptr[u8], size: i64
    ) -> i32 {
        return PyUnicodeWriter_WriteASCII(writer, text, size);
    }  def jacpy_object_getattr_text(
        op: ptr[PyObject], name: ptr[u8]
    ) -> ptr[PyObject] {
        return PyObject_GetAttrString(op, name);
    }  def jacpy_object_setattr_text(
        op: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32 {
        return PyObject_SetAttrString(op, name, value);
    }  def jacpy_object_getoptionalattr_text(
        op: ptr[PyObject], name: ptr[u8], result: ptr[ptr[PyObject]]
    ) -> i32 {
        found = NULL;
        status = PyObject_GetOptionalAttrString(op, name, &mut found);
        result.view(1)[0] = found;
        return status;
    }  def jacpy_module_add_object_ref_text(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32 {
        return PyModule_AddObjectRef(mod, name, value);
    }  def jacpy_module_add_text(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32 {
        return PyModule_Add(mod, name, value);
    }  def jacpy_module_add_int_text(
        mod: ptr[PyObject], name: ptr[u8], value: i64
    ) -> i32 {
        return PyModule_AddIntConstant(mod, name, value);
    }  def jacpy_module_add_string_text(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[u8]
    ) -> i32 {
        return PyModule_AddStringConstant(mod, name, value);
    }  def jacpy_arg_parse_sized_text(
        arg: ptr[PyObject], format: ptr[u8], data: ptr[ptr[u8]], size: ptr[i64]
    ) -> i32 {
        return PyArg_Parse(arg, format, data, size);
    }  def jacpy_audit_tuple_text(event: ptr[u8], args: ptr[PyObject]) -> i32 {
        return PySys_AuditTuple(event, args);
    }  def jacpy_atexit_callbacks(
        interp: ptr[PyInterpreterState]
    ) -> ptr[ptr[PyObject]] {
        return ptr[ptr[PyObject]](
            ptr[u8](interp) + PyInterpreterState_ATEXIT_CALLBACKS
        );
    }  def jacpy_atexit_push(
        interp: ptr[PyInterpreterState], func: ptr, data: ptr
    ) -> i32 {
        if not current_tstate() {
            _Py_FatalErrorFunc(
                ptr[u8]("jacpy_atexit_push"),
                ptr[u8](
                    "the function must be called with the GIL held, after Python initialization and before Python finalization, but the GIL is released (the current Python thread state is NULL)"
                )
            );
        }
        callback = ptr[atexit_callback](PyMem_Malloc(u64(24)));
        if not callback {
            PyErr_NoMemory();
            return i32(-1);
        }
        head = ptr[ptr[atexit_callback]](
            ptr[u8](interp) + PyInterpreterState_ATEXIT_LL_CALLBACKS
        );
        callback.view(1)[0].func = int(func);
        callback.view(1)[0].data = data;
        callback.view(1)[0].next = head.view(1)[0];
        head.view(1)[0] = callback;
        return i32(0);
    }  def jacpy_atexit_detach(
        interp: ptr[PyInterpreterState]
    ) -> ptr[atexit_callback] {
        head = ptr[ptr[atexit_callback]](
            ptr[u8](interp) + PyInterpreterState_ATEXIT_LL_CALLBACKS
        );
        first = head.view(1)[0];
        head.view(1)[0] = ptr[atexit_callback]();
        return first;
    }  def jacpy_apple_streams(tstate: ptr[PyThreadState]) -> PyStatus {
        ok = PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
        if MI_PLATFORM_LINUX != 0 {
            return ok;
        }
        interp = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
        config = interp + PyInterpreterState_CONFIG;
        if ptr[i32](config + PyConfig_USE_SYSTEM_LOGGER).view(1)[0] == 0 {
            return ok;
        }
        support = PyImport_ImportModule(ptr[u8]("_apple_support"));
        writer = NULL;
        result = NULL;
        if support {
            writer = PyCFunction_NewEx(addressof(apple_log_write_method), NULL, NULL);
            if writer {
                result = PyObject_CallMethod(
                    support,
                    ptr[u8]("init_streams"),
                    ptr[u8]("Oii"),
                    writer,
                    i32(0),
                    i32(16)
                );
            }
        }
        status = ok;
        if not result {
            _PyErr_Print(tstate);
            status = PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("jacpy_apple_streams"),
                err_msg=ptr[u8]("failed to initialize Apple log streams"),
                exitcode=0
            );
        }
        object_xdecref(result);
        object_xdecref(writer);
        object_xdecref(support);
        return status;
    }  def jacpy_stack_address(slots: ptr) -> i64 {
        return int(slots);
    }  def jacpy_va_list(va: VaList) -> VaList {
        return va;
    }
}

impl items_of_list(lst: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[PyListObject](lst).view(1)[0].ob_item;
}

impl items_of_tuple(tup: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](tup) + PyTupleObject_ITEMS);
}

impl bytes_payload(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PyBytesObject_OB_SVAL;
}

impl bytearray_payload(op: ptr[PyObject]) -> ptr[u8] {
    if object_size(op) != 0 {
        return ptr[PyByteArrayObject](op).view(1)[0].ob_start;
    }
    return ptr[u8](addressof(_PyByteArray_empty_string));
}

impl has_flag(op: ptr[PyObject], flag: u64) -> i64 {
    return 1 if type_has_feature(object_type(op), flag) else 0;
}

impl is_exactly(op: ptr[PyObject], type: ptr[PyObject]) -> i64 {
    return 1 if object_type(op) == ptr[PyTypeObject](type) else 0;
}

impl errno_slot -> ptr[i32] {
    return __jac_errno();
}

impl binary_buffer(value: ptr[PyObject], view: ptr[Py_buffer]) -> bool {
    return PyObject_GetBuffer(value, view, PYBUF_SIMPLE) >= 0;
}

impl ascii_buffer(value: ptr[PyObject], view: ptr[Py_buffer]) -> bool {
    if unicode_check(value) {
        if not uo_is_ascii(value) {
            PyErr_SetString(
                PyExc_ValueError,
                ptr[u8]("string argument should contain only ASCII characters")
            );
            return False;
        }
        return PyBuffer_FillInfo(
            view, value, ptr(uo_data(value)), uo_length(value), 1, PYBUF_SIMPLE
        )
            >= 0;
    }
    if PyObject_GetBuffer(value, view, PYBUF_SIMPLE) < 0 {
        if PyObject_CheckBuffer(value) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "argument should be bytes, buffer or ASCII string, not '%.100s'"
                ),
                object_type(value).view(1)[0].tp_name
            );
        }
        return False;
    }
    return True;
}

impl text_buffer(value: ptr[PyObject], view: ptr[Py_buffer]) -> bool {
    if not unicode_check(value) {
        return PyObject_GetBuffer(value, view, PYBUF_SIMPLE) == 0;
    }
    size: i64 = 0;
    data = PyUnicode_AsUTF8AndSize(value, &mut size);
    if not data {
        return False;
    }
    return PyBuffer_FillInfo(view, value, ptr(data), size, 1, PYBUF_SIMPLE) == 0;
}

impl libm_resolve(system: ptr, name: ptr[u8], fallback: ptr) -> int {
    if system {
        found = dlsym(system, name);
        if found {
            return int(found);
        }
    }
    return int(fallback);
}

impl libm -> ptr[LibmTable] {
    table = addressof(libm_table);
    if __atomic_load_i64(int(addressof(libm_ready)), 2) != 0 {
        return table;
    }
    system = ptr();
    if MI_PLATFORM_LINUX != 0 {
        system = dlopen(ptr[u8]("libm.so.6"), RTLD_LAZY | LINUX_RTLD_NOLOAD);
        if not system {
            system = dlopen(ptr[u8]("libm.so.6"), RTLD_LAZY);
        }
    } else {
        system = dlopen(
            ptr[u8]("/usr/lib/libSystem.B.dylib"), RTLD_LAZY | DARWIN_RTLD_NOLOAD
        );
        if not system {
            system = dlopen(ptr[u8]("/usr/lib/libSystem.B.dylib"), RTLD_LAZY);
        }
    }
    table.view(1)[0].log = libm_resolve(system, ptr[u8]("log"), ptr(log));
    table.view(1)[0].log2 = libm_resolve(system, ptr[u8]("log2"), ptr(log2));
    table.view(1)[0].log10 = libm_resolve(system, ptr[u8]("log10"), ptr(log10));
    table.view(1)[0].exp = libm_resolve(system, ptr[u8]("exp"), ptr(exp));
    table.view(1)[0].exp2 = libm_resolve(system, ptr[u8]("exp2"), ptr(exp2));
    table.view(1)[0].sin = libm_resolve(system, ptr[u8]("sin"), ptr(sin));
    table.view(1)[0].cos = libm_resolve(system, ptr[u8]("cos"), ptr(cos));
    table.view(1)[0].tan = libm_resolve(system, ptr[u8]("tan"), ptr(tan));
    table.view(1)[0].fma = libm_resolve(system, ptr[u8]("fma"), ptr(fma));
    __atomic_store_i64(int(addressof(libm_ready)), 1, 3);
    return table;
}

impl dead_weakref(value: ptr[PyObject], unused: ptr) -> i32 {
    if not weakref_check(value) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("not a weakref"));
        return i32(-1);
    }
    return i32(1) if weakref_is_dead(value) else i32(0);
}

impl weakref_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(_PyWeakref_RefType)))
        or object_is_type(op, ptr[PyTypeObject](addressof(_PyWeakref_ProxyType)))
        or object_is_type(
            op, ptr[PyTypeObject](addressof(_PyWeakref_CallableProxyType))
        );
}

impl weakref_is_dead(op: ptr[PyObject]) -> bool {
    obj_ = ptr[PyWeakReference](op).view(1)[0].wr_object;
    if obj_ == Py_None {
        return True;
    }
    return object_refcount(obj_) == 0;
}

impl try_incref(op: ptr[PyObject]) -> bool {
    if object_refcount(op) > 0 {
        object_incref(op);
        return True;
    }
    return False;
}

impl thread_impl(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[u8](tstate);
}

impl asyncio_add_list(
    head: ptr[llist_node], tasks: ptr[PyObject], node_offset: i64
) -> i64 {
    list_node = head.view(1)[0].next;
    while list_node != head {
        following = list_node.view(1)[0].next;
        task = ptr[PyObject](ptr[u8](list_node) - node_offset);
        if try_incref(task) {
            status = PyList_Append(tasks, task);
            object_decref(task);
            if status < 0 {
                return -1;
            }
        }
        list_node = following;
    }
    return 0;
}

impl interp_runtime(interp: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
}

impl interp_first_thread(interp: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](interp + PyInterpreterState_THREADS_HEAD).view(1)[0];
}

impl thread_next(tstate: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](tstate + PyThreadState_NEXT).view(1)[0];
}

impl apple_log_write_impl(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    logtype: i32 = 0;
    text = ptr[u8]();
    if PyArg_ParseTuple(args, ptr[u8]("iy"), &mut logtype, &mut text) == 0 {
        return NULL;
    }
    __jac_system_log(logtype, text);
    return object_new_ref(Py_None);
}

impl static_strings_end -> i64 {
    return _PyRuntimeState_STRINGS_ASCII;
}
