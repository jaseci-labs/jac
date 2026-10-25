import from c {
    obj CachedMDict {
        has copied: ptr[PyObject] = ptr[PyObject](),
            interpid: i64 = 0;
    }  obj ExtensionsCacheValue {
        has module_def: ptr[ModuleDef] = ptr[ModuleDef](),
            m_init: ptr = ptr(),
            m_index: i64 = 0,
            m_dict: ptr[CachedMDict] = ptr[CachedMDict](),
            m_dict_copied: ptr[PyObject] = ptr[PyObject](),
            m_dict_interpid: i64 = 0,
            origin: i64 = 0;
    }  obj ImportScratch {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0;
    }  def jacpy_stack_address(slots: &mut ImportScratch) -> int;  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: &mut ptr[PyObject]
    ) -> i32;  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format_: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  def _PyUnicode_InternImmortal(
        interp: ptr[u8], p: &mut ptr[PyObject]
    );  def PyInterpreterState_GetID(interp: ptr[u8]) -> i64;  def _PyThreadState_NewBound(
        interp: ptr[u8], whence: i32
    ) -> ptr[PyThreadState];  def PyErr_PrintEx(set_sys_last_vars: i32);  def PySys_FormatStderr(
        format: str, *args: any
    );  def fprintf(stream: ptr, format: ptr[u8], *args: any) -> i32;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  def strrchr(text: ptr[u8], character: i32) -> ptr[u8];  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  def strlen(text: ptr[u8]) -> u64;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memset(target: ptr, value: i32, size: u64) -> ptr;  glob _PySys_ImplCacheTag:
             ptr[u8]; glob PyImport_Inittab: ptr[_inittab] = addressof(
             _PyImport_Inittab
         ); glob:priv inittab_copy: ptr[_inittab] = ptr[_inittab](),
         extensions_alloc: list[ptr] = [ptr(PyMem_RawMalloc), ptr(PyMem_RawFree)];
}

glob:priv EXTENSIONS_VALUE_SIZE: Final[u64] = 56,
     EXTENSIONS_VALUE_M_DICT: Final[i64] = 32,
     HTSEP: Final[u8] = 58,
     SIZE_MAX: Final[u64] = 0xFFFFFFFFFFFFFFFF;

def inittab_copy_slot -> ptr[ptr[_inittab]];

def pyimport_inittab_slot -> ptr[ptr[_inittab]];

def interp_i32(interp: ptr[u8], offset: i64) -> ptr[i32];

def interp_slot(interp: ptr[u8], offset: i64) -> ptr[ptr[PyObject]];

def modules_of(interp: ptr[u8]) -> ptr[PyObject];

def modules_by_index_of(interp: ptr[u8]) -> ptr[PyObject];

def importlib_of(interp: ptr[u8]) -> ptr[PyObject];

def tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def is_main_interpreter(interp: ptr[u8]) -> bool;

def runtime_imports(offset: i64) -> ptr[u8];

def extensions_hashtable_slot -> ptr[ptr];

def pkgcontext_slot -> ptr[ptr[u8]];

def builtin_inittab -> ptr[_inittab];

def set_builtin_inittab(table: ptr[_inittab]);

def list_item(lst: ptr[PyObject], index: i64) -> ptr[PyObject];

def module_def_of(mod: ptr[PyObject]) -> ptr[ModuleDef];

def config_verbose(interp: ptr[u8]) -> i32;

import from c {
    def _PyImport_AcquireLock(interp: ptr[u8]) {
        _PyRecursiveMutex_Lock(interp + PyInterpreterState_IMPORTS_LOCK);
    }  def _PyImport_ReleaseLock(interp: ptr[u8]) {
        _PyRecursiveMutex_Unlock(interp + PyInterpreterState_IMPORTS_LOCK);
    }  def _PyImport_ReInitLock(interp: ptr[u8]) {
        ptr[u64](interp + PyInterpreterState_IMPORTS_LOCK_THREAD).view(1)[0] = PyThread_get_thread_ident_ex();
    }  def _PyImport_InitModules(interp: ptr[u8]) -> ptr[PyObject] {
        modules = PyDict_New();
        interp_slot(interp, PyInterpreterState_IMPORTS_MODULES).view(1)[0] = modules;
        if not modules {
            return NULL;
        }
        return modules;
    }  def _PyImport_GetModules(interp: ptr[u8]) -> ptr[PyObject] {
        return modules_of(interp);
    }  def _PyImport_GetModulesRef(interp: ptr[u8]) -> ptr[PyObject] {
        _PyImport_AcquireLock(interp);
        modules = modules_of(interp);
        if not modules {
            modules = Py_None;
        }
        object_incref(modules);
        _PyImport_ReleaseLock(interp);
        return modules;
    }  def _PyImport_ClearModules(interp: ptr[u8]) {
        slot = interp_slot(interp, PyInterpreterState_IMPORTS_MODULES);
        old = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        object_xdecref(old);
    }
}

def get_modules_dict(tstate: ptr[PyThreadState], fatal: bool) -> ptr[PyObject];

import from c {
    def PyImport_GetModuleDict -> ptr[PyObject] {
        return get_modules_dict(thread_state(), True);
    }  def _PyImport_SetModule(name: ptr[PyObject], m: ptr[PyObject]) -> i32 {
        modules = get_modules_dict(thread_state(), True);
        return PyObject_SetItem(modules, name, m);
    }  def _PyImport_SetModuleString(name: ptr[u8], m: ptr[PyObject]) -> i32 {
        modules = get_modules_dict(thread_state(), True);
        return PyMapping_SetItemString(modules, name, m);
    }
}

def import_get_module(
    tstate: ptr[PyThreadState], name: ptr[PyObject]
) -> ptr[PyObject];

def import_ensure_initialized(
    interp: ptr[u8], mod: ptr[PyObject], name: ptr[PyObject]
) -> i32;

import from c {
    def PyImport_GetModule(name: ptr[PyObject]) -> ptr[PyObject] {
        tstate = thread_state();

        mod = import_get_module(tstate, name);
        if mod and mod != Py_None {
            if import_ensure_initialized(tstate_interp(tstate), mod, name) < 0 {
                object_decref(mod);
                remove_importlib_frames(tstate);
                return NULL;
            }
            mod_check = import_get_module(tstate, name);
            if mod_check != mod {
                object_xdecref(mod_check);
                if exception_raised(tstate) {
                    object_decref(mod);
                    remove_importlib_frames(tstate);
                    return NULL;
                }
                object_decref(mod);
                return NULL;
            }
            object_decref(mod_check);
        }
        return mod;
    }
}

def import_add_module_lock_held(
    modules: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def import_add_module(
    tstate: ptr[PyThreadState], name: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def PyImport_AddModuleRef(name: ptr[u8]) -> ptr[PyObject] {
        name_obj = PyUnicode_FromString(name);
        if not name_obj {
            return NULL;
        }
        module = import_add_module(thread_state(), name_obj);
        object_decref(name_obj);
        return module;
    }  def PyImport_AddModuleObject(name: ptr[PyObject]) -> ptr[PyObject] {
        mod = import_add_module(thread_state(), name);
        if not mod {
            return NULL;
        }

        ref = PyWeakref_NewRef(mod, NULL);
        object_decref(mod);
        if not ref {
            return NULL;
        }
        mod = weakref_get_ref(ref);
        object_decref(ref);
        object_xdecref(mod);

        if not mod and not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("sys.modules does not hold a strong reference to the module")
            );
        }
        return mod;
    }  def PyImport_AddModule(name: ptr[u8]) -> ptr[PyObject] {
        nameobj = PyUnicode_FromString(name);
        if not nameobj {
            return NULL;
        }
        module = PyImport_AddModuleObject(nameobj);
        object_decref(nameobj);
        return module;
    }
}

def remove_module(tstate: ptr[PyThreadState], name: ptr[PyObject]);

import from c {
    def _PyImport_GetNextModuleIndex -> i64 {
        return __atomic_add_i64(
            int(runtime_imports(_PyRuntimeState_IMPORTS_LAST_MODULE_INDEX)), 1, 5
        )
            + 1;
    }
}

def _get_module_index_from_def(def_: ptr[ModuleDef]) -> i64;

def _set_module_index(def_: ptr[ModuleDef], index: i64);

def _modules_by_index_check(interp: ptr[u8], index: i64) -> ptr[u8];

def _modules_by_index_get(interp: ptr[u8], index: i64) -> ptr[PyObject];

def _modules_by_index_set(interp: ptr[u8], index: i64, module: ptr[PyObject]) -> i32;

def _modules_by_index_clear_one(interp: ptr[u8], index: i64) -> i32;

import from c {
    def PyState_FindModule(module: ptr[ModuleDef]) -> ptr[PyObject] {
        interp = current_interp();
        if module.view(1)[0].m_slots {
            return NULL;
        }
        index = _get_module_index_from_def(module);
        return _modules_by_index_get(interp, index);
    }  def _PyState_AddModule(
        tstate: ptr[PyThreadState], module: ptr[PyObject], def_: ptr[ModuleDef]
    ) -> i32 {
        if not def_ {
            return -1;
        }
        if def_.view(1)[0].m_slots {
            _PyErr_SetString(
                tstate,
                PyExc_SystemError,
                ptr[u8]("PyState_AddModule called on module with slots")
            );
            return -1;
        }
        index = _get_module_index_from_def(def_);
        return _modules_by_index_set(tstate_interp(tstate), index, module);
    }  def PyState_AddModule(module: ptr[PyObject], def_: ptr[ModuleDef]) -> i32 {
        if not def_ {
            _Py_FatalErrorFunc(
                ptr[u8]("PyState_AddModule"), ptr[u8]("module definition is NULL")
            );
            return -1;
        }

        tstate = thread_state();
        if def_.view(1)[0].m_slots {
            _PyErr_SetString(
                tstate,
                PyExc_SystemError,
                ptr[u8]("PyState_AddModule called on module with slots")
            );
            return -1;
        }

        interp = tstate_interp(tstate);
        index = _get_module_index_from_def(def_);
        by_index = modules_by_index_of(interp);
        if by_index
            and index < object_size(by_index)
            and module == list_item(by_index, index) {
            _Py_FatalErrorFormat(
                ptr[u8]("PyState_AddModule"), ptr[u8]("module %p already added"), module
            );
            return -1;
        }

        return _modules_by_index_set(interp, index, module);
    }  def PyState_RemoveModule(def_: ptr[ModuleDef]) -> i32 {
        tstate = thread_state();
        if def_.view(1)[0].m_slots {
            _PyErr_SetString(
                tstate,
                PyExc_SystemError,
                ptr[u8]("PyState_RemoveModule called on module with slots")
            );
            return -1;
        }
        index = _get_module_index_from_def(def_);
        return _modules_by_index_clear_one(tstate_interp(tstate), index);
    }  def _PyImport_ClearModulesByIndex(interp: ptr[u8]) {
        by_index = modules_by_index_of(interp);
        if not by_index {
            return;
        }

        i: i64 = 0;
        while i < object_size(by_index) {
            m = list_item(by_index, i);
            if module_check(m) {
                md = ptr[ModuleDef](PyModule_GetDef(m));
                if md {
                    old = md.view(1)[0].m_base.m_copy;
                    md.view(1)[0].m_base.m_copy = NULL;
                    object_xdecref(old);
                }
            }
            i += 1;
        }

        if PyList_SetSlice(by_index, 0, object_size(by_index), NULL) != 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing interpreters module list")
            );
        }
    }  def _PyImport_ResolveNameWithPackageContext(name: ptr[u8]) -> ptr[u8] {
        slot = pkgcontext_slot();
        context = slot.view(1)[0];
        if context {
            p = strrchr(context, i32(46));
            if p and strcmp(name, p + 1) == 0 {
                slot.view(1)[0] = ptr[u8]();
                return context;
            }
        }
        return name;
    }  def _PyImport_SwapPackageContext(newcontext: ptr[u8]) -> ptr[u8] {
        slot = pkgcontext_slot();
        oldcontext = slot.view(1)[0];
        slot.view(1)[0] = newcontext;
        return oldcontext;
    }  def _PyImport_GetDLOpenFlags(interp: ptr[u8]) -> i32 {
        return interp_i32(interp, PyInterpreterState_IMPORTS_DLOPENFLAGS).view(1)[0];
    }  def _PyImport_SetDLOpenFlags(interp: ptr[u8], new_val: i32) {
        interp_i32(interp, PyInterpreterState_IMPORTS_DLOPENFLAGS).view(1)[0] = new_val;
    }
}

def exec_builtin_or_dynamic(mod: ptr[PyObject]) -> i32;

import from c {
    def _PyImport_ClearExtension(name: ptr[PyObject], filename: ptr[PyObject]) -> i32 {
        interp = current_interp();

        if clear_singlephase_extension(interp, name, filename) < 0 {
            return -1;
        }

        return 0;
    }
}

def extensions_lock_acquire;

def extensions_lock_release;

def alloc_extensions_cache_value -> ptr[ExtensionsCacheValue];

def free_extensions_cache_value(value: ptr[ExtensionsCacheValue]);

def _get_cached_module_index(cached: ptr[ExtensionsCacheValue]) -> i64;

def fixup_cached_def(value: ptr[ExtensionsCacheValue]);

def restore_old_cached_def(def_: ptr[ModuleDef], oldbase: ptr[u8]);

def cleanup_old_cached_def(oldbase: ptr[u8]);

def del_cached_def(value: ptr[ExtensionsCacheValue]);

def init_cached_m_dict(value: ptr[ExtensionsCacheValue], m_dict: ptr[PyObject]) -> i32;

def del_cached_m_dict(value: ptr[ExtensionsCacheValue]);

def get_cached_m_dict(
    value: ptr[ExtensionsCacheValue], name: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def del_extensions_cache_value(raw: ptr);

def hashtable_key_from_2_strings(
    str1: ptr[PyObject], str2: ptr[PyObject], sep: u8
) -> ptr[u8];

def hashtable_hash_str(key: ptr) -> u64;

def hashtable_compare_str(key1: ptr, key2: ptr) -> i32;

def hashtable_destroy_str(key: ptr);

def _extensions_cache_init -> i32;

def _extensions_cache_find_unlocked(
    path: ptr[PyObject], name: ptr[PyObject], keep_key: bool
) -> tuple[ptr[_Py_hashtable_entry_t], ptr[u8]];

def _extensions_cache_get(
    path: ptr[PyObject], name: ptr[PyObject]
) -> ptr[ExtensionsCacheValue];

def _extensions_cache_set(
    path: ptr[PyObject],
    name: ptr[PyObject],
    def_: ptr[ModuleDef],
    m_init: ptr,
    m_index: i64,
    m_dict: ptr[PyObject],
    origin: i32
) -> ptr[ExtensionsCacheValue];

def _extensions_cache_delete(path: ptr[PyObject], name: ptr[PyObject]);

def _extensions_cache_clear_all;

def check_multi_interp_extensions(interp: ptr[u8]) -> bool;

import from c {
    def _PyImport_CheckSubinterpIncompatibleExtensionAllowed(name: ptr[u8]) -> i32 {
        interp = current_interp();
        if check_multi_interp_extensions(interp) {
            PyErr_Format(
                PyExc_ImportError,
                ptr[u8]("module %s does not support loading in subinterpreters"),
                name
            );
            return -1;
        }
        return 0;
    }
}

def switch_to_main_interpreter(tstate: ptr[PyThreadState]) -> ptr[PyThreadState];

def switch_back_from_main_interpreter(
    tstate: ptr[PyThreadState], main_tstate: ptr[PyThreadState], tempobj: ptr[PyObject]
);

def get_core_module_dict(
    interp: ptr[u8], name: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def update_global_state_for_extension(
    tstate: ptr[PyThreadState],
    path: ptr[PyObject],
    name: ptr[PyObject],
    def_: ptr[ModuleDef],
    sp_m_init: ptr,
    sp_m_index: i64,
    sp_m_dict: ptr[PyObject],
    sp_origin: i32
) -> ptr[ExtensionsCacheValue];

def finish_singlephase_extension(
    tstate: ptr[PyThreadState],
    mod: ptr[PyObject],
    cached: ptr[ExtensionsCacheValue],
    name: ptr[PyObject],
    modules: ptr[PyObject]
) -> i32;

def reload_singlephase_extension(
    tstate: ptr[PyThreadState],
    cached: ptr[ExtensionsCacheValue],
    info: ptr[ExtModuleLoaderInfo]
) -> ptr[PyObject];

def import_find_extension(
    tstate: ptr[PyThreadState], info: ptr[ExtModuleLoaderInfo]
) -> tuple[ptr[PyObject], ptr[u8]];

def import_run_extension(
    tstate: ptr[PyThreadState],
    p0: ptr,
    info: ptr[ExtModuleLoaderInfo],
    spec: ptr[PyObject],
    modules: ptr[PyObject]
) -> ptr[PyObject];

def clear_singlephase_extension(
    interp: ptr[u8], name: ptr[PyObject], path: ptr[PyObject]
) -> i32;

import from c {
    def _PyImport_FixupBuiltin(
        tstate: ptr[PyThreadState],
        mod: ptr[PyObject],
        name: ptr[u8],
        modules: ptr[PyObject]
    ) -> i32 {
        nameobj = PyUnicode_InternFromString(name);
        if not nameobj {
            return -1;
        }

        def_ = ptr[ModuleDef](PyModule_GetDef(mod));
        if not def_ {
            PyErr_BadInternalCall();
            object_decref(nameobj);
            return -1;
        }

        cached = _extensions_cache_get(nameobj, nameobj);
        if not cached {
            cached = update_global_state_for_extension(
                tstate,
                nameobj,
                nameobj,
                def_,
                ptr(),
                def_.view(1)[0].m_base.m_index,
                NULL,
                EXT_MODULE_ORIGIN_CORE
            );
            if not cached {
                object_decref(nameobj);
                return -1;
            }
        }

        if finish_singlephase_extension(tstate, mod, cached, nameobj, modules) < 0 {
            object_decref(nameobj);
            return -1;
        }

        object_decref(nameobj);
        return 0;
    }
}

def is_builtin(name: ptr[PyObject]) -> i32;

def create_builtin(
    tstate: ptr[PyThreadState], name: ptr[PyObject], spec: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def PyImport_ExtendInittab(newtab: ptr[_inittab]) -> i32 {
        if builtin_inittab() {
            _Py_FatalErrorFunc(
                ptr[u8]("PyImport_ExtendInittab"),
                ptr[u8](
                    "PyImport_ExtendInittab() may not be called after Py_Initialize()"
                )
            );
        }

        n: u64 = 0;
        while (newtab + i64(n)).view(1)[0].name {
            n += u64(1);
        }
        if n == u64(0) {
            return 0;
        }
        i: u64 = 0;
        while (pyimport_inittab_slot().view(1)[0] + i64(i)).view(1)[0].name {
            i += u64(1);
        }

        entry_size = u64(_inittab_SIZE);
        p = ptr[_inittab]();
        if i + n <= SIZE_MAX // entry_size - u64(1) {
            size = entry_size * (i + n + u64(1));
            p = ptr[_inittab](
                _PyMem_DefaultRawRealloc(inittab_copy_slot().view(1)[0], size)
            );
        }
        if not p {
            return -1;
        }

        if inittab_copy_slot().view(1)[0] != pyimport_inittab_slot().view(1)[0] {
            memcpy(p, pyimport_inittab_slot().view(1)[0], (i + u64(1)) * entry_size);
        }
        memcpy(p + i64(i), newtab, (n + u64(1)) * entry_size);
        inittab_copy_slot().view(1)[0] = p;
        pyimport_inittab_slot().view(1)[0] = p;
        return 0;
    }  def PyImport_AppendInittab(name: ptr[u8], initfunc: ptr) -> i32 {
        if builtin_inittab() {
            _Py_FatalErrorFunc(
                ptr[u8]("PyImport_AppendInittab"),
                ptr[u8](
                    "PyImport_AppendInittab() may not be called after Py_Initialize()"
                )
            );
        }

        scratch: own ImportScratch = ImportScratch();
        newtab = ptr[_inittab](jacpy_stack_address(&mut scratch));
        newtab.view(2)[0].name = name;
        newtab.view(2)[0].initfunc = initfunc;

        return PyImport_ExtendInittab(newtab);
    }
}

def init_builtin_modules_table -> i32;

def clear_inittab_copy;

def fini_builtin_modules_table;

import from c {
    def _PyImport_GetBuiltinModuleNames -> ptr[PyObject] {
        lst = PyList_New(0);
        if not lst {
            return NULL;
        }
        inittab = builtin_inittab();
        i: i64 = 0;
        while (inittab + i).view(1)[0].name {
            name = PyUnicode_FromString((inittab + i).view(1)[0].name);
            if not name {
                object_decref(lst);
                return NULL;
            }
            if PyList_Append(lst, name) < 0 {
                object_decref(name);
                object_decref(lst);
                return NULL;
            }
            object_decref(name);
            i += 1;
        }
        return lst;
    }  def PyImport_GetMagicNumber -> i64 {
        return PYC_MAGIC_NUMBER_TOKEN;
    }  def PyImport_GetMagicTag -> ptr[u8] {
        return ptr[ptr[u8]](addressof(_PySys_ImplCacheTag)).view(1)[0];
    }
}

impl inittab_copy_slot -> ptr[ptr[_inittab]] {
    return ptr[ptr[_inittab]](addressof(inittab_copy));
}

impl pyimport_inittab_slot -> ptr[ptr[_inittab]] {
    return ptr[ptr[_inittab]](addressof(PyImport_Inittab));
}

impl interp_i32(interp: ptr[u8], offset: i64) -> ptr[i32] {
    return ptr[i32](interp + offset);
}

impl interp_slot(interp: ptr[u8], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](interp + offset);
}

impl modules_of(interp: ptr[u8]) -> ptr[PyObject] {
    return interp_slot(interp, PyInterpreterState_IMPORTS_MODULES).view(1)[0];
}

impl modules_by_index_of(interp: ptr[u8]) -> ptr[PyObject] {
    return interp_slot(interp, PyInterpreterState_IMPORTS_MODULES_BY_INDEX).view(1)[0];
}

impl importlib_of(interp: ptr[u8]) -> ptr[PyObject] {
    return interp_slot(interp, PyInterpreterState_IMPORTS_IMPORTLIB).view(1)[0];
}

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return interp_of(ptr[u8](tstate));
}

impl is_main_interpreter(interp: ptr[u8]) -> bool {
    return interp == ptr[u8](_PyInterpreterState_Main());
}

impl runtime_imports(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl extensions_hashtable_slot -> ptr[ptr] {
    return ptr[ptr](runtime_imports(_PyRuntimeState_IMPORTS_EXTENSIONS_HASHTABLE));
}

impl pkgcontext_slot -> ptr[ptr[u8]] {
    return ptr[ptr[u8]](
        __thread_local_block("jac_interpreter_importing_pkgcontext", 8)
    );
}

impl builtin_inittab -> ptr[_inittab] {
    return ptr[ptr[_inittab]](runtime_imports(_PyRuntimeState_IMPORTS_INITTAB)).view(1)[
        0
    ];
}

impl set_builtin_inittab(table: ptr[_inittab]) {
    ptr[ptr[_inittab]](runtime_imports(_PyRuntimeState_IMPORTS_INITTAB)).view(1)[0] = table;
}

impl list_item(lst: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return (ptr[PyListObject](lst).view(1)[0].ob_item + index).view(1)[0];
}

impl module_def_of(mod: ptr[PyObject]) -> ptr[ModuleDef] {
    return ptr[ModuleDef](ptr[PyModuleObject](mod).view(1)[0].md_def);
}

impl config_verbose(interp: ptr[u8]) -> i32 {
    return ptr[i32](_PyInterpreterState_GetConfig(interp) + PyConfig_VERBOSE).view(1)[
        0
    ];
}

impl get_modules_dict(tstate: ptr[PyThreadState], fatal: bool) -> ptr[PyObject] {
    modules = modules_of(tstate_interp(tstate));
    if not modules {
        if fatal {
            _Py_FatalErrorFunc(
                ptr[u8]("get_modules_dict"),
                ptr[u8]("interpreter has no modules dictionary")
            );
        }
        _PyErr_SetString(
            tstate, PyExc_RuntimeError, ptr[u8]("unable to get sys.modules")
        );
        return NULL;
    }
    return modules;
}

impl import_get_module(
    tstate: ptr[PyThreadState], name: ptr[PyObject]
) -> ptr[PyObject] {
    modules = get_modules_dict(tstate, False);
    if not modules {
        return NULL;
    }

    m = NULL;
    object_incref(modules);
    PyMapping_GetOptionalItem(modules, name, &mut m);
    object_decref(modules);
    return m;
}

impl import_ensure_initialized(
    interp: ptr[u8], mod: ptr[PyObject], name: ptr[PyObject]
) -> i32 {
    spec = NULL;
    rc = PyObject_GetOptionalAttr(mod, py_id(_Py_ID___spec__), &mut spec);
    if rc > 0 {
        rc = _PyModuleSpec_IsInitializing(spec);
        object_decref(spec);
    }
    if rc < 0 {
        return rc;
    }
    if rc != 0 {
        value = call_method_one_arg(
            importlib_of(interp), py_id(_Py_ID__lock_unlock_module), name
        );
        if not value {
            return -1;
        }
        object_decref(value);
    }

    if ptr[i32](_PyInterpreterState_GetConfig(interp) + PyConfig_IMPORT_TIME).view(1)[0]
        == 2 {
        header = interp_i32(interp, PyInterpreterState_IMPORTS_FIND_AND_LOAD_HEADER);
        if header.view(1)[0] != 0 {
            fputs(
                ptr[u8]("import time: self [us] | cumulative | imported package\n"),
                stderr_stream()
            );
            header.view(1)[0] = 0;
        }
        level: i32 = interp_i32(
            interp, PyInterpreterState_IMPORTS_FIND_AND_LOAD_IMPORT_LEVEL
        ).view(
            1
        )[0]
            * 2;
        text: ptr[u8] = PyUnicode_AsUTF8(name);
        fprintf(
            stderr_stream(),
            ptr[u8]("import time: cached    | cached     | %*s\n"),
            level,
            text
        );
    }

    return 0;
}

impl import_add_module_lock_held(
    modules: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    m = NULL;
    if PyMapping_GetOptionalItem(modules, name, &mut m) < 0 {
        return NULL;
    }
    if m and module_check(m) {
        return m;
    }
    object_xdecref(m);
    m = PyModule_NewObject(name);
    if not m {
        return NULL;
    }
    if PyObject_SetItem(modules, name, m) != 0 {
        object_decref(m);
        return NULL;
    }

    return m;
}

impl import_add_module(
    tstate: ptr[PyThreadState], name: ptr[PyObject]
) -> ptr[PyObject] {
    modules = get_modules_dict(tstate, False);
    if not modules {
        return NULL;
    }
    return import_add_module_lock_held(modules, name);
}

impl remove_module(tstate: ptr[PyThreadState], name: ptr[PyObject]) {
    exc = _PyErr_GetRaisedException(tstate);

    modules = get_modules_dict(tstate, True);
    if object_type(modules) == ptr[PyTypeObject](addressof(PyDict_Type)) {
        PyDict_Pop(modules, name, None);
    } elif PyObject_DelItem(modules, name) < 0 {
        if _PyErr_ExceptionMatches(tstate, PyExc_KeyError) != 0 {
            _PyErr_Clear(tstate);
        }
    }

    _PyErr_ChainExceptions1(exc);
}

impl _get_module_index_from_def(def_: ptr[ModuleDef]) -> i64 {
    return def_.view(1)[0].m_base.m_index;
}

impl _set_module_index(def_: ptr[ModuleDef], index: i64) {
    if index == def_.view(1)[0].m_base.m_index {
        return;
    }
    def_.view(1)[0].m_base.m_index = index;
}

impl _modules_by_index_check(interp: ptr[u8], index: i64) -> ptr[u8] {
    if index <= 0 {
        return ptr[u8]("invalid module index");
    }
    by_index = modules_by_index_of(interp);
    if not by_index {
        return ptr[u8]("Interpreters module-list not accessible.");
    }
    if index >= object_size(by_index) {
        return ptr[u8]("Module index out of bounds.");
    }
    return ptr[u8]();
}

impl _modules_by_index_get(interp: ptr[u8], index: i64) -> ptr[PyObject] {
    if _modules_by_index_check(interp, index) {
        return NULL;
    }
    res = list_item(modules_by_index_of(interp), index);
    if res == Py_None {
        return NULL;
    }
    return res;
}

impl _modules_by_index_set(interp: ptr[u8], index: i64, module: ptr[PyObject]) -> i32 {
    slot = interp_slot(interp, PyInterpreterState_IMPORTS_MODULES_BY_INDEX);
    if not slot.view(1)[0] {
        slot.view(1)[0] = PyList_New(0);
        if not slot.view(1)[0] {
            return -1;
        }
    }

    while object_size(slot.view(1)[0]) <= index {
        if PyList_Append(slot.view(1)[0], Py_None) < 0 {
            return -1;
        }
    }

    return PyList_SetItem(slot.view(1)[0], index, object_new_ref(module));
}

impl _modules_by_index_clear_one(interp: ptr[u8], index: i64) -> i32 {
    err = _modules_by_index_check(interp, index);
    if err {
        _Py_FatalErrorFunc(ptr[u8]("_modules_by_index_clear_one"), err);
        return -1;
    }
    return PyList_SetItem(modules_by_index_of(interp), index, object_new_ref(Py_None));
}

impl exec_builtin_or_dynamic(mod: ptr[PyObject]) -> i32 {
    if not module_check(mod) {
        return 0;
    }

    def_ = PyModule_GetDef(mod);
    if not def_ {
        return 0;
    }

    state = PyModule_GetState(mod);
    if state {
        return 0;
    }

    return PyModule_ExecDef(mod, def_);
}

impl extensions_lock_acquire {
    PyMutex_Lock(
        ptr[PyMutex](runtime_imports(_PyRuntimeState_IMPORTS_EXTENSIONS_MUTEX))
    );
}

impl extensions_lock_release {
    PyMutex_Unlock(
        ptr[PyMutex](runtime_imports(_PyRuntimeState_IMPORTS_EXTENSIONS_MUTEX))
    );
}

impl alloc_extensions_cache_value -> ptr[ExtensionsCacheValue] {
    value = PyMem_RawMalloc(EXTENSIONS_VALUE_SIZE);
    if not value {
        PyErr_NoMemory();
        return ptr[ExtensionsCacheValue]();
    }
    memset(value, i32(0), EXTENSIONS_VALUE_SIZE);
    return ptr[ExtensionsCacheValue](value);
}

impl free_extensions_cache_value(value: ptr[ExtensionsCacheValue]) {
    PyMem_RawFree(value);
}

impl _get_cached_module_index(cached: ptr[ExtensionsCacheValue]) -> i64 {
    return cached.view(1)[0].m_index;
}

impl fixup_cached_def(value: ptr[ExtensionsCacheValue]) {
    def_ = value.view(1)[0].module_def;

    _Py_SetImmortalUntracked(ptr[PyObject](def_));

    def_.view(1)[0].m_base.m_init = int(value.view(1)[0].m_init);

    _set_module_index(def_, value.view(1)[0].m_index);

    if value.view(1)[0].m_dict {
        def_.view(1)[0].m_base.m_copy = object_new_ref(
            value.view(1)[0].m_dict.view(1)[0].copied
        );
    }
}

impl restore_old_cached_def(def_: ptr[ModuleDef], oldbase: ptr[u8]) {
    memcpy(def_, oldbase, u64(PyModuleDef_Base_SIZE));
}

impl cleanup_old_cached_def(oldbase: ptr[u8]) {
    object_xdecref(ptr[PyModuleDef_Base](oldbase).view(1)[0].m_copy);
}

impl del_cached_def(value: ptr[ExtensionsCacheValue]) {
    def_ = value.view(1)[0].module_def;
    object_xdecref(def_.view(1)[0].m_base.m_copy);
    def_.view(1)[0].m_base.m_copy = NULL;
}

impl init_cached_m_dict(
    value: ptr[ExtensionsCacheValue], m_dict: ptr[PyObject]
) -> i32 {
    if not m_dict {
        return 0;
    }

    interp = current_interp();

    copied = PyDict_Copy(m_dict);
    if not copied {
        return -1;
    }

    value.view(1)[0].m_dict_copied = copied;
    value.view(1)[0].m_dict_interpid = PyInterpreterState_GetID(interp);

    value.view(1)[0].m_dict = ptr[CachedMDict](
        ptr[u8](value) + EXTENSIONS_VALUE_M_DICT
    );
    return 0;
}

impl del_cached_m_dict(value: ptr[ExtensionsCacheValue]) {
    if value.view(1)[0].m_dict {
        object_xdecref(value.view(1)[0].m_dict.view(1)[0].copied);
        value.view(1)[0].m_dict = ptr[CachedMDict]();
    }
}

impl get_cached_m_dict(
    value: ptr[ExtensionsCacheValue], name: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    interp = current_interp();
    if value.view(1)[0].origin == i64(EXT_MODULE_ORIGIN_CORE) {
        return get_core_module_dict(interp, name, path);
    }
    m_dict = value.view(1)[0].module_def.view(1)[0].m_base.m_copy;
    object_xincref(m_dict);
    return m_dict;
}

impl del_extensions_cache_value(raw: ptr) {
    value = ptr[ExtensionsCacheValue](raw);
    if value {
        del_cached_m_dict(value);
        del_cached_def(value);
        free_extensions_cache_value(value);
    }
}

impl hashtable_key_from_2_strings(
    str1: ptr[PyObject], str2: ptr[PyObject], sep: u8
) -> ptr[u8] {
    str1_data = _PyUnicode_AsUTF8NoNUL(str1);
    str2_data = _PyUnicode_AsUTF8NoNUL(str2);
    if not str1_data or not str2_data {
        return ptr[u8]();
    }
    str1_len = strlen(str1_data);
    str2_len = strlen(str2_data);

    size = str1_len + u64(1) + str2_len + u64(1);

    key = ptr[u8](PyMem_RawMalloc(size));
    if not key {
        PyErr_NoMemory();
        return ptr[u8]();
    }

    memcpy(key, str1_data, str1_len);
    (key + i64(str1_len)).view(1)[0] = sep;
    memcpy(key + i64(str1_len) + 1, str2_data, str2_len);
    (key + i64(size) - 1).view(1)[0] = u8(0);
    return key;
}

impl hashtable_hash_str(key: ptr) -> u64 {
    return u64.wrap(Py_HashBuffer(key, i64(strlen(ptr[u8](key)))));
}

impl hashtable_compare_str(key1: ptr, key2: ptr) -> i32 {
    if strcmp(ptr[u8](key1), ptr[u8](key2)) == 0 {
        return 1;
    }
    return 0;
}

impl hashtable_destroy_str(key: ptr) {
    PyMem_RawFree(key);
}

impl _extensions_cache_init -> i32 {
    table = _Py_hashtable_new_full(
        ptr(hashtable_hash_str),
        ptr(hashtable_compare_str),
        ptr(hashtable_destroy_str),
        ptr(del_extensions_cache_value),
        ptr(addressof(extensions_alloc))
    );
    extensions_hashtable_slot().view(1)[0] = table;
    if not table {
        PyErr_NoMemory();
        return -1;
    }
    return 0;
}

impl _extensions_cache_find_unlocked(
    path: ptr[PyObject], name: ptr[PyObject], keep_key: bool
) -> tuple[ptr[_Py_hashtable_entry_t], ptr[u8]] {
    table = ptr[_Py_hashtable_t](extensions_hashtable_slot().view(1)[0]);
    if not table {
        return (ptr[_Py_hashtable_entry_t](), ptr[u8]());
    }
    key = hashtable_key_from_2_strings(path, name, HTSEP);
    if not key {
        return (ptr[_Py_hashtable_entry_t](), ptr[u8]());
    }
    ht_entry = table.view(1)[0].get_entry_func(table, key);
    if keep_key {
        return (ht_entry, key);
    }
    hashtable_destroy_str(key);
    return (ht_entry, ptr[u8]());
}

impl _extensions_cache_get(
    path: ptr[PyObject], name: ptr[PyObject]
) -> ptr[ExtensionsCacheValue] {
    value = ptr[ExtensionsCacheValue]();
    extensions_lock_acquire();

    (ht_entry, unused) = _extensions_cache_find_unlocked(path, name, False);
    if ht_entry {
        value = ptr[ExtensionsCacheValue](ht_entry.view(1)[0].value);
    }

    extensions_lock_release();
    return value;
}

impl _extensions_cache_set(
    path: ptr[PyObject],
    name: ptr[PyObject],
    def_: ptr[ModuleDef],
    m_init: ptr,
    m_index: i64,
    m_dict: ptr[PyObject],
    origin: i32
) -> ptr[ExtensionsCacheValue] {
    value = ptr[ExtensionsCacheValue]();
    key = ptr[u8]();
    newvalue = ptr[ExtensionsCacheValue]();
    scratch: own ImportScratch = ImportScratch();
    olddefbase = ptr[u8](jacpy_stack_address(&mut scratch));
    memcpy(olddefbase, def_, u64(PyModuleDef_Base_SIZE));

    extensions_lock_acquire();

    reused = False;
    failed = False;
    if not extensions_hashtable_slot().view(1)[0] {
        if _extensions_cache_init() < 0 {
            failed = True;
        }
    }

    ht_entry = ptr[_Py_hashtable_entry_t]();
    if not failed {
        (ht_entry, key) = _extensions_cache_find_unlocked(path, name, True);
        if ht_entry {
            value = ptr[ExtensionsCacheValue](ht_entry.view(1)[0].value);
        }
        if value {
            reused = True;
        }
    }

    if not failed and not reused {
        newvalue = alloc_extensions_cache_value();
        if not newvalue {
            failed = True;
        }
    }

    if not failed and not reused {
        newvalue.view(1)[0].module_def = def_;
        newvalue.view(1)[0].m_init = m_init;
        newvalue.view(1)[0].m_index = m_index;
        newvalue.view(1)[0].origin = i64(origin);
        if init_cached_m_dict(newvalue, m_dict) < 0 {
            failed = True;
        }
    }

    if not failed and not reused {
        fixup_cached_def(newvalue);

        if not ht_entry {
            if _Py_hashtable_set(extensions_hashtable_slot().view(1)[0], key, newvalue)
                < 0 {
                PyErr_NoMemory();
                failed = True;
            } else {
                key = ptr[u8]();
            }
        } else {
            ht_entry.view(1)[0].value = newvalue;
        }
    }

    if not reused {
        if failed {
            value = ptr[ExtensionsCacheValue]();
            restore_old_cached_def(def_, olddefbase);
            if newvalue {
                del_extensions_cache_value(newvalue);
            }
        } else {
            value = newvalue;
            cleanup_old_cached_def(olddefbase);
        }
    }

    extensions_lock_release();
    if key {
        hashtable_destroy_str(key);
    }

    return value;
}

impl _extensions_cache_delete(path: ptr[PyObject], name: ptr[PyObject]) {
    extensions_lock_acquire();

    if extensions_hashtable_slot().view(1)[0] {
        (ht_entry, unused) = _extensions_cache_find_unlocked(path, name, False);
        if ht_entry and ht_entry.view(1)[0].value {
            value = ptr[ExtensionsCacheValue](ht_entry.view(1)[0].value);
            ht_entry.view(1)[0].value = ptr();

            del_extensions_cache_value(value);
        }
    }

    extensions_lock_release();
}

impl _extensions_cache_clear_all {
    _Py_hashtable_destroy(extensions_hashtable_slot().view(1)[0]);
    extensions_hashtable_slot().view(1)[0] = ptr();
}

impl check_multi_interp_extensions(interp: ptr[u8]) -> bool {
    override_value = interp_i32(
        interp, PyInterpreterState_IMPORTS_OVERRIDE_MULTI_INTERP_EXTENSIONS_CHECK
    ).view(
        1
    )[0];
    if override_value < 0 {
        return False;
    } elif override_value > 0 {
        return True;
    } elif (
        ptr[u64](interp + PyInterpreterState_FEATURE_FLAGS).view(1)[0]
        & Py_RTFLAGS_MULTI_INTERP_EXTENSIONS
    )
        != 0 {
        return True;
    }
    return False;
}

impl switch_to_main_interpreter(tstate: ptr[PyThreadState]) -> ptr[PyThreadState] {
    if is_main_interpreter(tstate_interp(tstate)) {
        return tstate;
    }
    main_tstate = _PyThreadState_NewBound(
        ptr[u8](_PyInterpreterState_Main()), _PyThreadState_WHENCE_EXEC
    );
    if not main_tstate {
        return main_tstate;
    }
    PyThreadState_Swap(main_tstate);
    return main_tstate;
}

impl switch_back_from_main_interpreter(
    tstate: ptr[PyThreadState], main_tstate: ptr[PyThreadState], tempobj: ptr[PyObject]
) {
    if PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_MemoryError) != 0 {
            PyErr_Clear();
        } else {
            PyErr_PrintEx(0);
        }
    }

    object_xdecref(tempobj);

    PyThreadState_Clear(main_tstate);
    PyThreadState_Swap(tstate);
    PyThreadState_Delete(main_tstate);
}

impl get_core_module_dict(
    interp: ptr[u8], name: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    if path == name {
        if PyUnicode_CompareWithASCIIString(name, ptr[u8]("sys")) == 0 {
            return object_new_ref(
                interp_slot(interp, PyInterpreterState_SYSDICT_COPY).view(1)[0]
            );
        }
        if PyUnicode_CompareWithASCIIString(name, ptr[u8]("builtins")) == 0 {
            return object_new_ref(
                interp_slot(interp, PyInterpreterState_BUILTINS_COPY).view(1)[0]
            );
        }
    }
    return NULL;
}

impl update_global_state_for_extension(
    tstate: ptr[PyThreadState],
    path: ptr[PyObject],
    name: ptr[PyObject],
    def_: ptr[ModuleDef],
    sp_m_init: ptr,
    sp_m_index: i64,
    sp_m_dict: ptr[PyObject],
    sp_origin: i32
) -> ptr[ExtensionsCacheValue] {
    cached = ptr[ExtensionsCacheValue]();
    m_init = ptr();
    m_dict = NULL;

    if sp_m_init {
        m_init = sp_m_init;
    } elif sp_m_dict {
        m_dict = sp_m_dict;
    }

    if is_main_interpreter(tstate_interp(tstate)) or def_.view(1)[0].m_size == -1 {
        cached = _extensions_cache_set(
            path, name, def_, m_init, sp_m_index, m_dict, sp_origin
        );
        if not cached {
            return cached;
        }
    }

    return cached;
}

impl finish_singlephase_extension(
    tstate: ptr[PyThreadState],
    mod: ptr[PyObject],
    cached: ptr[ExtensionsCacheValue],
    name: ptr[PyObject],
    modules: ptr[PyObject]
) -> i32 {
    index = _get_cached_module_index(cached);
    if _modules_by_index_set(tstate_interp(tstate), index, mod) < 0 {
        return -1;
    }

    if modules {
        if PyObject_SetItem(modules, name, mod) < 0 {
            return -1;
        }
    }

    return 0;
}

impl reload_singlephase_extension(
    tstate: ptr[PyThreadState],
    cached: ptr[ExtensionsCacheValue],
    info: ptr[ExtModuleLoaderInfo]
) -> ptr[PyObject] {
    def_ = cached.view(1)[0].module_def;
    mod = NULL;

    name_buf = PyUnicode_AsUTF8(info.view(1)[0].name);
    if _PyImport_CheckSubinterpIncompatibleExtensionAllowed(name_buf) < 0 {
        return NULL;
    }

    modules = get_modules_dict(tstate, True);
    if def_.view(1)[0].m_size == -1 {
        m_copy = get_cached_m_dict(cached, info.view(1)[0].name, info.view(1)[0].path);
        if not m_copy {
            return NULL;
        }
        mod = import_add_module(tstate, info.view(1)[0].name);
        if not mod {
            object_decref(m_copy);
            return NULL;
        }
        mdict = PyModule_GetDict(mod);
        if not mdict {
            object_decref(m_copy);
            object_decref(mod);
            return NULL;
        }
        rc = PyDict_Update(mdict, m_copy);
        object_decref(m_copy);
        if rc < 0 {
            object_decref(mod);
            return NULL;
        }
    } else {
        p0 = ptr(int(def_.view(1)[0].m_base.m_init));
        if not p0 {
            return NULL;
        }
        scratch: own ImportScratch = ImportScratch();
        res = ptr[ExtModuleLoaderResult](jacpy_stack_address(&mut scratch));
        if _PyImport_RunModInitFunc(p0, info, res) < 0 {
            _Py_ext_module_loader_result_apply_error(res, name_buf);
            return NULL;
        }
        mod = res.view(1)[0].module;
        _Py_ext_module_loader_result_clear(res);
        if info.view(1)[0].filename {
            if PyModule_AddObjectRef(mod, ptr[u8]("__file__"), info.view(1)[0].filename)
                < 0 {
                PyErr_Clear();
            }
        }
        if PyObject_SetItem(modules, info.view(1)[0].name, mod) == -1 {
            object_decref(mod);
            return NULL;
        }
    }

    index = _get_cached_module_index(cached);
    if _modules_by_index_set(tstate_interp(tstate), index, mod) < 0 {
        PyObject_DelItem(modules, info.view(1)[0].name);
        object_decref(mod);
        return NULL;
    }

    return mod;
}

impl import_find_extension(
    tstate: ptr[PyThreadState], info: ptr[ExtModuleLoaderInfo]
) -> tuple[ptr[PyObject], ptr[u8]] {
    cached = _extensions_cache_get(info.view(1)[0].path, info.view(1)[0].name);
    if not cached {
        return (NULL, ptr[u8]());
    }

    name_buf = PyUnicode_AsUTF8(info.view(1)[0].name);
    if _PyImport_CheckSubinterpIncompatibleExtensionAllowed(name_buf) < 0 {
        return (NULL, ptr[u8](cached));
    }

    mod = reload_singlephase_extension(tstate, cached, info);
    if not mod {
        return (NULL, ptr[u8](cached));
    }

    if config_verbose(tstate_interp(tstate)) != 0 {
        PySys_FormatStderr(
            "import %U # previously loaded (%R)\n",
            info.view(1)[0].name,
            info.view(1)[0].path
        );
    }

    return (mod, ptr[u8](cached));
}

impl import_run_extension(
    tstate: ptr[PyThreadState],
    p0: ptr,
    info: ptr[ExtModuleLoaderInfo],
    spec: ptr[PyObject],
    modules: ptr[PyObject]
) -> ptr[PyObject] {
    mod = NULL;
    def_ = ptr[ModuleDef]();
    cached = ptr[ExtensionsCacheValue]();
    name_buf = bytes_data(info.view(1)[0].name_encoded);

    switched = False;
    main_tstate = switch_to_main_interpreter(tstate);
    if not main_tstate {
        return NULL;
    } elif main_tstate != tstate {
        switched = True;
    }

    scratch: own ImportScratch = ImportScratch();
    res = ptr[ExtModuleLoaderResult](jacpy_stack_address(&mut scratch));
    rc = _PyImport_RunModInitFunc(p0, info, res);
    if rc >= 0 {
        mod = res.view(1)[0].module;
        res.view(1)[0].module = NULL;
        def_ = ptr[ModuleDef](res.view(1)[0].module_def);

        if res.view(1)[0].kind == EXT_MODULE_KIND_SINGLEPHASE {
            if info.view(1)[0].filename {
                filename = NULL;
                if switched {
                    filename = _PyUnicode_Copy(info.view(1)[0].filename);
                    if not filename {
                        return NULL;
                    }
                } else {
                    filename = object_new_ref(info.view(1)[0].filename);
                }
                _PyUnicode_InternImmortal(current_interp(), &mut filename);

                if PyModule_AddObjectRef(mod, ptr[u8]("__file__"), filename) < 0 {
                    PyErr_Clear();
                }
            }

            sp_m_init = ptr();
            sp_m_dict = NULL;
            if def_.view(1)[0].m_size == -1 {
                sp_m_dict = PyModule_GetDict(mod);
            } else {
                sp_m_init = p0;
            }
            cached = update_global_state_for_extension(
                main_tstate,
                info.view(1)[0].path,
                info.view(1)[0].name,
                def_,
                sp_m_init,
                def_.view(1)[0].m_base.m_index,
                sp_m_dict,
                info.view(1)[0].origin
            );
        }
    }

    if rc < 0 {
        _Py_ext_module_loader_result_apply_error(res, name_buf);
    }

    if switched {
        if rc < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception while importing from subinterpreter")
            );
        }
        switch_back_from_main_interpreter(tstate, main_tstate, mod);
        mod = NULL;
        if rc < 0 {
            PyErr_SetString(
                PyExc_ImportError,
                ptr[u8]("failed to import from subinterpreter due to exception")
            );
            _Py_ext_module_loader_result_clear(res);
            return NULL;
        }
    }

    if rc < 0 {
        object_xdecref(mod);
        _Py_ext_module_loader_result_clear(res);
        return NULL;
    }

    if res.view(1)[0].kind == EXT_MODULE_KIND_SINGLEPHASE and not cached {
        object_xdecref(mod);
        _Py_ext_module_loader_result_clear(res);
        return NULL;
    }

    if res.view(1)[0].kind == EXT_MODULE_KIND_MULTIPHASE {
        mod = PyModule_FromDefAndSpec2(
            ptr[PyModuleDef](def_), spec, PYTHON_API_VERSION
        );
        if not mod {
            _Py_ext_module_loader_result_clear(res);
            return NULL;
        }
    } else {
        if _PyImport_CheckSubinterpIncompatibleExtensionAllowed(name_buf) < 0 {
            object_xdecref(mod);
            _Py_ext_module_loader_result_clear(res);
            return NULL;
        }
        if switched {
            mod = reload_singlephase_extension(tstate, cached, info);
            if not mod {
                _Py_ext_module_loader_result_clear(res);
                return NULL;
            }
        } else {
            modules_dict = get_modules_dict(tstate, True);
            if finish_singlephase_extension(
                tstate, mod, cached, info.view(1)[0].name, modules_dict
            )
                < 0 {
                object_xdecref(mod);
                _Py_ext_module_loader_result_clear(res);
                return NULL;
            }
        }
    }

    _Py_ext_module_loader_result_clear(res);
    return mod;
}

impl clear_singlephase_extension(
    interp: ptr[u8], name: ptr[PyObject], path: ptr[PyObject]
) -> i32 {
    cached = _extensions_cache_get(path, name);
    if not cached {
        if PyErr_Occurred() {
            return -1;
        }
        return 0;
    }
    def_ = cached.view(1)[0].module_def;

    def_.view(1)[0].m_base.m_init = 0;
    old = def_.view(1)[0].m_base.m_copy;
    def_.view(1)[0].m_base.m_copy = NULL;
    object_xdecref(old);
    def_.view(1)[0].m_base.m_index = 0;

    index = _get_cached_module_index(cached);
    if not _modules_by_index_check(interp, index) {
        if _modules_by_index_clear_one(interp, index) < 0 {
            return -1;
        }
    }

    tstate = thread_state();
    main_tstate = switch_to_main_interpreter(tstate);
    if not main_tstate {
        return -1;
    }

    _extensions_cache_delete(path, name);

    if main_tstate != tstate {
        switch_back_from_main_interpreter(tstate, main_tstate, NULL);
    }

    return 0;
}

impl is_builtin(name: ptr[PyObject]) -> i32 {
    inittab = builtin_inittab();
    i: i64 = 0;
    while (inittab + i).view(1)[0].name {
        if _PyUnicode_EqualToASCIIString(name, (inittab + i).view(1)[0].name) != 0 {
            if not (inittab + i).view(1)[0].initfunc {
                return -1;
            }
            return 1;
        }
        i += 1;
    }
    return 0;
}

impl create_builtin(
    tstate: ptr[PyThreadState], name: ptr[PyObject], spec: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own ImportScratch = ImportScratch();
    info = ptr[ExtModuleLoaderInfo](jacpy_stack_address(&mut scratch));
    if _Py_ext_module_loader_info_init_for_builtin(info, name) < 0 {
        return NULL;
    }

    (mod, cached_raw) = import_find_extension(tstate, info);
    if mod or exception_raised(tstate) {
        _Py_ext_module_loader_info_clear(info);
        return mod;
    }

    if cached_raw {
        _extensions_cache_delete(info.view(1)[0].path, info.view(1)[0].name);
    }

    found = ptr[_inittab]();
    p = builtin_inittab();
    while p.view(1)[0].name {
        if _PyUnicode_EqualToASCIIString(info.view(1)[0].name, p.view(1)[0].name)
            != 0 {
            found = p;
        }
        p = p + 1;
    }
    if not found {
        _Py_ext_module_loader_info_clear(info);
        return object_new_ref(Py_None);
    }

    p0 = found.view(1)[0].initfunc;
    if not p0 {
        mod = import_add_module(tstate, info.view(1)[0].name);
        _Py_ext_module_loader_info_clear(info);
        return mod;
    }

    mod = import_run_extension(tstate, p0, info, spec, get_modules_dict(tstate, True));

    _Py_ext_module_loader_info_clear(info);
    return mod;
}

impl init_builtin_modules_table -> i32 {
    size: u64 = 0;
    table = pyimport_inittab_slot().view(1)[0];
    while (table + i64(size)).view(1)[0].name {
        size += u64(1);
    }
    size += u64(1);

    entry_size = u64(_inittab_SIZE);
    copied = ptr[_inittab](_PyMem_DefaultRawMalloc(size * entry_size));
    if not copied {
        return -1;
    }
    memcpy(copied, table, size * entry_size);
    set_builtin_inittab(copied);
    return 0;
}

impl clear_inittab_copy {
    _PyMem_DefaultRawFree(inittab_copy_slot().view(1)[0]);
    inittab_copy_slot().view(1)[0] = ptr[_inittab]();
}

impl fini_builtin_modules_table {
    inittab = builtin_inittab();
    set_builtin_inittab(ptr[_inittab]());
    _PyMem_DefaultRawFree(inittab);
}
