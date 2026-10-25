import from c {
    def strlen(text: ptr[u8]) -> u64;  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  def strchr(text: ptr[u8], character: i32) -> ptr[u8];  def strdup(
        text: ptr[u8]
    ) -> ptr[u8];  def strtoul(text: ptr[u8], end: ptr, base: i32) -> u64;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memmove(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def wcslen(text: ptr[i32]) -> u64;  def wcscmp(
        left: ptr[i32], right: ptr[i32]
    ) -> i32;  def wcstol(text: ptr[i32], end: ptr, base: i32) -> i64;  def getenv(
        name: ptr[u8]
    ) -> ptr[u8];  def setlocale(category: i32, locale: ptr[u8]) -> ptr[u8];  def malloc(
        size: u64
    ) -> ptr;  def calloc(nelem: u64, elsize: u64) -> ptr;  def free(block: ptr);  def printf(
        format: ptr[u8], *args: any
    ) -> i32;  def fprintf(stream: ptr, format: ptr[u8], *args: any) -> i32;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  def puts(text: ptr[u8]) -> i32;  def putchar(character: i32) -> i32;  def setvbuf(
        stream: ptr, buffer: ptr[u8], mode: i32, size: u64
    ) -> i32;  def jacpy_stdio_stream(stream: i32) -> ptr;  def jacpy_stack_address(
        slots: &mut InitconfigStack
    ) -> int;  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def Py_GetVersion -> ptr[u8];  def Py_DecodeLocale(
        arg: ptr[u8], wlen: ptr[u64]
    ) -> ptr[i32];  def _Py_DecodeUTF8Ex(
        s: ptr[u8],
        size: i64,
        wstr: ptr[ptr[i32]],
        wlen: ptr[u64],
        reason: ptr[ptr[u8]],
        errors: i32
    ) -> i32;  def _Py_EncodeUTF8Ex(
        text: ptr[i32],
        out_str: ptr[ptr[u8]],
        error_pos: ptr[u64],
        reason: ptr[ptr[u8]],
        raw_malloc: i32,
        errors: i32
    ) -> i32;  def _Py_GetForceASCII -> i32;  def _Py_GetLocaleEncoding -> ptr[i32];  def _Py_abspath(
        path: ptr[i32], abspath_p: ptr[ptr[i32]]
    ) -> i32;  def _Py_isabs(path: ptr[i32]) -> i32;  def _PyMem_DefaultRawMalloc(
        size: u64
    ) -> ptr;  def _PyMem_DefaultRawFree(ptr_: ptr);  def _PyMem_DefaultRawWcsdup(
        str_: ptr[i32]
    ) -> ptr[i32];  def _PyMem_RawWcsdup(str_: ptr[i32]) -> ptr[i32];  def _PyMem_RawStrdup(
        str_: ptr[u8]
    ) -> ptr[u8];  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyInterpreterState_GetConfig(interp: ptr[u8]) -> ptr[u8];  def _Py_GetConfig -> ptr[
        u8
    ];  def _PySys_GetRequiredAttrString(name: ptr[u8]) -> ptr[PyObject];  def PySys_SetObject(
        name: ptr[u8], value: ptr[PyObject]
    ) -> i32;  def _PySys_SetFlagObj(pos: i64, value: ptr[PyObject]) -> i32;  def _PySys_SetIntMaxStrDigits(
        maxdigits: i32
    ) -> i32;  def _PySys_ReadPreinitWarnOptions(
        options: ptr[PyWideStringList]
    ) -> PyStatus;  def _PySys_ReadPreinitXOptions(config: ptr[u8]) -> PyStatus;  def _Py_PreInitializeFromConfig(
        config: ptr[u8], args: ptr[_PyArgv]
    ) -> PyStatus;  def Py_PreInitializeFromArgs(
        src_config: ptr[PyPreConfig], argc: i64, argv: ptr[ptr[i32]]
    ) -> PyStatus;  def Py_InitializeFromConfig(config: ptr[u8]) -> PyStatus;  def _PyConfig_InitPathConfig(
        config: ptr[u8], compute_path_config: i32
    ) -> PyStatus;  def _Py_IsLocaleCoercionTarget(ctype_loc: ptr[u8]) -> i32;  def PyImport_ExtendInittab(
        newtab: ptr
    ) -> i32;  def _PyOS_ResetGetOpt;  def _PyOS_GetOpt(
        argc: i64, argv: ptr[ptr[i32]], longindex: ptr[i32]
    ) -> i32;  def _Py_GetEnv(use_environment: i32, name: ptr[u8]) -> ptr[u8];  def _PyArgv_AsWstrList(
        args: ptr[_PyArgv], list: ptr[PyWideStringList]
    ) -> PyStatus;  def _PyPreCmdline_Clear(cmdline: ptr[_PyPreCmdline]);  def _PyPreCmdline_Read(
        cmdline: ptr[_PyPreCmdline], preconfig: ptr[PyPreConfig]
    ) -> PyStatus;  def _PyPreCmdline_SetConfig(
        cmdline: ptr[_PyPreCmdline], config: ptr[u8]
    ) -> PyStatus;  def _PyPreConfig_InitFromPreConfig(
        config: ptr[PyPreConfig], config2: ptr[PyPreConfig]
    ) -> PyStatus;  def _PyPreConfig_GetConfig(
        preconfig: ptr[PyPreConfig], config: ptr[u8]
    );  def _PyPreConfig_AsDict(config: ptr[PyPreConfig]) -> ptr[PyObject];  def PyPreConfig_InitIsolatedConfig(
        config: ptr[PyPreConfig]
    );  glob _PyOS_optind: i64; glob _PyOS_optarg: ptr[i32]; glob Py_FileSystemDefaultEncoding:
             ptr[u8]; glob Py_HasFileSystemDefaultEncoding: i32; glob Py_FileSystemDefaultEncodeErrors:
             ptr[u8]; glob _Py_HasFileSystemDefaultEncodeErrors: i32; obj InitconfigStack {
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
            w15: u64 = 0,
            w16: u64 = 0,
            w17: u64 = 0,
            w18: u64 = 0,
            w19: u64 = 0,
            w20: u64 = 0,
            w21: u64 = 0,
            w22: u64 = 0,
            w23: u64 = 0,
            w24: u64 = 0,
            w25: u64 = 0,
            w26: u64 = 0,
            w27: u64 = 0,
            w28: u64 = 0,
            w29: u64 = 0,
            w30: u64 = 0,
            w31: u64 = 0;
    }  glob:priv empty_wide: i32 = 0; glob Py_UTF8Mode: i32 = 0; glob Py_DebugFlag:
             i32 = 0; glob Py_VerboseFlag: i32 = 0; glob Py_QuietFlag: i32 = 0; glob Py_InteractiveFlag:
             i32 = 0; glob Py_InspectFlag: i32 = 0; glob Py_OptimizeFlag: i32 = 0; glob Py_NoSiteFlag:
             i32 = 0; glob Py_BytesWarningFlag: i32 = 0; glob Py_FrozenFlag: i32 = 0; glob Py_IgnoreEnvironmentFlag:
             i32 = 0; glob Py_DontWriteBytecodeFlag: i32 = 0; glob Py_NoUserSiteDirectory:
             i32 = 0; glob Py_UnbufferedStdioFlag: i32 = 0; glob Py_HashRandomizationFlag:
             i32 = 0; glob Py_IsolatedFlag: i32 = 0; def Py_GETENV(
        name: ptr[u8]
    ) -> ptr[u8] {
        if addressof(Py_IgnoreEnvironmentFlag).view(1)[0] != 0 {
            return ptr[u8]();
        }
        return getenv(name);
    }  def PyStatus_Ok -> PyStatus {
        return status_ok();
    }  def PyStatus_Error(err_msg: ptr[u8]) -> PyStatus {
        return PyStatus(
            _type=_PyStatus_TYPE_ERROR, func=ptr[u8](), err_msg=err_msg, exitcode=0
        );
    }  def PyStatus_NoMemory -> PyStatus {
        return PyStatus_Error(ptr[u8]("memory allocation failed"));
    }  def PyStatus_Exit(exitcode: i32) -> PyStatus {
        return status_exit(exitcode);
    }  def PyStatus_IsError(status: PyStatus) -> i32 {
        return i32(1 if status._type == _PyStatus_TYPE_ERROR else 0);
    }  def PyStatus_IsExit(status: PyStatus) -> i32 {
        return i32(1 if status._type == _PyStatus_TYPE_EXIT else 0);
    }  def PyStatus_Exception(status: PyStatus) -> i32 {
        return i32(1 if status._type != _PyStatus_TYPE_OK else 0);
    }  def _PyErr_SetFromPyStatus(status: PyStatus) {
        if status._type != _PyStatus_TYPE_ERROR {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("_PyErr_SetFromPyStatus() status is not an error")
            );
            return;
        }
        err_msg = status.err_msg;
        if not err_msg or strlen(err_msg) == 0 {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("_PyErr_SetFromPyStatus() status has no error message")
            );
            return;
        }
        if strcmp(err_msg, ptr[u8]("memory allocation failed")) == 0 {
            PyErr_NoMemory();
            return;
        }
        func = status.func;
        if func {
            PyErr_Format(PyExc_RuntimeError, ptr[u8]("%s: %s"), func, err_msg);
        } else {
            PyErr_Format(PyExc_RuntimeError, ptr[u8]("%s"), err_msg);
        }
        return;
    }  def _PyWideStringList_Clear(list: ptr[PyWideStringList]) {
        wide_list_clear(list, False);
        return;
    }  def _PyWideStringList_Copy(
        list: ptr[PyWideStringList], list2: ptr[PyWideStringList]
    ) -> i32 {
        return wide_list_copy_items(
            list, list2.view(1)[0].length, list2.view(1)[0].items, False
        );
    }  def PyWideStringList_Insert(
        list: ptr[PyWideStringList], index: i64, item: ptr[i32]
    ) -> PyStatus {
        length = list.view(1)[0].length;
        if length == PY_SSIZE_T_MAX {
            return no_memory(ptr[u8]("PyWideStringList_Insert"));
        }
        if index < 0 {
            return status_err(
                ptr[u8]("PyWideStringList_Insert"),
                ptr[u8]("PyWideStringList_Insert index must be >= 0")
            );
        }
        position = index;
        if position > length {
            position = length;
        }

        item2 = _PyMem_RawWcsdup(item);
        if not item2 {
            return no_memory(ptr[u8]("PyWideStringList_Insert"));
        }

        items2 = ptr[ptr[i32]](
            PyMem_RawRealloc(ptr(list.view(1)[0].items), u64((length + 1) * 8))
        );
        if not items2 {
            PyMem_RawFree(ptr(item2));
            return no_memory(ptr[u8]("PyWideStringList_Insert"));
        }

        if position < length {
            memmove(
                ptr(items2 + (position + 1)),
                ptr(items2 + position),
                u64((length - position) * 8)
            );
        }

        (items2 + position).view(1)[0] = item2;
        list.view(1)[0].items = items2;
        list.view(1)[0].length = length + 1;
        return status_ok();
    }  def PyWideStringList_Append(
        list: ptr[PyWideStringList], item: ptr[i32]
    ) -> PyStatus {
        return PyWideStringList_Insert(list, list.view(1)[0].length, item);
    }  def _PyWideStringList_Extend(
        list: ptr[PyWideStringList], list2: ptr[PyWideStringList]
    ) -> PyStatus {
        count = list2.view(1)[0].length;
        for i in range(count) {
            status = PyWideStringList_Append(
                list, (list2.view(1)[0].items + i).view(1)[0]
            );
            if status._type != _PyStatus_TYPE_OK {
                return status;
            }
        }
        return status_ok();
    }  def _PyWideStringList_AsList(list: ptr[PyWideStringList]) -> ptr[PyObject] {
        count = list.view(1)[0].length;
        pylist = PyList_New(count);
        if not pylist {
            return NULL;
        }
        items = ptr[PyListObject](pylist).view(1)[0].ob_item;
        for i in range(count) {
            item = PyUnicode_FromWideChar((list.view(1)[0].items + i).view(1)[0], -1);
            if not item {
                object_decref(pylist);
                return NULL;
            }
            (items + i).view(1)[0] = item;
        }
        return pylist;
    }  def _Py_ClearArgcArgv {
        wide_list_clear(runtime_orig_argv(), True);
        return;
    }  def Py_GetArgcArgv(argc: ptr[i32], argv: ptr[ptr[ptr[i32]]]) {
        orig = runtime_orig_argv();
        argc.view(1)[0] = i32.wrap(orig.view(1)[0].length);
        argv.view(1)[0] = orig.view(1)[0].items;
        return;
    }  def PyConfig_Clear(config: ptr[u8]) {
        config_clear_wstr(config, PyConfig_PYCACHE_PREFIX);
        config_clear_wstr(config, PyConfig_PYTHONPATH_ENV);
        config_clear_wstr(config, PyConfig_HOME);
        config_clear_wstr(config, PyConfig_PROGRAM_NAME);

        _PyWideStringList_Clear(config_list(config, PyConfig_ARGV));
        _PyWideStringList_Clear(config_list(config, PyConfig_WARNOPTIONS));
        _PyWideStringList_Clear(config_list(config, PyConfig_XOPTIONS));
        _PyWideStringList_Clear(config_list(config, PyConfig_MODULE_SEARCH_PATHS));
        set_config_int(config, PyConfig_MODULE_SEARCH_PATHS_SET, 0);
        config_clear_wstr(config, PyConfig_STDLIB_DIR);

        config_clear_wstr(config, PyConfig_EXECUTABLE);
        config_clear_wstr(config, PyConfig_BASE_EXECUTABLE);
        config_clear_wstr(config, PyConfig_PREFIX);
        config_clear_wstr(config, PyConfig_BASE_PREFIX);
        config_clear_wstr(config, PyConfig_EXEC_PREFIX);
        config_clear_wstr(config, PyConfig_BASE_EXEC_PREFIX);
        config_clear_wstr(config, PyConfig_PLATLIBDIR);
        config_clear_wstr(config, PyConfig_SYS_PATH_0);

        config_clear_wstr(config, PyConfig_FILESYSTEM_ENCODING);
        config_clear_wstr(config, PyConfig_FILESYSTEM_ERRORS);
        config_clear_wstr(config, PyConfig_STDIO_ENCODING);
        config_clear_wstr(config, PyConfig_STDIO_ERRORS);
        config_clear_wstr(config, PyConfig_RUN_COMMAND);
        config_clear_wstr(config, PyConfig_RUN_MODULE);
        config_clear_wstr(config, PyConfig_RUN_FILENAME);
        config_clear_wstr(config, PyConfig_CHECK_HASH_PYCS_MODE);

        _PyWideStringList_Clear(config_list(config, PyConfig_ORIG_ARGV));
        return;
    }  def _PyConfig_InitCompatConfig(config: ptr[u8]) {
        memset(ptr(config), 0, u64(PyConfig_SIZE));

        set_config_int(config, PyConfig_CONFIG_INIT, _PyConfig_INIT_COMPAT);
        set_config_int(config, PyConfig_IMPORT_TIME, -1);
        set_config_int(config, PyConfig_ISOLATED, -1);
        set_config_int(config, PyConfig_USE_ENVIRONMENT, -1);
        set_config_int(config, PyConfig_DEV_MODE, -1);
        set_config_int(config, PyConfig_INSTALL_SIGNAL_HANDLERS, 1);
        set_config_int(config, PyConfig_USE_HASH_SEED, -1);
        set_config_int(config, PyConfig_FAULTHANDLER, -1);
        set_config_int(config, PyConfig_TRACEMALLOC, -1);
        set_config_int(config, PyConfig_PERF_PROFILING, -1);
        set_config_int(config, PyConfig_REMOTE_DEBUG, -1);
        set_config_int(config, PyConfig_MODULE_SEARCH_PATHS_SET, 0);
        set_config_int(config, PyConfig_PARSE_ARGV, 0);
        set_config_int(config, PyConfig_SITE_IMPORT, -1);
        set_config_int(config, PyConfig_BYTES_WARNING, -1);
        set_config_int(config, PyConfig_WARN_DEFAULT_ENCODING, 0);
        set_config_int(config, PyConfig_INSPECT, -1);
        set_config_int(config, PyConfig_INTERACTIVE, -1);
        set_config_int(config, PyConfig_OPTIMIZATION_LEVEL, -1);
        set_config_int(config, PyConfig_PARSER_DEBUG, -1);
        set_config_int(config, PyConfig_WRITE_BYTECODE, -1);
        set_config_int(config, PyConfig_VERBOSE, -1);
        set_config_int(config, PyConfig_QUIET, -1);
        set_config_int(config, PyConfig_USER_SITE_DIRECTORY, -1);
        set_config_int(config, PyConfig_CONFIGURE_C_STDIO, 0);
        set_config_int(config, PyConfig_BUFFERED_STDIO, -1);
        set_config_int(config, PyConfig_INSTALL_IMPORTLIB, 1);
        set_config_wstr(config, PyConfig_CHECK_HASH_PYCS_MODE, ptr[i32]());
        set_config_int(config, PyConfig_PATHCONFIG_WARNINGS, -1);
        set_config_int(config, PyConfig_INIT_MAIN, 1);
        set_config_int(config, PyConfig_USE_FROZEN_MODULES, 1);
        set_config_int(config, PyConfig_SAFE_PATH, 0);
        set_config_int(config, PyConfig_INT_MAX_STR_DIGITS, -1);
        set_config_int(config, PyConfig_IS_PYTHON_BUILD, 0);
        set_config_int(config, PyConfig_CODE_DEBUG_RANGES, 1);
        set_config_int(config, PyConfig_CPU_COUNT, -1);
        set_config_int(config, PyConfig_THREAD_INHERIT_CONTEXT, 0);
        set_config_int(config, PyConfig_CONTEXT_AWARE_WARNINGS, 0);
        return;
    }  def PyConfig_InitPythonConfig(config: ptr[u8]) {
        config_init_defaults(config);
        set_config_int(config, PyConfig_CONFIG_INIT, _PyConfig_INIT_PYTHON);
        set_config_int(config, PyConfig_CONFIGURE_C_STDIO, 1);
        set_config_int(config, PyConfig_PARSE_ARGV, 1);
        return;
    }  def PyConfig_InitIsolatedConfig(config: ptr[u8]) {
        config_init_defaults(config);
        set_config_int(config, PyConfig_CONFIG_INIT, _PyConfig_INIT_ISOLATED);
        set_config_int(config, PyConfig_ISOLATED, 1);
        set_config_int(config, PyConfig_USE_ENVIRONMENT, 0);
        set_config_int(config, PyConfig_USER_SITE_DIRECTORY, 0);
        set_config_int(config, PyConfig_DEV_MODE, 0);
        set_config_int(config, PyConfig_INSTALL_SIGNAL_HANDLERS, 0);
        set_config_int(config, PyConfig_USE_HASH_SEED, 0);
        set_config_int(config, PyConfig_TRACEMALLOC, 0);
        set_config_int(config, PyConfig_PERF_PROFILING, 0);
        set_config_int(
            config, PyConfig_INT_MAX_STR_DIGITS, _PY_LONG_DEFAULT_MAX_STR_DIGITS
        );
        set_config_int(config, PyConfig_SAFE_PATH, 1);
        set_config_int(config, PyConfig_PATHCONFIG_WARNINGS, 0);
        set_config_int(config, PyConfig_THREAD_INHERIT_CONTEXT, 0);
        return;
    }  def PyConfig_SetString(
        config: ptr[u8], config_str: ptr[ptr[i32]], str_: ptr[i32]
    ) -> PyStatus {
        status = _Py_PreInitializeFromConfig(config, ptr[_PyArgv]());
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        str2 = ptr[i32]();
        if str_ {
            str2 = _PyMem_RawWcsdup(str_);
            if not str2 {
                return no_memory(ptr[u8]("PyConfig_SetString"));
            }
        }
        PyMem_RawFree(ptr(config_str.view(1)[0]));
        config_str.view(1)[0] = str2;
        return status_ok();
    }  def PyConfig_SetBytesString(
        config: ptr[u8], config_str: ptr[ptr[i32]], str_: ptr[u8]
    ) -> PyStatus {
        return config_set_bytes_string(
            config, config_str, str_, ptr[u8]("cannot decode string")
        );
    }  def _PyConfig_Copy(config: ptr[u8], config2: ptr[u8]) -> PyStatus {
        PyConfig_Clear(config);
        for spec in PYCONFIG_SPEC {
            member = config + spec.offset;
            member2 = config2 + spec.offset;
            kind = spec.type;
            if kind == MEMBER_INT or kind == MEMBER_UINT or kind == MEMBER_BOOL {
                ptr[i32](member).view(1)[0] = ptr[i32](member2).view(1)[0];
            } elif kind == MEMBER_ULONG {
                ptr[u64](member).view(1)[0] = ptr[u64](member2).view(1)[0];
            } elif kind == MEMBER_WSTR or kind == MEMBER_WSTR_OPT {
                status = PyConfig_SetString(
                    config, ptr[ptr[i32]](member), ptr[ptr[i32]](member2).view(1)[0]
                );
                if status._type != _PyStatus_TYPE_OK {
                    return status;
                }
            } elif _PyWideStringList_Copy(
                ptr[PyWideStringList](member), ptr[PyWideStringList](member2)
            )
                < 0 {
                return no_memory(ptr[u8]("_PyConfig_Copy"));
            }
        }
        return status_ok();
    }  def _PyConfig_AsDict(config: ptr[u8]) -> ptr[PyObject] {
        dict_ = PyDict_New();
        if not dict_ {
            return NULL;
        }
        for spec in PYCONFIG_SPEC {
            obj_ = config_get(config, spec, 0);
            if not obj_ {
                object_decref(dict_);
                return NULL;
            }
            res = PyDict_SetItemString(dict_, spec.name, obj_);
            object_decref(obj_);
            if res < 0 {
                object_decref(dict_);
                return NULL;
            }
        }
        return dict_;
    }  def _PyConfig_FromDict(config: ptr[u8], dict_: ptr[PyObject]) -> i32 {
        if not dict_check(dict_) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("dict expected"));
            return -1;
        }

        for spec in PYCONFIG_SPEC {
            member = config + spec.offset;
            kind = spec.type;
            name = spec.name;
            if kind == MEMBER_INT or kind == MEMBER_UINT or kind == MEMBER_BOOL {
                (res, value) = config_dict_get_int(dict_, name);
                if res < 0 {
                    return -1;
                }
                if kind == MEMBER_BOOL or kind == MEMBER_UINT {
                    if value < 0 {
                        config_dict_invalid_value(name);
                        return -1;
                    }
                }
                ptr[i32](member).view(1)[0] = value;
            } elif kind == MEMBER_ULONG {
                (ures, uvalue) = config_dict_get_ulong(dict_, name);
                if ures < 0 {
                    return -1;
                }
                ptr[u64](member).view(1)[0] = uvalue;
            } elif kind == MEMBER_WSTR {
                wstr = ptr[ptr[i32]](member);
                if config_dict_get_wstr(dict_, name, config, wstr) < 0 {
                    return -1;
                }
                if not wstr.view(1)[0] {
                    config_dict_invalid_value(name);
                    return -1;
                }
            } elif kind == MEMBER_WSTR_OPT {
                if config_dict_get_wstr(dict_, name, config, ptr[ptr[i32]](member))
                    < 0 {
                    return -1;
                }
            } elif strcmp(name, ptr[u8]("xoptions")) == 0 {
                if config_dict_get_xoptions(
                    dict_, name, config, ptr[PyWideStringList](member)
                )
                    < 0 {
                    return -1;
                }
            } elif config_dict_get_wstrlist(
                dict_, name, config, ptr[PyWideStringList](member)
            )
                < 0 {
                return -1;
            }
        }

        config_init = config_int(config, PyConfig_CONFIG_INIT);
        if not (
            config_init == _PyConfig_INIT_COMPAT
            or config_init == _PyConfig_INIT_PYTHON
            or config_init == _PyConfig_INIT_ISOLATED
        ) {
            config_dict_invalid_value(ptr[u8]("_config_init"));
            return -1;
        }

        if ptr[u64](config + PyConfig_HASH_SEED).view(1)[0] > MAX_HASH_SEED {
            config_dict_invalid_value(ptr[u8]("hash_seed"));
            return -1;
        }
        return 0;
    }
}

glob:priv PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     MAX_HASH_SEED: Final[u64] = 4294967295,
     ULONG_MAX_VALUE: Final[u64] = 18446744073709551615,
     INT64_MAX_VALUE: Final[u64] = 9223372036854775807,
     INT_MIN_VALUE: Final[i64] = -2147483648,
     INT_MAX_VALUE: Final[i64] = 2147483647,
     UINT_MAX_VALUE: Final[i64] = 4294967295,
     DECODE_LOCALE_ERROR: Final[u64] = 18446744073709551614,
     ERANGE_VALUE: Final[i64] = 34,
     ERROR_STRICT: Final[i32] = 1,
     DELIM_CHAR: Final[i32] = 58,
     MEMBER_INT: Final[i32] = 0,
     MEMBER_UINT: Final[i32] = 1,
     MEMBER_ULONG: Final[i32] = 2,
     MEMBER_BOOL: Final[i32] = 3,
     MEMBER_WSTR: Final[i32] = 10,
     MEMBER_WSTR_OPT: Final[i32] = 11,
     MEMBER_WSTR_LIST: Final[i32] = 12,
     MEMBER_INIT_ONLY: Final[i32] = 0,
     MEMBER_READ_ONLY: Final[i32] = 1,
     MEMBER_PUBLIC: Final[i32] = 2,
     SETTER_NONE: Final[i32] = 0,
     SETTER_NOT: Final[i32] = 1,
     INITCONFIG_INITTAB: Final[i64] = 0,
     INITCONFIG_INITTAB_SIZE: Final[i64] = 8,
     INITCONFIG_STATUS: Final[i64] = 16,
     INITCONFIG_ERR_MSG: Final[i64] = 48,
     INITCONFIG_PRECONFIG: Final[i64] = 56,
     INITCONFIG_CONFIG: Final[i64] = 96;

obj:priv ConfigSpec {
    has name: ptr[u8],
        offset: i64,
        type: i32,
        visibility: i32,
        sys_attr: ptr[u8],
        flag_index: i64,
        flag_setter: i32;
}

glob:priv PYCONFIG_SPEC: list[ConfigSpec] = pyconfig_spec(),
     PYPRECONFIG_SPEC: list[ConfigSpec] = pypreconfig_spec();

def spec_entry(
    name: ptr[u8],
    offset: i64,
    type: i32,
    visibility: i32,
    sys_attr: ptr[u8],
    flag_index: i64,
    flag_setter: i32
) -> ConfigSpec;

def pyconfig_spec -> list[ConfigSpec];

def pypreconfig_spec -> list[ConfigSpec];

def read_only(table: list[ConfigSpec], name: ptr[u8], offset: i64, type: i32);

def init_only(table: list[ConfigSpec], name: ptr[u8], offset: i64, type: i32);

def has_system_logger -> bool;

def system_logger_offset -> i64;

def find_spec(table: list[ConfigSpec], name: ptr[u8], skip_init_only: bool) -> int;

def status_exit(exitcode: i32) -> PyStatus;

def config_wstr(config: ptr[u8], offset: i64) -> ptr[i32];

def config_wstr_slot(config: ptr[u8], offset: i64) -> ptr[ptr[i32]];

def set_config_wstr(config: ptr[u8], offset: i64, value: ptr[i32]);

def config_clear_wstr(config: ptr[u8], offset: i64);

def runtime_orig_argv -> ptr[PyWideStringList];

def runtime_preconfig -> ptr[PyPreConfig];

def wide_is(wide: ptr[i32], text: ptr[u8]) -> bool;

def wide_find_equal(wide: ptr[i32]) -> ptr[i32];

def wide_from_ascii(text: ptr[u8]) -> ptr[i32];

def raw_wide_from_ascii(text: ptr[u8]) -> ptr[i32];

def config_set_ascii(
    config: ptr[u8], config_str: ptr[ptr[i32]], text: ptr[u8], func: ptr[u8]
) -> PyStatus;

def list_append_ascii(
    list: ptr[PyWideStringList], text: ptr[u8], func: ptr[u8]
) -> PyStatus;

def raw_free(block: ptr, use_default_allocator: bool);

def wide_list_clear(list: ptr[PyWideStringList], use_default_allocator: bool);

def wide_list_copy_items(
    list: ptr[PyWideStringList],
    length: i64,
    items: ptr[ptr[i32]],
    use_default_allocator: bool
) -> i32;

def wide_list_find(list: ptr[PyWideStringList], item: ptr[i32]) -> i32;

def wide_list_as_tuple(list: ptr[PyWideStringList]) -> ptr[PyObject];

def config_sys_flag_long(value: i32) -> ptr[PyObject];

def config_sys_flag_not(value: i32) -> ptr[PyObject];

def config_init_defaults(config: ptr[u8]);

def config_set_bytes_string(
    config: ptr[u8], config_str: ptr[ptr[i32]], str_: ptr[u8], decode_err_msg: ptr[u8]
) -> PyStatus;

def config_dict_get(dict_: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject];

def config_dict_invalid_type(name: ptr[u8]);

def config_dict_invalid_value(name: ptr[u8]);

def config_dict_get_int(dict_: ptr[PyObject], name: ptr[u8]) -> tuple[i32, i32];

def config_dict_get_ulong(dict_: ptr[PyObject], name: ptr[u8]) -> tuple[i32, u64];

def config_dict_get_wstr(
    dict_: ptr[PyObject], name: ptr[u8], config: ptr[u8], result: ptr[ptr[i32]]
) -> i32;

def config_dict_get_wstrlist(
    dict_: ptr[PyObject], name: ptr[u8], config: ptr[u8], result: ptr[PyWideStringList]
) -> i32;

def config_dict_get_xoptions(
    dict_: ptr[PyObject], name: ptr[u8], config: ptr[u8], result: ptr[PyWideStringList]
) -> i32;

def config_get_env(config: ptr[u8], name: ptr[u8]) -> ptr[u8];

def config_get_env_dup(
    config: ptr[u8], dest: ptr[ptr[i32]], name: ptr[u8], decode_err_msg: ptr[u8]
) -> PyStatus;

def copy_flag(config: ptr[u8], offset: i64, value: i32);

def copy_not_flag(config: ptr[u8], offset: i64, value: i32);

def global_flag(flag: ptr[i32]) -> i32;

def config_get_global_vars(config: ptr[u8]);

def set_flag(config: ptr[u8], offset: i64, flag: ptr[i32]);

def set_not_flag(config: ptr[u8], offset: i64, flag: ptr[i32]);

def config_set_global_vars(config: ptr[u8]);

def config_get_xoption(config: ptr[u8], name: ptr[u8]) -> ptr[i32];

def config_get_xoption_value(config: ptr[u8], name: ptr[u8]) -> ptr[i32];

def config_init_hash_seed(config: ptr[u8]) -> PyStatus;

def config_wstr_to_int(wstr: ptr[i32]) -> tuple[i32, i32];

def config_read_gil(config: ptr[u8], length: u64, first_char: i32) -> PyStatus;

def config_read_env_vars(config: ptr[u8]) -> PyStatus;

def cpu_count_error -> PyStatus;

def config_init_cpu_count(config: ptr[u8]) -> PyStatus;

def config_init_switch(
    config: ptr[u8],
    offset: i64,
    env_name: ptr[u8],
    env_error: ptr[u8],
    xoption_name: ptr[u8],
    xoption_error: ptr[u8],
    func: ptr[u8]
) -> PyStatus;

def config_init_thread_inherit_context(config: ptr[u8]) -> PyStatus;

def config_init_context_aware_warnings(config: ptr[u8]) -> PyStatus;

def config_init_perf_profiling(config: ptr[u8]) -> PyStatus;

def config_init_tracemalloc(config: ptr[u8]) -> PyStatus;

def config_init_int_max_str_digits(config: ptr[u8]) -> PyStatus;

def config_init_pycache_prefix(config: ptr[u8]) -> PyStatus;

def config_init_import_time(config: ptr[u8]) -> PyStatus;

def config_read_complex_options(config: ptr[u8]) -> PyStatus;

def config_get_stdio_errors(preconfig: ptr[PyPreConfig]) -> ptr[u8];

def config_get_locale_encoding(
    config: ptr[u8], preconfig: ptr[PyPreConfig], locale_encoding: ptr[ptr[i32]]
) -> PyStatus;

def config_init_stdio_encoding(
    config: ptr[u8], preconfig: ptr[PyPreConfig]
) -> PyStatus;

def config_get_fs_encoding(
    config: ptr[u8], preconfig: ptr[PyPreConfig], fs_encoding: ptr[ptr[i32]]
) -> PyStatus;

def config_init_fs_encoding(config: ptr[u8], preconfig: ptr[PyPreConfig]) -> PyStatus;

def config_init_import(config: ptr[u8], compute_path_config: i32) -> PyStatus;

def config_read(config: ptr[u8], compute_path_config: i32) -> PyStatus;

def config_init_stdio(config: ptr[u8]);

import from c {
    def _PyConfig_InitImportConfig(config: ptr[u8]) -> PyStatus {
        return config_init_import(config, 1);
    }  def _PyConfig_Write(config: ptr[u8], runtime: ptr[_PyRuntimeState]) -> PyStatus {
        config_set_global_vars(config);

        if config_int(config, PyConfig_CONFIGURE_C_STDIO) != 0 {
            config_init_stdio(config);
        }

        preconfig = ptr[PyPreConfig](ptr[u8](runtime) + _PyRuntimeState_PRECONFIG);
        preconfig.view(1)[0].isolated = config_int(config, PyConfig_ISOLATED);
        preconfig.view(1)[0].use_environment = config_int(
            config, PyConfig_USE_ENVIRONMENT
        );
        preconfig.view(1)[0].dev_mode = config_int(config, PyConfig_DEV_MODE);

        orig_argv = config_list(config, PyConfig_ORIG_ARGV);
        if wide_list_copy_items(
            runtime_orig_argv(),
            orig_argv.view(1)[0].length,
            orig_argv.view(1)[0].items,
            True
        )
            < 0 {
            return no_memory(ptr[u8]("_PyConfig_Write"));
        }
        return status_ok();
    }  def _PyConfig_SetPyArgv(config: ptr[u8], args: ptr[_PyArgv]) -> PyStatus {
        status = _Py_PreInitializeFromConfig(config, args);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        return _PyArgv_AsWstrList(args, config_list(config, PyConfig_ARGV));
    }  def PyConfig_SetBytesArgv(
        config: ptr[u8], argc: i64, argv: ptr[ptr[u8]]
    ) -> PyStatus {
        slots: own InitconfigStack = InitconfigStack();
        args = ptr[_PyArgv](jacpy_stack_address(&mut slots));
        args.view(1)[0].argc = argc;
        args.view(1)[0].use_bytes_argv = 1;
        args.view(1)[0].bytes_argv = argv;
        args.view(1)[0].wchar_argv = ptr[ptr[i32]]();
        return _PyConfig_SetPyArgv(config, args);
    }  def PyConfig_SetArgv(
        config: ptr[u8], argc: i64, argv: ptr[ptr[i32]]
    ) -> PyStatus {
        slots: own InitconfigStack = InitconfigStack();
        args = ptr[_PyArgv](jacpy_stack_address(&mut slots));
        args.view(1)[0].argc = argc;
        args.view(1)[0].use_bytes_argv = 0;
        args.view(1)[0].bytes_argv = ptr[ptr[u8]]();
        args.view(1)[0].wchar_argv = argv;
        return _PyConfig_SetPyArgv(config, args);
    }  def PyConfig_SetWideStringList(
        config: ptr[u8], list: ptr[PyWideStringList], length: i64, items: ptr[ptr[i32]]
    ) -> PyStatus {
        status = _Py_PreInitializeFromConfig(config, ptr[_PyArgv]());
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        if wide_list_copy_items(list, length, items, False) < 0 {
            return no_memory(ptr[u8]("PyConfig_SetWideStringList"));
        }
        return status_ok();
    }  def _PyConfig_Read(config: ptr[u8], compute_path_config: i32) -> PyStatus {
        status = _Py_PreInitializeFromConfig(config, ptr[_PyArgv]());
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }

        config_get_global_vars(config);

        orig_argv = config_list(config, PyConfig_ORIG_ARGV);
        argv = config_list(config, PyConfig_ARGV);
        if orig_argv.view(1)[0].length == 0
            and not (
                argv.view(1)[0].length == 1
                and argv.view(1)[0].items.view(1)[0].view(1)[0] == 0
            ) {
            if _PyWideStringList_Copy(orig_argv, argv) < 0 {
                return no_memory(ptr[u8]("_PyConfig_Read"));
            }
        }

        slots: own InitconfigStack = InitconfigStack();
        precmdline = ptr[_PyPreCmdline](jacpy_stack_address(&mut slots));
        precmdline.view(1)[0].use_environment = -1;
        precmdline.view(1)[0].isolated = -1;
        precmdline.view(1)[0].dev_mode = -1;

        status = core_read_precmdline(config, precmdline);
        if status._type == _PyStatus_TYPE_OK {
            if config_int(config, PyConfig_ISOLATED) != 0 {
                set_config_int(config, PyConfig_SAFE_PATH, 1);
                set_config_int(config, PyConfig_USE_ENVIRONMENT, 0);
                set_config_int(config, PyConfig_USER_SITE_DIRECTORY, 0);
            }
            status = config_read_cmdline(config);
        }
        if status._type == _PyStatus_TYPE_OK {
            status = _PySys_ReadPreinitXOptions(config);
        }
        if status._type == _PyStatus_TYPE_OK {
            status = config_read(config, compute_path_config);
        }
        if status._type == _PyStatus_TYPE_OK {
            status = status_ok();
        }

        _PyPreCmdline_Clear(precmdline);
        return status;
    }  def PyConfig_Read(config: ptr[u8]) -> PyStatus {
        return _PyConfig_Read(config, 0);
    }  def _Py_GetConfigsAsDict -> ptr[PyObject] {
        result = PyDict_New();
        if not result {
            return NULL;
        }

        dict_ = global_variables_as_dict();
        if not dict_ {
            object_decref(result);
            return NULL;
        }
        if PyDict_SetItemString(result, ptr[u8]("global_config"), dict_) < 0 {
            object_decref(result);
            object_decref(dict_);
            return NULL;
        }
        object_decref(dict_);

        interp = current_interp();
        runtime = ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
        dict_ = _PyPreConfig_AsDict(
            ptr[PyPreConfig](runtime + _PyRuntimeState_PRECONFIG)
        );
        if not dict_ {
            object_decref(result);
            return NULL;
        }
        if PyDict_SetItemString(result, ptr[u8]("pre_config"), dict_) < 0 {
            object_decref(result);
            object_decref(dict_);
            return NULL;
        }
        object_decref(dict_);

        dict_ = _PyConfig_AsDict(_PyInterpreterState_GetConfig(interp));
        if not dict_ {
            object_decref(result);
            return NULL;
        }
        if PyDict_SetItemString(result, ptr[u8]("config"), dict_) < 0 {
            object_decref(result);
            object_decref(dict_);
            return NULL;
        }
        object_decref(dict_);
        return result;
    }  def _Py_DumpPathConfig(tstate: ptr[PyThreadState]) {
        exc = _PyErr_GetRaisedException(tstate);

        PySys_WriteStderr(ptr[u8]("Python path configuration:\n"));

        interp = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
        config = _PyInterpreterState_GetConfig(interp);
        dump_config(ptr[u8]("PYTHONHOME"), config_wstr(config, PyConfig_HOME));
        dump_config(
            ptr[u8]("PYTHONPATH"), config_wstr(config, PyConfig_PYTHONPATH_ENV)
        );
        dump_config(
            ptr[u8]("program name"), config_wstr(config, PyConfig_PROGRAM_NAME)
        );
        PySys_WriteStderr(ptr[u8]("  isolated = %i\n"), config_int(config, PyConfig_ISOLATED));
        PySys_WriteStderr(
            ptr[u8]("  environment = %i\n"), config_int(config, PyConfig_USE_ENVIRONMENT)
        );
        PySys_WriteStderr(
            ptr[u8]("  user site = %i\n"), config_int(config, PyConfig_USER_SITE_DIRECTORY)
        );
        PySys_WriteStderr(ptr[u8]("  safe_path = %i\n"), config_int(config, PyConfig_SAFE_PATH));
        PySys_WriteStderr(
            ptr[u8]("  import site = %i\n"), config_int(config, PyConfig_SITE_IMPORT)
        );
        PySys_WriteStderr(
            ptr[u8]("  is in build tree = %i\n"), config_int(config, PyConfig_IS_PYTHON_BUILD)
        );
        dump_config(ptr[u8]("stdlib dir"), config_wstr(config, PyConfig_STDLIB_DIR));
        dump_config(ptr[u8]("sys.path[0]"), config_wstr(config, PyConfig_SYS_PATH_0));

        obj_ = NULL;
        dump_sys_name(ptr[u8]("_base_executable"));
        res = _PySys_GetOptionalAttrString(ptr[u8]("_base_executable"), &mut obj_);
        dump_sys_value(res, obj_);
        obj_ = NULL;
        dump_sys_name(ptr[u8]("base_prefix"));
        res = _PySys_GetOptionalAttrString(ptr[u8]("base_prefix"), &mut obj_);
        dump_sys_value(res, obj_);
        obj_ = NULL;
        dump_sys_name(ptr[u8]("base_exec_prefix"));
        res = _PySys_GetOptionalAttrString(ptr[u8]("base_exec_prefix"), &mut obj_);
        dump_sys_value(res, obj_);
        obj_ = NULL;
        dump_sys_name(ptr[u8]("platlibdir"));
        res = _PySys_GetOptionalAttrString(ptr[u8]("platlibdir"), &mut obj_);
        dump_sys_value(res, obj_);
        obj_ = NULL;
        dump_sys_name(ptr[u8]("executable"));
        res = _PySys_GetOptionalAttrString(ptr[u8]("executable"), &mut obj_);
        dump_sys_value(res, obj_);
        obj_ = NULL;
        dump_sys_name(ptr[u8]("prefix"));
        res = _PySys_GetOptionalAttrString(ptr[u8]("prefix"), &mut obj_);
        dump_sys_value(res, obj_);
        obj_ = NULL;
        dump_sys_name(ptr[u8]("exec_prefix"));
        res = _PySys_GetOptionalAttrString(ptr[u8]("exec_prefix"), &mut obj_);
        dump_sys_value(res, obj_);

        sys_path = NULL;
        _PySys_GetOptionalAttrString(ptr[u8]("path"), &mut sys_path);
        if sys_path and list_check(sys_path) {
            PySys_WriteStderr(ptr[u8]("  sys.path = [\n"));
            count = object_size(sys_path);
            items = ptr[PyListObject](sys_path).view(1)[0].ob_item;
            for i in range(count) {
                PySys_FormatStderr(ptr[u8]("    %A,\n"), (items + i).view(1)[0]);
            }
            PySys_WriteStderr(ptr[u8]("  ]\n"));
        }
        object_xdecref(sys_path);

        _PyErr_SetRaisedException(tstate, exc);
        return;
    }
}

def global_set_item(dict_: ptr[PyObject], key: ptr[u8], obj_: ptr[PyObject]) -> i32;

def global_int(flag: ptr[i32]) -> ptr[PyObject];

def global_str(text: ptr[u8]) -> ptr[PyObject];

def global_variables_set_items(dict_: ptr[PyObject]) -> i32;

def global_variables_as_dict -> ptr[PyObject];

def init_dump_ascii_wstr(text: ptr[i32]);

def dump_config(name: ptr[u8], value: ptr[i32]);

def dump_sys_name(name: ptr[u8]);

def dump_sys_value(res: i32, obj_: ptr[PyObject]);

def config_usage(error: i32, program: ptr[i32]);

def config_envvars_usage;

def config_xoptions_usage;

def config_complete_usage(program: ptr[i32]);

def config_parse_cmdline(
    config: ptr[u8], warnoptions: ptr[PyWideStringList], opt_index: ptr[i64]
) -> PyStatus;

def bump(config: ptr[u8], offset: i64);

def version_length(version: ptr[u8]) -> i32;

def config_init_env_warnoptions(
    config: ptr[u8], warnoptions: ptr[PyWideStringList]
) -> PyStatus;

def warnoptions_append(
    config: ptr[u8], options: ptr[PyWideStringList], option: ptr[i32]
) -> PyStatus;

def warnoptions_append_ascii(
    config: ptr[u8], options: ptr[PyWideStringList], text: ptr[u8]
) -> PyStatus;

def warnoptions_extend(
    config: ptr[u8], options: ptr[PyWideStringList], options2: ptr[PyWideStringList]
) -> PyStatus;

def config_init_warnoptions(
    config: ptr[u8],
    cmdline_warnoptions: ptr[PyWideStringList],
    env_warnoptions: ptr[PyWideStringList],
    sys_warnoptions: ptr[PyWideStringList],
    options: ptr[PyWideStringList]
) -> PyStatus;

def config_update_argv(config: ptr[u8], opt_index: i64) -> PyStatus;

def core_read_precmdline(config: ptr[u8], precmdline: ptr[_PyPreCmdline]) -> PyStatus;

def config_run_filename_abspath(config: ptr[u8]) -> PyStatus;

def config_read_cmdline(config: ptr[u8]) -> PyStatus;

def usage_help -> ptr[u8];

def usage_xoptions -> ptr[u8];

def usage_envvars_head -> ptr[u8];

def usage_envvars_tail -> ptr[u8];


import from c {
    def PyInitConfig_Create -> ptr[u8] {
        config = ptr[u8](calloc(u64(1), u64(INITCONFIG_CONFIG + PyConfig_SIZE)));
        if not config {
            return config;
        }
        PyPreConfig_InitIsolatedConfig(initconfig_preconfig(config));
        PyConfig_InitIsolatedConfig(initconfig_config(config));
        initconfig_status(config).view(1)[0] = status_ok();
        return config;
    }  def PyInitConfig_Free(config: ptr[u8]) {
        if not config {
            return;
        }
        initconfig_free_config(initconfig_config(config));
        PyMem_RawFree(ptr[ptr](config + INITCONFIG_INITTAB).view(1)[0]);
        free(ptr(ptr[ptr[u8]](config + INITCONFIG_ERR_MSG).view(1)[0]));
        free(ptr(config));
        return;
    }  def PyInitConfig_GetError(config: ptr[u8], perr_msg: ptr[ptr[u8]]) -> i32 {
        status = initconfig_status(config);
        err_msg_slot = ptr[ptr[u8]](config + INITCONFIG_ERR_MSG);
        if status.view(1)[0]._type == _PyStatus_TYPE_EXIT {
            slots: own InitconfigStack = InitconfigStack();
            buffer = ptr[u8](jacpy_stack_address(&mut slots));
            PyOS_snprintf(
                buffer, u64(22), ptr[u8]("exit code %i"), status.view(1)[0].exitcode
            );

            if err_msg_slot.view(1)[0] {
                free(ptr(err_msg_slot.view(1)[0]));
            }
            err_msg_slot.view(1)[0] = strdup(buffer);
            if err_msg_slot.view(1)[0] {
                perr_msg.view(1)[0] = err_msg_slot.view(1)[0];
                return 1;
            }
            status.view(1)[0] = no_memory(ptr[u8]("PyInitConfig_GetError"));
        }

        if status.view(1)[0]._type == _PyStatus_TYPE_ERROR
            and status.view(1)[0].err_msg {
            perr_msg.view(1)[0] = status.view(1)[0].err_msg;
            return 1;
        }
        perr_msg.view(1)[0] = ptr[u8]();
        return 0;
    }  def PyInitConfig_GetExitCode(config: ptr[u8], exitcode: ptr[i32]) -> i32 {
        status = initconfig_status(config);
        if status.view(1)[0]._type == _PyStatus_TYPE_EXIT {
            exitcode.view(1)[0] = status.view(1)[0].exitcode;
            return 1;
        }
        return 0;
    }  def PyInitConfig_HasOption(config: ptr[u8], name: ptr[u8]) -> i32 {
        if find_spec(PYCONFIG_SPEC, name, False) >= 0 {
            return 1;
        }
        return i32(1 if find_spec(PYPRECONFIG_SPEC, name, False) >= 0 else 0);
    }  def PyInitConfig_GetInt(config: ptr[u8], name: ptr[u8], value: ptr[i64]) -> i32 {
        (kind, member) = initconfig_prepare(config, name);
        if kind < 0 {
            return -1;
        }
        if kind == MEMBER_INT or kind == MEMBER_UINT or kind == MEMBER_BOOL {
            value.view(1)[0] = i64(ptr[i32](member).view(1)[0]);
        } elif kind == MEMBER_ULONG {
            ulong_value = ptr[u64](member).view(1)[0];
            if INT64_MAX_VALUE < ulong_value {
                initconfig_set_error(
                    config, ptr[u8]("config option value doesn't fit into int64_t")
                );
                return -1;
            }
            value.view(1)[0] = i64(ulong_value);
        } else {
            initconfig_set_error(config, ptr[u8]("config option type is not int"));
            return -1;
        }
        return 0;
    }  def PyInitConfig_GetStr(
        config: ptr[u8], name: ptr[u8], value: ptr[ptr[u8]]
    ) -> i32 {
        (kind, member) = initconfig_prepare(config, name);
        if kind < 0 {
            return -1;
        }
        if kind != MEMBER_WSTR and kind != MEMBER_WSTR_OPT {
            initconfig_set_error(config, ptr[u8]("config option type is not string"));
            return -1;
        }
        wstr = ptr[ptr[i32]](member).view(1)[0];
        if not wstr {
            value.view(1)[0] = ptr[u8]();
            return 0;
        }
        value.view(1)[0] = wstr_to_utf8(config, wstr);
        if not value.view(1)[0] {
            return -1;
        }
        return 0;
    }  def PyInitConfig_GetStrList(
        config: ptr[u8], name: ptr[u8], length: ptr[u64], items: ptr[ptr[ptr[u8]]]
    ) -> i32 {
        (kind, member) = initconfig_prepare(config, name);
        if kind < 0 {
            return -1;
        }
        if kind != MEMBER_WSTR_LIST {
            initconfig_set_error(
                config, ptr[u8]("config option type is not string list")
            );
            return -1;
        }

        list = ptr[PyWideStringList](member);
        count = list.view(1)[0].length;
        length.view(1)[0] = u64(count);

        array = ptr[ptr[u8]](malloc(u64(count * 8)));
        items.view(1)[0] = array;
        if not array {
            initconfig_status(config).view(1)[0] = no_memory(
                ptr[u8]("PyInitConfig_GetStrList")
            );
            return -1;
        }

        for i in range(count) {
            text = wstr_to_utf8(config, (list.view(1)[0].items + i).view(1)[0]);
            (array + i).view(1)[0] = text;
            if not text {
                PyInitConfig_FreeStrList(u64(i), array);
                return -1;
            }
        }
        return 0;
    }  def PyInitConfig_FreeStrList(length: u64, items: ptr[ptr[u8]]) {
        for i in range(i64(length)) {
            free(ptr((items + i).view(1)[0]));
        }
        free(ptr(items));
        return;
    }  def PyInitConfig_SetInt(config: ptr[u8], name: ptr[u8], value: i64) -> i32 {
        (kind, member) = initconfig_prepare(config, name);
        if kind < 0 {
            return -1;
        }

        if kind == MEMBER_INT {
            if value < INT_MIN_VALUE or INT_MAX_VALUE < value {
                initconfig_set_error(
                    config, ptr[u8]("config option value is out of int range")
                );
                return -1;
            }
            ptr[i32](member).view(1)[0] = i32(value);
        } elif kind == MEMBER_UINT or kind == MEMBER_BOOL {
            if value < 0 or UINT_MAX_VALUE < value {
                initconfig_set_error(
                    config, ptr[u8]("config option value is out of unsigned int range")
                );
                return -1;
            }
            ptr[i32](member).view(1)[0] = i32.wrap(value);
        } elif kind == MEMBER_ULONG {
            if value < 0 {
                initconfig_set_error(
                    config, ptr[u8]("config option value is out of unsigned long range")
                );
                return -1;
            }
            ptr[u64](member).view(1)[0] = u64(value);
        } else {
            initconfig_set_error(config, ptr[u8]("config option type is not int"));
            return -1;
        }

        if strcmp(name, ptr[u8]("hash_seed")) == 0 {
            set_config_int(initconfig_config(config), PyConfig_USE_HASH_SEED, 1);
        }
        return 0;
    }  def PyInitConfig_SetStr(config: ptr[u8], name: ptr[u8], value: ptr[u8]) -> i32 {
        (kind, member) = initconfig_prepare(config, name);
        if kind < 0 {
            return -1;
        }

        if kind != MEMBER_WSTR and kind != MEMBER_WSTR_OPT {
            initconfig_set_error(config, ptr[u8]("config option type is not string"));
            return -1;
        }

        if not value and kind != MEMBER_WSTR_OPT {
            initconfig_set_error(
                config, ptr[u8]("config option string cannot be NULL")
            );
        }

        slot = ptr[ptr[i32]](member);
        slot.view(1)[0] = utf8_to_wstr(config, value);
        if not slot.view(1)[0] {
            return -1;
        }
        return 0;
    }  def PyInitConfig_SetStrList(
        config: ptr[u8], name: ptr[u8], length: u64, items: ptr[ptr[u8]]
    ) -> i32 {
        (kind, member) = initconfig_prepare(config, name);
        if kind < 0 {
            return -1;
        }

        if kind != MEMBER_WSTR_LIST {
            initconfig_set_error(
                config, ptr[u8]("config option type is not strings list")
            );
            return -1;
        }
        if initconfig_set_str_list(
            config, ptr[PyWideStringList](member), i64(length), items
        )
            < 0 {
            return -1;
        }

        if strcmp(name, ptr[u8]("module_search_paths")) == 0 {
            set_config_int(
                initconfig_config(config), PyConfig_MODULE_SEARCH_PATHS_SET, 1
            );
        }
        return 0;
    }  def PyInitConfig_AddModule(
        config: ptr[u8], name: ptr[u8], initfunc: ptr
    ) -> i32 {
        inittab_slot = ptr[ptr[u64]](config + INITCONFIG_INITTAB);
        size_slot = ptr[i64](config + INITCONFIG_INITTAB_SIZE);
        inittab_size = size_slot.view(1)[0];
        new_inittab = ptr[u64](
            PyMem_RawRealloc(ptr(inittab_slot.view(1)[0]), u64(16 * (inittab_size + 2)))
        );
        if not new_inittab {
            initconfig_status(config).view(1)[0] = no_memory(
                ptr[u8]("PyInitConfig_AddModule")
            );
            return -1;
        }
        inittab_slot.view(1)[0] = new_inittab;

        tab_entry = new_inittab + 2 * inittab_size;
        tab_entry.view(2)[0] = u64(int(name));
        tab_entry.view(2)[1] = u64(int(initfunc));

        terminator = new_inittab + 2 * (inittab_size + 1);
        terminator.view(2)[0] = u64(0);
        terminator.view(2)[1] = u64(0);

        size_slot.view(1)[0] = inittab_size + 1;
        return 0;
    }  def Py_InitializeFromInitConfig(config: ptr[u8]) -> i32 {
        status = initconfig_status(config);
        if ptr[i64](config + INITCONFIG_INITTAB_SIZE).view(1)[0] >= 1 {
            if PyImport_ExtendInittab(ptr[ptr](config + INITCONFIG_INITTAB).view(1)[0])
                < 0 {
                status.view(1)[0] = no_memory(ptr[u8]("Py_InitializeFromInitConfig"));
                return -1;
            }
        }

        preconfig = initconfig_preconfig(config);
        pyconfig = initconfig_config(config);
        _PyPreConfig_GetConfig(preconfig, pyconfig);

        argv = config_list(pyconfig, PyConfig_ARGV);
        status.view(1)[0] = Py_PreInitializeFromArgs(
            preconfig, argv.view(1)[0].length, argv.view(1)[0].items
        );
        if status.view(1)[0]._type != _PyStatus_TYPE_OK {
            return -1;
        }

        status.view(1)[0] = Py_InitializeFromConfig(pyconfig);
        if status.view(1)[0]._type != _PyStatus_TYPE_OK {
            return -1;
        }
        return 0;
    }  def _PyConfig_CreateXOptionsDict(config: ptr[u8]) -> ptr[PyObject] {
        dict_ = PyDict_New();
        if not dict_ {
            return NULL;
        }
        xoptions = config_list(config, PyConfig_XOPTIONS);
        count = xoptions.view(1)[0].length;
        for i in range(count) {
            if config_add_xoption(dict_, (xoptions.view(1)[0].items + i).view(1)[0])
                < 0 {
                object_decref(dict_);
                return NULL;
            }
        }
        return dict_;
    }  def PyConfig_Get(name: ptr[u8]) -> ptr[PyObject] {
        index = find_spec(PYCONFIG_SPEC, name, True);
        if index >= 0 {
            return config_get(_Py_GetConfig(), PYCONFIG_SPEC[index], 1);
        }

        index = find_spec(PYPRECONFIG_SPEC, name, True);
        if index >= 0 {
            return preconfig_get(runtime_preconfig(), PYPRECONFIG_SPEC[index]);
        }

        config_unknown_name_error(name);
        return NULL;
    }  def PyConfig_GetInt(name: ptr[u8], value: ptr[i32]) -> i32 {
        obj_ = PyConfig_Get(name);
        if not obj_ {
            return -1;
        }

        if not long_check(obj_) {
            object_decref(obj_);
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("config option %s is not an int"), name
            );
            return -1;
        }

        as_int = PyLong_AsInt(obj_);
        object_decref(obj_);
        if as_int == -1 and PyErr_Occurred() {
            PyErr_Format(
                PyExc_OverflowError,
                ptr[u8]("config option %s value does not fit into a C int"),
                name
            );
            return -1;
        }

        value.view(1)[0] = as_int;
        return 0;
    }  def PyConfig_Names -> ptr[PyObject] {
        names = PyList_New(0);
        if not names {
            return NULL;
        }
        if config_names_add(names, PYCONFIG_SPEC) < 0
            or config_names_add(names, PYPRECONFIG_SPEC) < 0 {
            object_decref(names);
            return NULL;
        }
        frozen = PyFrozenSet_New(names);
        object_decref(names);
        return frozen;
    }  def PyConfig_Set(name: ptr[u8], value: ptr[PyObject]) -> i32 {
        if PySys_Audit(ptr[u8]("cpython.PyConfig_Set"), ptr[u8]("sO"), name, value) < 0 {
            return -1;
        }

        index = find_spec(PYCONFIG_SPEC, name, True);
        spec = ConfigSpec(
            name=ptr[u8](),
            offset=0,
            type=0,
            visibility=MEMBER_INIT_ONLY,
            sys_attr=ptr[u8](),
            flag_index=-1,
            flag_setter=SETTER_NONE
        );
        if index >= 0 {
            spec = PYCONFIG_SPEC[index];
        } else {
            index = find_spec(PYPRECONFIG_SPEC, name, True);
            if index < 0 {
                config_unknown_name_error(name);
                return -1;
            }
            spec = PYPRECONFIG_SPEC[index];
        }

        if spec.visibility != MEMBER_PUBLIC {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("cannot set read-only option %s"), name
            );
            return -1;
        }

        int_value: i32 = 0;
        has_int_value = False;
        kind = spec.type;

        if kind == MEMBER_INT or kind == MEMBER_UINT or kind == MEMBER_BOOL {
            if not long_check(value) {
                PyErr_Format(
                    PyExc_TypeError, ptr[u8]("expected int or bool, got %T"), value
                );
                return -1;
            }
            int_value = PyLong_AsInt(value);
            if int_value == -1 and PyErr_Occurred() {
                return -1;
            }
            if int_value < 0 and kind != MEMBER_INT {
                PyErr_Format(PyExc_ValueError, ptr[u8]("value must be >= 0"));
                return -1;
            }
            has_int_value = True;
        } elif kind == MEMBER_ULONG {
            PyErr_Format(PyExc_ValueError, ptr[u8]("cannot set option %s"), name);
            return -1;
        } elif kind == MEMBER_WSTR {
            if not unicode_check_exact(value) {
                PyErr_Format(PyExc_TypeError, ptr[u8]("expected str, got %T"), value);
                return -1;
            }
        } elif kind == MEMBER_WSTR_OPT {
            if value != Py_None and not unicode_check_exact(value) {
                PyErr_Format(
                    PyExc_TypeError, ptr[u8]("expected str or None, got %T"), value
                );
                return -1;
            }
        } elif strcmp(spec.name, ptr[u8]("xoptions")) != 0 {
            if not list_check(value) {
                PyErr_Format(
                    PyExc_TypeError, ptr[u8]("expected list[str], got %T"), value
                );
                return -1;
            }
            i: i64 = 0;
            while i < object_size(value) {
                item = (ptr[PyListObject](value).view(1)[0].ob_item + i).view(1)[0];
                if not unicode_check(item) {
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8]("expected str, list item %zd has type %T"),
                        i,
                        item
                    );
                    return -1;
                }
                i += 1;
            }
        } else {
            if not dict_check(value) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("expected dict[str, str | bool], got %T"),
                    value
                );
                return -1;
            }
            pos: i64 = 0;
            key = NULL;
            item = NULL;
            while PyDict_Next(value, &mut pos, &mut key, &mut item) != 0 {
                if not unicode_check(key) {
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8]("expected str, got dict key type %T"),
                        key
                    );
                    return -1;
                }
                if not unicode_check(item) and not bool_check(item) {
                    PyErr_Format(
                        PyExc_TypeError,
                        ptr[u8]("expected str or bool, got dict value type %T"),
                        key
                    );
                    return -1;
                }
            }
        }

        if spec.sys_attr {
            return PySys_SetObject(spec.sys_attr, value);
        } elif has_int_value {
            if spec.flag_index >= 0 {
                return config_set_sys_flag(spec, int_value);
            } elif strcmp(spec.name, ptr[u8]("int_max_str_digits")) == 0 {
                return _PySys_SetIntMaxStrDigits(int_value);
            }
            return config_set_int_attr(spec, int_value);
        }

        PyErr_Format(PyExc_ValueError, ptr[u8]("cannot set option %s"), name);
        return -1;
    }
}

def initconfig_status(config: ptr[u8]) -> ptr[PyStatus];

def initconfig_preconfig(config: ptr[u8]) -> ptr[PyPreConfig];

def initconfig_config(config: ptr[u8]) -> ptr[u8];

def initconfig_set_error(config: ptr[u8], err_msg: ptr[u8]);

def initconfig_prepare(config: ptr[u8], name: ptr[u8]) -> tuple[i32, ptr[u8]];

def wstr_to_utf8(config: ptr[u8], wstr: ptr[i32]) -> ptr[u8];

def utf8_to_wstr(config: ptr[u8], text: ptr[u8]) -> ptr[i32];

def initconfig_free_wstr(member: ptr[i32]);

def initconfig_free_wstr_list(list: ptr[PyWideStringList]);

def initconfig_free_config(config: ptr[u8]);

def initconfig_set_str_list(
    config: ptr[u8], list: ptr[PyWideStringList], length: i64, items: ptr[ptr[u8]]
) -> i32;

def config_add_xoption(dict_: ptr[PyObject], text: ptr[i32]) -> i32;

def config_get_sys_write_bytecode -> tuple[i32, i32];

def config_get(config: ptr[u8], spec: ConfigSpec, use_sys: i32) -> ptr[PyObject];

def preconfig_get(preconfig: ptr[PyPreConfig], spec: ConfigSpec) -> ptr[PyObject];

def config_unknown_name_error(name: ptr[u8]);

def config_names_add(names: ptr[PyObject], table: list[ConfigSpec]) -> i32;

def interp_config -> ptr[u8];

def config_set_sys_flag(spec: ConfigSpec, value: i32) -> i32;

def config_set_int_attr(spec: ConfigSpec, value: i32) -> i32;

impl spec_entry(
    name: ptr[u8],
    offset: i64,
    type: i32,
    visibility: i32,
    sys_attr: ptr[u8],
    flag_index: i64,
    flag_setter: i32
) -> ConfigSpec {
    return ConfigSpec(
        name=name,
        offset=offset,
        type=type,
        visibility=visibility,
        sys_attr=sys_attr,
        flag_index=flag_index,
        flag_setter=flag_setter
    );
}

impl pyconfig_spec -> list[ConfigSpec] {
    none = ptr[u8]();
    table: list[ConfigSpec] = [];

    table.append(
        spec_entry(
            ptr[u8]("argv"),
            PyConfig_ARGV,
            MEMBER_WSTR_LIST,
            MEMBER_PUBLIC,
            ptr[u8]("argv"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("base_exec_prefix"),
            PyConfig_BASE_EXEC_PREFIX,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("base_exec_prefix"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("base_executable"),
            PyConfig_BASE_EXECUTABLE,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("_base_executable"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("base_prefix"),
            PyConfig_BASE_PREFIX,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("base_prefix"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("bytes_warning"),
            PyConfig_BYTES_WARNING,
            MEMBER_UINT,
            MEMBER_PUBLIC,
            none,
            9,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("cpu_count"),
            PyConfig_CPU_COUNT,
            MEMBER_INT,
            MEMBER_PUBLIC,
            none,
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("exec_prefix"),
            PyConfig_EXEC_PREFIX,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("exec_prefix"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("executable"),
            PyConfig_EXECUTABLE,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("executable"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("inspect"),
            PyConfig_INSPECT,
            MEMBER_BOOL,
            MEMBER_PUBLIC,
            none,
            1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("int_max_str_digits"),
            PyConfig_INT_MAX_STR_DIGITS,
            MEMBER_UINT,
            MEMBER_PUBLIC,
            none,
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("interactive"),
            PyConfig_INTERACTIVE,
            MEMBER_BOOL,
            MEMBER_PUBLIC,
            none,
            2,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("module_search_paths"),
            PyConfig_MODULE_SEARCH_PATHS,
            MEMBER_WSTR_LIST,
            MEMBER_PUBLIC,
            ptr[u8]("path"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("optimization_level"),
            PyConfig_OPTIMIZATION_LEVEL,
            MEMBER_UINT,
            MEMBER_PUBLIC,
            none,
            3,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("parser_debug"),
            PyConfig_PARSER_DEBUG,
            MEMBER_BOOL,
            MEMBER_PUBLIC,
            none,
            0,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("platlibdir"),
            PyConfig_PLATLIBDIR,
            MEMBER_WSTR,
            MEMBER_PUBLIC,
            ptr[u8]("platlibdir"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("prefix"),
            PyConfig_PREFIX,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("prefix"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("pycache_prefix"),
            PyConfig_PYCACHE_PREFIX,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("pycache_prefix"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("quiet"),
            PyConfig_QUIET,
            MEMBER_BOOL,
            MEMBER_PUBLIC,
            none,
            10,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("stdlib_dir"),
            PyConfig_STDLIB_DIR,
            MEMBER_WSTR_OPT,
            MEMBER_PUBLIC,
            ptr[u8]("_stdlib_dir"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("use_environment"),
            PyConfig_USE_ENVIRONMENT,
            MEMBER_BOOL,
            MEMBER_PUBLIC,
            none,
            7,
            SETTER_NOT
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("verbose"),
            PyConfig_VERBOSE,
            MEMBER_UINT,
            MEMBER_PUBLIC,
            none,
            8,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("warnoptions"),
            PyConfig_WARNOPTIONS,
            MEMBER_WSTR_LIST,
            MEMBER_PUBLIC,
            ptr[u8]("warnoptions"),
            -1,
            SETTER_NONE
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("write_bytecode"),
            PyConfig_WRITE_BYTECODE,
            MEMBER_BOOL,
            MEMBER_PUBLIC,
            none,
            4,
            SETTER_NOT
        )
    );
    table.append(
        spec_entry(
            ptr[u8]("xoptions"),
            PyConfig_XOPTIONS,
            MEMBER_WSTR_LIST,
            MEMBER_PUBLIC,
            ptr[u8]("_xoptions"),
            -1,
            SETTER_NONE
        )
    );

    read_only(table, ptr[u8]("buffered_stdio"), PyConfig_BUFFERED_STDIO, MEMBER_BOOL);
    read_only(
        table,
        ptr[u8]("check_hash_pycs_mode"),
        PyConfig_CHECK_HASH_PYCS_MODE,
        MEMBER_WSTR
    );
    read_only(
        table, ptr[u8]("code_debug_ranges"), PyConfig_CODE_DEBUG_RANGES, MEMBER_BOOL
    );
    read_only(
        table, ptr[u8]("configure_c_stdio"), PyConfig_CONFIGURE_C_STDIO, MEMBER_BOOL
    );
    read_only(table, ptr[u8]("dev_mode"), PyConfig_DEV_MODE, MEMBER_BOOL);
    read_only(table, ptr[u8]("dump_refs"), PyConfig_DUMP_REFS, MEMBER_BOOL);
    read_only(
        table, ptr[u8]("dump_refs_file"), PyConfig_DUMP_REFS_FILE, MEMBER_WSTR_OPT
    );
    read_only(table, ptr[u8]("faulthandler"), PyConfig_FAULTHANDLER, MEMBER_BOOL);
    read_only(
        table, ptr[u8]("filesystem_encoding"), PyConfig_FILESYSTEM_ENCODING, MEMBER_WSTR
    );
    read_only(
        table, ptr[u8]("filesystem_errors"), PyConfig_FILESYSTEM_ERRORS, MEMBER_WSTR
    );
    read_only(table, ptr[u8]("hash_seed"), PyConfig_HASH_SEED, MEMBER_ULONG);
    read_only(table, ptr[u8]("home"), PyConfig_HOME, MEMBER_WSTR_OPT);
    read_only(
        table,
        ptr[u8]("thread_inherit_context"),
        PyConfig_THREAD_INHERIT_CONTEXT,
        MEMBER_INT
    );
    read_only(
        table,
        ptr[u8]("context_aware_warnings"),
        PyConfig_CONTEXT_AWARE_WARNINGS,
        MEMBER_INT
    );
    read_only(table, ptr[u8]("import_time"), PyConfig_IMPORT_TIME, MEMBER_UINT);
    read_only(
        table,
        ptr[u8]("install_signal_handlers"),
        PyConfig_INSTALL_SIGNAL_HANDLERS,
        MEMBER_BOOL
    );
    read_only(table, ptr[u8]("isolated"), PyConfig_ISOLATED, MEMBER_BOOL);
    read_only(table, ptr[u8]("malloc_stats"), PyConfig_MALLOC_STATS, MEMBER_BOOL);
    table.append(
        spec_entry(
            ptr[u8]("orig_argv"),
            PyConfig_ORIG_ARGV,
            MEMBER_WSTR_LIST,
            MEMBER_READ_ONLY,
            ptr[u8]("orig_argv"),
            -1,
            SETTER_NONE
        )
    );
    read_only(table, ptr[u8]("parse_argv"), PyConfig_PARSE_ARGV, MEMBER_BOOL);
    read_only(
        table, ptr[u8]("pathconfig_warnings"), PyConfig_PATHCONFIG_WARNINGS, MEMBER_BOOL
    );
    read_only(table, ptr[u8]("perf_profiling"), PyConfig_PERF_PROFILING, MEMBER_UINT);
    read_only(table, ptr[u8]("remote_debug"), PyConfig_REMOTE_DEBUG, MEMBER_BOOL);
    read_only(table, ptr[u8]("program_name"), PyConfig_PROGRAM_NAME, MEMBER_WSTR);
    read_only(table, ptr[u8]("run_command"), PyConfig_RUN_COMMAND, MEMBER_WSTR_OPT);
    read_only(table, ptr[u8]("run_filename"), PyConfig_RUN_FILENAME, MEMBER_WSTR_OPT);
    read_only(table, ptr[u8]("run_module"), PyConfig_RUN_MODULE, MEMBER_WSTR_OPT);
    read_only(table, ptr[u8]("safe_path"), PyConfig_SAFE_PATH, MEMBER_BOOL);
    read_only(table, ptr[u8]("show_ref_count"), PyConfig_SHOW_REF_COUNT, MEMBER_BOOL);
    read_only(table, ptr[u8]("site_import"), PyConfig_SITE_IMPORT, MEMBER_BOOL);
    read_only(
        table,
        ptr[u8]("skip_source_first_line"),
        PyConfig_SKIP_SOURCE_FIRST_LINE,
        MEMBER_BOOL
    );
    read_only(table, ptr[u8]("stdio_encoding"), PyConfig_STDIO_ENCODING, MEMBER_WSTR);
    read_only(table, ptr[u8]("stdio_errors"), PyConfig_STDIO_ERRORS, MEMBER_WSTR);
    read_only(table, ptr[u8]("tracemalloc"), PyConfig_TRACEMALLOC, MEMBER_UINT);
    read_only(
        table, ptr[u8]("use_frozen_modules"), PyConfig_USE_FROZEN_MODULES, MEMBER_BOOL
    );
    read_only(table, ptr[u8]("use_hash_seed"), PyConfig_USE_HASH_SEED, MEMBER_BOOL);
    if has_system_logger() {
        read_only(
            table, ptr[u8]("use_system_logger"), system_logger_offset(), MEMBER_BOOL
        );
    }
    read_only(
        table, ptr[u8]("user_site_directory"), PyConfig_USER_SITE_DIRECTORY, MEMBER_BOOL
    );
    read_only(
        table,
        ptr[u8]("warn_default_encoding"),
        PyConfig_WARN_DEFAULT_ENCODING,
        MEMBER_BOOL
    );

    init_only(table, ptr[u8]("_config_init"), PyConfig_CONFIG_INIT, MEMBER_UINT);
    init_only(table, ptr[u8]("_init_main"), PyConfig_INIT_MAIN, MEMBER_BOOL);
    init_only(
        table, ptr[u8]("_install_importlib"), PyConfig_INSTALL_IMPORTLIB, MEMBER_BOOL
    );
    init_only(
        table, ptr[u8]("_is_python_build"), PyConfig_IS_PYTHON_BUILD, MEMBER_BOOL
    );
    init_only(
        table,
        ptr[u8]("module_search_paths_set"),
        PyConfig_MODULE_SEARCH_PATHS_SET,
        MEMBER_BOOL
    );
    init_only(
        table, ptr[u8]("pythonpath_env"), PyConfig_PYTHONPATH_ENV, MEMBER_WSTR_OPT
    );
    init_only(table, ptr[u8]("sys_path_0"), PyConfig_SYS_PATH_0, MEMBER_WSTR_OPT);
    return table;
}

impl pypreconfig_spec -> list[ConfigSpec] {
    table: list[ConfigSpec] = [];
    read_only(table, ptr[u8]("allocator"), PyPreConfig_ALLOCATOR, MEMBER_INT);
    read_only(
        table, ptr[u8]("coerce_c_locale"), PyPreConfig_COERCE_C_LOCALE, MEMBER_BOOL
    );
    read_only(
        table,
        ptr[u8]("coerce_c_locale_warn"),
        PyPreConfig_COERCE_C_LOCALE_WARN,
        MEMBER_BOOL
    );
    read_only(
        table, ptr[u8]("configure_locale"), PyPreConfig_CONFIGURE_LOCALE, MEMBER_BOOL
    );
    read_only(table, ptr[u8]("utf8_mode"), PyPreConfig_UTF8_MODE, MEMBER_BOOL);
    init_only(table, ptr[u8]("_config_init"), PyPreConfig_CONFIG_INIT, MEMBER_INT);
    init_only(table, ptr[u8]("dev_mode"), PyPreConfig_DEV_MODE, MEMBER_BOOL);
    init_only(table, ptr[u8]("isolated"), PyPreConfig_ISOLATED, MEMBER_BOOL);
    init_only(table, ptr[u8]("parse_argv"), PyPreConfig_PARSE_ARGV, MEMBER_BOOL);
    init_only(
        table, ptr[u8]("use_environment"), PyPreConfig_USE_ENVIRONMENT, MEMBER_BOOL
    );
    return table;
}

impl read_only(table: list[ConfigSpec], name: ptr[u8], offset: i64, type: i32) {
    table.append(
        spec_entry(name, offset, type, MEMBER_READ_ONLY, ptr[u8](), -1, SETTER_NONE)
    );
}

impl init_only(table: list[ConfigSpec], name: ptr[u8], offset: i64, type: i32) {
    table.append(
        spec_entry(name, offset, type, MEMBER_INIT_ONLY, ptr[u8](), -1, SETTER_NONE)
    );
}

impl has_system_logger -> bool {
    return PyConfig_CPU_COUNT - PyConfig_CONTEXT_AWARE_WARNINGS > 4;
}

impl system_logger_offset -> i64 {
    return PyConfig_CONTEXT_AWARE_WARNINGS + 4;
}

impl find_spec(table: list[ConfigSpec], name: ptr[u8], skip_init_only: bool) -> int {
    index = 0;
    for spec in table {
        if not (skip_init_only and spec.visibility == MEMBER_INIT_ONLY) {
            if strcmp(name, spec.name) == 0 {
                return index;
            }
        }
        index += 1;
    }
    return -1;
}

impl status_exit(exitcode: i32) -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_EXIT, func=ptr[u8](), err_msg=ptr[u8](), exitcode=exitcode
    );
}

impl config_wstr(config: ptr[u8], offset: i64) -> ptr[i32] {
    return ptr[ptr[i32]](config + offset).view(1)[0];
}

impl config_wstr_slot(config: ptr[u8], offset: i64) -> ptr[ptr[i32]] {
    return ptr[ptr[i32]](config + offset);
}

impl set_config_wstr(config: ptr[u8], offset: i64, value: ptr[i32]) {
    ptr[ptr[i32]](config + offset).view(1)[0] = value;
}

impl config_clear_wstr(config: ptr[u8], offset: i64) {
    PyMem_RawFree(ptr(config_wstr(config, offset)));
    set_config_wstr(config, offset, ptr[i32]());
}

impl runtime_orig_argv -> ptr[PyWideStringList] {
    return ptr[PyWideStringList](runtime_at(_PyRuntimeState_ORIG_ARGV));
}

impl runtime_preconfig -> ptr[PyPreConfig] {
    return ptr[PyPreConfig](runtime_at(_PyRuntimeState_PRECONFIG));
}

impl wide_is(wide: ptr[i32], text: ptr[u8]) -> bool {
    i: i64 = 0;
    while True {
        c = i32((text + i).view(1)[0]);
        if (wide + i).view(1)[0] != c {
            return False;
        }
        if c == 0 {
            return True;
        }
        i += 1;
    }
    return False;
}

impl wide_find_equal(wide: ptr[i32]) -> ptr[i32] {
    i: i64 = 0;
    while (wide + i).view(1)[0] != 0 {
        if (wide + i).view(1)[0] == 61 {
            return wide + i;
        }
        i += 1;
    }
    return ptr[i32]();
}

impl wide_from_ascii(text: ptr[u8]) -> ptr[i32] {
    length = i64(strlen(text));
    wide = ptr[i32](malloc(u64((length + 1) * 4)));
    if not wide {
        return wide;
    }
    for i in range(length + 1) {
        (wide + i).view(1)[0] = i32((text + i).view(1)[0]);
    }
    return wide;
}

impl raw_wide_from_ascii(text: ptr[u8]) -> ptr[i32] {
    length = i64(strlen(text));
    wide = ptr[i32](PyMem_RawMalloc(u64((length + 1) * 4)));
    if not wide {
        return wide;
    }
    for i in range(length + 1) {
        (wide + i).view(1)[0] = i32((text + i).view(1)[0]);
    }
    return wide;
}

impl config_set_ascii(
    config: ptr[u8], config_str: ptr[ptr[i32]], text: ptr[u8], func: ptr[u8]
) -> PyStatus {
    wide = wide_from_ascii(text);
    if not wide {
        return no_memory(func);
    }
    status = PyConfig_SetString(config, config_str, wide);
    free(ptr(wide));
    return status;
}

impl list_append_ascii(
    list: ptr[PyWideStringList], text: ptr[u8], func: ptr[u8]
) -> PyStatus {
    wide = wide_from_ascii(text);
    if not wide {
        return no_memory(func);
    }
    status = PyWideStringList_Append(list, wide);
    free(ptr(wide));
    return status;
}

impl raw_free(block: ptr, use_default_allocator: bool) {
    if use_default_allocator {
        _PyMem_DefaultRawFree(block);
    } else {
        PyMem_RawFree(block);
    }
}

impl wide_list_clear(list: ptr[PyWideStringList], use_default_allocator: bool) {
    count = list.view(1)[0].length;
    items = list.view(1)[0].items;
    for i in range(count) {
        raw_free(ptr((items + i).view(1)[0]), use_default_allocator);
    }
    raw_free(ptr(items), use_default_allocator);
    list.view(1)[0].length = 0;
    list.view(1)[0].items = ptr[ptr[i32]]();
}

impl wide_list_copy_items(
    list: ptr[PyWideStringList],
    length: i64,
    items: ptr[ptr[i32]],
    use_default_allocator: bool
) -> i32 {
    if length == 0 {
        wide_list_clear(list, use_default_allocator);
        return 0;
    }

    size = u64(length * 8);
    copy = ptr[ptr[i32]]();
    if use_default_allocator {
        copy = ptr[ptr[i32]](_PyMem_DefaultRawMalloc(size));
    } else {
        copy = ptr[ptr[i32]](PyMem_RawMalloc(size));
    }
    if not copy {
        return -1;
    }

    for i in range(length) {
        item = ptr[i32]();
        if use_default_allocator {
            item = _PyMem_DefaultRawWcsdup((items + i).view(1)[0]);
        } else {
            item = _PyMem_RawWcsdup((items + i).view(1)[0]);
        }
        if not item {
            for k in range(i) {
                raw_free(ptr((copy + k).view(1)[0]), use_default_allocator);
            }
            raw_free(ptr(copy), use_default_allocator);
            return -1;
        }
        (copy + i).view(1)[0] = item;
    }

    wide_list_clear(list, use_default_allocator);
    list.view(1)[0].length = length;
    list.view(1)[0].items = copy;
    return 0;
}

impl wide_list_find(list: ptr[PyWideStringList], item: ptr[i32]) -> i32 {
    count = list.view(1)[0].length;
    for i in range(count) {
        if wcscmp((list.view(1)[0].items + i).view(1)[0], item) == 0 {
            return 1;
        }
    }
    return 0;
}

impl wide_list_as_tuple(list: ptr[PyWideStringList]) -> ptr[PyObject] {
    count = list.view(1)[0].length;
    tup = PyTuple_New(count);
    if not tup {
        return NULL;
    }
    for i in range(count) {
        item = PyUnicode_FromWideChar((list.view(1)[0].items + i).view(1)[0], -1);
        if not item {
            object_decref(tup);
            return NULL;
        }
        tuple_set_item(tup, i, item);
    }
    return tup;
}

impl config_sys_flag_long(value: i32) -> ptr[PyObject] {
    return PyLong_FromLong(i64(value));
}

impl config_sys_flag_not(value: i32) -> ptr[PyObject] {
    return config_sys_flag_long(i32(1 if value == 0 else 0));
}

impl config_init_defaults(config: ptr[u8]) {
    _PyConfig_InitCompatConfig(config);

    set_config_int(config, PyConfig_ISOLATED, 0);
    set_config_int(config, PyConfig_USE_ENVIRONMENT, 1);
    set_config_int(config, PyConfig_SITE_IMPORT, 1);
    set_config_int(config, PyConfig_BYTES_WARNING, 0);
    set_config_int(config, PyConfig_INSPECT, 0);
    set_config_int(config, PyConfig_INTERACTIVE, 0);
    set_config_int(config, PyConfig_OPTIMIZATION_LEVEL, 0);
    set_config_int(config, PyConfig_PARSER_DEBUG, 0);
    set_config_int(config, PyConfig_WRITE_BYTECODE, 1);
    set_config_int(config, PyConfig_VERBOSE, 0);
    set_config_int(config, PyConfig_QUIET, 0);
    set_config_int(config, PyConfig_USER_SITE_DIRECTORY, 1);
    set_config_int(config, PyConfig_BUFFERED_STDIO, 1);
    set_config_int(config, PyConfig_PATHCONFIG_WARNINGS, 1);
    set_config_int(config, PyConfig_THREAD_INHERIT_CONTEXT, 0);
    set_config_int(config, PyConfig_CONTEXT_AWARE_WARNINGS, 0);
}

impl config_set_bytes_string(
    config: ptr[u8], config_str: ptr[ptr[i32]], str_: ptr[u8], decode_err_msg: ptr[u8]
) -> PyStatus {
    status = _Py_PreInitializeFromConfig(config, ptr[_PyArgv]());
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    str2 = ptr[i32]();
    if str_ {
        slots: own InitconfigStack = InitconfigStack();
        len_slot = ptr[u64](jacpy_stack_address(&mut slots));
        str2 = Py_DecodeLocale(str_, len_slot);
        if not str2 {
            if len_slot.view(1)[0] == DECODE_LOCALE_ERROR {
                return status_err(ptr[u8]("config_set_bytes_string"), decode_err_msg);
            }
            return no_memory(ptr[u8]("config_set_bytes_string"));
        }
    }
    PyMem_RawFree(ptr(config_str.view(1)[0]));
    config_str.view(1)[0] = str2;
    return status_ok();
}

impl config_dict_get(dict_: ptr[PyObject], name: ptr[u8]) -> ptr[PyObject] {
    item = NULL;
    if PyDict_GetItemStringRef(dict_, name, &mut item) < 0 or not item {
        if not PyErr_Occurred() {
            PyErr_Format(PyExc_ValueError, ptr[u8]("missing config key: %s"), name);
        }
        return NULL;
    }
    return item;
}

impl config_dict_invalid_type(name: ptr[u8]) {
    PyErr_Format(PyExc_TypeError, ptr[u8]("invalid config type: %s"), name);
}

impl config_dict_invalid_value(name: ptr[u8]) {
    PyErr_Format(PyExc_ValueError, ptr[u8]("invalid config value: %s"), name);
}

impl config_dict_get_int(dict_: ptr[PyObject], name: ptr[u8]) -> tuple[i32, i32] {
    item = config_dict_get(dict_, name);
    if not item {
        return (i32(-1), i32(0));
    }
    value = PyLong_AsInt(item);
    object_decref(item);
    if value == -1 and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            config_dict_invalid_type(name);
        } elif PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
            config_dict_invalid_value(name);
        }
        return (i32(-1), i32(0));
    }
    return (i32(0), value);
}

impl config_dict_get_ulong(dict_: ptr[PyObject], name: ptr[u8]) -> tuple[i32, u64] {
    item = config_dict_get(dict_, name);
    if not item {
        return (i32(-1), u64(0));
    }
    value = PyLong_AsUnsignedLong(item);
    object_decref(item);
    if value == ULONG_MAX_VALUE and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            config_dict_invalid_type(name);
        } elif PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
            config_dict_invalid_value(name);
        }
        return (i32(-1), u64(0));
    }
    return (i32(0), value);
}

impl config_dict_get_wstr(
    dict_: ptr[PyObject], name: ptr[u8], config: ptr[u8], result: ptr[ptr[i32]]
) -> i32 {
    item = config_dict_get(dict_, name);
    if not item {
        return -1;
    }

    status = status_ok();
    if item == Py_None {
        status = PyConfig_SetString(config, result, ptr[i32]());
    } elif not unicode_check(item) {
        config_dict_invalid_type(name);
        object_decref(item);
        return -1;
    } else {
        wstr = PyUnicode_AsWideCharString(item, None);
        if not wstr {
            object_decref(item);
            return -1;
        }
        status = PyConfig_SetString(config, result, wstr);
        PyMem_Free(ptr(wstr));
    }
    if status._type != _PyStatus_TYPE_OK {
        PyErr_NoMemory();
        object_decref(item);
        return -1;
    }
    object_decref(item);
    return 0;
}

impl config_dict_get_wstrlist(
    dict_: ptr[PyObject], name: ptr[u8], config: ptr[u8], result: ptr[PyWideStringList]
) -> i32 {
    list_ = config_dict_get(dict_, name);
    if not list_ {
        return -1;
    }

    is_list = list_check_exact(list_);
    if not is_list and not tuple_check_exact(list_) {
        object_decref(list_);
        config_dict_invalid_type(name);
        return -1;
    }

    slots: own InitconfigStack = InitconfigStack();
    wstrlist = ptr[PyWideStringList](jacpy_stack_address(&mut slots));
    count = object_size(list_);
    for i in range(count) {
        item = NULL;
        if is_list {
            item = (ptr[PyListObject](list_).view(1)[0].ob_item + i).view(1)[0];
        } else {
            item = tuple_get_item(list_, i);
        }

        if item == Py_None {
            config_dict_invalid_value(name);
            _PyWideStringList_Clear(wstrlist);
            object_decref(list_);
            return -1;
        } elif not unicode_check(item) {
            config_dict_invalid_type(name);
            _PyWideStringList_Clear(wstrlist);
            object_decref(list_);
            return -1;
        }
        wstr = PyUnicode_AsWideCharString(item, None);
        if not wstr {
            _PyWideStringList_Clear(wstrlist);
            object_decref(list_);
            return -1;
        }
        status = PyWideStringList_Append(wstrlist, wstr);
        PyMem_Free(ptr(wstr));
        if status._type != _PyStatus_TYPE_OK {
            PyErr_NoMemory();
            _PyWideStringList_Clear(wstrlist);
            object_decref(list_);
            return -1;
        }
    }

    if _PyWideStringList_Copy(result, wstrlist) < 0 {
        PyErr_NoMemory();
        _PyWideStringList_Clear(wstrlist);
        object_decref(list_);
        return -1;
    }
    _PyWideStringList_Clear(wstrlist);
    object_decref(list_);
    return 0;
}

impl config_dict_get_xoptions(
    dict_: ptr[PyObject], name: ptr[u8], config: ptr[u8], result: ptr[PyWideStringList]
) -> i32 {
    xoptions = config_dict_get(dict_, name);
    if not xoptions {
        return -1;
    }

    if not dict_check_exact(xoptions) {
        object_decref(xoptions);
        config_dict_invalid_type(name);
        return -1;
    }

    slots: own InitconfigStack = InitconfigStack();
    wstrlist = ptr[PyWideStringList](jacpy_stack_address(&mut slots));
    pos: i64 = 0;
    key = NULL;
    value = NULL;
    while PyDict_Next(xoptions, &mut pos, &mut key, &mut value) != 0 {
        item = NULL;
        if value != py_true() {
            item = PyUnicode_FromFormat("%S=%S", key, value);
            if not item {
                _PyWideStringList_Clear(wstrlist);
                object_decref(xoptions);
                return -1;
            }
        } else {
            item = object_new_ref(key);
        }

        wstr = PyUnicode_AsWideCharString(item, None);
        object_decref(item);
        if not wstr {
            _PyWideStringList_Clear(wstrlist);
            object_decref(xoptions);
            return -1;
        }

        status = PyWideStringList_Append(wstrlist, wstr);
        PyMem_Free(ptr(wstr));
        if status._type != _PyStatus_TYPE_OK {
            PyErr_NoMemory();
            _PyWideStringList_Clear(wstrlist);
            object_decref(xoptions);
            return -1;
        }
    }

    if _PyWideStringList_Copy(result, wstrlist) < 0 {
        PyErr_NoMemory();
        _PyWideStringList_Clear(wstrlist);
        object_decref(xoptions);
        return -1;
    }
    _PyWideStringList_Clear(wstrlist);
    object_decref(xoptions);
    return 0;
}

impl config_get_env(config: ptr[u8], name: ptr[u8]) -> ptr[u8] {
    return _Py_GetEnv(config_int(config, PyConfig_USE_ENVIRONMENT), name);
}

impl config_get_env_dup(
    config: ptr[u8], dest: ptr[ptr[i32]], name: ptr[u8], decode_err_msg: ptr[u8]
) -> PyStatus {
    if config_int(config, PyConfig_USE_ENVIRONMENT) == 0 {
        dest.view(1)[0] = ptr[i32]();
        return status_ok();
    }
    var = getenv(name);
    if not var or var.view(1)[0] == u8(0) {
        dest.view(1)[0] = ptr[i32]();
        return status_ok();
    }
    return config_set_bytes_string(config, dest, var, decode_err_msg);
}

impl copy_flag(config: ptr[u8], offset: i64, value: i32) {
    if config_int(config, offset) == -1 {
        set_config_int(config, offset, value);
    }
}

impl copy_not_flag(config: ptr[u8], offset: i64, value: i32) {
    if config_int(config, offset) == -1 {
        set_config_int(config, offset, i32(1 if value == 0 else 0));
    }
}

impl global_flag(flag: ptr[i32]) -> i32 {
    return flag.view(1)[0];
}

impl config_get_global_vars(config: ptr[u8]) {
    if config_int(config, PyConfig_CONFIG_INIT) != _PyConfig_INIT_COMPAT {
        return;
    }
    copy_flag(config, PyConfig_ISOLATED, global_flag(addressof(Py_IsolatedFlag)));
    copy_not_flag(
        config,
        PyConfig_USE_ENVIRONMENT,
        global_flag(addressof(Py_IgnoreEnvironmentFlag))
    );
    copy_flag(
        config, PyConfig_BYTES_WARNING, global_flag(addressof(Py_BytesWarningFlag))
    );
    copy_flag(config, PyConfig_INSPECT, global_flag(addressof(Py_InspectFlag)));
    copy_flag(config, PyConfig_INTERACTIVE, global_flag(addressof(Py_InteractiveFlag)));
    copy_flag(
        config, PyConfig_OPTIMIZATION_LEVEL, global_flag(addressof(Py_OptimizeFlag))
    );
    copy_flag(config, PyConfig_PARSER_DEBUG, global_flag(addressof(Py_DebugFlag)));
    copy_flag(config, PyConfig_VERBOSE, global_flag(addressof(Py_VerboseFlag)));
    copy_flag(config, PyConfig_QUIET, global_flag(addressof(Py_QuietFlag)));
    copy_not_flag(
        config, PyConfig_PATHCONFIG_WARNINGS, global_flag(addressof(Py_FrozenFlag))
    );
    copy_not_flag(
        config, PyConfig_BUFFERED_STDIO, global_flag(addressof(Py_UnbufferedStdioFlag))
    );
    copy_not_flag(config, PyConfig_SITE_IMPORT, global_flag(addressof(Py_NoSiteFlag)));
    copy_not_flag(
        config,
        PyConfig_WRITE_BYTECODE,
        global_flag(addressof(Py_DontWriteBytecodeFlag))
    );
    copy_not_flag(
        config,
        PyConfig_USER_SITE_DIRECTORY,
        global_flag(addressof(Py_NoUserSiteDirectory))
    );
}

impl set_flag(config: ptr[u8], offset: i64, flag: ptr[i32]) {
    value = config_int(config, offset);
    if value != -1 {
        flag.view(1)[0] = value;
    }
}

impl set_not_flag(config: ptr[u8], offset: i64, flag: ptr[i32]) {
    value = config_int(config, offset);
    if value != -1 {
        flag.view(1)[0] = i32(1 if value == 0 else 0);
    }
}

impl config_set_global_vars(config: ptr[u8]) {
    set_flag(config, PyConfig_ISOLATED, addressof(Py_IsolatedFlag));
    set_not_flag(config, PyConfig_USE_ENVIRONMENT, addressof(Py_IgnoreEnvironmentFlag));
    set_flag(config, PyConfig_BYTES_WARNING, addressof(Py_BytesWarningFlag));
    set_flag(config, PyConfig_INSPECT, addressof(Py_InspectFlag));
    set_flag(config, PyConfig_INTERACTIVE, addressof(Py_InteractiveFlag));
    set_flag(config, PyConfig_OPTIMIZATION_LEVEL, addressof(Py_OptimizeFlag));
    set_flag(config, PyConfig_PARSER_DEBUG, addressof(Py_DebugFlag));
    set_flag(config, PyConfig_VERBOSE, addressof(Py_VerboseFlag));
    set_flag(config, PyConfig_QUIET, addressof(Py_QuietFlag));
    set_not_flag(config, PyConfig_PATHCONFIG_WARNINGS, addressof(Py_FrozenFlag));
    set_not_flag(config, PyConfig_BUFFERED_STDIO, addressof(Py_UnbufferedStdioFlag));
    set_not_flag(config, PyConfig_SITE_IMPORT, addressof(Py_NoSiteFlag));
    set_not_flag(config, PyConfig_WRITE_BYTECODE, addressof(Py_DontWriteBytecodeFlag));
    set_not_flag(
        config, PyConfig_USER_SITE_DIRECTORY, addressof(Py_NoUserSiteDirectory)
    );

    random_or_seed = config_int(config, PyConfig_USE_HASH_SEED) == 0
        or ptr[u64](config + PyConfig_HASH_SEED).view(1)[0] != u64(0);
    addressof(Py_HashRandomizationFlag).view(1)[0] = i32(1 if random_or_seed else 0);
}

impl config_get_xoption(config: ptr[u8], name: ptr[u8]) -> ptr[i32] {
    return get_xoption_ascii(config_list(config, PyConfig_XOPTIONS), name);
}

impl config_get_xoption_value(config: ptr[u8], name: ptr[u8]) -> ptr[i32] {
    xoption = config_get_xoption(config, name);
    if not xoption {
        return ptr[i32]();
    }
    sep = wide_find_equal(xoption);
    if sep {
        return sep + 1;
    }
    return addressof(empty_wide);
}

impl config_init_hash_seed(config: ptr[u8]) -> PyStatus {
    seed_text = config_get_env(config, ptr[u8]("PYTHONHASHSEED"));

    if seed_text and strcmp(seed_text, ptr[u8]("random")) != 0 {
        slots: own InitconfigStack = InitconfigStack();
        endptr = ptr[ptr[u8]](jacpy_stack_address(&mut slots));
        endptr.view(1)[0] = seed_text;
        jacpy_set_errno(0);
        seed = strtoul(seed_text, ptr(endptr), 10);
        if endptr.view(1)[0].view(1)[0] != u8(0)
            or seed > MAX_HASH_SEED
            or (jacpy_errno() == ERANGE_VALUE and seed == ULONG_MAX_VALUE) {
            return status_err(
                ptr[u8]("config_init_hash_seed"),
                ptr[u8](
                    "PYTHONHASHSEED must be \"random\" or an integer in range [0; 4294967295]"
                )
            );
        }
        set_config_int(config, PyConfig_USE_HASH_SEED, 1);
        ptr[u64](config + PyConfig_HASH_SEED).view(1)[0] = seed;
    } else {
        set_config_int(config, PyConfig_USE_HASH_SEED, 0);
        ptr[u64](config + PyConfig_HASH_SEED).view(1)[0] = u64(0);
    }
    return status_ok();
}

impl config_wstr_to_int(wstr: ptr[i32]) -> tuple[i32, i32] {
    slots: own InitconfigStack = InitconfigStack();
    endptr = ptr[ptr[i32]](jacpy_stack_address(&mut slots));
    endptr.view(1)[0] = wstr;
    jacpy_set_errno(0);
    value = wcstol(wstr, ptr(endptr), 10);
    if endptr.view(1)[0].view(1)[0] != 0 or jacpy_errno() == ERANGE_VALUE {
        return (i32(-1), i32(0));
    }
    if value < INT_MIN_VALUE or value > INT_MAX_VALUE {
        return (i32(-1), i32(0));
    }
    return (i32(0), i32(value));
}

impl config_read_gil(config: ptr[u8], length: u64, first_char: i32) -> PyStatus {
    if length == u64(1) and first_char == 48 {
        return status_err(
            ptr[u8]("config_read_gil"),
            ptr[u8]("Disabling the GIL is not supported by this build")
        );
    } elif length == u64(1) and first_char == 49 {
        return status_ok();
    }
    return status_err(
        ptr[u8]("config_read_gil"),
        ptr[u8]("PYTHON_GIL / -X gil must be \"0\" or \"1\"")
    );
}

impl config_read_env_vars(config: ptr[u8]) -> PyStatus {
    use_env = config_int(config, PyConfig_USE_ENVIRONMENT);

    set_config_int(
        config,
        PyConfig_PARSER_DEBUG,
        env_flag(
            use_env, config_int(config, PyConfig_PARSER_DEBUG), ptr[u8]("PYTHONDEBUG")
        )
    );
    set_config_int(
        config,
        PyConfig_VERBOSE,
        env_flag(
            use_env, config_int(config, PyConfig_VERBOSE), ptr[u8]("PYTHONVERBOSE")
        )
    );
    set_config_int(
        config,
        PyConfig_OPTIMIZATION_LEVEL,
        env_flag(
            use_env,
            config_int(config, PyConfig_OPTIMIZATION_LEVEL),
            ptr[u8]("PYTHONOPTIMIZE")
        )
    );
    if config_int(config, PyConfig_INSPECT) == 0
        and _Py_GetEnv(use_env, ptr[u8]("PYTHONINSPECT")) {
        set_config_int(config, PyConfig_INSPECT, 1);
    }

    if env_flag(use_env, 0, ptr[u8]("PYTHONDONTWRITEBYTECODE")) != 0 {
        set_config_int(config, PyConfig_WRITE_BYTECODE, 0);
    }
    if env_flag(use_env, 0, ptr[u8]("PYTHONNOUSERSITE")) != 0 {
        set_config_int(config, PyConfig_USER_SITE_DIRECTORY, 0);
    }
    if env_flag(use_env, 0, ptr[u8]("PYTHONUNBUFFERED")) != 0 {
        set_config_int(config, PyConfig_BUFFERED_STDIO, 0);
    }

    if config_get_env(config, ptr[u8]("PYTHONDUMPREFS")) {
        set_config_int(config, PyConfig_DUMP_REFS, 1);
    }
    if config_get_env(config, ptr[u8]("PYTHONMALLOCSTATS")) {
        set_config_int(config, PyConfig_MALLOC_STATS, 1);
    }

    if not config_wstr(config, PyConfig_DUMP_REFS_FILE) {
        status = config_get_env_dup(
            config,
            config_wstr_slot(config, PyConfig_DUMP_REFS_FILE),
            ptr[u8]("PYTHONDUMPREFSFILE"),
            ptr[u8]("cannot decode PYTHONDUMPREFSFILE")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if not config_wstr(config, PyConfig_PYTHONPATH_ENV) {
        status = config_get_env_dup(
            config,
            config_wstr_slot(config, PyConfig_PYTHONPATH_ENV),
            ptr[u8]("PYTHONPATH"),
            ptr[u8]("cannot decode PYTHONPATH")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if not config_wstr(config, PyConfig_PLATLIBDIR) {
        status = config_get_env_dup(
            config,
            config_wstr_slot(config, PyConfig_PLATLIBDIR),
            ptr[u8]("PYTHONPLATLIBDIR"),
            ptr[u8]("cannot decode PYTHONPLATLIBDIR")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_int(config, PyConfig_USE_HASH_SEED) < 0 {
        status = config_init_hash_seed(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_get_env(config, ptr[u8]("PYTHONSAFEPATH")) {
        set_config_int(config, PyConfig_SAFE_PATH, 1);
    }

    gil = config_get_env(config, ptr[u8]("PYTHON_GIL"));
    if gil {
        status = config_read_gil(config, strlen(gil), i32(gil.view(1)[0]));
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }
    return status_ok();
}

impl cpu_count_error -> PyStatus {
    return status_err(
        ptr[u8]("config_init_cpu_count"),
        ptr[u8](
            "-X cpu_count=n option: n is missing or an invalid number, n must be greater than 0"
        )
    );
}

impl config_init_cpu_count(config: ptr[u8]) -> PyStatus {
    env = config_get_env(config, ptr[u8]("PYTHON_CPU_COUNT"));
    if env {
        cpu_count: i32 = -1;
        if strcmp(env, ptr[u8]("default")) != 0 {
            (res, value) = str_to_int(env);
            if res < 0 or value < 1 {
                return cpu_count_error();
            }
            cpu_count = value;
        }
        set_config_int(config, PyConfig_CPU_COUNT, cpu_count);
    }

    xoption = config_get_xoption(config, ptr[u8]("cpu_count"));
    if xoption {
        xcount: i32 = -1;
        sep = wide_find_equal(xoption);
        if not sep {
            return cpu_count_error();
        }
        if not wide_is(sep + 1, ptr[u8]("default")) {
            (wres, wvalue) = config_wstr_to_int(sep + 1);
            if wres < 0 or wvalue < 1 {
                return cpu_count_error();
            }
            xcount = wvalue;
        }
        set_config_int(config, PyConfig_CPU_COUNT, xcount);
    }
    return status_ok();
}

impl config_init_switch(
    config: ptr[u8],
    offset: i64,
    env_name: ptr[u8],
    env_error: ptr[u8],
    xoption_name: ptr[u8],
    xoption_error: ptr[u8],
    func: ptr[u8]
) -> PyStatus {
    env = config_get_env(config, env_name);
    if env {
        (res, enabled) = str_to_int(env);
        if res < 0 or enabled < 0 or enabled > 1 {
            return status_err(func, env_error);
        }
        set_config_int(config, offset, enabled);
    }

    xoption = config_get_xoption(config, xoption_name);
    if xoption {
        sep = wide_find_equal(xoption);
        if not sep {
            return status_err(func, xoption_error);
        }
        (wres, wenabled) = config_wstr_to_int(sep + 1);
        if wres < 0 or wenabled < 0 or wenabled > 1 {
            return status_err(func, xoption_error);
        }
        set_config_int(config, offset, wenabled);
    }
    return status_ok();
}

impl config_init_thread_inherit_context(config: ptr[u8]) -> PyStatus {
    return config_init_switch(
        config,
        PyConfig_THREAD_INHERIT_CONTEXT,
        ptr[u8]("PYTHON_THREAD_INHERIT_CONTEXT"),
        ptr[u8]("PYTHON_THREAD_INHERIT_CONTEXT=N: N is missing or invalid"),
        ptr[u8]("thread_inherit_context"),
        ptr[u8]("-X thread_inherit_context=n: n is missing or invalid"),
        ptr[u8]("config_init_thread_inherit_context")
    );
}

impl config_init_context_aware_warnings(config: ptr[u8]) -> PyStatus {
    return config_init_switch(
        config,
        PyConfig_CONTEXT_AWARE_WARNINGS,
        ptr[u8]("PYTHON_CONTEXT_AWARE_WARNINGS"),
        ptr[u8]("PYTHON_CONTEXT_AWARE_WARNINGS=N: N is missing or invalid"),
        ptr[u8]("context_aware_warnings"),
        ptr[u8]("-X context_aware_warnings=n: n is missing or invalid"),
        ptr[u8]("config_init_context_aware_warnings")
    );
}

impl config_init_perf_profiling(config: ptr[u8]) -> PyStatus {
    active: i32 = 0;
    env = config_get_env(config, ptr[u8]("PYTHONPERFSUPPORT"));
    if env {
        (res, value) = str_to_int(env);
        active = value;
        if res != 0 {
            active = 0;
        }
        if active != 0 {
            set_config_int(config, PyConfig_PERF_PROFILING, 1);
        }
    }
    if config_get_xoption(config, ptr[u8]("perf")) {
        set_config_int(config, PyConfig_PERF_PROFILING, 1);
    }
    env = config_get_env(config, ptr[u8]("PYTHON_PERF_JIT_SUPPORT"));
    if env {
        (res2, value2) = str_to_int(env);
        if res2 == 0 {
            active = value2;
        } else {
            active = 0;
        }
        if active != 0 {
            set_config_int(config, PyConfig_PERF_PROFILING, 2);
        }
    }
    if config_get_xoption(config, ptr[u8]("perf_jit")) {
        set_config_int(config, PyConfig_PERF_PROFILING, 2);
    }
    return status_ok();
}

impl config_init_tracemalloc(config: ptr[u8]) -> PyStatus {
    env = config_get_env(config, ptr[u8]("PYTHONTRACEMALLOC"));
    if env {
        (res, nframe) = str_to_int(env);
        valid = res == 0 and nframe >= 0;
        if not valid {
            return status_err(
                ptr[u8]("config_init_tracemalloc"),
                ptr[u8]("PYTHONTRACEMALLOC: invalid number of frames")
            );
        }
        set_config_int(config, PyConfig_TRACEMALLOC, nframe);
    }

    xoption = config_get_xoption(config, ptr[u8]("tracemalloc"));
    if xoption {
        frames: i32 = 1;
        sep = wide_find_equal(xoption);
        if sep {
            (wres, wframes) = config_wstr_to_int(sep + 1);
            if not (wres == 0 and wframes >= 0) {
                return status_err(
                    ptr[u8]("config_init_tracemalloc"),
                    ptr[u8]("-X tracemalloc=NFRAME: invalid number of frames")
                );
            }
            frames = wframes;
        }
        set_config_int(config, PyConfig_TRACEMALLOC, frames);
    }
    return status_ok();
}

impl config_init_int_max_str_digits(config: ptr[u8]) -> PyStatus {
    env = config_get_env(config, ptr[u8]("PYTHONINTMAXSTRDIGITS"));
    if env {
        (res, maxdigits) = str_to_int(env);
        valid = res == 0
            and (maxdigits == 0 or maxdigits >= _PY_LONG_MAX_STR_DIGITS_THRESHOLD);
        if not valid {
            return status_err(
                ptr[u8]("config_init_int_max_str_digits"),
                ptr[u8](
                    "PYTHONINTMAXSTRDIGITS: invalid limit; must be >= 640 or 0 for unlimited."
                )
            );
        }
        set_config_int(config, PyConfig_INT_MAX_STR_DIGITS, maxdigits);
    }

    xoption = config_get_xoption(config, ptr[u8]("int_max_str_digits"));
    if xoption {
        sep = wide_find_equal(xoption);
        valid = False;
        digits: i32 = 0;
        if sep {
            (wres, wdigits) = config_wstr_to_int(sep + 1);
            if wres == 0 {
                digits = wdigits;
                valid = wdigits == 0 or wdigits >= _PY_LONG_MAX_STR_DIGITS_THRESHOLD;
            }
        }
        if not valid {
            return status_err(
                ptr[u8]("config_init_int_max_str_digits"),
                ptr[u8](
                    "-X int_max_str_digits: invalid limit; must be >= 640 or 0 for unlimited."
                )
            );
        }
        set_config_int(config, PyConfig_INT_MAX_STR_DIGITS, digits);
    }
    if config_int(config, PyConfig_INT_MAX_STR_DIGITS) < 0 {
        set_config_int(
            config, PyConfig_INT_MAX_STR_DIGITS, _PY_LONG_DEFAULT_MAX_STR_DIGITS
        );
    }
    return status_ok();
}

impl config_init_pycache_prefix(config: ptr[u8]) -> PyStatus {
    xoption = config_get_xoption(config, ptr[u8]("pycache_prefix"));
    if xoption {
        sep = wide_find_equal(xoption);
        if sep and wcslen(sep) > u64(1) {
            prefix = _PyMem_RawWcsdup(sep + 1);
            set_config_wstr(config, PyConfig_PYCACHE_PREFIX, prefix);
            if not prefix {
                return no_memory(ptr[u8]("config_init_pycache_prefix"));
            }
        } else {
            set_config_wstr(config, PyConfig_PYCACHE_PREFIX, ptr[i32]());
        }
        return status_ok();
    }

    return config_get_env_dup(
        config,
        config_wstr_slot(config, PyConfig_PYCACHE_PREFIX),
        ptr[u8]("PYTHONPYCACHEPREFIX"),
        ptr[u8]("cannot decode PYTHONPYCACHEPREFIX")
    );
}

impl config_init_import_time(config: ptr[u8]) -> PyStatus {
    importtime: i32 = 0;

    env = config_get_env(config, ptr[u8]("PYTHONPROFILEIMPORTTIME"));
    if env {
        (res, value) = str_to_int(env);
        importtime = value;
        if res != 0 {
            importtime = 1;
        }
        if importtime < 0 or importtime > 2 {
            return status_err(
                ptr[u8]("config_init_import_time"),
                ptr[u8](
                    "PYTHONPROFILEIMPORTTIME: numeric values other than 1 and 2 are reserved for future use."
                )
            );
        }
    }

    x_value = config_get_xoption_value(config, ptr[u8]("importtime"));
    if x_value {
        if x_value.view(1)[0] == 0 {
            importtime = 1;
        } else {
            (wres, wvalue) = config_wstr_to_int(x_value);
            if wres != 0 {
                importtime = 1;
            } else {
                importtime = wvalue;
            }
        }
        if importtime < 0 or importtime > 2 {
            return status_err(
                ptr[u8]("config_init_import_time"),
                ptr[u8](
                    "-X importtime: values other than 1 and 2 are reserved for future use."
                )
            );
        }
    }

    set_config_int(config, PyConfig_IMPORT_TIME, importtime);
    return status_ok();
}

impl config_read_complex_options(config: ptr[u8]) -> PyStatus {
    if config_int(config, PyConfig_FAULTHANDLER) < 0 {
        if config_get_env(config, ptr[u8]("PYTHONFAULTHANDLER"))
            or config_get_xoption(config, ptr[u8]("faulthandler")) {
            set_config_int(config, PyConfig_FAULTHANDLER, 1);
        }
    }
    if config_get_env(config, ptr[u8]("PYTHONNODEBUGRANGES"))
        or config_get_xoption(config, ptr[u8]("no_debug_ranges")) {
        set_config_int(config, PyConfig_CODE_DEBUG_RANGES, 0);
    }

    if config_int(config, PyConfig_IMPORT_TIME) < 0 {
        status = config_init_import_time(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_int(config, PyConfig_TRACEMALLOC) < 0 {
        status = config_init_tracemalloc(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_int(config, PyConfig_PERF_PROFILING) < 0 {
        status = config_init_perf_profiling(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_int(config, PyConfig_REMOTE_DEBUG) < 0 {
        set_config_int(config, PyConfig_REMOTE_DEBUG, 0);
    }

    if config_int(config, PyConfig_INT_MAX_STR_DIGITS) < 0 {
        status = config_init_int_max_str_digits(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_int(config, PyConfig_CPU_COUNT) < 0 {
        status = config_init_cpu_count(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if not config_wstr(config, PyConfig_PYCACHE_PREFIX) {
        status = config_init_pycache_prefix(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    status = config_init_thread_inherit_context(config);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    status = config_init_context_aware_warnings(config);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }
    return status_ok();
}

impl config_get_stdio_errors(preconfig: ptr[PyPreConfig]) -> ptr[u8] {
    if preconfig.view(1)[0].utf8_mode != 0 {
        return ptr[u8]("surrogateescape");
    }
    loc = setlocale(LC_CTYPE, ptr[u8]());
    if loc {
        if strcmp(loc, ptr[u8]("C")) == 0 or strcmp(loc, ptr[u8]("POSIX")) == 0 {
            return ptr[u8]("surrogateescape");
        }
        if _Py_IsLocaleCoercionTarget(loc) != 0 {
            return ptr[u8]("surrogateescape");
        }
    }
    return ptr[u8]("strict");
}

impl config_get_locale_encoding(
    config: ptr[u8], preconfig: ptr[PyPreConfig], locale_encoding: ptr[ptr[i32]]
) -> PyStatus {
    encoding = ptr[i32]();
    if preconfig.view(1)[0].utf8_mode != 0 {
        encoding = raw_wide_from_ascii(ptr[u8]("utf-8"));
    } else {
        encoding = _Py_GetLocaleEncoding();
    }
    if not encoding {
        return no_memory(ptr[u8]("config_get_locale_encoding"));
    }
    status = PyConfig_SetString(config, locale_encoding, encoding);
    PyMem_RawFree(ptr(encoding));
    return status;
}

impl config_init_stdio_encoding(
    config: ptr[u8], preconfig: ptr[PyPreConfig]
) -> PyStatus {
    if config_wstr(config, PyConfig_STDIO_ENCODING)
        and config_wstr(config, PyConfig_STDIO_ERRORS) {
        return status_ok();
    }

    opt = config_get_env(config, ptr[u8]("PYTHONIOENCODING"));
    if opt {
        pythonioencoding = _PyMem_RawStrdup(opt);
        if not pythonioencoding {
            return no_memory(ptr[u8]("config_init_stdio_encoding"));
        }

        errors = strchr(pythonioencoding, 58);
        if errors {
            errors.view(1)[0] = u8(0);
            errors = errors + 1;
            if errors.view(1)[0] == u8(0) {
                errors = ptr[u8]();
            }
        }

        if pythonioencoding.view(1)[0] != u8(0) {
            if not config_wstr(config, PyConfig_STDIO_ENCODING) {
                status = config_set_bytes_string(
                    config,
                    config_wstr_slot(config, PyConfig_STDIO_ENCODING),
                    pythonioencoding,
                    ptr[u8]("cannot decode PYTHONIOENCODING environment variable")
                );
                if status._type != _PyStatus_TYPE_OK {
                    PyMem_RawFree(ptr(pythonioencoding));
                    return status;
                }
            }
            if not errors {
                errors = ptr[u8]("strict");
            }
        }

        if not config_wstr(config, PyConfig_STDIO_ERRORS) and errors {
            status = config_set_bytes_string(
                config,
                config_wstr_slot(config, PyConfig_STDIO_ERRORS),
                errors,
                ptr[u8]("cannot decode PYTHONIOENCODING environment variable")
            );
            if status._type != _PyStatus_TYPE_OK {
                PyMem_RawFree(ptr(pythonioencoding));
                return status;
            }
        }

        PyMem_RawFree(ptr(pythonioencoding));
    }

    if not config_wstr(config, PyConfig_STDIO_ENCODING) {
        status = config_get_locale_encoding(
            config, preconfig, config_wstr_slot(config, PyConfig_STDIO_ENCODING)
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }
    if not config_wstr(config, PyConfig_STDIO_ERRORS) {
        status = config_set_ascii(
            config,
            config_wstr_slot(config, PyConfig_STDIO_ERRORS),
            config_get_stdio_errors(preconfig),
            ptr[u8]("config_init_stdio_encoding")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }
    return status_ok();
}

impl config_get_fs_encoding(
    config: ptr[u8], preconfig: ptr[PyPreConfig], fs_encoding: ptr[ptr[i32]]
) -> PyStatus {
    if _Py_FORCE_UTF8_FS_ENCODING != 0 {
        return config_set_ascii(
            config, fs_encoding, ptr[u8]("utf-8"), ptr[u8]("config_get_fs_encoding")
        );
    }
    if preconfig.view(1)[0].utf8_mode != 0 {
        return config_set_ascii(
            config, fs_encoding, ptr[u8]("utf-8"), ptr[u8]("config_get_fs_encoding")
        );
    }
    if _Py_GetForceASCII() != 0 {
        return config_set_ascii(
            config, fs_encoding, ptr[u8]("ascii"), ptr[u8]("config_get_fs_encoding")
        );
    }
    return config_get_locale_encoding(config, preconfig, fs_encoding);
}

impl config_init_fs_encoding(config: ptr[u8], preconfig: ptr[PyPreConfig]) -> PyStatus {
    if not config_wstr(config, PyConfig_FILESYSTEM_ENCODING) {
        status = config_get_fs_encoding(
            config, preconfig, config_wstr_slot(config, PyConfig_FILESYSTEM_ENCODING)
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if not config_wstr(config, PyConfig_FILESYSTEM_ERRORS) {
        status = config_set_ascii(
            config,
            config_wstr_slot(config, PyConfig_FILESYSTEM_ERRORS),
            ptr[u8]("surrogateescape"),
            ptr[u8]("config_init_fs_encoding")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }
    return status_ok();
}

impl config_init_import(config: ptr[u8], compute_path_config: i32) -> PyStatus {
    status = _PyConfig_InitPathConfig(config, compute_path_config);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    env = config_get_env(config, ptr[u8]("PYTHON_FROZEN_MODULES"));
    if env {
        if strcmp(env, ptr[u8]("on")) == 0 {
            set_config_int(config, PyConfig_USE_FROZEN_MODULES, 1);
        } elif strcmp(env, ptr[u8]("off")) == 0 {
            set_config_int(config, PyConfig_USE_FROZEN_MODULES, 0);
        } else {
            return PyStatus_Error(
                ptr[u8](
                    "bad value for PYTHON_FROZEN_MODULES (expected \"on\" or \"off\")"
                )
            );
        }
    }

    value = config_get_xoption_value(config, ptr[u8]("frozen_modules"));
    if value {
        if wide_is(value, ptr[u8]("on")) {
            set_config_int(config, PyConfig_USE_FROZEN_MODULES, 1);
        } elif wide_is(value, ptr[u8]("off")) {
            set_config_int(config, PyConfig_USE_FROZEN_MODULES, 0);
        } elif value.view(1)[0] == 0 {
            set_config_int(config, PyConfig_USE_FROZEN_MODULES, 1);
        } else {
            return PyStatus_Error(
                ptr[u8](
                    "bad value for option -X frozen_modules (expected \"on\" or \"off\")"
                )
            );
        }
    }
    return status_ok();
}

impl config_read(config: ptr[u8], compute_path_config: i32) -> PyStatus {
    preconfig = runtime_preconfig();

    if config_int(config, PyConfig_USE_ENVIRONMENT) != 0 {
        status = config_read_env_vars(config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_get_xoption(config, ptr[u8]("showrefcount")) {
        set_config_int(config, PyConfig_SHOW_REF_COUNT, 1);
    }

    x_gil = config_get_xoption_value(config, ptr[u8]("gil"));
    if x_gil {
        status = config_read_gil(config, wcslen(x_gil), x_gil.view(1)[0]);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    status = config_read_complex_options(config);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    if config_int(config, PyConfig_INSTALL_IMPORTLIB) != 0 {
        status = config_init_import(config, compute_path_config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_int(config, PyConfig_DEV_MODE) != 0 {
        if config_int(config, PyConfig_FAULTHANDLER) < 0 {
            set_config_int(config, PyConfig_FAULTHANDLER, 1);
        }
    }
    if config_int(config, PyConfig_FAULTHANDLER) < 0 {
        set_config_int(config, PyConfig_FAULTHANDLER, 0);
    }
    if config_int(config, PyConfig_TRACEMALLOC) < 0 {
        set_config_int(config, PyConfig_TRACEMALLOC, 0);
    }
    if config_int(config, PyConfig_PERF_PROFILING) < 0 {
        set_config_int(config, PyConfig_PERF_PROFILING, 0);
    }
    if config_int(config, PyConfig_REMOTE_DEBUG) < 0 {
        set_config_int(config, PyConfig_REMOTE_DEBUG, -1);
    }
    if config_int(config, PyConfig_USE_HASH_SEED) < 0 {
        set_config_int(config, PyConfig_USE_HASH_SEED, 0);
        ptr[u64](config + PyConfig_HASH_SEED).view(1)[0] = u64(0);
    }

    if not config_wstr(config, PyConfig_FILESYSTEM_ENCODING)
        or not config_wstr(config, PyConfig_FILESYSTEM_ERRORS) {
        status = config_init_fs_encoding(config, preconfig);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    status = config_init_stdio_encoding(config, preconfig);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    if config_list(config, PyConfig_ARGV).view(1)[0].length < 1 {
        status = list_append_ascii(
            config_list(config, PyConfig_ARGV), ptr[u8](""), ptr[u8]("config_read")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if not config_wstr(config, PyConfig_CHECK_HASH_PYCS_MODE) {
        status = config_set_ascii(
            config,
            config_wstr_slot(config, PyConfig_CHECK_HASH_PYCS_MODE),
            ptr[u8]("default"),
            ptr[u8]("config_read")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }

    if config_int(config, PyConfig_CONFIGURE_C_STDIO) < 0 {
        set_config_int(config, PyConfig_CONFIGURE_C_STDIO, 1);
    }

    if config_int(config, PyConfig_PARSE_ARGV) == 1 {
        set_config_int(config, PyConfig_PARSE_ARGV, 2);
    }
    return status_ok();
}

impl config_init_stdio(config: ptr[u8]) {
    stdin_ = jacpy_stdio_stream(0);
    stdout_ = jacpy_stdio_stream(1);
    stderr_ = jacpy_stdio_stream(2);
    if config_int(config, PyConfig_BUFFERED_STDIO) == 0 {
        setvbuf(stdin_, ptr[u8](), _IONBF, BUFSIZ);
        setvbuf(stdout_, ptr[u8](), _IONBF, BUFSIZ);
        setvbuf(stderr_, ptr[u8](), _IONBF, BUFSIZ);
    } elif config_int(config, PyConfig_INTERACTIVE) != 0 {
        setvbuf(stdin_, ptr[u8](), _IOLBF, BUFSIZ);
        setvbuf(stdout_, ptr[u8](), _IOLBF, BUFSIZ);
    }
}

impl global_set_item(dict_: ptr[PyObject], key: ptr[u8], obj_: ptr[PyObject]) -> i32 {
    if not obj_ {
        return -1;
    }
    res = PyDict_SetItemString(dict_, key, obj_);
    object_decref(obj_);
    return res;
}

impl global_int(flag: ptr[i32]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(flag.view(1)[0]));
}

impl global_str(text: ptr[u8]) -> ptr[PyObject] {
    if text {
        return PyUnicode_FromString(text);
    }
    return object_new_ref(Py_None);
}

impl global_variables_set_items(dict_: ptr[PyObject]) -> i32 {
    if global_set_item(
        dict_,
        ptr[u8]("Py_FileSystemDefaultEncoding"),
        global_str(addressof(Py_FileSystemDefaultEncoding).view(1)[0])
    )
        < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_HasFileSystemDefaultEncoding"),
            global_int(addressof(Py_HasFileSystemDefaultEncoding))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_FileSystemDefaultEncodeErrors"),
            global_str(addressof(Py_FileSystemDefaultEncodeErrors).view(1)[0])
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("_Py_HasFileSystemDefaultEncodeErrors"),
            global_int(addressof(_Py_HasFileSystemDefaultEncodeErrors))
        )
            < 0 {
        return -1;
    }
    if global_set_item(
        dict_, ptr[u8]("Py_UTF8Mode"), global_int(addressof(Py_UTF8Mode))
    )
        < 0
        or global_set_item(
            dict_, ptr[u8]("Py_DebugFlag"), global_int(addressof(Py_DebugFlag))
        )
            < 0
        or global_set_item(
            dict_, ptr[u8]("Py_VerboseFlag"), global_int(addressof(Py_VerboseFlag))
        )
            < 0
        or global_set_item(
            dict_, ptr[u8]("Py_QuietFlag"), global_int(addressof(Py_QuietFlag))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_InteractiveFlag"),
            global_int(addressof(Py_InteractiveFlag))
        )
            < 0
        or global_set_item(
            dict_, ptr[u8]("Py_InspectFlag"), global_int(addressof(Py_InspectFlag))
        )
            < 0 {
        return -1;
    }
    if global_set_item(
        dict_, ptr[u8]("Py_OptimizeFlag"), global_int(addressof(Py_OptimizeFlag))
    )
        < 0
        or global_set_item(
            dict_, ptr[u8]("Py_NoSiteFlag"), global_int(addressof(Py_NoSiteFlag))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_BytesWarningFlag"),
            global_int(addressof(Py_BytesWarningFlag))
        )
            < 0
        or global_set_item(
            dict_, ptr[u8]("Py_FrozenFlag"), global_int(addressof(Py_FrozenFlag))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_IgnoreEnvironmentFlag"),
            global_int(addressof(Py_IgnoreEnvironmentFlag))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_DontWriteBytecodeFlag"),
            global_int(addressof(Py_DontWriteBytecodeFlag))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_NoUserSiteDirectory"),
            global_int(addressof(Py_NoUserSiteDirectory))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_UnbufferedStdioFlag"),
            global_int(addressof(Py_UnbufferedStdioFlag))
        )
            < 0
        or global_set_item(
            dict_,
            ptr[u8]("Py_HashRandomizationFlag"),
            global_int(addressof(Py_HashRandomizationFlag))
        )
            < 0
        or global_set_item(
            dict_, ptr[u8]("Py_IsolatedFlag"), global_int(addressof(Py_IsolatedFlag))
        )
            < 0 {
        return -1;
    }
    return 0;
}

impl global_variables_as_dict -> ptr[PyObject] {
    dict_ = PyDict_New();
    if not dict_ {
        return NULL;
    }
    if global_variables_set_items(dict_) < 0 {
        object_decref(dict_);
        return NULL;
    }
    return dict_;
}

impl init_dump_ascii_wstr(text: ptr[i32]) {
    if not text {
        PySys_WriteStderr(ptr[u8]("(not set)"));
        return;
    }
    PySys_WriteStderr(ptr[u8]("'"));
    i: i64 = 0;
    while (text + i).view(1)[0] != 0 {
        ch = u32.wrap((text + i).view(1)[0]);
        if ch == u32(39) {
            PySys_WriteStderr(ptr[u8]("\\'"));
        } elif u32(32) <= ch and ch < u32(127) {
            PySys_WriteStderr(ptr[u8]("%c"), i32(ch));
        } elif ch <= u32(255) {
            PySys_WriteStderr(ptr[u8]("\\x%02x"), i32(ch));
        } elif ch > u32(65535) {
            PySys_WriteStderr(ptr[u8]("\\U%08x"), i32.wrap(ch));
        } else {
            PySys_WriteStderr(ptr[u8]("\\u%04x"), i32(ch));
        }
        i += 1;
    }
    PySys_WriteStderr(ptr[u8]("'"));
}

impl dump_config(name: ptr[u8], value: ptr[i32]) {
    PySys_WriteStderr(ptr[u8]("  %s = "), name);
    init_dump_ascii_wstr(value);
    PySys_WriteStderr(ptr[u8]("\n"));
}

impl dump_sys_name(name: ptr[u8]) {
    PySys_FormatStderr(ptr[u8]("  sys.%s = "), name);
}

impl dump_sys_value(res: i32, obj_: ptr[PyObject]) {
    if res < 0 {
        PyErr_Clear();
    }
    if obj_ {
        PySys_FormatStderr(ptr[u8]("%A"), obj_);
        object_decref(obj_);
    } else {
        PySys_WriteStderr(ptr[u8]("(not set)"));
    }
    PySys_FormatStderr(ptr[u8]("\n"));
}

impl config_usage(error: i32, program: ptr[i32]) {
    f = jacpy_stdio_stream(2) if error != 0 else jacpy_stdio_stream(1);
    fprintf(
        f,
        ptr[u8]("usage: %ls [option] ... [-c cmd | -m mod | file | -] [arg] ...\n"),
        program
    );
    if error != 0 {
        fprintf(f, ptr[u8]("Try `python -h' for more information.\n"));
    } else {
        fputs(usage_help(), f);
    }
}

impl config_envvars_usage {
    fputs(usage_envvars_head(), jacpy_stdio_stream(1));
    if MI_PLATFORM_LINUX == 0 {
        fputs(
            ptr[u8]("PYTHONEXECUTABLE: set sys.argv[0] to this value (macOS only)\n"),
            jacpy_stdio_stream(1)
        );
    }
    printf(
        usage_envvars_tail(), DELIM_CHAR, ptr[u8]("<prefix>/lib/pythonX.X"), DELIM_CHAR
    );
}

impl config_xoptions_usage {
    puts(usage_xoptions());
}

impl config_complete_usage(program: ptr[i32]) {
    config_usage(0, program);
    putchar(10);
    config_envvars_usage();
    putchar(10);
    config_xoptions_usage();
}

impl config_parse_cmdline(
    config: ptr[u8], warnoptions: ptr[PyWideStringList], opt_index: ptr[i64]
) -> PyStatus {
    argv = config_list(config, PyConfig_ARGV);
    print_version = 0;
    program = config_wstr(config, PyConfig_PROGRAM_NAME);
    if not program and argv.view(1)[0].length >= 1 {
        program = argv.view(1)[0].items.view(1)[0];
    }

    slots: own InitconfigStack = InitconfigStack();
    longindex = ptr[i32](jacpy_stack_address(&mut slots));

    _PyOS_ResetGetOpt();
    while True {
        longindex.view(1)[0] = -1;
        c = _PyOS_GetOpt(argv.view(1)[0].length, argv.view(1)[0].items, longindex);
        if c == -1 {
            break;
        }

        optarg = addressof(_PyOS_optarg).view(1)[0];
        if c == 99 {
            if not config_wstr(config, PyConfig_RUN_COMMAND) {
                length = i64(wcslen(optarg)) + 2;
                command = ptr[i32](PyMem_RawMalloc(u64(4 * length)));
                if not command {
                    return no_memory(ptr[u8]("config_parse_cmdline"));
                }
                memcpy(ptr(command), ptr(optarg), u64((length - 2) * 4));
                (command + (length - 2)).view(1)[0] = 10;
                (command + (length - 1)).view(1)[0] = 0;
                set_config_wstr(config, PyConfig_RUN_COMMAND, command);
            }
            break;
        }

        if c == 109 {
            if not config_wstr(config, PyConfig_RUN_MODULE) {
                run_module = _PyMem_RawWcsdup(optarg);
                set_config_wstr(config, PyConfig_RUN_MODULE, run_module);
                if not run_module {
                    return no_memory(ptr[u8]("config_parse_cmdline"));
                }
            }
            break;
        }

        if c == 0 {
            if wide_is(optarg, ptr[u8]("always"))
                or wide_is(optarg, ptr[u8]("never"))
                or wide_is(optarg, ptr[u8]("default")) {
                status = PyConfig_SetString(
                    config,
                    config_wstr_slot(config, PyConfig_CHECK_HASH_PYCS_MODE),
                    optarg
                );
                if status._type != _PyStatus_TYPE_OK {
                    return status;
                }
            } else {
                fprintf(
                    jacpy_stdio_stream(2),
                    ptr[u8](
                        "--check-hash-based-pycs must be one of 'default', 'always', or 'never'\n"
                    )
                );
                config_usage(1, program);
                return status_exit(2);
            }
        } elif c == 1 {
            config_complete_usage(program);
            return status_exit(0);
        } elif c == 2 {
            config_envvars_usage();
            return status_exit(0);
        } elif c == 3 {
            config_xoptions_usage();
            return status_exit(0);
        } elif c == 98 {
            bump(config, PyConfig_BYTES_WARNING);
        } elif c == 100 {
            bump(config, PyConfig_PARSER_DEBUG);
        } elif c == 105 {
            bump(config, PyConfig_INSPECT);
            bump(config, PyConfig_INTERACTIVE);
        } elif c == 69 or c == 73 or c == 88 or c == 116 {
            print_version += 0;
        } elif c == 79 {
            bump(config, PyConfig_OPTIMIZATION_LEVEL);
        } elif c == 80 {
            set_config_int(config, PyConfig_SAFE_PATH, 1);
        } elif c == 66 {
            set_config_int(config, PyConfig_WRITE_BYTECODE, 0);
        } elif c == 115 {
            set_config_int(config, PyConfig_USER_SITE_DIRECTORY, 0);
        } elif c == 83 {
            set_config_int(config, PyConfig_SITE_IMPORT, 0);
        } elif c == 117 {
            set_config_int(config, PyConfig_BUFFERED_STDIO, 0);
        } elif c == 118 {
            bump(config, PyConfig_VERBOSE);
        } elif c == 120 {
            set_config_int(config, PyConfig_SKIP_SOURCE_FIRST_LINE, 1);
        } elif c == 104 or c == 63 {
            config_usage(0, program);
            return status_exit(0);
        } elif c == 86 {
            print_version += 1;
        } elif c == 87 {
            status = PyWideStringList_Append(warnoptions, optarg);
            if status._type != _PyStatus_TYPE_OK {
                return status;
            }
        } elif c == 113 {
            bump(config, PyConfig_QUIET);
        } elif c == 82 {
            set_config_int(config, PyConfig_USE_HASH_SEED, 0);
        } else {
            config_usage(1, program);
            return status_exit(2);
        }
    }

    if print_version != 0 {
        version = Py_GetVersion();
        if print_version >= 2 {
            printf(ptr[u8]("Python %s\n"), version);
        } else {
            printf(ptr[u8]("Python %.*s\n"), version_length(version), version);
        }
        return status_exit(0);
    }

    optind = addressof(_PyOS_optind).view(1)[0];
    if not config_wstr(config, PyConfig_RUN_COMMAND)
        and not config_wstr(config, PyConfig_RUN_MODULE)
        and optind < argv.view(1)[0].length
        and not wide_is((argv.view(1)[0].items + optind).view(1)[0], ptr[u8]("-"))
        and not config_wstr(config, PyConfig_RUN_FILENAME) {
        run_filename = _PyMem_RawWcsdup((argv.view(1)[0].items + optind).view(1)[0]);
        set_config_wstr(config, PyConfig_RUN_FILENAME, run_filename);
        if not run_filename {
            return no_memory(ptr[u8]("config_parse_cmdline"));
        }
    }

    if config_wstr(config, PyConfig_RUN_COMMAND)
        or config_wstr(config, PyConfig_RUN_MODULE) {
        optind = optind - 1;
        addressof(_PyOS_optind).view(1)[0] = optind;
    }

    opt_index.view(1)[0] = optind;
    return status_ok();
}

impl bump(config: ptr[u8], offset: i64) {
    set_config_int(config, offset, config_int(config, offset) + 1);
}

impl version_length(version: ptr[u8]) -> i32 {
    n: i32 = 0;
    while (version + n).view(1)[0] != u8(0) and (version + n).view(1)[0] != u8(32) {
        n += 1;
    }
    return n;
}

impl config_init_env_warnoptions(
    config: ptr[u8], warnoptions: ptr[PyWideStringList]
) -> PyStatus {
    slots: own InitconfigStack = InitconfigStack();
    env_slot = ptr[ptr[i32]](jacpy_stack_address(&mut slots));
    status = config_get_env_dup(
        config,
        env_slot,
        ptr[u8]("PYTHONWARNINGS"),
        ptr[u8]("cannot decode PYTHONWARNINGS")
    );
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    env = env_slot.view(1)[0];
    if not env {
        return status_ok();
    }

    i: i64 = 0;
    while True {
        while (env + i).view(1)[0] == 44 {
            i += 1;
        }
        if (env + i).view(1)[0] == 0 {
            break;
        }
        start = i;
        while (env + i).view(1)[0] != 0 and (env + i).view(1)[0] != 44 {
            i += 1;
        }
        at_end = (env + i).view(1)[0] == 0;
        (env + i).view(1)[0] = 0;
        status = PyWideStringList_Append(warnoptions, env + start);
        if status._type != _PyStatus_TYPE_OK {
            PyMem_RawFree(ptr(env));
            return status;
        }
        if at_end {
            break;
        }
        i += 1;
    }
    PyMem_RawFree(ptr(env));
    return status_ok();
}

impl warnoptions_append(
    config: ptr[u8], options: ptr[PyWideStringList], option: ptr[i32]
) -> PyStatus {
    if wide_list_find(config_list(config, PyConfig_WARNOPTIONS), option) != 0 {
        return status_ok();
    }
    if wide_list_find(options, option) != 0 {
        return status_ok();
    }
    return PyWideStringList_Append(options, option);
}

impl warnoptions_append_ascii(
    config: ptr[u8], options: ptr[PyWideStringList], text: ptr[u8]
) -> PyStatus {
    wide = wide_from_ascii(text);
    if not wide {
        return no_memory(ptr[u8]("config_init_warnoptions"));
    }
    status = warnoptions_append(config, options, wide);
    free(ptr(wide));
    return status;
}

impl warnoptions_extend(
    config: ptr[u8], options: ptr[PyWideStringList], options2: ptr[PyWideStringList]
) -> PyStatus {
    count = options2.view(1)[0].length;
    items = options2.view(1)[0].items;
    for i in range(count) {
        status = warnoptions_append(config, options, (items + i).view(1)[0]);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    }
    return status_ok();
}

impl config_init_warnoptions(
    config: ptr[u8],
    cmdline_warnoptions: ptr[PyWideStringList],
    env_warnoptions: ptr[PyWideStringList],
    sys_warnoptions: ptr[PyWideStringList],
    options: ptr[PyWideStringList]
) -> PyStatus {
    status = status_ok();
    if config_int(config, PyConfig_DEV_MODE) != 0 {
        status = warnoptions_append_ascii(config, options, ptr[u8]("default"));
    }
    if status._type == _PyStatus_TYPE_OK {
        status = warnoptions_extend(config, options, env_warnoptions);
    }
    if status._type == _PyStatus_TYPE_OK {
        status = warnoptions_extend(config, options, cmdline_warnoptions);
    }
    if status._type == _PyStatus_TYPE_OK {
        bytes_warning = config_int(config, PyConfig_BYTES_WARNING);
        if bytes_warning != 0 {
            if bytes_warning > 1 {
                status = warnoptions_append_ascii(
                    config, options, ptr[u8]("error::BytesWarning")
                );
            } else {
                status = warnoptions_append_ascii(
                    config, options, ptr[u8]("default::BytesWarning")
                );
            }
        }
    }
    if status._type == _PyStatus_TYPE_OK {
        status = warnoptions_extend(config, options, sys_warnoptions);
    }
    if status._type == _PyStatus_TYPE_OK {
        status = _PyWideStringList_Extend(
            options, config_list(config, PyConfig_WARNOPTIONS)
        );
    }
    if status._type != _PyStatus_TYPE_OK {
        _PyWideStringList_Clear(options);
        return status;
    }

    warnoptions = config_list(config, PyConfig_WARNOPTIONS);
    _PyWideStringList_Clear(warnoptions);
    warnoptions.view(1)[0].length = options.view(1)[0].length;
    warnoptions.view(1)[0].items = options.view(1)[0].items;
    options.view(1)[0].length = 0;
    options.view(1)[0].items = ptr[ptr[i32]]();
    return status_ok();
}

impl config_update_argv(config: ptr[u8], opt_index: i64) -> PyStatus {
    cmdline_argv = config_list(config, PyConfig_ARGV);
    slots: own InitconfigStack = InitconfigStack();
    config_argv = ptr[PyWideStringList](jacpy_stack_address(&mut slots));

    if cmdline_argv.view(1)[0].length <= opt_index {
        status = list_append_ascii(
            config_argv, ptr[u8](""), ptr[u8]("config_update_argv")
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
    } elif wide_list_copy_items(
        config_argv,
        cmdline_argv.view(1)[0].length - opt_index,
        cmdline_argv.view(1)[0].items + opt_index,
        False
    )
        < 0 {
        return no_memory(ptr[u8]("config_update_argv"));
    }

    arg0 = ptr[i32]();
    if config_wstr(config, PyConfig_RUN_COMMAND) {
        arg0 = raw_wide_from_ascii(ptr[u8]("-c"));
        if not arg0 {
            _PyWideStringList_Clear(config_argv);
            return no_memory(ptr[u8]("config_update_argv"));
        }
    } elif config_wstr(config, PyConfig_RUN_MODULE) {
        arg0 = raw_wide_from_ascii(ptr[u8]("-m"));
        if not arg0 {
            _PyWideStringList_Clear(config_argv);
            return no_memory(ptr[u8]("config_update_argv"));
        }
    }

    if arg0 {
        items = config_argv.view(1)[0].items;
        PyMem_RawFree(ptr(items.view(1)[0]));
        items.view(1)[0] = arg0;
    }

    _PyWideStringList_Clear(cmdline_argv);
    cmdline_argv.view(1)[0].length = config_argv.view(1)[0].length;
    cmdline_argv.view(1)[0].items = config_argv.view(1)[0].items;
    return status_ok();
}

impl core_read_precmdline(config: ptr[u8], precmdline: ptr[_PyPreCmdline]) -> PyStatus {
    if config_int(config, PyConfig_PARSE_ARGV) == 1 {
        if _PyWideStringList_Copy(
            ptr[PyWideStringList](precmdline), config_list(config, PyConfig_ARGV)
        )
            < 0 {
            return no_memory(ptr[u8]("core_read_precmdline"));
        }
    }

    slots: own InitconfigStack = InitconfigStack();
    preconfig = ptr[PyPreConfig](jacpy_stack_address(&mut slots));

    status = _PyPreConfig_InitFromPreConfig(preconfig, runtime_preconfig());
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    _PyPreConfig_GetConfig(preconfig, config);

    status = _PyPreCmdline_Read(precmdline, preconfig);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    status = _PyPreCmdline_SetConfig(precmdline, config);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }
    return status_ok();
}

impl config_run_filename_abspath(config: ptr[u8]) -> PyStatus {
    run_filename = config_wstr(config, PyConfig_RUN_FILENAME);
    if not run_filename {
        return status_ok();
    }

    if _Py_isabs(run_filename) != 0 {
        return status_ok();
    }

    slots: own InitconfigStack = InitconfigStack();
    abs_slot = ptr[ptr[i32]](jacpy_stack_address(&mut slots));
    if _Py_abspath(run_filename, abs_slot) < 0 {
        return status_ok();
    }
    abs_filename = abs_slot.view(1)[0];
    if not abs_filename {
        return no_memory(ptr[u8]("config_run_filename_abspath"));
    }

    PyMem_RawFree(ptr(run_filename));
    set_config_wstr(config, PyConfig_RUN_FILENAME, abs_filename);
    return status_ok();
}

impl config_read_cmdline(config: ptr[u8]) -> PyStatus {
    slots: own InitconfigStack = InitconfigStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    cmdline_warnoptions = ptr[PyWideStringList](base);
    env_warnoptions = ptr[PyWideStringList](base + 16);
    sys_warnoptions = ptr[PyWideStringList](base + 32);
    options = ptr[PyWideStringList](base + 48);
    opt_index = ptr[i64](base + 64);

    if config_int(config, PyConfig_PARSE_ARGV) < 0 {
        set_config_int(config, PyConfig_PARSE_ARGV, 1);
    }

    status = status_ok();
    if config_int(config, PyConfig_PARSE_ARGV) == 1 {
        status = config_parse_cmdline(config, cmdline_warnoptions, opt_index);
        if status._type == _PyStatus_TYPE_OK {
            status = config_run_filename_abspath(config);
        }
        if status._type == _PyStatus_TYPE_OK {
            status = config_update_argv(config, opt_index.view(1)[0]);
        }
    } else {
        status = config_run_filename_abspath(config);
    }

    if status._type == _PyStatus_TYPE_OK
        and config_int(config, PyConfig_USE_ENVIRONMENT) != 0 {
        status = config_init_env_warnoptions(config, env_warnoptions);
    }

    if status._type == _PyStatus_TYPE_OK {
        status = _PySys_ReadPreinitWarnOptions(sys_warnoptions);
    }

    if status._type == _PyStatus_TYPE_OK {
        status = config_init_warnoptions(
            config, cmdline_warnoptions, env_warnoptions, sys_warnoptions, options
        );
    }

    _PyWideStringList_Clear(cmdline_warnoptions);
    _PyWideStringList_Clear(env_warnoptions);
    _PyWideStringList_Clear(sys_warnoptions);
    return status;
}

impl usage_help -> ptr[u8] {
    return ptr[u8](
        "Options (and corresponding environment variables):\n"
        "-b     : issue warnings about converting bytes/bytearray to str and comparing\n"
        "         bytes/bytearray with str or bytes with int. (-bb: issue errors)\n"
        "-B     : don't write .pyc files on import; also PYTHONDONTWRITEBYTECODE=x\n"
        "-c cmd : program passed in as string (terminates option list)\n"
        "-d     : turn on parser debugging output (for experts only, only works on\n"
        "         debug builds); also PYTHONDEBUG=x\n"
        "-E     : ignore PYTHON* environment variables (such as PYTHONPATH)\n"
        "-h     : print this help message and exit (also -? or --help)\n"
        "-i     : inspect interactively after running script; forces a prompt even\n"
        "         if stdin does not appear to be a terminal; also PYTHONINSPECT=x\n"
        "-I     : isolate Python from the user's environment (implies -E, -P and -s)\n"
        "-m mod : run library module as a script (terminates option list)\n"
        "-O     : remove assert and __debug__-dependent statements; add .opt-1 before\n"
        "         .pyc extension; also PYTHONOPTIMIZE=x\n"
        "-OO    : do -O changes and also discard docstrings; add .opt-2 before\n"
        "         .pyc extension\n"
        "-P     : don't prepend a potentially unsafe path to sys.path; also\n"
        "         PYTHONSAFEPATH\n"
        "-q     : don't print version and copyright messages on interactive startup\n"
        "-s     : don't add user site directory to sys.path; also PYTHONNOUSERSITE=x\n"
        "-S     : don't imply 'import site' on initialization\n"
        "-u     : force the stdout and stderr streams to be unbuffered;\n"
        "         this option has no effect on stdin; also PYTHONUNBUFFERED=x\n"
        "-v     : verbose (trace import statements); also PYTHONVERBOSE=x\n"
        "         can be supplied multiple times to increase verbosity\n"
        "-V     : print the Python version number and exit (also --version)\n"
        "         when given twice, print more information about the build\n"
        "-W arg : warning control; arg is action:message:category:module:lineno\n"
        "         also PYTHONWARNINGS=arg\n"
        "-x     : skip first line of source, allowing use of non-Unix forms of #!cmd\n"
        "-X opt : set implementation-specific option\n"
        "--check-hash-based-pycs always|default|never:\n"
        "         control how Python invalidates hash-based .pyc files\n"
        "--help-env: print help about Python environment variables and exit\n"
        "--help-xoptions: print help about implementation-specific -X options and exit\n"
        "--help-all: print complete help information and exit\n"
        "\n"
        "Arguments:\n"
        "file   : program read from script file\n"
        "-      : program read from stdin (default; interactive mode if a tty)\n"
        "arg ...: arguments passed to program in sys.argv[1:]\n"
    );
}

impl usage_xoptions -> ptr[u8] {
    return ptr[u8](
        "The following implementation-specific options are available:\n"
        "-X context_aware_warnings=[0|1]: if true (1) then the warnings module will\n"
        "         use a context variables; if false (0) then the warnings module will\n"
        "         use module globals, which is not concurrent-safe; set to true for\n"
        "         free-threaded builds and false otherwise; also\n"
        "         PYTHON_CONTEXT_AWARE_WARNINGS\n"
        "-X cpu_count=N: override the return value of os.cpu_count();\n"
        "         -X cpu_count=default cancels overriding; also PYTHON_CPU_COUNT\n"
        "-X dev : enable Python Development Mode; also PYTHONDEVMODE\n"
        "-X disable-remote-debug: disable remote debugging; also PYTHON_DISABLE_REMOTE_DEBUG\n"
        "-X faulthandler: dump the Python traceback on fatal errors;\n"
        "         also PYTHONFAULTHANDLER\n"
        "-X frozen_modules=[on|off]: whether to use frozen modules; the default is \"on\"\n"
        "         for installed Python and \"off\" for a local build;\n"
        "         also PYTHON_FROZEN_MODULES\n"
        "-X importtime[=2]: show how long each import takes; use -X importtime=2 to\n"
        "         log imports of already-loaded modules; also PYTHONPROFILEIMPORTTIME\n"
        "-X int_max_str_digits=N: limit the size of int<->str conversions;\n"
        "         0 disables the limit; also PYTHONINTMAXSTRDIGITS\n"
        "-X no_debug_ranges: don't include extra location information in code objects;\n"
        "         also PYTHONNODEBUGRANGES\n"
        "-X perf: support the Linux \"perf\" profiler; also PYTHONPERFSUPPORT=1\n"
        "-X perf_jit: support the Linux \"perf\" profiler with DWARF support;\n"
        "         also PYTHON_PERF_JIT_SUPPORT=1\n"
        "-X pycache_prefix=PATH: write .pyc files to a parallel tree instead of to the\n"
        "         code tree; also PYTHONPYCACHEPREFIX\n"
        "-X showrefcount: output the total reference count and number of used\n"
        "         memory blocks when the program finishes or after each statement in\n"
        "         the interactive interpreter; only works on debug builds\n"
        "-X thread_inherit_context=[0|1]: enable (1) or disable (0) threads inheriting\n"
        "         context vars by default; enabled by default in the free-threaded\n"
        "         build and disabled otherwise; also PYTHON_THREAD_INHERIT_CONTEXT\n"
        "-X tracemalloc[=N]: trace Python memory allocations; N sets a traceback limit\n"
        "         of N frames (default: 1); also PYTHONTRACEMALLOC=N\n"
        "-X utf8[=0|1]: enable (1) or disable (0) UTF-8 mode; also PYTHONUTF8\n"
        "-X warn_default_encoding: enable opt-in EncodingWarning for 'encoding=None';\n"
        "         also PYTHONWARNDEFAULTENCODING"
    );
}

impl usage_envvars_head -> ptr[u8] {
    return ptr[u8](
        "Environment variables that change behavior:\n"
        "PYTHONASYNCIODEBUG: enable asyncio debug mode\n"
        "PYTHON_BASIC_REPL: use the traditional parser-based REPL\n"
        "PYTHONBREAKPOINT: if this variable is set to 0, it disables the default\n"
        "                  debugger.  It can be set to the callable of your debugger of\n"
        "                  choice.\n"
        "PYTHONCASEOK    : ignore case in 'import' statements (Windows)\n"
        "PYTHONCOERCECLOCALE: if this variable is set to 0, it disables the locale\n"
        "                  coercion behavior.  Use PYTHONCOERCECLOCALE=warn to request\n"
        "                  display of locale coercion and locale compatibility warnings\n"
        "                  on stderr.\n"
        "PYTHON_COLORS   : if this variable is set to 1, the interpreter will colorize\n"
        "                  various kinds of output.  Setting it to 0 deactivates\n"
        "                  this behavior.\n"
    );
}

impl usage_envvars_tail -> ptr[u8] {
    return ptr[u8](
        "PYTHONHASHSEED  : if this variable is set to 'random', a random value is used\n"
        "                  to seed the hashes of str and bytes objects.  It can also be\n"
        "                  set to an integer in the range [0,4294967295] to get hash\n"
        "                  values with a predictable seed.\n"
        "PYTHON_HISTORY  : the location of a .python_history file.\n"
        "PYTHONHOME      : alternate <prefix> directory (or <prefix>%lc<exec_prefix>).\n"
        "                  The default module search path uses %s.\n"
        "PYTHONIOENCODING: encoding[:errors] used for stdin/stdout/stderr\n"
        "PYTHONMALLOC    : set the Python memory allocators and/or install debug hooks\n"
        "                  on Python memory allocators.  Use PYTHONMALLOC=debug to\n"
        "                  install debug hooks.\n"
        "PYTHONMALLOCSTATS: print memory allocator statistics\n"
        "PYTHONPATH      : '%lc'-separated list of directories prefixed to the\n"
        "                  default module search path.  The result is sys.path.\n"
        "PYTHONPLATLIBDIR: override sys.platlibdir\n"
        "PYTHONSTARTUP   : file executed on interactive startup (no default)\n"
        "PYTHONUSERBASE  : defines the user base directory (site.USER_BASE)\n"
        "\n"
        "These variables have equivalent command-line options (see --help for details):\n"
        "PYTHON_CONTEXT_AWARE_WARNINGS: if true (1), enable thread-safe warnings\n"
        "                  module behaviour (-X context_aware_warnings)\n"
        "PYTHON_CPU_COUNT: override the return value of os.cpu_count() (-X cpu_count)\n"
        "PYTHONDEBUG     : enable parser debug mode (-d)\n"
        "PYTHONDEVMODE   : enable Python Development Mode (-X dev)\n"
        "PYTHONDONTWRITEBYTECODE: don't write .pyc files (-B)\n"
        "PYTHONFAULTHANDLER: dump the Python traceback on fatal errors (-X faulthandler)\n"
        "PYTHON_FROZEN_MODULES: whether to use frozen modules; the default is \"on\"\n"
        "                  for installed Python and \"off\" for a local build\n"
        "                  (-X frozen_modules)\n"
        "PYTHONINSPECT   : inspect interactively after running script (-i)\n"
        "PYTHONINTMAXSTRDIGITS: limit the size of int<->str conversions;\n"
        "                  0 disables the limit (-X int_max_str_digits=N)\n"
        "PYTHONNODEBUGRANGES: don't include extra location information in code objects\n"
        "                  (-X no_debug_ranges)\n"
        "PYTHONNOUSERSITE: disable user site directory (-s)\n"
        "PYTHONOPTIMIZE  : enable level 1 optimizations (-O)\n"
        "PYTHON_PERF_JIT_SUPPORT: enable Linux \"perf\" profiler support with JIT\n"
        "                  (-X perf_jit)\n"
        "PYTHONPERFSUPPORT: support the Linux \"perf\" profiler (-X perf)\n"
        "PYTHONPROFILEIMPORTTIME: show how long each import takes (-X importtime)\n"
        "PYTHONPYCACHEPREFIX: root directory for bytecode cache (pyc) files\n"
        "                  (-X pycache_prefix)\n"
        "PYTHONSAFEPATH  : don't prepend a potentially unsafe path to sys.path.\n"
        "PYTHON_THREAD_INHERIT_CONTEXT: if true (1), threads inherit context vars\n"
        "                  (-X thread_inherit_context)\n"
        "PYTHONTRACEMALLOC: trace Python memory allocations (-X tracemalloc)\n"
        "PYTHONUNBUFFERED: disable stdout/stderr buffering (-u)\n"
        "PYTHONUTF8      : control the UTF-8 mode (-X utf8)\n"
        "PYTHONVERBOSE   : trace import statements (-v)\n"
        "PYTHONWARNDEFAULTENCODING: enable opt-in EncodingWarning for 'encoding=None'\n"
        "                  (-X warn_default_encoding)\n"
        "PYTHONWARNINGS  : warning control (-W)\n"
    );
}


impl initconfig_status(config: ptr[u8]) -> ptr[PyStatus] {
    return ptr[PyStatus](config + INITCONFIG_STATUS);
}

impl initconfig_preconfig(config: ptr[u8]) -> ptr[PyPreConfig] {
    return ptr[PyPreConfig](config + INITCONFIG_PRECONFIG);
}

impl initconfig_config(config: ptr[u8]) -> ptr[u8] {
    return config + INITCONFIG_CONFIG;
}

impl initconfig_set_error(config: ptr[u8], err_msg: ptr[u8]) {
    initconfig_status(config).view(1)[0] = status_err(
        ptr[u8]("initconfig_set_error"), err_msg
    );
}

impl initconfig_prepare(config: ptr[u8], name: ptr[u8]) -> tuple[i32, ptr[u8]] {
    index = find_spec(PYCONFIG_SPEC, name, False);
    if index >= 0 {
        spec = PYCONFIG_SPEC[index];
        return (spec.type, initconfig_config(config) + spec.offset);
    }
    index = find_spec(PYPRECONFIG_SPEC, name, False);
    if index >= 0 {
        prespec = PYPRECONFIG_SPEC[index];
        return (prespec.type, ptr[u8](initconfig_preconfig(config)) + prespec.offset);
    }
    initconfig_set_error(config, ptr[u8]("unknown config option name"));
    return (i32(-1), ptr[u8]());
}

impl wstr_to_utf8(config: ptr[u8], wstr: ptr[i32]) -> ptr[u8] {
    slots: own InitconfigStack = InitconfigStack();
    utf8_slot = ptr[ptr[u8]](jacpy_stack_address(&mut slots));
    res = _Py_EncodeUTF8Ex(
        wstr, utf8_slot, ptr[u64](), ptr[ptr[u8]](), 1, ERROR_STRICT
    );
    if res == -2 {
        initconfig_set_error(config, ptr[u8]("encoding error"));
        return ptr[u8]();
    }
    if res < 0 {
        initconfig_status(config).view(1)[0] = no_memory(ptr[u8]("wstr_to_utf8"));
        return ptr[u8]();
    }

    utf8 = utf8_slot.view(1)[0];
    size = strlen(utf8) + u64(1);
    text = ptr[u8](malloc(size));
    if not text {
        PyMem_RawFree(ptr(utf8));
        initconfig_status(config).view(1)[0] = no_memory(ptr[u8]("wstr_to_utf8"));
        return ptr[u8]();
    }
    memcpy(ptr(text), ptr(utf8), size);
    PyMem_RawFree(ptr(utf8));
    return text;
}

impl utf8_to_wstr(config: ptr[u8], text: ptr[u8]) -> ptr[i32] {
    slots: own InitconfigStack = InitconfigStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    wstr_slot = ptr[ptr[i32]](base);
    wlen_slot = ptr[u64](base + 8);
    res = _Py_DecodeUTF8Ex(
        text, i64(strlen(text)), wstr_slot, wlen_slot, ptr[ptr[u8]](), ERROR_STRICT
    );
    if res == -2 {
        initconfig_set_error(config, ptr[u8]("decoding error"));
        return ptr[i32]();
    }
    if res < 0 {
        initconfig_status(config).view(1)[0] = no_memory(ptr[u8]("utf8_to_wstr"));
        return ptr[i32]();
    }

    wstr = wstr_slot.view(1)[0];
    size = (wlen_slot.view(1)[0] + u64(1)) * u64(4);
    wstr2 = ptr[i32](malloc(size));
    if not wstr2 {
        PyMem_RawFree(ptr(wstr));
        initconfig_status(config).view(1)[0] = no_memory(ptr[u8]("utf8_to_wstr"));
        return ptr[i32]();
    }
    memcpy(ptr(wstr2), ptr(wstr), size);
    PyMem_RawFree(ptr(wstr));
    return wstr2;
}

impl initconfig_free_wstr(member: ptr[i32]) {
    if member {
        free(ptr(member));
    }
}

impl initconfig_free_wstr_list(list: ptr[PyWideStringList]) {
    count = list.view(1)[0].length;
    for i in range(count) {
        free(ptr((list.view(1)[0].items + i).view(1)[0]));
    }
    free(ptr(list.view(1)[0].items));
}

impl initconfig_free_config(config: ptr[u8]) {
    for spec in PYCONFIG_SPEC {
        member = config + spec.offset;
        if spec.type == MEMBER_WSTR or spec.type == MEMBER_WSTR_OPT {
            initconfig_free_wstr(ptr[ptr[i32]](member).view(1)[0]);
        } elif spec.type == MEMBER_WSTR_LIST {
            initconfig_free_wstr_list(ptr[PyWideStringList](member));
        }
    }
}

impl initconfig_set_str_list(
    config: ptr[u8], list: ptr[PyWideStringList], length: i64, items: ptr[ptr[u8]]
) -> i32 {
    slots: own InitconfigStack = InitconfigStack();
    wlist = ptr[PyWideStringList](jacpy_stack_address(&mut slots));
    wlist.view(1)[0].items = ptr[ptr[i32]](malloc(u64(8 * length)));
    if not wlist.view(1)[0].items {
        initconfig_status(config).view(1)[0] = no_memory(
            ptr[u8]("initconfig_set_str_list")
        );
        return -1;
    }

    for i in range(length) {
        arg = utf8_to_wstr(config, (items + i).view(1)[0]);
        if not arg {
            initconfig_free_wstr_list(wlist);
            return -1;
        }
        (wlist.view(1)[0].items + i).view(1)[0] = arg;
        wlist.view(1)[0].length = wlist.view(1)[0].length + 1;
    }

    initconfig_free_wstr_list(list);
    list.view(1)[0].length = wlist.view(1)[0].length;
    list.view(1)[0].items = wlist.view(1)[0].items;
    return 0;
}

impl config_add_xoption(dict_: ptr[PyObject], text: ptr[i32]) -> i32 {
    name = NULL;
    value = NULL;
    name_end = wide_find_equal(text);
    if not name_end {
        name = PyUnicode_FromWideChar(text, -1);
        if not name {
            return -1;
        }
        value = object_new_ref(py_true());
    } else {
        name = PyUnicode_FromWideChar(text, (int(name_end) - int(text)) // 4);
        if not name {
            return -1;
        }
        value = PyUnicode_FromWideChar(name_end + 1, -1);
        if not value {
            object_decref(name);
            return -1;
        }
    }
    if PyDict_SetItem(dict_, name, value) < 0 {
        object_decref(name);
        object_decref(value);
        return -1;
    }
    object_decref(name);
    object_decref(value);
    return 0;
}

impl config_get_sys_write_bytecode -> tuple[i32, i32] {
    attr = _PySys_GetRequiredAttrString(ptr[u8]("dont_write_bytecode"));
    if not attr {
        return (i32(-1), i32(0));
    }
    is_true = PyObject_IsTrue(attr);
    object_decref(attr);
    if is_true < 0 {
        return (i32(-1), i32(0));
    }
    return (i32(0), i32(1 if is_true == 0 else 0));
}

impl config_get(config: ptr[u8], spec: ConfigSpec, use_sys: i32) -> ptr[PyObject] {
    if use_sys != 0 {
        if spec.sys_attr {
            return _PySys_GetRequiredAttrString(spec.sys_attr);
        }

        if strcmp(spec.name, ptr[u8]("write_bytecode")) == 0 {
            (res, value) = config_get_sys_write_bytecode();
            if res < 0 {
                return NULL;
            }
            return PyBool_FromLong(i64(value));
        }

        if strcmp(spec.name, ptr[u8]("int_max_str_digits")) == 0 {
            interp = current_interp();
            return PyLong_FromLong(
                i64(
                    ptr[i32](interp + PyInterpreterState_LONG_MAX_STR_DIGITS).view(1)[0]
                )
            );
        }
    }

    member = config + spec.offset;
    kind = spec.type;
    if kind == MEMBER_INT or kind == MEMBER_UINT {
        return PyLong_FromLong(i64(ptr[i32](member).view(1)[0]));
    }
    if kind == MEMBER_BOOL {
        return PyBool_FromLong(i64(1 if ptr[i32](member).view(1)[0] != 0 else 0));
    }
    if kind == MEMBER_ULONG {
        return PyLong_FromUnsignedLong(ptr[u64](member).view(1)[0]);
    }
    if kind == MEMBER_WSTR or kind == MEMBER_WSTR_OPT {
        wstr = ptr[ptr[i32]](member).view(1)[0];
        if wstr {
            return PyUnicode_FromWideChar(wstr, -1);
        }
        return object_new_ref(Py_None);
    }
    if strcmp(spec.name, ptr[u8]("xoptions")) == 0 {
        return _PyConfig_CreateXOptionsDict(config);
    }
    return wide_list_as_tuple(ptr[PyWideStringList](member));
}

impl preconfig_get(preconfig: ptr[PyPreConfig], spec: ConfigSpec) -> ptr[PyObject] {
    value = ptr[i32](ptr[u8](preconfig) + spec.offset).view(1)[0];
    if spec.type == MEMBER_BOOL {
        return PyBool_FromLong(i64(1 if value != 0 else 0));
    }
    return PyLong_FromLong(i64(value));
}

impl config_unknown_name_error(name: ptr[u8]) {
    PyErr_Format(PyExc_ValueError, ptr[u8]("unknown config option name: %s"), name);
}

impl config_names_add(names: ptr[PyObject], table: list[ConfigSpec]) -> i32 {
    for spec in table {
        if spec.visibility == MEMBER_INIT_ONLY {
            continue;
        }
        name = PyUnicode_FromString(spec.name);
        if not name {
            return -1;
        }
        res = PyList_Append(names, name);
        object_decref(name);
        if res < 0 {
            return -1;
        }
    }
    return 0;
}

impl interp_config -> ptr[u8] {
    return current_interp() + PyInterpreterState_CONFIG;
}

impl config_set_sys_flag(spec: ConfigSpec, value: i32) -> i32 {
    config = interp_config();
    int_value = value;
    if spec.type == MEMBER_BOOL and int_value != 0 {
        int_value = 1;
    }

    flag = NULL;
    if spec.flag_setter == SETTER_NOT {
        flag = config_sys_flag_not(int_value);
    } else {
        flag = config_sys_flag_long(int_value);
    }
    if not flag {
        return -1;
    }

    if _PySys_SetFlagObj(spec.flag_index, flag) < 0 {
        object_decref(flag);
        return -1;
    }

    ptr[i32](config + spec.offset).view(1)[0] = int_value;

    if strcmp(spec.name, ptr[u8]("write_bytecode")) == 0 {
        if PySys_SetObject(ptr[u8]("dont_write_bytecode"), flag) < 0 {
            object_decref(flag);
            return -1;
        }
    }

    object_decref(flag);
    return 0;
}

impl config_set_int_attr(spec: ConfigSpec, value: i32) -> i32 {
    ptr[i32](interp_config() + spec.offset).view(1)[0] = value;
    return 0;
}
