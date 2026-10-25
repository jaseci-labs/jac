import from c {
    obj ImpStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0,
            w10: u64 = 0,
            w11: u64 = 0,
            w12: u64 = 0,
            w13: u64 = 0,
            w14: u64 = 0,
            w15: u64 = 0;
    }  def jacpy_stack_address(slots: &mut ImpStack) -> int;  def fclose(
        stream: ptr[FILE]
    ) -> i32;  def _Py_GetConfig -> ptr[u8];  def _Py_KeyedHash(
        key: u64, src: ptr, src_sz: i64
    ) -> u64;  def PyMemoryView_FromMemory(
        mem: ptr[u8], size: i64, flags: i32
    ) -> ptr[PyObject];  def _PyRecursiveMutex_IsLockedByCurrentThread(
        m: ptr[u8]
    ) -> i32;  def PyMutex_IsLocked(m: ptr[PyMutex]) -> i32;
}

def subclass_PyCode_Type(value: ptr[PyObject], fname: str, label: str);

def import_lock(interp: ptr[u8]) -> ptr[u8];

def _imp_lock_held_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _imp_acquire_lock_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _imp_release_lock_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _imp__fix_co_filename_impl(
    module: ptr[PyObject], code: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def _imp_create_builtin_impl(
    module: ptr[PyObject], spec: ptr[PyObject]
) -> ptr[PyObject];

def _imp_extension_suffixes_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _imp_init_frozen_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def _imp_find_frozen_impl(
    module: ptr[PyObject], name: ptr[PyObject], withdata: bool
) -> ptr[PyObject];

def _imp_get_frozen_object_impl(
    module: ptr[PyObject], name: ptr[PyObject], dataobj: ptr[PyObject]
) -> ptr[PyObject];

def _imp_is_frozen_package_impl(
    module: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def _imp_is_builtin_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def _imp_is_frozen_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def _imp__frozen_module_names_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _imp__override_frozen_modules_for_tests_impl(
    module: ptr[PyObject], override_: i32
) -> ptr[PyObject];

def _imp__override_multi_interp_extensions_check_impl(
    module: ptr[PyObject], override_: i32
) -> ptr[PyObject];

def create_dynamic_done(
    fp: ptr[FILE], info: ptr[ExtModuleLoaderInfo], mod: ptr[PyObject]
) -> ptr[PyObject];

def _imp_create_dynamic_impl(
    module: ptr[PyObject], spec: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject];

def _imp_exec_dynamic_impl(module: ptr[PyObject], mod: ptr[PyObject]) -> i32;

def _imp_exec_builtin_impl(module: ptr[PyObject], mod: ptr[PyObject]) -> i32;

def _imp_source_hash_impl(
    module: ptr[PyObject], key: i64, source: BufferArgument
) -> ptr[PyObject];

def imp_module_exec(module: ptr[PyObject]) -> i32;

impl subclass_PyCode_Type(value: ptr[PyObject], fname: str, label: str) {
    if not object_type_check(value, ptr[PyTypeObject](addressof(PyCode_Type))) {
        bad_argument(fname, label, "code", value);
    }
}

impl import_lock(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_IMPORTS_LOCK;
}

impl _imp_lock_held_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = current_interp();
    return PyBool_FromLong(i64(PyMutex_IsLocked(ptr[PyMutex](import_lock(interp)))));
}

impl _imp_acquire_lock_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = current_interp();
    _PyImport_AcquireLock(ptr[PyInterpreterState](interp));
    return object_new_ref(Py_None);
}

impl _imp_release_lock_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = current_interp();
    if _PyRecursiveMutex_IsLockedByCurrentThread(import_lock(interp)) == 0 {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("not holding the import lock"));
        return NULL;
    }
    _PyImport_ReleaseLock(ptr[PyInterpreterState](interp));
    return object_new_ref(Py_None);
}

impl _imp__fix_co_filename_impl(
    module: ptr[PyObject], code: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    update_compiled_module(code, path);
    return object_new_ref(Py_None);
}

impl _imp_create_builtin_impl(
    module: ptr[PyObject], spec: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = current_tstate();
    name = PyObject_GetAttrString(spec, ptr[u8]("name"));
    if not name {
        return NULL;
    }
    if not unicode_check(name) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("name must be string, not %.200s"),
            object_type(name).view(1)[0].tp_name
        );
        object_decref(name);
        return NULL;
    }
    mod = create_builtin(tstate, name, spec);
    object_decref(name);
    return mod;
}

impl _imp_extension_suffixes_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    lst = PyList_New(0);
    if not lst {
        return NULL;
    }
    table = ptr[ptr[u8]](addressof(_PyImport_DynLoadFiletab));
    index: i64 = 0;
    while (table + index).view(1)[0] {
        item = PyUnicode_FromString((table + index).view(1)[0]);
        if not item {
            object_decref(lst);
            return NULL;
        }
        if PyList_Append(lst, item) < 0 {
            object_decref(lst);
            object_decref(item);
            return NULL;
        }
        object_decref(item);
        index += 1;
    }
    return lst;
}

impl _imp_init_frozen_impl(
    module: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = current_tstate();
    ret = PyImport_ImportFrozenModuleObject(name);
    if ret < 0 {
        return NULL;
    }
    if ret == 0 {
        return object_new_ref(Py_None);
    }
    return import_add_module(tstate, name);
}

impl _imp_find_frozen_impl(
    module: ptr[PyObject], name: ptr[PyObject], withdata: bool
) -> ptr[PyObject] {
    slots: own ImpStack = ImpStack();
    info = ptr[FrozenInfo](jacpy_stack_address(&mut slots));
    status = find_frozen(name, info);
    if status == FROZEN_NOT_FOUND or status == FROZEN_DISABLED {
        return object_new_ref(Py_None);
    } elif status == FROZEN_BAD_NAME {
        return object_new_ref(Py_None);
    } elif status != FROZEN_OKAY {
        set_frozen_error(status, name);
        return NULL;
    }
    data = NULL;
    if withdata {
        data = PyMemoryView_FromMemory(
            info.view(1)[0].data, info.view(1)[0].size, PyBUF_READ
        );
        if not data {
            return NULL;
        }
    }
    origname = NULL;
    original = info.view(1)[0].origname;
    if original and original.view(1)[0] != u8(0) {
        origname = PyUnicode_FromString(original);
        if not origname {
            object_xdecref(data);
            return NULL;
        }
    }
    data_item = data or Py_None;
    package_item = addressof(_Py_TrueStruct)
        if info.view(1)[0].is_package
        else addressof(_Py_FalseStruct);
    origname_item = origname or Py_None;
    result = PyTuple_Pack(i64(3), data_item, package_item, origname_item);
    object_xdecref(origname);
    object_xdecref(data);
    return result;
}

impl _imp_get_frozen_object_impl(
    module: ptr[PyObject], name: ptr[PyObject], dataobj: ptr[PyObject]
) -> ptr[PyObject] {
    info_slots: own ImpStack = ImpStack();
    buf_slots: own ImpStack = ImpStack();
    info = ptr[FrozenInfo](jacpy_stack_address(&mut info_slots));
    buf = ptr[Py_buffer](jacpy_stack_address(&mut buf_slots));
    if PyObject_CheckBuffer(dataobj) != 0 {
        if PyObject_GetBuffer(dataobj, buf, PyBUF_SIMPLE) != 0 {
            return NULL;
        }
        info.view(1)[0].data = ptr[u8](buf.view(1)[0].buf);
        info.view(1)[0].size = buf.view(1)[0].length;
    } elif dataobj != Py_None {
        _PyArg_BadArgument(
            ptr[u8]("get_frozen_object"),
            ptr[u8]("argument 2"),
            ptr[u8]("bytes"),
            dataobj
        );
        return NULL;
    } else {
        status = find_frozen(name, info);
        if status != FROZEN_OKAY {
            set_frozen_error(status, name);
            return NULL;
        }
    }
    if not info.view(1)[0].nameobj {
        info.view(1)[0].nameobj = name;
    }
    if info.view(1)[0].size == 0 {
        set_frozen_error(FROZEN_INVALID, name);
        return NULL;
    }
    interp = current_interp();
    codeobj = unmarshal_frozen_code(interp, info);
    if dataobj != Py_None {
        PyBuffer_Release(buf);
    }
    return codeobj;
}

impl _imp_is_frozen_package_impl(
    module: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ImpStack = ImpStack();
    info = ptr[FrozenInfo](jacpy_stack_address(&mut slots));
    status = find_frozen(name, info);
    if status != FROZEN_OKAY and status != FROZEN_EXCLUDED {
        set_frozen_error(status, name);
        return NULL;
    }
    if info.view(1)[0].is_package {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl _imp_is_builtin_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(is_builtin(name)));
}

impl _imp_is_frozen_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    slots: own ImpStack = ImpStack();
    info = ptr[FrozenInfo](jacpy_stack_address(&mut slots));
    status = find_frozen(name, info);
    if status != FROZEN_OKAY {
        return PyBool_FromLong(0);
    }
    return PyBool_FromLong(1);
}

impl _imp__frozen_module_names_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return list_frozen_module_names();
}

impl _imp__override_frozen_modules_for_tests_impl(
    module: ptr[PyObject], override_: i32
) -> ptr[PyObject] {
    interp = current_interp();
    ptr[i32](interp + PyInterpreterState_IMPORTS_OVERRIDE_FROZEN_MODULES).view(1)[0] = override_;
    return object_new_ref(Py_None);
}

impl _imp__override_multi_interp_extensions_check_impl(
    module: ptr[PyObject], override_: i32
) -> ptr[PyObject] {
    interp = current_interp();
    if interp == ptr[u8](_PyInterpreterState_Main()) {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8](
                "_imp._override_multi_interp_extensions_check() cannot be used in the main interpreter"
            )
        );
        return NULL;
    }
    slot = ptr[i32](
        interp + PyInterpreterState_IMPORTS_OVERRIDE_MULTI_INTERP_EXTENSIONS_CHECK
    );
    oldvalue = slot.view(1)[0];
    slot.view(1)[0] = override_;
    return PyLong_FromLong(i64(oldvalue));
}

impl create_dynamic_done(
    fp: ptr[FILE], info: ptr[ExtModuleLoaderInfo], mod: ptr[PyObject]
) -> ptr[PyObject] {
    if fp {
        fclose(fp);
    }
    _Py_ext_module_loader_info_clear(info);
    return mod;
}

impl _imp_create_dynamic_impl(
    module: ptr[PyObject], spec: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject] {
    fp = ptr[FILE]();
    tstate = current_tstate();
    slots: own ImpStack = ImpStack();
    info = ptr[ExtModuleLoaderInfo](jacpy_stack_address(&mut slots));
    if _Py_ext_module_loader_info_init_from_spec(info, spec) < 0 {
        return NULL;
    }
    (mod, cached) = import_find_extension(tstate, info);
    if mod {
        return create_dynamic_done(fp, info, mod);
    } elif exception_raised(tstate) {
        return create_dynamic_done(fp, info, mod);
    }
    if cached {
        _extensions_cache_delete(info.view(1)[0].path, info.view(1)[0].name);
    }
    if PySys_Audit(
        "import",
        "OOOOO",
        info.view(1)[0].name,
        info.view(1)[0].filename,
        Py_None,
        Py_None,
        Py_None
    )
        < 0 {
        return create_dynamic_done(fp, info, NULL);
    }
    if file {
        fp = Py_fopen(info.view(1)[0].filename, ptr[u8]("r"));
        if not fp {
            return create_dynamic_done(fp, info, NULL);
        }
    }
    p0 = _PyImport_GetModInitFunc(info, fp);
    if not p0 {
        return create_dynamic_done(fp, info, NULL);
    }
    mod = import_run_extension(tstate, p0, info, spec, get_modules_dict(tstate, True));
    return create_dynamic_done(fp, info, mod);
}

impl _imp_exec_dynamic_impl(module: ptr[PyObject], mod: ptr[PyObject]) -> i32 {
    return exec_builtin_or_dynamic(mod);
}

impl _imp_exec_builtin_impl(module: ptr[PyObject], mod: ptr[PyObject]) -> i32 {
    return exec_builtin_or_dynamic(mod);
}

impl _imp_source_hash_impl(
    module: ptr[PyObject], key: i64, source: BufferArgument
) -> ptr[PyObject] {
    slots: own ImpStack = ImpStack();
    hash_data = ptr[u64](jacpy_stack_address(&mut slots));
    view = source.view;
    hash_data.view(1)[0] = _Py_KeyedHash(
        u64.wrap(key), view.view(1)[0].buf, view.view(1)[0].length
    );
    return PyBytes_FromStringAndSize(ptr[u8](hash_data), 8);
}

impl imp_module_exec(module: ptr[PyObject]) -> i32 {
    mode = ptr[ptr[i32]](_Py_GetConfig() + PyConfig_CHECK_HASH_PYCS_MODE).view(1)[0];
    pyc_mode = PyUnicode_FromWideChar(mode, -1);
    if PyModule_Add(module, ptr[u8]("check_hash_based_pycs"), pyc_mode) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(
        module, ptr[u8]("pyc_magic_number_token"), PYC_MAGIC_NUMBER_TOKEN
    )
        < 0 {
        return -1;
    }
    return 0;
}
