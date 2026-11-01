import from c {
    obj FrozenInfo {
        has nameobj: ptr[PyObject],
            data: ptr[u8],
            size: i64,
            is_package: bool,
            is_alias: bool,
            origname: ptr[u8];
    }  obj ImportStack {
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
    }  def jacpy_stack_address(slots: &mut ImportStack) -> int;  def jacpy_stdio_stream(
        stream: i32
    ) -> ptr;  def fputs(text: ptr[u8], stream: ptr) -> i32;  def fprintf(
        stream: ptr, format: ptr[u8], *args: any
    ) -> i32;  def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def _PyInterpreterState_GetConfig(
        interp: ptr[u8]
    ) -> ptr[u8];  def _PyTime_AsMicroseconds(t: i64, round: i32) -> i64;  def _PySys_GetRequiredAttrString(
        name: ptr[u8]
    ) -> ptr[PyObject];  def _PySys_ClearAttrString(
        interp: ptr[u8], name: ptr[u8], verbose: i32
    ) -> i32;  def PyMarshal_ReadObjectFromString(
        data: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyStatus_NoMemory -> PyStatus;  def _PyErr_Print(
        tstate: ptr[PyThreadState]
    );  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def _PySys_Audit(
        tstate: ptr[PyThreadState], event: ptr[u8], format_: ptr[u8], *args: any
    ) -> i32;  def _PySys_GetOptionalAttrString(
        name: ptr[u8], value: &mut ptr[PyObject]
    ) -> i32;  def PySys_FormatStderr(format: ptr[u8], *args: any);  def PySys_WriteStderr(
        format: ptr[u8], *args: any
    );  glob _PyImport_FrozenBootstrap: ptr[_frozen],
         _PyImport_FrozenStdlib: ptr[_frozen],
         _PyImport_FrozenTest: ptr[_frozen],
         PyImport_FrozenModules: ptr[_frozen],
         _PyImport_FrozenAliases: ptr[_module_alias],
         PyImport_Inittab: ptr[_inittab],
         PyExc_ImportWarning: ptr[PyObject]; def PyImport_ExecCodeModule(
        name: ptr[u8], co: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyImport_ExecCodeModuleWithPathnames(name, co, ptr[u8](), ptr[u8]());
    }  def PyImport_ExecCodeModuleEx(
        name: ptr[u8], co: ptr[PyObject], pathname: ptr[u8]
    ) -> ptr[PyObject] {
        return PyImport_ExecCodeModuleWithPathnames(name, co, pathname, ptr[u8]());
    }  def PyImport_ExecCodeModuleWithPathnames(
        name: ptr[u8], co: ptr[PyObject], pathname: ptr[u8], cpathname: ptr[u8]
    ) -> ptr[PyObject] {
        nameobj = PyUnicode_FromString(name);
        if not nameobj {
            return NULL;
        }
        cpathobj = NULL;
        pathobj = NULL;
        if cpathname {
            cpathobj = PyUnicode_DecodeFSDefault(cpathname);
            if not cpathobj {
                object_decref(nameobj);
                return NULL;
            }
        }
        if pathname {
            pathobj = PyUnicode_DecodeFSDefault(pathname);
            if not pathobj {
                object_decref(nameobj);
                object_xdecref(cpathobj);
                return NULL;
            }
        } elif cpathobj {
            interp = current_interp();
            if not interp {
                _Py_FatalErrorFunc(
                    ptr[u8]("PyImport_ExecCodeModuleWithPathnames"),
                    ptr[u8]("no current interpreter")
                );
            }
            external = PyObject_GetAttrString(
                importlib_of(interp), ptr[u8]("_bootstrap_external")
            );
            if external {
                pathobj = PyObject_CallMethodObjArgs(
                    external, py_id(_Py_ID__get_sourcefile), cpathobj, NULL
                );
                object_decref(external);
            }
            if not pathobj {
                PyErr_Clear();
            }
        }
        m = PyImport_ExecCodeModuleObject(nameobj, co, pathobj, cpathobj);
        object_decref(nameobj);
        object_xdecref(pathobj);
        object_xdecref(cpathobj);
        return m;
    }  def PyImport_ExecCodeModuleObject(
        name: ptr[PyObject],
        co: ptr[PyObject],
        pathname: ptr[PyObject],
        cpathname: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = current_tstate();
        d = module_dict_for_exec(tstate, name);
        if not d {
            return NULL;
        }
        path = pathname;
        if not path {
            path = code_field(co, PyCodeObject_FILENAME).view(1)[0];
        }
        external = PyObject_GetAttrString(
            importlib_of(tstate_interp(tstate)), ptr[u8]("_bootstrap_external")
        );
        if not external {
            object_decref(d);
            return NULL;
        }
        res = PyObject_CallMethodObjArgs(
            external, py_id(_Py_ID__fix_up_module), d, name, path, cpathname, NULL
        );
        object_decref(external);
        if res {
            object_decref(res);
            res = exec_code_in_module(tstate, name, d, co);
        }
        object_decref(d);
        return res;
    }  def PyImport_ImportFrozenModuleObject(name: ptr[PyObject]) -> i32 {
        tstate = current_tstate();
        slots: own ImportStack = ImportStack();
        info = ptr[FrozenInfo](jacpy_stack_address(&mut slots));
        status = find_frozen(name, info);
        if status == FROZEN_NOT_FOUND or status == FROZEN_DISABLED {
            return 0;
        } elif status == FROZEN_BAD_NAME {
            return 0;
        } elif status != FROZEN_OKAY {
            set_frozen_error(status, name);
            return -1;
        }
        co = unmarshal_frozen_code(tstate_interp(tstate), info);
        if not co {
            return -1;
        }
        if info.view(1)[0].is_package {
            m = import_add_module(tstate, name);
            if not m {
                object_decref(co);
                return -1;
            }
            package_dict = PyModule_GetDict(m);
            l = PyList_New(0);
            if not l {
                object_decref(m);
                object_decref(co);
                return -1;
            }
            err = PyDict_SetItemString(package_dict, ptr[u8]("__path__"), l);
            object_decref(l);
            object_decref(m);
            if err != 0 {
                object_decref(co);
                return -1;
            }
        }
        d = module_dict_for_exec(tstate, name);
        if not d {
            object_decref(co);
            return -1;
        }
        m = exec_code_in_module(tstate, name, d, co);
        if not m {
            object_decref(d);
            object_decref(co);
            return -1;
        }
        object_decref(m);
        origname = NULL;
        if info.view(1)[0].origname {
            origname = PyUnicode_FromString(info.view(1)[0].origname);
            if not origname {
                object_decref(d);
                object_decref(co);
                return -1;
            }
        } else {
            origname = object_new_ref(Py_None);
        }
        err = PyDict_SetItemString(d, ptr[u8]("__origname__"), origname);
        object_decref(origname);
        if err != 0 {
            object_decref(d);
            object_decref(co);
            return -1;
        }
        object_decref(d);
        object_decref(co);
        return 1;
    }  def PyImport_ImportFrozenModule(name: ptr[u8]) -> i32 {
        nameobj = PyUnicode_InternFromString(name);
        if not nameobj {
            return -1;
        }
        ret = PyImport_ImportFrozenModuleObject(nameobj);
        object_decref(nameobj);
        return ret;
    }  def _PyImport_GetImportlibLoader(
        interp: ptr[u8], loader_name: ptr[u8]
    ) -> ptr[PyObject] {
        return PyObject_GetAttrString(importlib_of(interp), loader_name);
    }  def _PyImport_GetImportlibExternalLoader(
        interp: ptr[u8], loader_name: ptr[u8]
    ) -> ptr[PyObject] {
        bootstrap = PyObject_GetAttrString(
            importlib_of(interp), ptr[u8]("_bootstrap_external")
        );
        if not bootstrap {
            return NULL;
        }
        loader_type = PyObject_GetAttrString(bootstrap, loader_name);
        object_decref(bootstrap);
        return loader_type;
    }  def _PyImport_BlessMyLoader(
        interp: ptr[u8], module_globals: ptr[PyObject]
    ) -> ptr[PyObject] {
        external = PyObject_GetAttrString(
            importlib_of(interp), ptr[u8]("_bootstrap_external")
        );
        if not external {
            return NULL;
        }
        loader = PyObject_CallMethod(
            external, "_bless_my_loader", "O", module_globals, NULL
        );
        object_decref(external);
        return loader;
    }  def _PyImport_ImportlibModuleRepr(
        interp: ptr[u8], m: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyObject_CallMethod(importlib_of(interp), "_module_repr", "O", m);
    }  def PyImport_GetImporter(path: ptr[PyObject]) -> ptr[PyObject] {
        tstate = current_tstate();
        path_importer_cache = _PySys_GetRequiredAttrString(
            ptr[u8]("path_importer_cache")
        );
        if not path_importer_cache {
            return NULL;
        }
        path_hooks = _PySys_GetRequiredAttrString(ptr[u8]("path_hooks"));
        if not path_hooks {
            object_decref(path_importer_cache);
            return NULL;
        }
        importer = get_path_importer(tstate, path_importer_cache, path_hooks, path);
        object_decref(path_hooks);
        object_decref(path_importer_cache);
        return importer;
    }  def _PyImport_InitDefaultImportFunc(interp: ptr[u8]) -> i32 {
        import_func: ptr[PyObject] = NULL;
        if PyDict_GetItemStringRef(
            interp_slot(interp, PyInterpreterState_BUILTINS).view(1)[0],
            ptr[u8]("__import__"),
            &mut import_func
        )
            <= 0 {
            return -1;
        }
        interp_slot(interp, PyInterpreterState_IMPORTS_IMPORT_FUNC).view(1)[0] = import_func;
        return 0;
    }  def _PyImport_IsDefaultImportFunc(interp: ptr[u8], func: ptr[PyObject]) -> i32 {
        if func == import_func_of(interp) {
            return 1;
        }
        return 0;
    }  def PyImport_ImportModule(name: ptr[u8]) -> ptr[PyObject] {
        pname = PyUnicode_FromString(name);
        if not pname {
            return NULL;
        }
        result = PyImport_Import(pname);
        object_decref(pname);
        return result;
    }  def PyImport_ImportModuleNoBlock(name: ptr[u8]) -> ptr[PyObject] {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            ptr[u8](
                "PyImport_ImportModuleNoBlock() is deprecated and scheduled for removal in Python 3.15. Use PyImport_ImportModule() instead."
            ),
            1
        )
            != 0 {
            return NULL;
        }
        return PyImport_ImportModule(name);
    }  def PyImport_ImportModuleLevelObject(
        name: ptr[PyObject],
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        fromlist: ptr[PyObject],
        level: i32
    ) -> ptr[PyObject] {
        tstate = current_tstate();
        interp = tstate_interp(tstate);
        if not name {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("Empty module name"));
            return import_level_done(tstate, NULL, NULL, NULL);
        }
        if not unicode_check(name) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("module name must be a string"));
            return import_level_done(tstate, NULL, NULL, NULL);
        }
        if level < 0 {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("level must be >= 0"));
            return import_level_done(tstate, NULL, NULL, NULL);
        }
        abs_name = NULL;
        if level > 0 {
            abs_name = resolve_name(tstate, name, globals, level);
            if not abs_name {
                return import_level_done(tstate, NULL, NULL, NULL);
            }
        } else {
            if unicode_length(name) == 0 {
                PyErr_SetString(PyExc_ValueError, ptr[u8]("Empty module name"));
                return import_level_done(tstate, NULL, NULL, NULL);
            }
            abs_name = object_new_ref(name);
        }
        mod = import_get_module(tstate, abs_name);
        if not mod and exception_raised(tstate) {
            return import_level_done(tstate, abs_name, NULL, NULL);
        }
        if mod and mod != Py_None {
            if import_ensure_initialized(interp, mod, abs_name) < 0 {
                return import_level_done(tstate, abs_name, mod, NULL);
            }
            mod_check = import_get_module(tstate, abs_name);
            if mod_check != mod {
                object_xdecref(mod_check);
                if exception_raised(tstate) {
                    return import_level_done(tstate, abs_name, mod, NULL);
                }
                object_decref(mod);
                mod = import_find_and_load(tstate, abs_name);
                if not mod {
                    return import_level_done(tstate, abs_name, NULL, NULL);
                }
            } else {
                object_decref(mod_check);
            }
        } else {
            object_xdecref(mod);
            mod = import_find_and_load(tstate, abs_name);
            if not mod {
                return import_level_done(tstate, abs_name, NULL, NULL);
            }
        }
        has_from: i32 = 0;
        if fromlist and fromlist != Py_None {
            has_from = PyObject_IsTrue(fromlist);
            if has_from < 0 {
                return import_level_done(tstate, abs_name, mod, NULL);
            }
        }
        final_mod = NULL;
        if has_from == 0 {
            length = unicode_length(name);
            if level == 0 or length > 0 {
                dot = PyUnicode_FindChar(name, u32(46), 0, length, 1);
                if dot == -2 {
                    return import_level_done(tstate, abs_name, mod, NULL);
                }
                if dot == -1 {
                    final_mod = object_new_ref(mod);
                    return import_level_done(tstate, abs_name, mod, final_mod);
                }
                if level == 0 {
                    front = PyUnicode_Substring(name, 0, dot);
                    if not front {
                        return import_level_done(tstate, abs_name, mod, NULL);
                    }
                    final_mod = PyImport_ImportModuleLevelObject(
                        front, NULL, NULL, NULL, 0
                    );
                    object_decref(front);
                } else {
                    cut_off = length - dot;
                    abs_name_len = unicode_length(abs_name);
                    to_return = PyUnicode_Substring(
                        abs_name, 0, abs_name_len - cut_off
                    );
                    if not to_return {
                        return import_level_done(tstate, abs_name, mod, NULL);
                    }
                    final_mod = import_get_module(tstate, to_return);
                    if not final_mod {
                        if not exception_raised(tstate) {
                            PyErr_Format(
                                PyExc_KeyError,
                                ptr[u8]("%R not in sys.modules as expected"),
                                to_return
                            );
                        }
                        object_decref(to_return);
                        return import_level_done(tstate, abs_name, mod, NULL);
                    }
                    object_decref(to_return);
                }
            } else {
                final_mod = object_new_ref(mod);
            }
        } else {
            has_path = PyObject_HasAttrWithError(mod, py_id(_Py_ID___path__));
            if has_path < 0 {
                return import_level_done(tstate, abs_name, mod, NULL);
            }
            if has_path != 0 {
                final_mod = PyObject_CallMethodObjArgs(
                    importlib_of(interp),
                    py_id(_Py_ID__handle_fromlist),
                    mod,
                    fromlist,
                    import_func_of(interp),
                    NULL
                );
            } else {
                final_mod = object_new_ref(mod);
            }
        }
        return import_level_done(tstate, abs_name, mod, final_mod);
    }  def PyImport_ImportModuleLevel(
        name: ptr[u8],
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        fromlist: ptr[PyObject],
        level: i32
    ) -> ptr[PyObject] {
        nameobj = PyUnicode_FromString(name);
        if not nameobj {
            return NULL;
        }
        mod = PyImport_ImportModuleLevelObject(
            nameobj, globals, locals, fromlist, level
        );
        object_decref(nameobj);
        return mod;
    }  def PyImport_ReloadModule(m: ptr[PyObject]) -> ptr[PyObject] {
        importlib = PyImport_GetModule(py_id(_Py_ID_importlib));
        if not importlib {
            if PyErr_Occurred() {
                return NULL;
            }
            importlib = PyImport_ImportModule(ptr[u8]("importlib"));
            if not importlib {
                return NULL;
            }
        }
        reloaded_module = PyObject_CallMethodObjArgs(
            importlib, py_id(_Py_ID_reload), m, NULL
        );
        object_decref(importlib);
        return reloaded_module;
    }  def PyImport_Import(module_name: ptr[PyObject]) -> ptr[PyObject] {
        tstate = current_tstate();
        slots: own ImportStack = ImportStack();
        globals = NULL;
        builtins = NULL;
        import_fn = NULL;
        from_list = PyList_New(0);
        if not from_list {
            return import_done(globals, builtins, import_fn, from_list, NULL);
        }
        globals = PyEval_GetGlobals();
        if globals {
            object_incref(globals);
            builtins = PyObject_GetItem(globals, py_id(_Py_ID___builtins__));
            if not builtins {
                return import_done(globals, builtins, import_fn, from_list, NULL);
            }
        } elif exception_raised(tstate) {
            return import_done(globals, builtins, import_fn, from_list, NULL);
        } else {
            globals = PyDict_New();
            if not globals {
                return import_done(globals, builtins, import_fn, from_list, NULL);
            }
            p_builtins = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
            status = _PyEval_EnsureBuiltinsWithModule(tstate, globals, p_builtins);
            builtins = p_builtins.view(1)[0];
            if status < 0 {
                return import_done(globals, builtins, import_fn, from_list, NULL);
            }
        }
        if dict_check(builtins) {
            import_fn = PyObject_GetItem(builtins, py_id(_Py_ID___import__));
            if not import_fn {
                _PyErr_SetObject(tstate, PyExc_KeyError, py_id(_Py_ID___import__));
            }
        } else {
            import_fn = PyObject_GetAttr(builtins, py_id(_Py_ID___import__));
        }
        if not import_fn {
            return import_done(globals, builtins, import_fn, from_list, NULL);
        }
        r = PyObject_CallFunction(
            import_fn, "OOOOi", module_name, globals, globals, from_list, i32(0), NULL
        );
        if not r {
            return import_done(globals, builtins, import_fn, from_list, NULL);
        }
        object_decref(r);
        r = import_get_module(tstate, module_name);
        if not r and not exception_raised(tstate) {
            _PyErr_SetObject(tstate, PyExc_KeyError, module_name);
        }
        return import_done(globals, builtins, import_fn, from_list, r);
    }  def _PyImport_Init -> PyStatus {
        if builtin_inittab() {
            return status_err(
                ptr[u8]("_PyImport_Init"),
                ptr[u8]("global import state already initialized")
            );
        }
        if init_builtin_modules_table() != 0 {
            return PyStatus_NoMemory();
        }
        return status_ok();
    }  def _PyImport_Fini {
        _extensions_cache_clear_all();
        fini_builtin_modules_table();
    }  def _PyImport_Fini2 {
        addressof(PyImport_Inittab).view(1)[0] = ptr[_inittab](
            addressof(_PyImport_Inittab)
        );
        clear_inittab_copy();
    }  def _PyImport_InitCore(
        tstate: ptr[PyThreadState], sysmod: ptr[PyObject], importlib: i32
    ) -> PyStatus {
        if importlib != 0 {
            if init_importlib(tstate, sysmod) < 0 {
                return status_err(
                    ptr[u8]("_PyImport_InitCore"),
                    ptr[u8]("failed to initialize importlib")
                );
            }
        }
        return status_ok();
    }  def _PyImport_IsInitialized(interp: ptr[u8]) -> i32 {
        if not interp_slot(interp, PyInterpreterState_IMPORTS_MODULES).view(1)[0] {
            return 0;
        }
        return 1;
    }  def _PyImport_ClearCore(interp: ptr[u8]) {
        clear_slot(interp_slot(interp, PyInterpreterState_IMPORTS_MODULES));
        clear_slot(interp_slot(interp, PyInterpreterState_IMPORTS_MODULES_BY_INDEX));
        clear_slot(interp_slot(interp, PyInterpreterState_IMPORTS_IMPORTLIB));
        clear_slot(interp_slot(interp, PyInterpreterState_IMPORTS_IMPORT_FUNC));
    }  def _PyImport_FiniCore(interp: ptr[u8]) {
        verbose = config_verbose(interp);
        if _PySys_ClearAttrString(interp, ptr[u8]("meta_path"), verbose) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing sys.meta_path")
            );
        }
        if _PySys_ClearAttrString(interp, ptr[u8]("modules"), verbose) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing sys.modules")
            );
        }
        _PyImport_ClearCore(interp);
    }  def _PyImport_InitExternal(tstate: ptr[PyThreadState]) -> PyStatus {
        interp = tstate_interp(tstate);
        verbose = config_verbose(interp);
        if init_importlib_external(interp) != 0 {
            _PyErr_Print(tstate);
            return status_err(
                ptr[u8]("_PyImport_InitExternal"),
                ptr[u8]("external importer setup failed")
            );
        }
        if init_zipimport(tstate, verbose) != 0 {
            PyErr_Print();
            return status_err(
                ptr[u8]("_PyImport_InitExternal"),
                ptr[u8]("initializing zipimport failed")
            );
        }
        return status_ok();
    }  def _PyImport_FiniExternal(interp: ptr[u8]) {
        verbose = config_verbose(interp);
        if _PySys_ClearAttrString(interp, ptr[u8]("path_importer_cache"), verbose)
            < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing sys.path_importer_cache")
            );
        }
        if _PySys_ClearAttrString(interp, ptr[u8]("path_hooks"), verbose) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing sys.path_hooks")
            );
        }
    }  def PyImport_ImportModuleAttr(
        modname: ptr[PyObject], attrname: ptr[PyObject]
    ) -> ptr[PyObject] {
        mod = PyImport_Import(modname);
        if not mod {
            return NULL;
        }
        result = PyObject_GetAttr(mod, attrname);
        object_decref(mod);
        return result;
    }  def PyImport_ImportModuleAttrString(
        modname: ptr[u8], attrname: ptr[u8]
    ) -> ptr[PyObject] {
        pmodname = PyUnicode_FromString(modname);
        if not pmodname {
            return NULL;
        }
        pattrname = PyUnicode_FromString(attrname);
        if not pattrname {
            object_decref(pmodname);
            return NULL;
        }
        result = PyImport_ImportModuleAttr(pmodname, pattrname);
        object_decref(pattrname);
        object_decref(pmodname);
        return result;
    }
}

glob FROZEN_OKAY: Final[i32] = 0,
     FROZEN_BAD_NAME: Final[i32] = 1,
     FROZEN_NOT_FOUND: Final[i32] = 2,
     FROZEN_DISABLED: Final[i32] = 3,
     FROZEN_EXCLUDED: Final[i32] = 4,
     FROZEN_INVALID: Final[i32] = 5;

def tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def interp_slot(interp: ptr[u8], offset: i64) -> ptr[ptr[PyObject]];

def importlib_of(interp: ptr[u8]) -> ptr[PyObject];

def import_func_of(interp: ptr[u8]) -> ptr[PyObject];

def config_verbose(interp: ptr[u8]) -> i32;

def code_field(co: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]];

def clear_slot(slot: ptr[ptr[PyObject]]);

def module_dict_for_exec(
    tstate: ptr[PyThreadState], name: ptr[PyObject]
) -> ptr[PyObject];

def exec_code_in_module(
    tstate: ptr[PyThreadState],
    name: ptr[PyObject],
    module_dict: ptr[PyObject],
    code_object: ptr[PyObject]
) -> ptr[PyObject];

def update_code_filenames(
    co: ptr[PyObject], oldname: ptr[PyObject], newname: ptr[PyObject]
);

def update_compiled_module(co: ptr[PyObject], newname: ptr[PyObject]);

def resolve_module_alias(
    name: ptr[u8], aliases: ptr[_module_alias]
) -> tuple[bool, ptr[u8]];

def use_frozen -> bool;

def append_frozen_names(names: ptr[PyObject], table: ptr[_frozen]) -> bool;

def list_frozen_module_names -> ptr[PyObject];

def set_frozen_error(status: i32, modname: ptr[PyObject]);

def search_frozen(table: ptr[_frozen], name: ptr[u8]) -> ptr[_frozen];

def look_up_frozen(name: ptr[u8]) -> ptr[_frozen];

def find_frozen(nameobj: ptr[PyObject], info: ptr[FrozenInfo]) -> i32;

def unmarshal_frozen_code(interp: ptr[u8], info: ptr[FrozenInfo]) -> ptr[PyObject];

def bootstrap_imp(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def init_importlib(tstate: ptr[PyThreadState], sysmod: ptr[PyObject]) -> i32;

def init_importlib_external(interp: ptr[u8]) -> i32;

def get_path_importer(
    tstate: ptr[PyThreadState],
    path_importer_cache: ptr[PyObject],
    path_hooks: ptr[PyObject],
    p: ptr[PyObject]
) -> ptr[PyObject];

def remove_importlib_frames(tstate: ptr[PyThreadState]);

def resolve_name_fail(spec: ptr[PyObject], package: ptr[PyObject]) -> ptr[PyObject];

def resolve_name_no_parent(
    spec: ptr[PyObject], package: ptr[PyObject]
) -> ptr[PyObject];

def resolve_name(
    tstate: ptr[PyThreadState], name: ptr[PyObject], globals: ptr[PyObject], level: i32
) -> ptr[PyObject];

def import_find_and_load(
    tstate: ptr[PyThreadState], abs_name: ptr[PyObject]
) -> ptr[PyObject];

def import_level_done(
    tstate: ptr[PyThreadState],
    abs_name: ptr[PyObject],
    mod: ptr[PyObject],
    final_mod: ptr[PyObject]
) -> ptr[PyObject];

def import_done(
    globals: ptr[PyObject],
    builtins: ptr[PyObject],
    import_fn: ptr[PyObject],
    from_list: ptr[PyObject],
    r: ptr[PyObject]
) -> ptr[PyObject];

def init_zipimport(tstate: ptr[PyThreadState], verbose: i32) -> i32;

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl interp_slot(interp: ptr[u8], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](interp + offset);
}

impl importlib_of(interp: ptr[u8]) -> ptr[PyObject] {
    return interp_slot(interp, PyInterpreterState_IMPORTS_IMPORTLIB).view(1)[0];
}

impl import_func_of(interp: ptr[u8]) -> ptr[PyObject] {
    return interp_slot(interp, PyInterpreterState_IMPORTS_IMPORT_FUNC).view(1)[0];
}

impl config_verbose(interp: ptr[u8]) -> i32 {
    return ptr[i32](_PyInterpreterState_GetConfig(interp) + PyConfig_VERBOSE).view(1)[
        0
    ];
}

impl code_field(co: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](co) + offset);
}

impl clear_slot(slot: ptr[ptr[PyObject]]) {
    old = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(old);
}

impl module_dict_for_exec(
    tstate: ptr[PyThreadState], name: ptr[PyObject]
) -> ptr[PyObject] {
    m = import_add_module(tstate, name);
    if not m {
        return NULL;
    }
    d = PyModule_GetDict(m);
    r = PyDict_Contains(d, py_id(_Py_ID___builtins__));
    if r == 0 {
        r = PyDict_SetItem(d, py_id(_Py_ID___builtins__), PyEval_GetBuiltins());
    }
    if r < 0 {
        remove_module(tstate, name);
        object_decref(m);
        return NULL;
    }
    object_incref(d);
    object_decref(m);
    return d;
}

impl exec_code_in_module(
    tstate: ptr[PyThreadState],
    name: ptr[PyObject],
    module_dict: ptr[PyObject],
    code_object: ptr[PyObject]
) -> ptr[PyObject] {
    v = PyEval_EvalCode(code_object, module_dict, module_dict);
    if not v {
        remove_module(tstate, name);
        return NULL;
    }
    object_decref(v);
    m = import_get_module(tstate, name);
    if not m and not exception_raised(tstate) {
        PyErr_Format(
            PyExc_ImportError,
            ptr[u8]("Loaded module %R not found in sys.modules"),
            name
        );
    }
    return m;
}

impl update_code_filenames(
    co: ptr[PyObject], oldname: ptr[PyObject], newname: ptr[PyObject]
) {
    filename = code_field(co, PyCodeObject_FILENAME);
    if PyUnicode_Compare(filename.view(1)[0], oldname) != 0 {
        return;
    }
    old = filename.view(1)[0];
    filename.view(1)[0] = object_new_ref(newname);
    object_xdecref(old);
    constants = code_field(co, PyCodeObject_CONSTS).view(1)[0];
    n = object_size(constants);
    i: i64 = 0;
    while i < n {
        tmp = tuple_get_item(constants, i);
        if code_check(tmp) {
            update_code_filenames(tmp, oldname, newname);
        }
        i += 1;
    }
}

impl update_compiled_module(co: ptr[PyObject], newname: ptr[PyObject]) {
    filename = code_field(co, PyCodeObject_FILENAME).view(1)[0];
    if PyUnicode_Compare(filename, newname) == 0 {
        return;
    }
    oldname = filename;
    object_incref(oldname);
    update_code_filenames(co, oldname, newname);
    object_decref(oldname);
}

impl resolve_module_alias(
    name: ptr[u8], aliases: ptr[_module_alias]
) -> tuple[bool, ptr[u8]] {
    i: i64 = 0;
    while True {
        cache_entry = (aliases + i).view(1)[0];
        if not cache_entry.name {
            return (False, ptr[u8]());
        }
        if strcmp(name, cache_entry.name) == 0 {
            return (True, cache_entry.orig);
        }
        i += 1;
    }
    return (False, ptr[u8]());
}

impl use_frozen -> bool {
    interp = current_interp();
    override_ = ptr[i32](
        interp + PyInterpreterState_IMPORTS_OVERRIDE_FROZEN_MODULES
    ).view(
        1
    )[0];
    if override_ > 0 {
        return True;
    } elif override_ < 0 {
        return False;
    }
    return ptr[i32](
        _PyInterpreterState_GetConfig(interp) + PyConfig_USE_FROZEN_MODULES
    ).view(
        1
    )[0]
        != 0;
}

impl append_frozen_names(names: ptr[PyObject], table: ptr[_frozen]) -> bool {
    i: i64 = 0;
    while True {
        name = (table + i).view(1)[0].name;
        if not name {
            return True;
        }
        nameobj = PyUnicode_FromString(name);
        if not nameobj {
            return False;
        }
        res = PyList_Append(names, nameobj);
        object_decref(nameobj);
        if res != 0 {
            return False;
        }
        i += 1;
    }
    return True;
}

impl list_frozen_module_names -> ptr[PyObject] {
    names = PyList_New(0);
    if not names {
        return NULL;
    }
    enabled = use_frozen();
    if not append_frozen_names(names, _PyImport_FrozenBootstrap) {
        object_decref(names);
        return NULL;
    }
    if enabled {
        if not append_frozen_names(names, _PyImport_FrozenStdlib) {
            object_decref(names);
            return NULL;
        }
        if not append_frozen_names(names, _PyImport_FrozenTest) {
            object_decref(names);
            return NULL;
        }
    }
    custom = PyImport_FrozenModules;
    if custom {
        i: i64 = 0;
        while (custom + i).view(1)[0].name {
            nameobj = PyUnicode_FromString((custom + i).view(1)[0].name);
            if not nameobj {
                object_decref(names);
                return NULL;
            }
            found = PySequence_Contains(names, nameobj);
            if found < 0 {
                object_decref(nameobj);
                object_decref(names);
                return NULL;
            } elif found != 0 {
                object_decref(nameobj);
            } else {
                res = PyList_Append(names, nameobj);
                object_decref(nameobj);
                if res != 0 {
                    object_decref(names);
                    return NULL;
                }
            }
            i += 1;
        }
    }
    return names;
}

impl set_frozen_error(status: i32, modname: ptr[PyObject]) {
    msg = NULL;
    if status == FROZEN_BAD_NAME or status == FROZEN_NOT_FOUND {
        msg = PyUnicode_FromFormat("No such frozen object named %R", modname);
    } elif status == FROZEN_DISABLED {
        msg = PyUnicode_FromFormat(
            "Frozen modules are disabled and the frozen object named %R is not essential",
            modname
        );
    } elif status == FROZEN_EXCLUDED {
        msg = PyUnicode_FromFormat("Excluded frozen object named %R", modname);
    } elif status == FROZEN_INVALID {
        msg = PyUnicode_FromFormat("Frozen object named %R is invalid", modname);
    } else {
        return;
    }
    if not msg {
        PyErr_Clear();
    }
    PyErr_SetImportError(msg, modname, NULL);
    object_xdecref(msg);
}

impl search_frozen(table: ptr[_frozen], name: ptr[u8]) -> ptr[_frozen] {
    i: i64 = 0;
    while True {
        p = table + i;
        if not p.view(1)[0].name {
            return ptr[_frozen]();
        }
        if strcmp(name, p.view(1)[0].name) == 0 {
            return p;
        }
        i += 1;
    }
    return ptr[_frozen]();
}

impl look_up_frozen(name: ptr[u8]) -> ptr[_frozen] {
    p = search_frozen(_PyImport_FrozenBootstrap, name);
    if p {
        return p;
    }
    custom = PyImport_FrozenModules;
    if custom {
        p = search_frozen(custom, name);
        if p {
            return p;
        }
    }
    if use_frozen() {
        p = search_frozen(_PyImport_FrozenStdlib, name);
        if p {
            return p;
        }
        p = search_frozen(_PyImport_FrozenTest, name);
        if p {
            return p;
        }
    }
    return ptr[_frozen]();
}

impl find_frozen(nameobj: ptr[PyObject], info: ptr[FrozenInfo]) -> i32 {
    if info {
        info.view(1)[0].nameobj = NULL;
        info.view(1)[0].data = ptr[u8]();
        info.view(1)[0].size = 0;
        info.view(1)[0].is_package = False;
        info.view(1)[0].is_alias = False;
        info.view(1)[0].origname = ptr[u8]();
    }
    if not nameobj or nameobj == Py_None {
        return FROZEN_BAD_NAME;
    }
    name = _PyUnicode_AsUTF8NoNUL(nameobj);
    if not name {
        PyErr_Clear();
        return FROZEN_BAD_NAME;
    }
    p = look_up_frozen(name);
    if not p {
        return FROZEN_NOT_FOUND;
    }
    entry_size = i64(p.view(1)[0].size);
    if info {
        info.view(1)[0].nameobj = nameobj;
        info.view(1)[0].data = p.view(1)[0].code;
        info.view(1)[0].size = entry_size;
        info.view(1)[0].is_package = p.view(1)[0].is_package != 0;
        if entry_size < 0 {
            info.view(1)[0].size = -entry_size;
            info.view(1)[0].is_package = True;
        }
        (is_alias, orig) = resolve_module_alias(name, _PyImport_FrozenAliases);
        info.view(1)[0].is_alias = is_alias;
        info.view(1)[0].origname = orig if is_alias else name;
    }
    if not p.view(1)[0].code {
        return FROZEN_EXCLUDED;
    }
    if p.view(1)[0].code.view(1)[0] == u8(0) or entry_size == 0 {
        return FROZEN_INVALID;
    }
    return FROZEN_OKAY;
}

impl unmarshal_frozen_code(interp: ptr[u8], info: ptr[FrozenInfo]) -> ptr[PyObject] {
    co = PyMarshal_ReadObjectFromString(info.view(1)[0].data, info.view(1)[0].size);
    if not co {
        PyErr_Clear();
        set_frozen_error(FROZEN_INVALID, info.view(1)[0].nameobj);
        return NULL;
    }
    if not code_check(co) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("frozen object %R is not a code object"),
            info.view(1)[0].nameobj
        );
        object_decref(co);
        return NULL;
    }
    return co;
}

impl bootstrap_imp(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    name = PyUnicode_FromString(ptr[u8]("_imp"));
    if not name {
        return NULL;
    }
    attrs = Py_BuildValue(ptr[u8]("{sO}"), ptr[u8]("name"), name);
    if not attrs {
        object_decref(name);
        return NULL;
    }
    spec = _PyNamespace_New(attrs);
    object_decref(attrs);
    if not spec {
        object_decref(name);
        return NULL;
    }
    mod = create_builtin(tstate, name, spec);
    object_decref(name);
    object_decref(spec);
    if not mod {
        return NULL;
    }
    if exec_builtin_or_dynamic(mod) < 0 {
        object_decref(mod);
        return NULL;
    }
    return mod;
}

impl init_importlib(tstate: ptr[PyThreadState], sysmod: ptr[PyObject]) -> i32 {
    interp = tstate_interp(tstate);
    verbose = config_verbose(interp);
    if verbose != 0 {
        PySys_FormatStderr(ptr[u8]("import _frozen_importlib # frozen\n"));
    }
    if PyImport_ImportFrozenModule(ptr[u8]("_frozen_importlib")) <= 0 {
        return -1;
    }
    importlib = PyImport_AddModuleRef(ptr[u8]("_frozen_importlib"));
    if not importlib {
        return -1;
    }
    interp_slot(interp, PyInterpreterState_IMPORTS_IMPORTLIB).view(1)[0] = importlib;
    if verbose != 0 {
        PySys_FormatStderr(ptr[u8]("import _imp # builtin\n"));
    }
    imp_mod = bootstrap_imp(tstate);
    if not imp_mod {
        return -1;
    }
    if _PyImport_SetModuleString(ptr[u8]("_imp"), imp_mod) < 0 {
        object_decref(imp_mod);
        return -1;
    }
    value = PyObject_CallMethod(importlib, "_install", "OO", sysmod, imp_mod);
    object_decref(imp_mod);
    if not value {
        return -1;
    }
    object_decref(value);
    return 0;
}

impl init_importlib_external(interp: ptr[u8]) -> i32 {
    value = PyObject_CallMethod(
        importlib_of(interp), "_install_external_importers", ""
    );
    if not value {
        return -1;
    }
    object_decref(value);
    return 0;
}

impl get_path_importer(
    tstate: ptr[PyThreadState],
    path_importer_cache: ptr[PyObject],
    path_hooks: ptr[PyObject],
    p: ptr[PyObject]
) -> ptr[PyObject] {
    if not list_check(path_hooks) {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("sys.path_hooks is not a list"));
        return NULL;
    }
    if not dict_check(path_importer_cache) {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("sys.path_importer_cache is not a dict")
        );
        return NULL;
    }
    nhooks = PyList_Size(path_hooks);
    if nhooks < 0 {
        return NULL;
    }
    importer: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(path_importer_cache, p, &mut importer) != 0 {
        return importer;
    }
    if PyDict_SetItem(path_importer_cache, p, Py_None) != 0 {
        return NULL;
    }
    j: i64 = 0;
    while j < nhooks {
        hook = PyList_GetItem(path_hooks, j);
        if not hook {
            return NULL;
        }
        importer = PyObject_CallOneArg(hook, p);
        if importer {
            break;
        }
        if _PyErr_ExceptionMatches(tstate, PyExc_ImportError) == 0 {
            return NULL;
        }
        _PyErr_Clear(tstate);
        j += 1;
    }
    if not importer {
        return object_new_ref(Py_None);
    }
    if PyDict_SetItem(path_importer_cache, p, importer) < 0 {
        object_decref(importer);
        return NULL;
    }
    return importer;
}

impl remove_importlib_frames(tstate: ptr[PyThreadState]) {
    exc = _PyErr_GetRaisedException(tstate);
    if not exc or config_verbose(tstate_interp(tstate)) != 0 {
        _PyErr_SetRaisedException(tstate, exc);
        return;
    }
    always_trim = PyType_IsSubtype(ptr[PyObject](object_type(exc)), PyExc_ImportError)
        != 0;
    slots: own ImportStack = ImportStack();
    base_link = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    base_link.view(1)[0] = PyException_GetTraceback(exc);
    prev_link = base_link;
    outer_link = base_link;
    in_importlib = False;
    tb = base_link.view(1)[0];
    while tb {
        next_tb = code_field(tb, PyTracebackObject_TB_NEXT).view(1)[0];
        frame = code_field(tb, PyTracebackObject_TB_FRAME).view(1)[0];
        code = PyFrame_GetCode(frame);
        filename = code_field(code, PyCodeObject_FILENAME).view(1)[0];
        now_in_importlib = _PyUnicode_EqualToASCIIString(
            filename, ptr[u8]("<frozen importlib._bootstrap>")
        )
            != 0
            or _PyUnicode_EqualToASCIIString(
                filename, ptr[u8]("<frozen importlib._bootstrap_external>")
            )
                != 0;
        if now_in_importlib and not in_importlib {
            outer_link = prev_link;
        }
        in_importlib = now_in_importlib;
        if in_importlib
            and (
                always_trim
                or _PyUnicode_EqualToASCIIString(
                    code_field(code, PyCodeObject_NAME).view(1)[0],
                    ptr[u8]("_call_with_frames_removed")
                )
                    != 0
            ) {
            if next_tb {
                object_incref(next_tb);
            }
            old = outer_link.view(1)[0];
            outer_link.view(1)[0] = next_tb;
            object_xdecref(old);
            prev_link = outer_link;
        } else {
            prev_link = code_field(tb, PyTracebackObject_TB_NEXT);
        }
        object_decref(code);
        tb = next_tb;
    }
    base_tb = base_link.view(1)[0];
    if not base_tb {
        base_tb = object_new_ref(Py_None);
    }
    PyException_SetTraceback(exc, base_tb);
    object_xdecref(base_tb);
    _PyErr_SetRaisedException(tstate, exc);
}

impl resolve_name_fail(spec: ptr[PyObject], package: ptr[PyObject]) -> ptr[PyObject] {
    object_xdecref(spec);
    object_xdecref(package);
    return NULL;
}

impl resolve_name_no_parent(
    spec: ptr[PyObject], package: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_ImportError,
        ptr[u8]("attempted relative import with no known parent package")
    );
    return resolve_name_fail(spec, package);
}

impl resolve_name(
    tstate: ptr[PyThreadState], name: ptr[PyObject], globals: ptr[PyObject], level: i32
) -> ptr[PyObject] {
    if not globals {
        PyErr_SetString(PyExc_KeyError, ptr[u8]("'__name__' not in globals"));
        return NULL;
    }
    if not dict_check(globals) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("globals must be a dict"));
        return NULL;
    }
    package: ptr[PyObject] = NULL;
    spec: ptr[PyObject] = NULL;
    if PyDict_GetItemRef(globals, py_id(_Py_ID___package__), &mut package) < 0 {
        return resolve_name_fail(spec, package);
    }
    if package == Py_None {
        object_decref(package);
        package = NULL;
    }
    if PyDict_GetItemRef(globals, py_id(_Py_ID___spec__), &mut spec) < 0 {
        return resolve_name_fail(spec, package);
    }
    if package {
        if not unicode_check(package) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("package must be a string"));
            return resolve_name_fail(spec, package);
        } elif spec and spec != Py_None {
            parent = PyObject_GetAttr(spec, py_id(_Py_ID_parent));
            if not parent {
                return resolve_name_fail(spec, package);
            }
            equal = PyObject_RichCompareBool(package, parent, Py_EQ);
            object_decref(parent);
            if equal < 0 {
                return resolve_name_fail(spec, package);
            } elif equal == 0 {
                if PyErr_WarnEx(
                    PyExc_DeprecationWarning,
                    ptr[u8]("__package__ != __spec__.parent"),
                    1
                )
                    < 0 {
                    return resolve_name_fail(spec, package);
                }
            }
        }
    } elif spec and spec != Py_None {
        package = PyObject_GetAttr(spec, py_id(_Py_ID_parent));
        if not package {
            return resolve_name_fail(spec, package);
        } elif not unicode_check(package) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("__spec__.parent must be a string")
            );
            return resolve_name_fail(spec, package);
        }
    } else {
        if PyErr_WarnEx(
            PyExc_ImportWarning,
            ptr[u8](
                "can't resolve package from __spec__ or __package__, falling back on __name__ and __path__"
            ),
            1
        )
            < 0 {
            return resolve_name_fail(spec, package);
        }
        if PyDict_GetItemRef(globals, py_id(_Py_ID___name__), &mut package) < 0 {
            return resolve_name_fail(spec, package);
        }
        if not package {
            PyErr_SetString(PyExc_KeyError, ptr[u8]("'__name__' not in globals"));
            return resolve_name_fail(spec, package);
        }
        if not unicode_check(package) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("__name__ must be a string"));
            return resolve_name_fail(spec, package);
        }
        haspath = PyDict_Contains(globals, py_id(_Py_ID___path__));
        if haspath < 0 {
            return resolve_name_fail(spec, package);
        }
        if haspath == 0 {
            dot = PyUnicode_FindChar(package, u32(46), 0, unicode_length(package), -1);
            if dot == -2 {
                return resolve_name_fail(spec, package);
            } elif dot == -1 {
                return resolve_name_no_parent(spec, package);
            }
            substr = PyUnicode_Substring(package, 0, dot);
            if not substr {
                return resolve_name_fail(spec, package);
            }
            old = package;
            package = substr;
            object_decref(old);
        }
    }
    last_dot = unicode_length(package);
    if last_dot == 0 {
        return resolve_name_no_parent(spec, package);
    }
    level_up: i32 = 1;
    while level_up < level {
        last_dot = PyUnicode_FindChar(package, u32(46), 0, last_dot, -1);
        if last_dot == -2 {
            return resolve_name_fail(spec, package);
        } elif last_dot == -1 {
            PyErr_SetString(
                PyExc_ImportError,
                ptr[u8]("attempted relative import beyond top-level package")
            );
            return resolve_name_fail(spec, package);
        }
        level_up += 1;
    }
    object_xdecref(spec);
    base = PyUnicode_Substring(package, 0, last_dot);
    object_decref(package);
    if not base or unicode_length(name) == 0 {
        return base;
    }
    abs_name = PyUnicode_FromFormat("%U.%U", base, name);
    object_decref(base);
    return abs_name;
}

impl import_find_and_load(
    tstate: ptr[PyThreadState], abs_name: ptr[PyObject]
) -> ptr[PyObject] {
    interp = tstate_interp(tstate);
    import_time = ptr[i32](
        _PyInterpreterState_GetConfig(interp) + PyConfig_IMPORT_TIME
    ).view(
        1
    )[0];
    level_slot = ptr[i32](
        interp + PyInterpreterState_IMPORTS_FIND_AND_LOAD_IMPORT_LEVEL
    );
    accumulated_slot = ptr[i64](
        interp + PyInterpreterState_IMPORTS_FIND_AND_LOAD_ACCUMULATED
    );
    header_slot = ptr[i32](interp + PyInterpreterState_IMPORTS_FIND_AND_LOAD_HEADER);
    t1: i64 = 0;
    accumulated_copy = accumulated_slot.view(1)[0];
    sys_path: ptr[PyObject] = NULL;
    sys_meta_path: ptr[PyObject] = NULL;
    sys_path_hooks: ptr[PyObject] = NULL;
    if _PySys_GetOptionalAttrString(ptr[u8]("path"), &mut sys_path) < 0 {
        return NULL;
    }
    if _PySys_GetOptionalAttrString(ptr[u8]("meta_path"), &mut sys_meta_path) < 0 {
        object_xdecref(sys_path);
        return NULL;
    }
    if _PySys_GetOptionalAttrString(ptr[u8]("path_hooks"), &mut sys_path_hooks) < 0 {
        object_xdecref(sys_meta_path);
        object_xdecref(sys_path);
        return NULL;
    }
    audit_path = sys_path or Py_None;
    audit_meta_path = sys_meta_path or Py_None;
    audit_path_hooks = sys_path_hooks or Py_None;
    if _PySys_Audit(
        tstate,
        ptr[u8]("import"),
        ptr[u8]("OOOOO"),
        abs_name,
        Py_None,
        audit_path,
        audit_meta_path,
        audit_path_hooks
    )
        < 0 {
        object_xdecref(sys_path_hooks);
        object_xdecref(sys_meta_path);
        object_xdecref(sys_path);
        return NULL;
    }
    object_xdecref(sys_path_hooks);
    object_xdecref(sys_meta_path);
    object_xdecref(sys_path);
    if import_time != 0 {
        if header_slot.view(1)[0] != 0 {
            fputs(
                ptr[u8]("import time: self [us] | cumulative | imported package\n"),
                jacpy_stdio_stream(i32(2))
            );
            header_slot.view(1)[0] = 0;
        }
        level_slot.view(1)[0] += 1;
        PyTime_PerfCounterRaw(&mut t1);
        accumulated_slot.view(1)[0] = 0;
    }
    mod = PyObject_CallMethodObjArgs(
        importlib_of(interp),
        py_id(_Py_ID__find_and_load),
        abs_name,
        import_func_of(interp),
        NULL
    );
    if import_time != 0 {
        t2: i64 = 0;
        PyTime_PerfCounterRaw(&mut t2);
        cum = t2 - t1;
        level_slot.view(1)[0] -= 1;
        self_us = _PyTime_AsMicroseconds(cum - accumulated_slot.view(1)[0], i32(1));
        cum_us = _PyTime_AsMicroseconds(cum, i32(1));
        indent: i32 = level_slot.view(1)[0] * 2;
        fprintf(
            jacpy_stdio_stream(i32(2)),
            ptr[u8]("import time: %9ld | %10ld | %*s%s\n"),
            self_us,
            cum_us,
            indent,
            ptr[u8](""),
            PyUnicode_AsUTF8(abs_name)
        );
        accumulated_slot.view(1)[0] = accumulated_copy + cum;
    }
    return mod;
}

impl import_level_done(
    tstate: ptr[PyThreadState],
    abs_name: ptr[PyObject],
    mod: ptr[PyObject],
    final_mod: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(abs_name);
    object_xdecref(mod);
    if not final_mod {
        remove_importlib_frames(tstate);
    }
    return final_mod;
}

impl import_done(
    globals: ptr[PyObject],
    builtins: ptr[PyObject],
    import_fn: ptr[PyObject],
    from_list: ptr[PyObject],
    r: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(globals);
    object_xdecref(builtins);
    object_xdecref(import_fn);
    object_xdecref(from_list);
    return r;
}

impl init_zipimport(tstate: ptr[PyThreadState], verbose: i32) -> i32 {
    path_hooks = _PySys_GetRequiredAttrString(ptr[u8]("path_hooks"));
    if not path_hooks {
        return -1;
    }
    if verbose != 0 {
        PySys_WriteStderr(ptr[u8]("# installing zipimport hook\n"));
    }
    zipimporter = PyImport_ImportModuleAttrString(
        ptr[u8]("zipimport"), ptr[u8]("zipimporter")
    );
    if not zipimporter {
        _PyErr_Clear(tstate);
        if verbose != 0 {
            PySys_WriteStderr(ptr[u8]("# can't import zipimport.zipimporter\n"));
        }
    } else {
        err = PyList_Insert(path_hooks, 0, zipimporter);
        object_decref(zipimporter);
        if err < 0 {
            object_decref(path_hooks);
            return -1;
        }
        if verbose != 0 {
            PySys_WriteStderr(ptr[u8]("# installed zipimport hook\n"));
        }
    }
    object_decref(path_hooks);
    return 0;
}
