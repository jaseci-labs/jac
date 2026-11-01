import from c {
    def _PyRuntime_Initialize -> PyStatus;  def _PyRuntime_Finalize;  def PyPreConfig_InitPythonConfig(
        config: ptr[u8]
    );  def _Py_PreInitializeFromPyArgv(
        src_config: ptr[u8], args: ptr[u8]
    ) -> PyStatus;  def PyConfig_InitPythonConfig(config: ptr[u8]);  def PyConfig_SetBytesArgv(
        config: ptr[u8], argc: i64, argv: ptr[ptr[u8]]
    ) -> PyStatus;  def PyConfig_SetArgv(
        config: ptr[u8], argc: i64, argv: ptr[ptr[i32]]
    ) -> PyStatus;  def PyConfig_Clear(config: ptr[u8]);  def Py_InitializeFromConfig(
        config: ptr[u8]
    ) -> PyStatus;  def Py_FinalizeEx -> i32;  def Py_ExitStatusException(
        status: PyStatus
    );  def PyStatus_NoMemory -> PyStatus;  def _PyInterpreterState_GetConfig(
        interp: ptr[u8]
    ) -> ptr[u8];  def _PyInterpreterState_SetRunningMain(interp: ptr[u8]);  def _PyInterpreterState_SetNotRunningMain(
        interp: ptr[u8]
    );  def _PyPathConfig_UpdateGlobal(config: ptr[u8]) -> PyStatus;  def _PyPathConfig_ComputeSysPath0(
        argv: ptr[u8], path0_p: &mut ptr[PyObject]
    ) -> i32;  def _PyPathConfig_ClearGlobal;  def _Py_ClearArgcArgv;  def _PyImport_Fini2;  def PyImport_AddModuleRef(
        name: ptr[u8]
    ) -> ptr[PyObject];  def PyImport_GetImporter(
        path: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_GetEnv(
        use_environment: i32, name: ptr[u8]
    ) -> ptr[u8];  def _PyUnicode_Dedent(unicode: ptr[PyObject]) -> ptr[PyObject];  def _PyMem_RawWcsdup(
        text: ptr[i32]
    ) -> ptr[i32];  def PySys_Audit(
        event: ptr[u8], argFormat: ptr[u8], *args: any
    ) -> i32;  def PySys_WriteStderr(format: ptr[u8], *args: any);  def PySys_FormatStderr(
        format: ptr[u8], *args: any
    );  def Py_GetVersion -> ptr[u8];  def Py_GetPlatform -> ptr[u8];  def PyOS_setsig(
        sig: i32, handler: ptr
    ) -> ptr;  def _PyRun_AnyFileObject(
        fp: ptr[FILE],
        filename: ptr[PyObject],
        closeit: i32,
        flags: ptr[PyCompilerFlags]
    ) -> i32;  def PyRun_AnyFileExFlags(
        fp: ptr[FILE], filename: ptr[u8], closeit: i32, flags: ptr[PyCompilerFlags]
    ) -> i32;  def _PyRun_SimpleFileObject(
        fp: ptr[FILE],
        filename: ptr[PyObject],
        closeit: i32,
        flags: ptr[PyCompilerFlags]
    ) -> i32;  def _PyRun_SimpleStringFlagsWithName(
        command: ptr[u8], name: ptr[u8], flags: ptr[PyCompilerFlags]
    ) -> i32;  def _Py_HandleSystemExitAndKeyboardInterrupt(
        exitcode_p: &mut i32
    ) -> i32;  def PyErr_Print;  def fprintf(
        stream: ptr, format: ptr[u8], *args: any
    ) -> i32;  def fgetc(stream: ptr[FILE]) -> i32;  def ungetc(
        c: i32, stream: ptr[FILE]
    ) -> i32;  def fclose(stream: ptr[FILE]) -> i32;  def fileno(stream: ptr) -> i32;  def isatty(
        fd: i32
    ) -> i32;  def strerror(errnum: i32) -> ptr[u8];  def wcslen(
        text: ptr[i32]
    ) -> u64;  def perror(text: ptr[u8]);  def kill(pid: i32, sig: i32) -> i32;  def getpid -> i32;  def calloc(
        count: u64, size: u64
    ) -> ptr;  def free(block: ptr);  def jacpy_stdio_stream(stream: i32) -> ptr;  glob Py_InspectFlag:
             i32; obj MainStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0;
    }  def jacpy_stack_address(slots: &mut MainStack) -> int;  glob:priv MAIN_MODULE_NAME:
             list[i32] = [
             i32(95),
             i32(95),
             i32(109),
             i32(97),
             i32(105),
             i32(110),
             i32(95),
             i32(95),
             i32(0)
         ];
}

glob:priv MAIN_SIGINT: i32 = 2,
     MAIN_EOF: i32 = -1,
     PYARGV_ARGC: i64 = 0,
     PYARGV_USE_BYTES_ARGV: i64 = 8,
     PYARGV_BYTES_ARGV: i64 = 16,
     PYARGV_WCHAR_ARGV: i64 = 24,
     STATUS_TYPE_EXIT: u32 = 2,
     MODE_TYPE_MASK: i64 = 0o170000,
     MODE_DIRECTORY: i64 = 0o040000;

def:priv config_int(config: ptr[u8], offset: i64) -> i32;

def:priv config_wide(config: ptr[u8], offset: i64) -> ptr[i32];

def:priv status_exception(status: PyStatus) -> bool;

def:priv status_is_exit(status: PyStatus) -> bool;

def:priv bool_object(value: bool) -> ptr[PyObject];

def:priv stdio(stream: i32) -> ptr;

def:priv init_compiler_flags(cf: ptr[u8]) -> ptr[PyCompilerFlags];

def:priv pymain_init(args: ptr[u8]) -> PyStatus;

def:priv config_run_code(config: ptr[u8]) -> bool;

def:priv stdin_is_interactive(config: ptr[u8]) -> bool;

def:priv pymain_err_print -> tuple[i32, i32];

def:priv pymain_exit_err_print -> i32;

def:priv pymain_get_importer(filename: ptr[i32]) -> tuple[i32, ptr[PyObject], i32];

def:priv pymain_sys_path_add_path0(interp: ptr[u8], path0: ptr[PyObject]) -> i32;

def:priv id_object(offset: i64) -> ptr[PyObject];

def:priv pymain_header(config: ptr[u8]);

def:priv pymain_import_readline(config: ptr[u8]);

def:priv pymain_run_command(command: ptr[i32]) -> i32;

def:priv pymain_start_pyrepl(pythonstartup: i32) -> i32;

def:priv pymain_run_module(modname: ptr[i32], set_argv0: i32) -> i32;

def:priv pymain_run_file_obj(
    program_name: ptr[PyObject], filename: ptr[PyObject], skip_source_first_line: i32
) -> i32;

def:priv pymain_run_file(config: ptr[u8]) -> i32;

def:priv pymain_run_startup(config: ptr[u8]) -> tuple[i32, i32];

def:priv pymain_run_interactive_hook -> tuple[i32, i32];

def:priv pymain_set_inspect(config: ptr[u8], inspect: i32);

def:priv pymain_run_stdin(config: ptr[u8]) -> i32;

def:priv pymain_repl(config: ptr[u8], exitcode: i32) -> i32;

def:priv pymain_run_python(exitcode_in: i32) -> i32;

def:priv pymain_free;

def:priv exit_sigint -> i32;

def:priv pymain_exit_error(status: PyStatus);

def:priv unhandled_keyboard_interrupt_slot -> ptr[i32];

def:priv pymain_main(args: ptr[u8]) -> i32;

import from c {
    def Py_RunMain -> i32 {
        exitcode: i32 = 0;

        unhandled_keyboard_interrupt_slot().view(1)[0] = 0;

        exitcode = pymain_run_python(exitcode);

        if Py_FinalizeEx() < 0 {
            exitcode = 120;
        }

        pymain_free();

        if unhandled_keyboard_interrupt_slot().view(1)[0] != 0 {
            exitcode = exit_sigint();
        }

        return exitcode;
    }  def Py_Main(argc: i32, argv: ptr[ptr[i32]]) -> i32 {
        slots: own MainStack = MainStack();
        args = ptr[u8](jacpy_stack_address(&mut slots));
        ptr[i64](args + PYARGV_ARGC).view(1)[0] = i64(argc);
        ptr[i32](args + PYARGV_USE_BYTES_ARGV).view(1)[0] = 0;
        ptr[ptr[ptr[u8]]](args + PYARGV_BYTES_ARGV).view(1)[0] = ptr[ptr[u8]]();
        ptr[ptr[ptr[i32]]](args + PYARGV_WCHAR_ARGV).view(1)[0] = argv;
        return pymain_main(args);
    }  def Py_BytesMain(argc: i32, argv: ptr[ptr[u8]]) -> i32 {
        slots: own MainStack = MainStack();
        args = ptr[u8](jacpy_stack_address(&mut slots));
        ptr[i64](args + PYARGV_ARGC).view(1)[0] = i64(argc);
        ptr[i32](args + PYARGV_USE_BYTES_ARGV).view(1)[0] = 1;
        ptr[ptr[ptr[u8]]](args + PYARGV_BYTES_ARGV).view(1)[0] = argv;
        ptr[ptr[ptr[i32]]](args + PYARGV_WCHAR_ARGV).view(1)[0] = ptr[ptr[i32]]();
        return pymain_main(args);
    }
}

impl config_int(config: ptr[u8], offset: i64) -> i32 {
    return ptr[i32](config + offset).view(1)[0];
}

impl config_wide(config: ptr[u8], offset: i64) -> ptr[i32] {
    return ptr[ptr[i32]](config + offset).view(1)[0];
}

impl status_exception(status: PyStatus) -> bool {
    return status._type != _PyStatus_TYPE_OK;
}

impl status_is_exit(status: PyStatus) -> bool {
    return status._type == STATUS_TYPE_EXIT;
}

impl bool_object(value: bool) -> ptr[PyObject] {
    if value {
        return ptr[PyObject](addressof(_Py_TrueStruct));
    }
    return ptr[PyObject](addressof(_Py_FalseStruct));
}

impl stdio(stream: i32) -> ptr {
    return jacpy_stdio_stream(stream);
}

impl init_compiler_flags(cf: ptr[u8]) -> ptr[PyCompilerFlags] {
    ptr[i32](cf + PyCompilerFlags_CF_FLAGS).view(1)[0] = 0;
    ptr[i32](cf + PyCompilerFlags_CF_FEATURE_VERSION).view(1)[0] = PY_MINOR_VERSION;
    return ptr[PyCompilerFlags](cf);
}

impl pymain_init(args: ptr[u8]) -> PyStatus {
    status = _PyRuntime_Initialize();
    if status_exception(status) {
        return status;
    }

    preconfig = ptr[u8](calloc(1, u64(PyPreConfig_SIZE)));
    if not preconfig {
        return PyStatus_NoMemory();
    }
    PyPreConfig_InitPythonConfig(preconfig);

    status = _Py_PreInitializeFromPyArgv(preconfig, args);
    free(ptr(preconfig));
    if status_exception(status) {
        return status;
    }

    config = ptr[u8](calloc(1, u64(PyConfig_SIZE)));
    if not config {
        return PyStatus_NoMemory();
    }
    PyConfig_InitPythonConfig(config);

    argc = ptr[i64](args + PYARGV_ARGC).view(1)[0];
    if ptr[i32](args + PYARGV_USE_BYTES_ARGV).view(1)[0] != 0 {
        status = PyConfig_SetBytesArgv(
            config, argc, ptr[ptr[ptr[u8]]](args + PYARGV_BYTES_ARGV).view(1)[0]
        );
    } else {
        status = PyConfig_SetArgv(
            config, argc, ptr[ptr[ptr[i32]]](args + PYARGV_WCHAR_ARGV).view(1)[0]
        );
    }
    if not status_exception(status) {
        status = Py_InitializeFromConfig(config);
        if not status_exception(status) {
            status = PyStatus(
                _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
            );
        }
    }

    PyConfig_Clear(config);
    free(ptr(config));
    return status;
}

impl config_run_code(config: ptr[u8]) -> bool {
    return int(config_wide(config, PyConfig_RUN_COMMAND)) != 0
        or int(config_wide(config, PyConfig_RUN_FILENAME)) != 0
        or int(config_wide(config, PyConfig_RUN_MODULE)) != 0;
}

impl stdin_is_interactive(config: ptr[u8]) -> bool {
    return isatty(fileno(stdio(0))) != 0
        or config_int(config, PyConfig_INTERACTIVE) != 0;
}

impl pymain_err_print -> tuple[i32, i32] {
    exitcode: i32 = 0;
    if _Py_HandleSystemExitAndKeyboardInterrupt(&mut exitcode) != 0 {
        return (i32(1), exitcode);
    }

    PyErr_Print();
    return (i32(0), i32(0));
}

impl pymain_exit_err_print -> i32 {
    exitcode: i32 = 1;
    (handled, code) = pymain_err_print();
    if handled != 0 {
        exitcode = code;
    }
    return exitcode;
}

impl pymain_get_importer(filename: ptr[i32]) -> tuple[i32, ptr[PyObject], i32] {
    sys_path0 = PyUnicode_FromWideChar(filename, i64(wcslen(filename)));
    if sys_path0 {
        importer = PyImport_GetImporter(sys_path0);
        if importer {
            if importer == Py_None {
                object_decref(sys_path0);
                object_decref(importer);
                return (i32(0), NULL, i32(0));
            }

            object_decref(importer);
            return (i32(0), sys_path0, i32(0));
        }
    }

    object_xdecref(sys_path0);

    PySys_WriteStderr(ptr[u8]("Failed checking if argv[0] is an import path entry\n"));
    (handled, exitcode) = pymain_err_print();
    return (handled, NULL, exitcode);
}

impl pymain_sys_path_add_path0(interp: ptr[u8], path0: ptr[PyObject]) -> i32 {
    sys_path = NULL;
    sysdict = ptr[ptr[PyObject]](interp + PyInterpreterState_SYSDICT).view(1)[0];
    if sysdict {
        sys_path = PyDict_GetItemWithError(sysdict, id_object(_Py_ID_path));
        if not sys_path and PyErr_Occurred() {
            return -1;
        }
    }
    if not sys_path {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("unable to get sys.path"));
        return -1;
    }

    if PyList_Insert(sys_path, 0, path0) != 0 {
        return -1;
    }
    return 0;
}

impl id_object(offset: i64) -> ptr[PyObject] {
    return ptr[PyObject](
        ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_GLOBAL_STRINGS + offset
    );
}

impl pymain_header(config: ptr[u8]) {
    if config_int(config, PyConfig_QUIET) != 0 {
        return;
    }

    if config_int(config, PyConfig_VERBOSE) == 0
        and (config_run_code(config) or not stdin_is_interactive(config)) {
        return;
    }

    fprintf(stdio(2), ptr[u8]("Python %s on %s\n"), Py_GetVersion(), Py_GetPlatform());
    if config_int(config, PyConfig_SITE_IMPORT) != 0 {
        fprintf(
            stdio(2),
            ptr[u8]("%s\n"),
            ptr[u8](
                "Type \"help\", \"copyright\", \"credits\" or \"license\" for more information."
            )
        );
    }
}

impl pymain_import_readline(config: ptr[u8]) {
    if config_int(config, PyConfig_ISOLATED) != 0 {
        return;
    }
    if config_int(config, PyConfig_INSPECT) == 0 and config_run_code(config) {
        return;
    }
    if isatty(fileno(stdio(0))) == 0 {
        return;
    }

    mod = PyImport_ImportModule(ptr[u8]("readline"));
    if not mod {
        PyErr_Clear();
    } else {
        object_decref(mod);
    }
    mod = PyImport_ImportModule(ptr[u8]("rlcompleter"));
    if not mod {
        PyErr_Clear();
    } else {
        object_decref(mod);
    }
}

impl pymain_run_command(command: ptr[i32]) -> i32 {
    unicode = PyUnicode_FromWideChar(command, -1);
    if unicode {
        if PySys_Audit(ptr[u8]("cpython.run_command"), ptr[u8]("O"), unicode) < 0 {
            return pymain_exit_err_print();
        }

        dedented = _PyUnicode_Dedent(unicode);
        object_decref(unicode);
        if dedented {
            bytes_obj = PyUnicode_AsUTF8String(dedented);
            object_decref(dedented);
            if bytes_obj {
                slots: own MainStack = MainStack();
                cf = init_compiler_flags(ptr[u8](jacpy_stack_address(&mut slots)));
                flags_slot = ptr[i32](ptr[u8](cf) + PyCompilerFlags_CF_FLAGS);
                flags_slot.view(1)[0] = flags_slot.view(1)[0] | PyCF_IGNORE_COOKIE;
                ret = _PyRun_SimpleStringFlagsWithName(
                    PyBytes_AsString(bytes_obj), ptr[u8]("<string>"), cf
                );
                object_decref(bytes_obj);
                if ret != 0 {
                    return 1;
                }
                return 0;
            }
        }
    }

    PySys_WriteStderr(ptr[u8]("Unable to decode the command from the command line:\n"));
    return pymain_exit_err_print();
}

impl pymain_start_pyrepl(pythonstartup: i32) -> i32 {
    res: i32 = 0;
    console = NULL;
    empty_tuple = NULL;
    kwargs = NULL;
    console_result = NULL;
    main_module = NULL;

    pyrepl = PyImport_ImportModule(ptr[u8]("_pyrepl.main"));
    while True {
        if not pyrepl {
            fprintf(stdio(2), ptr[u8]("Could not import _pyrepl.main\n"));
            res = pymain_exit_err_print();
            break;
        }
        console = PyObject_GetAttrString(pyrepl, ptr[u8]("interactive_console"));
        if not console {
            fprintf(
                stdio(2), ptr[u8]("Could not access _pyrepl.main.interactive_console\n")
            );
            res = pymain_exit_err_print();
            break;
        }
        empty_tuple = PyTuple_New(0);
        if not empty_tuple {
            res = pymain_exit_err_print();
            break;
        }
        kwargs = PyDict_New();
        if not kwargs {
            res = pymain_exit_err_print();
            break;
        }
        main_module = PyImport_AddModuleRef(ptr[u8]("__main__"));
        if not main_module {
            res = pymain_exit_err_print();
            break;
        }
        startup_flag = bool_object(pythonstartup != 0);
        if PyDict_SetItemString(kwargs, ptr[u8]("mainmodule"), main_module) == 0
            and PyDict_SetItemString(kwargs, ptr[u8]("pythonstartup"), startup_flag)
                == 0 {
            console_result = PyObject_Call(console, empty_tuple, kwargs);
            if not console_result {
                res = pymain_exit_err_print();
            }
        }
        break;
    }
    object_xdecref(console_result);
    object_xdecref(kwargs);
    object_xdecref(empty_tuple);
    object_xdecref(console);
    object_xdecref(pyrepl);
    object_xdecref(main_module);
    return res;
}

impl pymain_run_module(modname: ptr[i32], set_argv0: i32) -> i32 {
    if PySys_Audit(ptr[u8]("cpython.run_module"), ptr[u8]("u"), modname) < 0 {
        return pymain_exit_err_print();
    }
    runmodule = PyImport_ImportModuleAttrString(
        ptr[u8]("runpy"), ptr[u8]("_run_module_as_main")
    );
    if not runmodule {
        fprintf(stdio(2), ptr[u8]("Could not import runpy._run_module_as_main\n"));
        return pymain_exit_err_print();
    }
    module = PyUnicode_FromWideChar(modname, i64(wcslen(modname)));
    if not module {
        fprintf(stdio(2), ptr[u8]("Could not convert module name to unicode\n"));
        object_decref(runmodule);
        return pymain_exit_err_print();
    }
    argv0_flag = bool_object(set_argv0 != 0);
    runargs = PyTuple_Pack(2, module, argv0_flag);
    if not runargs {
        fprintf(
            stdio(2),
            ptr[u8]("Could not create arguments for runpy._run_module_as_main\n")
        );
        object_decref(runmodule);
        object_decref(module);
        return pymain_exit_err_print();
    }
    result = PyObject_Call(runmodule, runargs, NULL);
    object_decref(runmodule);
    object_decref(module);
    object_decref(runargs);
    if not result {
        return pymain_exit_err_print();
    }
    object_decref(result);
    return 0;
}

impl pymain_run_file_obj(
    program_name: ptr[PyObject], filename: ptr[PyObject], skip_source_first_line: i32
) -> i32 {
    if PySys_Audit(ptr[u8]("cpython.run_file"), ptr[u8]("O"), filename) < 0 {
        return pymain_exit_err_print();
    }

    fp = Py_fopen(filename, ptr[u8]("rb"));
    if not fp {
        PyErr_Clear();
        err = i32(jacpy_errno());
        PySys_FormatStderr(
            ptr[u8]("%S: can't open file %R: [Errno %d] %s\n"),
            program_name,
            filename,
            err,
            strerror(err)
        );
        return 2;
    }

    if skip_source_first_line != 0 {
        ch = fgetc(fp);
        while ch != MAIN_EOF {
            if ch == 10 {
                ungetc(ch, fp);
                break;
            }
            ch = fgetc(fp);
        }
    }

    sb = _Py_stat_struct();
    if _Py_fstat_noraise(fileno(ptr(fp)), &mut sb) == 0
        and (i64(sb.st_mode) & MODE_TYPE_MASK) == MODE_DIRECTORY {
        PySys_FormatStderr(
            ptr[u8]("%S: %R is a directory, cannot continue\n"), program_name, filename
        );
        fclose(fp);
        return 1;
    }

    if Py_MakePendingCalls() == -1 {
        fclose(fp);
        return pymain_exit_err_print();
    }

    slots: own MainStack = MainStack();
    cf = init_compiler_flags(ptr[u8](jacpy_stack_address(&mut slots)));
    run = _PyRun_AnyFileObject(fp, filename, 1, cf);
    if run != 0 {
        return 1;
    }
    return 0;
}

impl pymain_run_file(config: ptr[u8]) -> i32 {
    filename = PyUnicode_FromWideChar(config_wide(config, PyConfig_RUN_FILENAME), -1);
    if not filename {
        PyErr_Print();
        return -1;
    }
    program_name = PyUnicode_FromWideChar(
        config_wide(config, PyConfig_PROGRAM_NAME), -1
    );
    if not program_name {
        object_decref(filename);
        PyErr_Print();
        return -1;
    }

    res = pymain_run_file_obj(
        program_name, filename, config_int(config, PyConfig_SKIP_SOURCE_FIRST_LINE)
    );
    object_decref(filename);
    object_decref(program_name);
    return res;
}

impl pymain_run_startup(config: ptr[u8]) -> tuple[i32, i32] {
    use_environment = config_int(config, PyConfig_USE_ENVIRONMENT);
    if use_environment == 0 {
        return (i32(0), i32(0));
    }
    env = _Py_GetEnv(use_environment, ptr[u8]("PYTHONSTARTUP"));
    if not env {
        return (i32(0), i32(0));
    }
    startup = PyUnicode_DecodeFSDefault(env);
    failed = not startup;
    if not failed {
        failed = PySys_Audit(ptr[u8]("cpython.run_startup"), ptr[u8]("O"), startup) < 0;
    }
    if not failed {
        fp = Py_fopen(startup, ptr[u8]("r"));
        if not fp {
            save_errno = jacpy_errno();
            PyErr_Clear();
            PySys_WriteStderr(ptr[u8]("Could not open PYTHONSTARTUP\n"));

            jacpy_set_errno(save_errno);
            PyErr_SetFromErrnoWithFilenameObjects(PyExc_OSError, startup, NULL);
            failed = True;
        } else {
            slots: own MainStack = MainStack();
            cf = init_compiler_flags(ptr[u8](jacpy_stack_address(&mut slots)));
            _PyRun_SimpleFileObject(fp, startup, 0, cf);
            PyErr_Clear();
            fclose(fp);
        }
    }
    ret: i32 = 0;
    exitcode: i32 = 0;
    if failed {
        (ret, exitcode) = pymain_err_print();
    }
    object_xdecref(startup);
    return (ret, exitcode);
}

impl pymain_run_interactive_hook -> tuple[i32, i32] {
    hook = PyImport_ImportModuleAttrString(
        ptr[u8]("sys"), ptr[u8]("__interactivehook__")
    );
    if not hook {
        if PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
            PyErr_Clear();
            return (i32(0), i32(0));
        }
    } elif PySys_Audit(ptr[u8]("cpython.run_interactivehook"), ptr[u8]("O"), hook)
        < 0 {
        object_decref(hook);
    } else {
        result = PyObject_CallNoArgs(hook);
        object_decref(hook);
        if result {
            object_decref(result);
            return (i32(0), i32(0));
        }
    }

    PySys_WriteStderr(ptr[u8]("Failed calling sys.__interactivehook__\n"));
    return pymain_err_print();
}

impl pymain_set_inspect(config: ptr[u8], inspect: i32) {
    ptr[i32](config + PyConfig_INSPECT).view(1)[0] = inspect;
    ptr[i32](addressof(Py_InspectFlag)).view(1)[0] = inspect;
}

impl pymain_run_stdin(config: ptr[u8]) -> i32 {
    if stdin_is_interactive(config) {
        pymain_set_inspect(config, 0);

        (stop, exitcode) = pymain_run_startup(config);
        if stop != 0 {
            return exitcode;
        }

        (hook_stop, hook_exitcode) = pymain_run_interactive_hook();
        if hook_stop != 0 {
            return hook_exitcode;
        }
    }

    if Py_MakePendingCalls() == -1 {
        return pymain_exit_err_print();
    }

    if PySys_Audit(ptr[u8]("cpython.run_stdin"), ptr[u8]()) < 0 {
        return pymain_exit_err_print();
    }

    if isatty(fileno(stdio(0))) == 0
        or int(
            _Py_GetEnv(
                config_int(config, PyConfig_USE_ENVIRONMENT),
                ptr[u8]("PYTHON_BASIC_REPL")
            )
        )
            != 0 {
        slots: own MainStack = MainStack();
        cf = init_compiler_flags(ptr[u8](jacpy_stack_address(&mut slots)));
        run = PyRun_AnyFileExFlags(ptr[FILE](stdio(0)), ptr[u8]("<stdin>"), 0, cf);
        if run != 0 {
            return 1;
        }
        return 0;
    }
    return pymain_start_pyrepl(0);
}

impl pymain_repl(config: ptr[u8], exitcode: i32) -> i32 {
    if config_int(config, PyConfig_INSPECT) == 0
        and int(
            _Py_GetEnv(
                config_int(config, PyConfig_USE_ENVIRONMENT), ptr[u8]("PYTHONINSPECT")
            )
        )
            != 0 {
        pymain_set_inspect(config, 1);
    }

    if not (
        config_int(config, PyConfig_INSPECT) != 0
        and stdin_is_interactive(config)
        and config_run_code(config)
    ) {
        return exitcode;
    }

    pymain_set_inspect(config, 0);
    (hook_stop, hook_exitcode) = pymain_run_interactive_hook();
    if hook_stop != 0 {
        return hook_exitcode;
    }

    if PySys_Audit(ptr[u8]("cpython.run_stdin"), ptr[u8]()) < 0 {
        return exitcode;
    }

    if isatty(fileno(stdio(0))) == 0
        or int(
            _Py_GetEnv(
                config_int(config, PyConfig_USE_ENVIRONMENT),
                ptr[u8]("PYTHON_BASIC_REPL")
            )
        )
            != 0 {
        slots: own MainStack = MainStack();
        cf = init_compiler_flags(ptr[u8](jacpy_stack_address(&mut slots)));
        run = PyRun_AnyFileExFlags(ptr[FILE](stdio(0)), ptr[u8]("<stdin>"), 0, cf);
        if run != 0 {
            return 1;
        }
        return 0;
    }
    run = pymain_start_pyrepl(1);
    if run != 0 {
        return 1;
    }
    return 0;
}

impl pymain_run_python(exitcode_in: i32) -> i32 {
    exitcode = exitcode_in;
    main_importer_path = NULL;
    interp = current_interp();

    config = _PyInterpreterState_GetConfig(interp);

    failed = False;
    while True {
        if status_exception(_PyPathConfig_UpdateGlobal(config)) {
            failed = True;
            break;
        }

        run_filename = config_wide(config, PyConfig_RUN_FILENAME);
        if run_filename {
            (stop, importer, code) = pymain_get_importer(run_filename);
            if stop != 0 {
                return code;
            }
            main_importer_path = importer;
        }

        pymain_import_readline(config);

        path0 = NULL;
        if main_importer_path {
            path0 = object_new_ref(main_importer_path);
        } elif config_int(config, PyConfig_SAFE_PATH) == 0 {
            res = _PyPathConfig_ComputeSysPath0(config + PyConfig_ARGV, &mut path0);
            if res < 0 {
                failed = True;
                break;
            } elif res == 0 {
                old = path0;
                path0 = NULL;
                object_xdecref(old);
            }
        }
        if path0 {
            wstr = PyUnicode_AsWideCharString(path0, None);
            if not wstr {
                object_decref(path0);
                failed = True;
                break;
            }
            sys_path_0 = _PyMem_RawWcsdup(wstr);
            ptr[ptr[i32]](config + PyConfig_SYS_PATH_0).view(1)[0] = sys_path_0;
            PyMem_Free(ptr(wstr));
            if not sys_path_0 {
                object_decref(path0);
                failed = True;
                break;
            }
            res = pymain_sys_path_add_path0(interp, path0);
            object_decref(path0);
            if res < 0 {
                failed = True;
                break;
            }
        }

        pymain_header(config);

        _PyInterpreterState_SetRunningMain(interp);

        run_command = config_wide(config, PyConfig_RUN_COMMAND);
        run_module = config_wide(config, PyConfig_RUN_MODULE);
        if run_command {
            exitcode = pymain_run_command(run_command);
        } elif run_module {
            exitcode = pymain_run_module(run_module, 1);
        } elif main_importer_path {
            exitcode = pymain_run_module(ptr[i32](addressof(MAIN_MODULE_NAME)), 0);
        } elif run_filename {
            exitcode = pymain_run_file(config);
        } else {
            exitcode = pymain_run_stdin(config);
        }

        exitcode = pymain_repl(config, exitcode);
        break;
    }
    if failed {
        exitcode = pymain_exit_err_print();
    }

    _PyInterpreterState_SetNotRunningMain(interp);
    object_xdecref(main_importer_path);
    return exitcode;
}

impl pymain_free {
    _PyImport_Fini2();

    _PyPathConfig_ClearGlobal();
    _Py_ClearArgcArgv();
    _PyRuntime_Finalize();
}

impl exit_sigint -> i32 {
    if int(PyOS_setsig(MAIN_SIGINT, ptr())) == -1 {
        perror(ptr[u8]("signal"));
    } else {
        kill(getpid(), MAIN_SIGINT);
    }

    return MAIN_SIGINT + 128;
}

impl pymain_exit_error(status: PyStatus) {
    if status_is_exit(status) {
        pymain_free();
    }
    Py_ExitStatusException(status);
}

impl unhandled_keyboard_interrupt_slot -> ptr[i32] {
    return ptr[i32](
        ptr[u8](addressof(_PyRuntime))
            + _PyRuntimeState_SIGNALS_UNHANDLED_KEYBOARD_INTERRUPT
    );
}

impl pymain_main(args: ptr[u8]) -> i32 {
    status = pymain_init(args);
    if status_is_exit(status) {
        pymain_free();
        return status.exitcode;
    }
    if status_exception(status) {
        pymain_exit_error(status);
    }

    return Py_RunMain();
}
