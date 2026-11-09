import from c {
    def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def strtol(
        s: ptr[u8], end: ptr, base: i32
    ) -> i64;  def getenv(name: ptr[u8]) -> ptr[u8];  def setlocale(
        category: i32, locale: ptr[u8]
    ) -> ptr[u8];  def memset(target: ptr, value: i32, size: u64) -> ptr;  def jacpy_errno -> i64;  def jacpy_set_errno(
        value: i64
    );  def jacpy_stack_address(slots: &mut PreconfigStack) -> int;  def Py_DecodeLocale(
        arg: ptr[u8], wlen: ptr[u64]
    ) -> ptr[i32];  def _PyMem_RawStrdup(str_: ptr[u8]) -> ptr[u8];  def _PyMem_GetAllocatorName(
        name: ptr[u8], allocator: ptr[i32]
    ) -> i32;  def _PyMem_SetupAllocators(allocator: i32) -> i32;  def _PyRuntime_Initialize -> PyStatus;  def _Py_LegacyLocaleDetected(
        warn: i32
    ) -> i32;  def _Py_CoerceLegacyLocale(warn: i32) -> i32;  def _Py_SetLocaleFromEnv(
        category: i32
    ) -> ptr[u8];  def _PyOS_ResetGetOpt;  def _PyOS_GetOpt(
        argc: i64, argv: ptr[ptr[i32]], longindex: ptr[i32]
    ) -> i32;  def PyWideStringList_Append(
        list: ptr[PyWideStringList], item: ptr[i32]
    ) -> PyStatus;  def _PyWideStringList_Clear(list: ptr[PyWideStringList]);  def _PyWideStringList_Copy(
        list: ptr[PyWideStringList], list2: ptr[PyWideStringList]
    ) -> i32;  def _PyWideStringList_Extend(
        list: ptr[PyWideStringList], list2: ptr[PyWideStringList]
    ) -> PyStatus;  glob _PyOS_opterr: i32; glob _PyOS_optarg: ptr[i32]; glob Py_IsolatedFlag:
             i32; glob Py_IgnoreEnvironmentFlag: i32; glob Py_UTF8Mode: i32; obj PreconfigStack {
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
            w23: u64 = 0;
    }  glob Py_FileSystemDefaultEncoding: ptr[u8] = ptr[u8](); glob Py_HasFileSystemDefaultEncoding:
             i32 = 0; glob Py_FileSystemDefaultEncodeErrors: ptr[u8] = ptr[u8](); glob _Py_HasFileSystemDefaultEncodeErrors:
             i32 = 0; def _Py_ClearFileSystemEncoding {
        if addressof(Py_HasFileSystemDefaultEncoding).view(1)[0] == 0
            and addressof(Py_FileSystemDefaultEncoding).view(1)[0] {
            PyMem_RawFree(ptr(addressof(Py_FileSystemDefaultEncoding).view(1)[0]));
            addressof(Py_FileSystemDefaultEncoding).view(1)[0] = ptr[u8]();
        }
        if addressof(_Py_HasFileSystemDefaultEncodeErrors).view(1)[0] == 0
            and addressof(Py_FileSystemDefaultEncodeErrors).view(1)[0] {
            PyMem_RawFree(ptr(addressof(Py_FileSystemDefaultEncodeErrors).view(1)[0]));
            addressof(Py_FileSystemDefaultEncodeErrors).view(1)[0] = ptr[u8]();
        }
        return;
    }  def _Py_SetFileSystemEncoding(encoding: ptr[u8], errors: ptr[u8]) -> i32 {
        encoding2 = _PyMem_RawStrdup(encoding);
        if not encoding2 {
            return -1;
        }
        errors2 = _PyMem_RawStrdup(errors);
        if not errors2 {
            PyMem_RawFree(ptr(encoding2));
            return -1;
        }
        _Py_ClearFileSystemEncoding();
        addressof(Py_FileSystemDefaultEncoding).view(1)[0] = encoding2;
        addressof(Py_HasFileSystemDefaultEncoding).view(1)[0] = 0;
        addressof(Py_FileSystemDefaultEncodeErrors).view(1)[0] = errors2;
        addressof(_Py_HasFileSystemDefaultEncodeErrors).view(1)[0] = 0;
        return 0;
    }  def _PyArgv_AsWstrList(
        args: ptr[_PyArgv], list: ptr[PyWideStringList]
    ) -> PyStatus {
        slots: own PreconfigStack = PreconfigStack();
        base = ptr[u8](jacpy_stack_address(&mut slots));
        wargv = ptr[PyWideStringList](base);
        len_slot = ptr[u64](base + 16);
        argc = args.view(1)[0].argc;
        if args.view(1)[0].use_bytes_argv != 0 {
            items = ptr[ptr[i32]](PyMem_RawMalloc(u64(8 * argc)));
            if not items {
                return no_memory(ptr[u8]("_PyArgv_AsWstrList"));
            }
            wargv.view(1)[0].items = items;
            for i in range(argc) {
                arg = Py_DecodeLocale(
                    (args.view(1)[0].bytes_argv + i).view(1)[0], len_slot
                );
                if not arg {
                    _PyWideStringList_Clear(wargv);
                    if len_slot.view(1)[0] == DECODE_LOCALE_ERROR {
                        return status_err(
                            ptr[u8]("_PyArgv_AsWstrList"),
                            ptr[u8]("cannot decode command line arguments")
                        );
                    }
                    return no_memory(ptr[u8]("_PyArgv_AsWstrList"));
                }
                (items + i).view(1)[0] = arg;
                wargv.view(1)[0].length = wargv.view(1)[0].length + 1;
            }
            _PyWideStringList_Clear(list);
            list.view(1)[0].length = wargv.view(1)[0].length;
            list.view(1)[0].items = wargv.view(1)[0].items;
        } else {
            wargv.view(1)[0].length = argc;
            wargv.view(1)[0].items = args.view(1)[0].wchar_argv;
            if _PyWideStringList_Copy(list, wargv) < 0 {
                return no_memory(ptr[u8]("_PyArgv_AsWstrList"));
            }
        }
        return status_ok();
    }  def _PyPreCmdline_Clear(cmdline: ptr[_PyPreCmdline]) {
        _PyWideStringList_Clear(cmdline_argv(cmdline));
        _PyWideStringList_Clear(cmdline_xoptions(cmdline));
        return;
    }  def _PyPreCmdline_SetArgv(
        cmdline: ptr[_PyPreCmdline], args: ptr[_PyArgv]
    ) -> PyStatus {
        return _PyArgv_AsWstrList(args, cmdline_argv(cmdline));
    }  def _PyPreCmdline_SetConfig(
        cmdline: ptr[_PyPreCmdline], config: ptr[u8]
    ) -> PyStatus {
        status = _PyWideStringList_Extend(
            config_list(config, PyConfig_XOPTIONS), cmdline_xoptions(cmdline)
        );
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        set_config_int(config, PyConfig_ISOLATED, cmdline.view(1)[0].isolated);
        set_config_int(
            config, PyConfig_USE_ENVIRONMENT, cmdline.view(1)[0].use_environment
        );
        set_config_int(config, PyConfig_DEV_MODE, cmdline.view(1)[0].dev_mode);
        set_config_int(
            config,
            PyConfig_WARN_DEFAULT_ENCODING,
            cmdline.view(1)[0].warn_default_encoding
        );
        return status_ok();
    }  def _PyPreCmdline_Read(
        cmdline: ptr[_PyPreCmdline], preconfig: ptr[PyPreConfig]
    ) -> PyStatus {
        precmdline_get_preconfig(cmdline, preconfig);

        if preconfig.view(1)[0].parse_argv != 0 {
            status = precmdline_parse_cmdline(cmdline);
            if status._type != _PyStatus_TYPE_OK {
                return status;
            }
        }

        if cmdline.view(1)[0].isolated < 0 {
            cmdline.view(1)[0].isolated = 0;
        }
        if cmdline.view(1)[0].isolated > 0 {
            cmdline.view(1)[0].use_environment = 0;
        }
        if cmdline.view(1)[0].use_environment < 0 {
            cmdline.view(1)[0].use_environment = 0;
        }

        use_env = cmdline.view(1)[0].use_environment;
        if cmdline.view(1)[0].dev_mode < 0
            and (
                get_xoption_ascii(cmdline_xoptions(cmdline), ptr[u8]("dev"))
                or _Py_GetEnv(use_env, ptr[u8]("PYTHONDEVMODE"))
            ) {
            cmdline.view(1)[0].dev_mode = 1;
        }
        if cmdline.view(1)[0].dev_mode < 0 {
            cmdline.view(1)[0].dev_mode = 0;
        }

        if get_xoption_ascii(
            cmdline_xoptions(cmdline), ptr[u8]("warn_default_encoding")
        )
            or _Py_GetEnv(use_env, ptr[u8]("PYTHONWARNDEFAULTENCODING")) {
            cmdline.view(1)[0].warn_default_encoding = 1;
        }
        return status_ok();
    }  def _PyPreConfig_InitCompatConfig(config: ptr[PyPreConfig]) {
        memset(ptr(config), 0, u64(PyPreConfig_SIZE));
        c = config.view(1);
        c[0]._config_init = _PyConfig_INIT_COMPAT;
        c[0].parse_argv = 0;
        c[0].isolated = -1;
        c[0].use_environment = -1;
        c[0].configure_locale = 1;
        c[0].utf8_mode = 0;
        c[0].coerce_c_locale = 0;
        c[0].coerce_c_locale_warn = 0;
        c[0].dev_mode = -1;
        c[0].allocator = PYMEM_ALLOCATOR_NOT_SET;
        return;
    }  def PyPreConfig_InitPythonConfig(config: ptr[PyPreConfig]) {
        _PyPreConfig_InitCompatConfig(config);
        c = config.view(1);
        c[0]._config_init = _PyConfig_INIT_PYTHON;
        c[0].isolated = 0;
        c[0].parse_argv = 1;
        c[0].use_environment = 1;
        c[0].coerce_c_locale = -1;
        c[0].coerce_c_locale_warn = -1;
        c[0].utf8_mode = -1;
        return;
    }  def PyPreConfig_InitIsolatedConfig(config: ptr[PyPreConfig]) {
        _PyPreConfig_InitCompatConfig(config);
        c = config.view(1);
        c[0]._config_init = _PyConfig_INIT_ISOLATED;
        c[0].configure_locale = 0;
        c[0].isolated = 1;
        c[0].use_environment = 0;
        c[0].utf8_mode = 0;
        c[0].dev_mode = 0;
        return;
    }  def _PyPreConfig_InitFromPreConfig(
        config: ptr[PyPreConfig], config2: ptr[PyPreConfig]
    ) -> PyStatus {
        PyPreConfig_InitPythonConfig(config);
        preconfig_copy(config, config2);
        return status_ok();
    }  def _PyPreConfig_InitFromConfig(preconfig: ptr[PyPreConfig], config: ptr[u8]) {
        config_init = config_int(config, PyConfig_CONFIG_INIT);
        if config_init == _PyConfig_INIT_PYTHON {
            PyPreConfig_InitPythonConfig(preconfig);
        } elif config_init == _PyConfig_INIT_ISOLATED {
            PyPreConfig_InitIsolatedConfig(preconfig);
        } else {
            _PyPreConfig_InitCompatConfig(preconfig);
        }
        _PyPreConfig_GetConfig(preconfig, config);
        return;
    }  def _PyPreConfig_AsDict(config: ptr[PyPreConfig]) -> ptr[PyObject] {
        dict_ = PyDict_New();
        if not dict_ {
            return NULL;
        }
        c = config.view(1);
        if preconfig_set_item(dict_, ptr[u8]("_config_init"), c[0]._config_init) < 0
            or preconfig_set_item(dict_, ptr[u8]("parse_argv"), c[0].parse_argv) < 0
            or preconfig_set_item(dict_, ptr[u8]("isolated"), c[0].isolated) < 0
            or preconfig_set_item(
                dict_, ptr[u8]("use_environment"), c[0].use_environment
            )
                < 0
            or preconfig_set_item(
                dict_, ptr[u8]("configure_locale"), c[0].configure_locale
            )
                < 0
            or preconfig_set_item(
                dict_, ptr[u8]("coerce_c_locale"), c[0].coerce_c_locale
            )
                < 0
            or preconfig_set_item(
                dict_, ptr[u8]("coerce_c_locale_warn"), c[0].coerce_c_locale_warn
            )
                < 0
            or preconfig_set_item(dict_, ptr[u8]("utf8_mode"), c[0].utf8_mode) < 0
            or preconfig_set_item(dict_, ptr[u8]("dev_mode"), c[0].dev_mode) < 0
            or preconfig_set_item(dict_, ptr[u8]("allocator"), c[0].allocator) < 0 {
            object_decref(dict_);
            return NULL;
        }
        return dict_;
    }  def _PyPreConfig_GetConfig(preconfig: ptr[PyPreConfig], config: ptr[u8]) {
        p = preconfig.view(1);
        value = config_int(config, PyConfig_PARSE_ARGV);
        if value != -1 {
            p[0].parse_argv = value;
        }
        value = config_int(config, PyConfig_ISOLATED);
        if value != -1 {
            p[0].isolated = value;
        }
        value = config_int(config, PyConfig_USE_ENVIRONMENT);
        if value != -1 {
            p[0].use_environment = value;
        }
        value = config_int(config, PyConfig_DEV_MODE);
        if value != -1 {
            p[0].dev_mode = value;
        }
        return;
    }  def _Py_GetEnv(use_environment: i32, name: ptr[u8]) -> ptr[u8] {
        if use_environment == 0 {
            return ptr[u8]();
        }
        var = getenv(name);
        if var and var.view(1)[0] != u8(0) {
            return var;
        }
        return ptr[u8]();
    }  def _Py_str_to_int(str_: ptr[u8], result: ptr[i32]) -> i32 {
        (res, value) = str_to_int(str_);
        if res < 0 {
            return -1;
        }
        result.view(1)[0] = value;
        return 0;
    }  def _Py_get_env_flag(use_environment: i32, flag: ptr[i32], name: ptr[u8]) {
        flag.view(1)[0] = env_flag(use_environment, flag.view(1)[0], name);
        return;
    }  def _Py_get_xoption(
        xoptions: ptr[PyWideStringList], name: ptr[i32]
    ) -> ptr[i32] {
        count = xoptions.view(1)[0].length;
        for i in range(count) {
            option = (xoptions.view(1)[0].items + i).view(1)[0];
            length = xoption_name_length(option);
            same = True;
            k: i64 = 0;
            while k < length {
                if (option + k).view(1)[0] != (name + k).view(1)[0] {
                    same = False;
                    break;
                }
                if (option + k).view(1)[0] == 0 {
                    break;
                }
                k += 1;
            }
            if same and (name + length).view(1)[0] == 0 {
                return option;
            }
        }
        return ptr[i32]();
    }  def _PyPreConfig_Read(config: ptr[PyPreConfig], args: ptr[_PyArgv]) -> PyStatus {
        status = _PyRuntime_Initialize();
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }

        preconfig_get_global_vars(config);

        loc = setlocale(LC_CTYPE, ptr[u8]());
        if not loc {
            return status_err(
                ptr[u8]("_PyPreConfig_Read"), ptr[u8]("failed to LC_CTYPE locale")
            );
        }
        init_ctype_locale = _PyMem_RawStrdup(loc);
        if not init_ctype_locale {
            return no_memory(ptr[u8]("_PyPreConfig_Read"));
        }

        slots: own PreconfigStack = PreconfigStack();
        base = ptr[u8](jacpy_stack_address(&mut slots));
        save_config = ptr[PyPreConfig](base);
        save_runtime_config = ptr[PyPreConfig](base + 48);
        cmdline = ptr[_PyPreCmdline](base + 96);
        cmdline.view(1)[0].isolated = -1;
        cmdline.view(1)[0].use_environment = -1;
        cmdline.view(1)[0].dev_mode = -1;

        status = _PyPreConfig_InitFromPreConfig(save_config, config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }

        if config.view(1)[0].configure_locale != 0 {
            _Py_SetLocaleFromEnv(LC_CTYPE);
        }

        runtime_preconfig = ptr[PyPreConfig](runtime_at(_PyRuntimeState_PRECONFIG));
        preconfig_copy(save_runtime_config, runtime_preconfig);

        locale_coerced = 0;
        loops = 0;
        status = status_ok();
        while True {
            utf8_mode = config.view(1)[0].utf8_mode;

            loops += 1;
            if loops == 3 {
                status = status_err(
                    ptr[u8]("_PyPreConfig_Read"),
                    ptr[u8]("Encoding changed twice while reading the configuration")
                );
                break;
            }

            preconfig_copy(runtime_preconfig, config);

            if args {
                status = _PyPreCmdline_SetArgv(cmdline, args);
                if status._type != _PyStatus_TYPE_OK {
                    break;
                }
            }

            status = preconfig_read(config, cmdline);
            if status._type != _PyStatus_TYPE_OK {
                break;
            }

            encoding_changed = 0;
            if config.view(1)[0].coerce_c_locale != 0 and locale_coerced == 0 {
                locale_coerced = 1;
                _Py_CoerceLegacyLocale(0);
                encoding_changed = 1;
            }

            if utf8_mode == -1 {
                if config.view(1)[0].utf8_mode == 1 {
                    encoding_changed = 1;
                }
            } elif config.view(1)[0].utf8_mode != utf8_mode {
                encoding_changed = 1;
            }

            if encoding_changed == 0 {
                status = status_ok();
                break;
            }

            new_utf8_mode = config.view(1)[0].utf8_mode;
            new_coerce_c_locale = config.view(1)[0].coerce_c_locale;
            preconfig_copy(config, save_config);
            config.view(1)[0].utf8_mode = new_utf8_mode;
            config.view(1)[0].coerce_c_locale = new_coerce_c_locale;
        }

        setlocale(LC_CTYPE, init_ctype_locale);
        PyMem_RawFree(ptr(init_ctype_locale));
        preconfig_copy(runtime_preconfig, save_runtime_config);
        _PyPreCmdline_Clear(cmdline);
        return status;
    }  def _PyPreConfig_Write(src_config: ptr[PyPreConfig]) -> PyStatus {
        slots: own PreconfigStack = PreconfigStack();
        config = ptr[PyPreConfig](jacpy_stack_address(&mut slots));

        status = _PyPreConfig_InitFromPreConfig(config, src_config);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }

        if ptr[i32](runtime_at(_PyRuntimeState_CORE_INITIALIZED)).view(1)[0] != 0 {
            return status_ok();
        }

        name = config.view(1)[0].allocator;
        if name != PYMEM_ALLOCATOR_NOT_SET {
            if _PyMem_SetupAllocators(name) < 0 {
                return status_err(
                    ptr[u8]("_PyPreConfig_Write"),
                    ptr[u8]("Unknown PYTHONMALLOC allocator")
                );
            }
        }

        preconfig_set_global_vars(config);

        if config.view(1)[0].configure_locale != 0 {
            if config.view(1)[0].coerce_c_locale != 0 {
                if _Py_CoerceLegacyLocale(config.view(1)[0].coerce_c_locale_warn)
                    == 0 {
                    config.view(1)[0].coerce_c_locale = 0;
                }
            }
            _Py_SetLocaleFromEnv(LC_CTYPE);
        }

        preconfig_copy(ptr[PyPreConfig](runtime_at(_PyRuntimeState_PRECONFIG)), config);
        return status_ok();
    }
}

glob:priv DECODE_LOCALE_ERROR: Final[u64] = 18446744073709551614,
     ERANGE_VALUE: Final[i64] = 34,
     INT_MIN_VALUE: Final[i64] = -2147483648,
     INT_MAX_VALUE: Final[i64] = 2147483647;

def config_int(config: ptr[u8], offset: i64) -> i32;

def set_config_int(config: ptr[u8], offset: i64, value: i32);

def config_list(config: ptr[u8], offset: i64) -> ptr[PyWideStringList];

def no_memory(func: ptr[u8]) -> PyStatus;

def env_flag(use_environment: i32, flag: i32, name: ptr[u8]) -> i32;

def cmdline_argv(cmdline: ptr[_PyPreCmdline]) -> ptr[PyWideStringList];

def cmdline_xoptions(cmdline: ptr[_PyPreCmdline]) -> ptr[PyWideStringList];

def precmdline_get_preconfig(cmdline: ptr[_PyPreCmdline], config: ptr[PyPreConfig]);

def precmdline_set_preconfig(cmdline: ptr[_PyPreCmdline], config: ptr[PyPreConfig]);

def precmdline_parse_cmdline(cmdline: ptr[_PyPreCmdline]) -> PyStatus;

def preconfig_copy(config: ptr[PyPreConfig], config2: ptr[PyPreConfig]);

def preconfig_set_item(dict_: ptr[PyObject], name: ptr[u8], value: i32) -> i32;

def preconfig_get_global_vars(config: ptr[PyPreConfig]);

def preconfig_set_global_vars(config: ptr[PyPreConfig]);

def str_to_int(text: ptr[u8]) -> tuple[i32, i32];

def xoption_name_length(option: ptr[i32]) -> i64;

def get_xoption_ascii(xoptions: ptr[PyWideStringList], name: ptr[u8]) -> ptr[i32];

def preconfig_init_utf8_mode(
    config: ptr[PyPreConfig], cmdline: ptr[_PyPreCmdline]
) -> PyStatus;

def preconfig_init_coerce_c_locale(config: ptr[PyPreConfig]);

def preconfig_init_allocator(config: ptr[PyPreConfig]) -> PyStatus;

def preconfig_read(config: ptr[PyPreConfig], cmdline: ptr[_PyPreCmdline]) -> PyStatus;

impl config_int(config: ptr[u8], offset: i64) -> i32 {
    return ptr[i32](config + offset).view(1)[0];
}

impl set_config_int(config: ptr[u8], offset: i64, value: i32) {
    ptr[i32](config + offset).view(1)[0] = value;
}

impl config_list(config: ptr[u8], offset: i64) -> ptr[PyWideStringList] {
    return ptr[PyWideStringList](config + offset);
}

impl no_memory(func: ptr[u8]) -> PyStatus {
    return status_err(func, ptr[u8]("memory allocation failed"));
}

impl env_flag(use_environment: i32, flag: i32, name: ptr[u8]) -> i32 {
    var = _Py_GetEnv(use_environment, name);
    if not var {
        return flag;
    }
    (res, value) = str_to_int(var);
    if res < 0 or value < 0 {
        value = 1;
    }
    if flag < value {
        return value;
    }
    return flag;
}

impl cmdline_argv(cmdline: ptr[_PyPreCmdline]) -> ptr[PyWideStringList] {
    return ptr[PyWideStringList](cmdline);
}

impl cmdline_xoptions(cmdline: ptr[_PyPreCmdline]) -> ptr[PyWideStringList] {
    return ptr[PyWideStringList](cmdline) + 1;
}

impl precmdline_get_preconfig(cmdline: ptr[_PyPreCmdline], config: ptr[PyPreConfig]) {
    if config.view(1)[0].isolated != -1 {
        cmdline.view(1)[0].isolated = config.view(1)[0].isolated;
    }
    if config.view(1)[0].use_environment != -1 {
        cmdline.view(1)[0].use_environment = config.view(1)[0].use_environment;
    }
    if config.view(1)[0].dev_mode != -1 {
        cmdline.view(1)[0].dev_mode = config.view(1)[0].dev_mode;
    }
}

impl precmdline_set_preconfig(cmdline: ptr[_PyPreCmdline], config: ptr[PyPreConfig]) {
    config.view(1)[0].isolated = cmdline.view(1)[0].isolated;
    config.view(1)[0].use_environment = cmdline.view(1)[0].use_environment;
    config.view(1)[0].dev_mode = cmdline.view(1)[0].dev_mode;
}

impl precmdline_parse_cmdline(cmdline: ptr[_PyPreCmdline]) -> PyStatus {
    argv = cmdline_argv(cmdline);
    slots: own PreconfigStack = PreconfigStack();
    longindex = ptr[i32](jacpy_stack_address(&mut slots));

    _PyOS_ResetGetOpt();
    addressof(_PyOS_opterr).view(1)[0] = 0;
    while True {
        longindex.view(1)[0] = -1;
        c = _PyOS_GetOpt(argv.view(1)[0].length, argv.view(1)[0].items, longindex);
        if c == -1 or c == 99 or c == 109 {
            break;
        }
        if c == 69 {
            cmdline.view(1)[0].use_environment = 0;
        } elif c == 73 {
            cmdline.view(1)[0].isolated = 1;
        } elif c == 88 {
            status = PyWideStringList_Append(
                cmdline_xoptions(cmdline), addressof(_PyOS_optarg).view(1)[0]
            );
            if status._type != _PyStatus_TYPE_OK {
                return status;
            }
        }
    }
    return status_ok();
}

impl preconfig_copy(config: ptr[PyPreConfig], config2: ptr[PyPreConfig]) {
    c = config.view(1);
    c2 = config2.view(1);
    c[0]._config_init = c2[0]._config_init;
    c[0].parse_argv = c2[0].parse_argv;
    c[0].isolated = c2[0].isolated;
    c[0].use_environment = c2[0].use_environment;
    c[0].configure_locale = c2[0].configure_locale;
    c[0].dev_mode = c2[0].dev_mode;
    c[0].coerce_c_locale = c2[0].coerce_c_locale;
    c[0].coerce_c_locale_warn = c2[0].coerce_c_locale_warn;
    c[0].utf8_mode = c2[0].utf8_mode;
    c[0].allocator = c2[0].allocator;
}

impl preconfig_set_item(dict_: ptr[PyObject], name: ptr[u8], value: i32) -> i32 {
    obj_ = PyLong_FromLong(i64(value));
    if not obj_ {
        return -1;
    }
    res = PyDict_SetItemString(dict_, name, obj_);
    object_decref(obj_);
    return res;
}

impl preconfig_get_global_vars(config: ptr[PyPreConfig]) {
    if config.view(1)[0]._config_init != _PyConfig_INIT_COMPAT {
        return;
    }
    if config.view(1)[0].isolated < 0 {
        config.view(1)[0].isolated = addressof(Py_IsolatedFlag).view(1)[0];
    }
    if config.view(1)[0].use_environment < 0 {
        config.view(1)[0].use_environment = i32(
            1 if addressof(Py_IgnoreEnvironmentFlag).view(1)[0] == 0 else 0
        );
    }
    utf8 = addressof(Py_UTF8Mode).view(1)[0];
    if utf8 > 0 {
        config.view(1)[0].utf8_mode = utf8;
    }
}

impl preconfig_set_global_vars(config: ptr[PyPreConfig]) {
    if config.view(1)[0].isolated >= 0 {
        addressof(Py_IsolatedFlag).view(1)[0] = config.view(1)[0].isolated;
    }
    if config.view(1)[0].use_environment >= 0 {
        addressof(Py_IgnoreEnvironmentFlag).view(1)[0] = i32(
            1 if config.view(1)[0].use_environment == 0 else 0
        );
    }
    if config.view(1)[0].utf8_mode >= 0 {
        addressof(Py_UTF8Mode).view(1)[0] = config.view(1)[0].utf8_mode;
    }
}

impl str_to_int(text: ptr[u8]) -> tuple[i32, i32] {
    slots: own PreconfigStack = PreconfigStack();
    endptr = ptr[ptr[u8]](jacpy_stack_address(&mut slots));
    endptr.view(1)[0] = text;
    jacpy_set_errno(0);
    value = strtol(text, ptr(endptr), 10);
    if endptr.view(1)[0].view(1)[0] != u8(0) or jacpy_errno() == ERANGE_VALUE {
        return (i32(-1), i32(0));
    }
    if value < INT_MIN_VALUE or value > INT_MAX_VALUE {
        return (i32(-1), i32(0));
    }
    return (i32(0), i32(value));
}

impl xoption_name_length(option: ptr[i32]) -> i64 {
    k: i64 = 0;
    while (option + k).view(1)[0] != 0 {
        if (option + k).view(1)[0] == 61 {
            return k;
        }
        k += 1;
    }
    return k;
}

impl get_xoption_ascii(xoptions: ptr[PyWideStringList], name: ptr[u8]) -> ptr[i32] {
    count = xoptions.view(1)[0].length;
    for i in range(count) {
        option = (xoptions.view(1)[0].items + i).view(1)[0];
        length = xoption_name_length(option);
        same = True;
        k: i64 = 0;
        while k < length {
            if (option + k).view(1)[0] != i32((name + k).view(1)[0]) {
                same = False;
                break;
            }
            k += 1;
        }
        if same and (name + length).view(1)[0] == u8(0) {
            return option;
        }
    }
    return ptr[i32]();
}

impl preconfig_init_utf8_mode(
    config: ptr[PyPreConfig], cmdline: ptr[_PyPreCmdline]
) -> PyStatus {
    if config.view(1)[0].utf8_mode >= 0 {
        return status_ok();
    }

    xopt = get_xoption_ascii(cmdline_xoptions(cmdline), ptr[u8]("utf8"));
    if xopt {
        sep = xopt + xoption_name_length(xopt);
        if sep.view(1)[0] == 61 {
            value = sep + 1;
            if value.view(1)[0] == 49 and value.view(2)[1] == 0 {
                config.view(1)[0].utf8_mode = 1;
            } elif value.view(1)[0] == 48 and value.view(2)[1] == 0 {
                config.view(1)[0].utf8_mode = 0;
            } else {
                return status_err(
                    ptr[u8]("preconfig_init_utf8_mode"),
                    ptr[u8]("invalid -X utf8 option value")
                );
            }
        } else {
            config.view(1)[0].utf8_mode = 1;
        }
        return status_ok();
    }

    opt = _Py_GetEnv(config.view(1)[0].use_environment, ptr[u8]("PYTHONUTF8"));
    if opt {
        if strcmp(opt, ptr[u8]("1")) == 0 {
            config.view(1)[0].utf8_mode = 1;
        } elif strcmp(opt, ptr[u8]("0")) == 0 {
            config.view(1)[0].utf8_mode = 0;
        } else {
            return status_err(
                ptr[u8]("preconfig_init_utf8_mode"),
                ptr[u8]("invalid PYTHONUTF8 environment variable value")
            );
        }
        return status_ok();
    }

    if config.view(1)[0].utf8_mode < 0 {
        ctype_loc = setlocale(LC_CTYPE, ptr[u8]());
        if ctype_loc
            and (
                strcmp(ctype_loc, ptr[u8]("C")) == 0
                or strcmp(ctype_loc, ptr[u8]("POSIX")) == 0
            ) {
            config.view(1)[0].utf8_mode = 1;
        }
    }

    if config.view(1)[0].utf8_mode < 0 {
        config.view(1)[0].utf8_mode = 0;
    }
    return status_ok();
}

impl preconfig_init_coerce_c_locale(config: ptr[PyPreConfig]) {
    c = config.view(1);
    if c[0].configure_locale == 0 {
        c[0].coerce_c_locale = 0;
        c[0].coerce_c_locale_warn = 0;
        return;
    }

    env = _Py_GetEnv(c[0].use_environment, ptr[u8]("PYTHONCOERCECLOCALE"));
    if env {
        if strcmp(env, ptr[u8]("0")) == 0 {
            if c[0].coerce_c_locale < 0 {
                c[0].coerce_c_locale = 0;
            }
        } elif strcmp(env, ptr[u8]("warn")) == 0 {
            if c[0].coerce_c_locale_warn < 0 {
                c[0].coerce_c_locale_warn = 1;
            }
        } elif c[0].coerce_c_locale < 0 {
            c[0].coerce_c_locale = 1;
        }
    }

    if c[0].coerce_c_locale < 0 or c[0].coerce_c_locale == 1 {
        if _Py_LegacyLocaleDetected(0) != 0 {
            c[0].coerce_c_locale = 2;
        } else {
            c[0].coerce_c_locale = 0;
        }
    }

    if c[0].coerce_c_locale_warn < 0 {
        c[0].coerce_c_locale_warn = 0;
    }
}

impl preconfig_init_allocator(config: ptr[PyPreConfig]) -> PyStatus {
    if config.view(1)[0].allocator == PYMEM_ALLOCATOR_NOT_SET {
        envvar = _Py_GetEnv(config.view(1)[0].use_environment, ptr[u8]("PYTHONMALLOC"));
        if envvar {
            slots: own PreconfigStack = PreconfigStack();
            name = ptr[i32](jacpy_stack_address(&mut slots));
            if _PyMem_GetAllocatorName(envvar, name) < 0 {
                return status_err(
                    ptr[u8]("preconfig_init_allocator"),
                    ptr[u8]("PYTHONMALLOC: unknown allocator")
                );
            }
            config.view(1)[0].allocator = name.view(1)[0];
        }
    }

    if config.view(1)[0].dev_mode != 0
        and config.view(1)[0].allocator == PYMEM_ALLOCATOR_NOT_SET {
        config.view(1)[0].allocator = PYMEM_ALLOCATOR_DEBUG;
    }
    return status_ok();
}

impl preconfig_read(config: ptr[PyPreConfig], cmdline: ptr[_PyPreCmdline]) -> PyStatus {
    status = _PyPreCmdline_Read(cmdline, config);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    precmdline_set_preconfig(cmdline, config);

    preconfig_init_coerce_c_locale(config);

    status = preconfig_init_utf8_mode(config, cmdline);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }

    status = preconfig_init_allocator(config);
    if status._type != _PyStatus_TYPE_OK {
        return status;
    }
    return status_ok();
}
