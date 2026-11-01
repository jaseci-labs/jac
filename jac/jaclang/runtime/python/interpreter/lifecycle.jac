import from c {
    obj LifecycleSlots {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0),
            w10: u64 = u64(0),
            w11: u64 = u64(0),
            w12: u64 = u64(0),
            w13: u64 = u64(0),
            w14: u64 = u64(0),
            w15: u64 = u64(0),
            w16: u64 = u64(0),
            w17: u64 = u64(0),
            w18: u64 = u64(0),
            w19: u64 = u64(0);
    }  obj ExitFuncCall {
        has func: Callable[[], None] = 0;
    }  def jacpy_stack_address(slots: &mut LifecycleSlots) -> int;  def jacpy_stdio_stream(
        stream: i32
    ) -> ptr;  def jacpy_apple_streams(tstate: ptr[PyThreadState]) -> PyStatus;  def strlen(
        text: ptr[u8]
    ) -> u64;  def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def getenv(
        name: ptr[u8]
    ) -> ptr[u8];  def setenv(name: ptr[u8], value: ptr[u8], overwrite: i32) -> i32;  def setlocale(
        category: i32, locale: ptr[u8]
    ) -> ptr[u8];  def nl_langinfo(item: i32) -> ptr[u8];  def fprintf(
        stream: ptr, format: ptr[u8], *args: any
    ) -> i32;  def vfprintf(stream: ptr, format: ptr[u8], va: ptr) -> i32;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  def fflush(stream: ptr) -> i32;  def fileno(stream: ptr) -> i32;  def isatty(
        fd: i32
    ) -> i32;  def abort;  def `exit(status: i32);  def calloc(
        count: u64, size: u64
    ) -> ptr;  def free(block: ptr);  def sigaction(
        sig: i32, action: ptr, old_action: ptr
    ) -> i32;  def sigemptyset(mask: ptr) -> i32;  def _Py_write_noraise(
        fd: i32, buf: ptr, count: u64
    ) -> i64;  def _Py_IsValidFD(fd: i32) -> i32;  def _Py_ResetForceASCII;  def _PyMem_RawStrdup(
        text: ptr[u8]
    ) -> ptr[u8];  def PyMem_RawFree(block: ptr);  def _PyRuntimeState_Init(
        runtime: ptr[u8]
    ) -> PyStatus;  def _PyRuntimeState_Fini(runtime: ptr[u8]);  def _PyInterpreterState_Enable(
        runtime: ptr[u8]
    ) -> PyStatus;  def _PyInterpreterState_New(
        tstate: ptr[PyThreadState], pinterp: &mut ptr[u8]
    ) -> PyStatus;  def _PyInterpreterState_SetWhence(interp: ptr[u8], whence: i64);  def _PyInterpreterState_GetConfig(
        interp: ptr[u8]
    ) -> ptr[u8];  def _PyInterpreterState_Clear(tstate: ptr[PyThreadState]);  def PyInterpreterState_Delete(
        interp: ptr[u8]
    );  def _PyInterpreterState_SetRunningMain(interp: ptr[u8]) -> i32;  def _PyInterpreterState_SetNotRunningMain(
        interp: ptr[u8]
    );  def _PyThreadState_IsRunningMain(tstate: ptr[PyThreadState]) -> i32;  def _PyThreadState_New(
        interp: ptr[u8], whence: i32
    ) -> ptr[PyThreadState];  def _PyThreadState_NewBound(
        interp: ptr[u8], whence: i32
    ) -> ptr[PyThreadState];  def _PyThreadState_Bind(tstate: ptr[PyThreadState]);  def _PyThreadState_Attach(
        tstate: ptr[PyThreadState]
    );  def _PyThreadState_Detach(tstate: ptr[PyThreadState]);  def _PyThreadState_SetShuttingDown(
        tstate: ptr[PyThreadState]
    );  def _PyThreadState_ClearMimallocHeaps(tstate: ptr[PyThreadState]);  def _PyGILState_Init(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyGILState_SetTstate(tstate: ptr[PyThreadState]);  def _PyGILState_Fini(
        interp: ptr[u8]
    );  def PyGILState_GetThisThreadState -> ptr[PyThreadState];  def _Py_IsMainThread -> i32;  def _Py_GetConfig -> ptr[
        u8
    ];  def _PyConfig_Write(config: ptr[u8], runtime: ptr[u8]) -> PyStatus;  def _PyConfig_Copy(
        config: ptr[u8], config2: ptr[u8]
    ) -> PyStatus;  def _PyConfig_Read(
        config: ptr[u8], compute_path_config: i32
    ) -> PyStatus;  def _PyConfig_InitImportConfig(config: ptr[u8]) -> PyStatus;  def _PyConfig_InitCompatConfig(
        config: ptr[u8]
    );  def PyConfig_InitPythonConfig(config: ptr[u8]);  def PyConfig_Clear(
        config: ptr[u8]
    );  def PyConfig_SetBytesArgv(
        config: ptr[u8], argc: i64, argv: ptr[ptr[u8]]
    ) -> PyStatus;  def _PyErr_SetFromPyStatus(status: PyStatus);  def _PyPreConfig_InitFromPreConfig(
        preconfig: ptr[u8], config2: ptr[u8]
    ) -> PyStatus;  def _PyPreConfig_InitFromConfig(
        preconfig: ptr[u8], config: ptr[u8]
    );  def _PyPreConfig_Read(preconfig: ptr[u8], args: ptr[u8]) -> PyStatus;  def _PyPreConfig_Write(
        preconfig: ptr[u8]
    ) -> PyStatus;  def _PyPathConfig_UpdateGlobal(config: ptr[u8]) -> PyStatus;  def _Py_InitVersion;  def Py_GetVersion -> ptr[
        u8
    ];  def Py_GetCopyright -> ptr[u8];  def _Py_DumpTraceback_Init;  def _Py_HashRandomization_Init(
        config: ptr[u8]
    ) -> PyStatus;  def _Py_HashRandomization_Fini;  def _PyImport_Init -> PyStatus;  def _PyImport_Fini;  def _PyImport_GetModules(
        interp: ptr[u8]
    ) -> ptr[PyObject];  def _PyImport_FixupBuiltin(
        tstate: ptr[PyThreadState],
        mod: ptr[PyObject],
        name: ptr[u8],
        modules: ptr[PyObject]
    ) -> i32;  def _PyImport_InitDefaultImportFunc(interp: ptr[u8]) -> i32;  def _PyImport_InitCore(
        tstate: ptr[PyThreadState], sysmod: ptr[PyObject], importlib: i32
    ) -> PyStatus;  def _PyImport_InitExternal(
        tstate: ptr[PyThreadState]
    ) -> PyStatus;  def _PyImport_FiniExternal(interp: ptr[u8]);  def _PyImport_FiniCore(
        interp: ptr[u8]
    );  def _PyImport_ClearModulesByIndex(interp: ptr[u8]);  def _PyImport_ClearModules(
        interp: ptr[u8]
    );  def _PyImport_GetImportlibLoader(
        interp: ptr[u8], loader_name: ptr[u8]
    ) -> ptr[PyObject];  def PyImport_AddModuleObject(
        name: ptr[PyObject]
    ) -> ptr[PyObject];  def PyImport_ImportModule(name: ptr[u8]) -> ptr[PyObject];  def PyImport_ImportModuleAttrString(
        mod_name: ptr[u8], attr_name: ptr[u8]
    ) -> ptr[PyObject];  def PyImport_ImportFrozenModule(name: ptr[u8]) -> i32;  def PyImport_GetModule(
        name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PySys_Create(
        tstate: ptr[PyThreadState], sysmod_p: &mut ptr[PyObject]
    ) -> PyStatus;  def _PySys_UpdateConfig(tstate: ptr[PyThreadState]) -> i32;  def _PySys_GetOptionalAttr(
        name: ptr[PyObject], value: &mut ptr[PyObject]
    ) -> i32;  def _PySys_GetOptionalAttrString(
        name: ptr[u8], value: &mut ptr[PyObject]
    ) -> i32;  def _PySys_SetAttr(key: ptr[PyObject], value: ptr[PyObject]) -> i32;  def PySys_SetObject(
        name: ptr[u8], value: ptr[PyObject]
    ) -> i32;  def _PySys_ClearAttrString(
        interp: ptr[u8], name: ptr[u8], verbose: i32
    ) -> i32;  def _PySys_ClearAuditHooks(tstate: ptr[PyThreadState]);  def _PySys_FiniTypes(
        interp: ptr[u8]
    );  def PySys_WriteStderr(format: ptr[u8], *args: any);  def PySys_FormatStderr(
        format: ptr[u8], *args: any
    );  def _PyErr_Print(tstate: ptr[PyThreadState]);  def PyErr_DisplayException(
        exc: ptr[PyObject]
    );  def PyRun_AnyFileExFlags(
        fp: ptr, filename: ptr[u8], closeit: i32, flags: ptr
    ) -> i32;  def Py_GETENV(name: ptr[u8]) -> ptr[u8];  def _PyEval_FiniGIL(
        interp: ptr[u8]
    );  def _PyEval_InitGIL(tstate: ptr[PyThreadState], own_gil: i32);  def _PyEval_Fini;  def _Py_FinishPendingCalls(
        tstate: ptr[PyThreadState]
    );  def _PyObject_InitState(interp: ptr[u8]) -> PyStatus;  def _PyMem_init_obmalloc(
        interp: ptr[u8]
    ) -> i32;  def _PyMem_FiniDelayed(interp: ptr[u8]);  def _PyTraceMalloc_Init -> PyStatus;  def _PyTraceMalloc_Start(
        max_nframe: i32
    ) -> i32;  def _PyTraceMalloc_Fini;  def _PyFloat_InitState(interp: ptr[u8]);  def _PyUnicode_InitGlobalObjects(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyUnicode_InitState(interp: ptr[u8]);  def _Py_GetConstant_Init;  def _PyTypes_InitTypes(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyLong_InitTypes(interp: ptr[u8]) -> PyStatus;  def _PyUnicode_InitTypes(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyFloat_InitTypes(interp: ptr[u8]) -> PyStatus;  def _PyExc_InitTypes(
        interp: ptr[u8]
    ) -> i32;  def _PyExc_InitGlobalObjects(interp: ptr[u8]) -> PyStatus;  def _PyExc_InitState(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyErr_InitTypes(interp: ptr[u8]) -> PyStatus;  def _PyContext_Init(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyXI_InitTypes(interp: ptr[u8]) -> PyStatus;  def _PyXI_Init(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyXI_Fini(interp: ptr[u8]);  def _PyXI_FiniTypes(
        interp: ptr[u8]
    );  def _PyInterpolation_InitTypes(interp: ptr[u8]) -> PyStatus;  def _PyDateTime_InitTypes(
        interp: ptr[u8]
    ) -> PyStatus;  def _PyBuiltin_Init(interp: ptr[u8]) -> ptr[PyObject];  def _PyBuiltins_AddExceptions(
        bltinmod: ptr[PyObject]
    ) -> i32;  def _PyType_Lookup(
        type: ptr[PyTypeObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_InitializeRecursionLimits(
        tstate: ptr[PyThreadState]
    );  def _PyCode_Init(interp: ptr[u8]) -> PyStatus;  def _PyCode_Fini(
        interp: ptr[u8]
    );  def _PyDtoa_Init(interp: ptr[u8]) -> PyStatus;  def _PyDtoa_Fini(
        interp: ptr[u8]
    );  def _PyGC_Init(interp: ptr[u8]) -> PyStatus;  def _PyGC_CollectNoFail(
        tstate: ptr[PyThreadState]
    );  def _PyGC_DumpShutdownStats(interp: ptr[u8]);  def PyGC_Collect -> i64;  def _PyWarnings_InitState(
        interp: ptr[u8]
    ) -> i32;  def _PyAtExit_Init(interp: ptr[u8]) -> PyStatus;  def _PyAtExit_Call(
        interp: ptr[u8]
    );  def _PyFaulthandler_Init(enable: i32) -> PyStatus;  def _PyFaulthandler_Fini;  def _PyUnicode_InitEncodings(
        tstate: ptr[PyThreadState]
    ) -> PyStatus;  def _PySignal_Init(install_signal_handlers: i32) -> i32;  def _PySignal_Fini;  def PyDict_Watch(
        watcher_id: i32, dct: ptr[PyObject]
    ) -> i32;  def PyDict_Unwatch(watcher_id: i32, dct: ptr[PyObject]) -> i32;  def PyDict_ContainsString(
        op: ptr[PyObject], key: ptr[u8]
    ) -> i32;  def _PyDict_Next(
        op: ptr[PyObject],
        pos: &mut i64,
        key: &mut ptr[PyObject],
        value: &mut ptr[PyObject],
        hash: &mut i64
    ) -> i32;  def _PySet_NextEntry(
        st: ptr[PyObject], pos: &mut i64, key: &mut ptr[PyObject], hash: &mut i64
    ) -> i32;  def _PyModule_Clear(m: ptr[PyObject]);  def _PyModule_ClearDict(
        d: ptr[PyObject]
    );  def _PyModule_IsExtension(ob: ptr[PyObject]) -> i32;  def _PyTypes_FiniExtTypes(
        interp: ptr[u8]
    );  def _PyUnicode_FiniTypes(interp: ptr[u8]);  def _PyExc_Fini(interp: ptr[u8]);  def _PyFloat_FiniType(
        interp: ptr[u8]
    );  def _PyLong_FiniTypes(interp: ptr[u8]);  def _PyThread_FiniType(
        interp: ptr[u8]
    );  def _PyErr_FiniTypes(interp: ptr[u8]);  def _PyTypes_FiniTypes(
        interp: ptr[u8]
    );  def _PyTypes_Fini(interp: ptr[u8]);  def _PyUnicode_ClearInterned(
        interp: ptr[u8]
    );  def _PyUnicode_Fini(interp: ptr[u8]);  def _PyObject_ClearFreeLists(
        freelists: ptr[u8], is_finalization: i32
    );  def _PyExc_ClearExceptionGroupType(interp: ptr[u8]);  def _Py_clear_generic_types(
        interp: ptr[u8]
    );  def _PyArg_Fini;  def _Py_ClearFileSystemEncoding;  def _PyPerfTrampoline_Fini -> i32;  def _PyHash_Fini;  def _PyObject_DebugMallocStats(
        out: ptr
    ) -> i32;  def _Py_FinalizeAllocatedBlocks(runtime: ptr[u8]);  def _PyObject_CallMethod(
        obj_: ptr[PyObject], name: ptr[PyObject], format: ptr[u8], *args: any
    ) -> ptr[PyObject];  def _PyCodec_Lookup(encoding: ptr[u8]) -> ptr[PyObject];  def _PyErr_Clear(
        tstate: ptr[PyThreadState]
    );  def _PyErr_GetRaisedException(tstate: ptr[PyThreadState]) -> ptr[PyObject];  def _PyFile_Flush(
        file: ptr[PyObject]
    ) -> i32;  def _Py_DumpTracebackThreads(
        fd: i32, interp: ptr[u8], current_tstate: ptr[PyThreadState]
    ) -> ptr[u8];  def _Py_DumpHexadecimal(fd: i32, value: u64, width: i64);  def _Py_DumpASCII(
        fd: i32, text: ptr[PyObject]
    );  def _Py_DumpDecimal(fd: i32, value: u64);  def PyOS_mystrnicmp(
        s1: ptr[u8], s2: ptr[u8], size: i64
    ) -> i32;  glob _PyOS_mystrnicmp_hack: ptr = ptr(PyOS_mystrnicmp); glob:priv runtime_initialized:
             i32 = 0,
         fatal_error_reentrant: i32 = 0,
         fatal_format_reentrant: i32 = 0,
         BACKSLASHREPLACE_W: list[i32] = [
             i32(98),
             i32(97),
             i32(99),
             i32(107),
             i32(115),
             i32(108),
             i32(97),
             i32(115),
             i32(104),
             i32(114),
             i32(101),
             i32(112),
             i32(108),
             i32(97),
             i32(99),
             i32(101),
             i32(0)
         ]; def _PyRuntime_Initialize -> PyStatus {
        return runtime_initialize();
    }  def _PyRuntime_Finalize {
        runtime_finalize();
    }  def Py_IsFinalizing -> i32 {
        if runtime_get_finalizing(runtime_ptr()) {
            return 1;
        }
        return 0;
    }  def _Py_IsCoreInitialized -> i32 {
        return rt_int(_PyRuntimeState_CORE_INITIALIZED).view(1)[0];
    }  def Py_IsInitialized -> i32 {
        return rt_int(_PyRuntimeState_INITIALIZED).view(1)[0];
    }  def _Py_LegacyLocaleDetected(warn: i32) -> i32 {
        return legacy_locale_detected(warn);
    }  def _Py_IsLocaleCoercionTarget(ctype_loc: ptr[u8]) -> i32 {
        i = 0;
        while i < 3 {
            if strcmp(ctype_loc, target_locale(i)) == 0 {
                return 1;
            }
            i += 1;
        }
        return 0;
    }  def _Py_CoerceLegacyLocale(warn: i32) -> i32 {
        coerced: i32 = 0;
        oldloc = _PyMem_RawStrdup(setlocale(LC_CTYPE, ptr[u8]()));
        if not oldloc {
            return coerced;
        }

        locale_override = getenv(ptr[u8]("LC_ALL"));
        if not locale_override or locale_override.view(1)[0] == u8(0) {
            i = 0;
            while i < 3 {
                target = target_locale(i);
                new_locale = setlocale(LC_CTYPE, target);
                if new_locale {
                    codeset = nl_langinfo(CODESET);
                    if not codeset or codeset.view(1)[0] == u8(0) {
                        set_locale_from_env(LC_CTYPE);
                        i += 1;
                        continue;
                    }
                    coerced = coerce_default_locale_settings(warn, target);
                    PyMem_RawFree(ptr(oldloc));
                    return coerced;
                }
                i += 1;
            }
        }

        setlocale(LC_CTYPE, oldloc);
        PyMem_RawFree(ptr(oldloc));
        return coerced;
    }  def _Py_SetLocaleFromEnv(category: i32) -> ptr[u8] {
        return set_locale_from_env(category);
    }  def _Py_PreInitializeFromPyArgv(src_config: ptr[u8], args: ptr[u8]) -> PyStatus {
        return preinitialize_from_pyargv(src_config, args);
    }  def Py_PreInitializeFromBytesArgs(
        src_config: ptr[u8], argc: i64, argv: ptr[ptr[u8]]
    ) -> PyStatus {
        slots: own LifecycleSlots = LifecycleSlots();
        args = ptr[u8](jacpy_stack_address(&mut slots));
        ptr[i32](args + _PyArgv_USE_BYTES_ARGV).view(1)[0] = 1;
        ptr[i64](args + _PyArgv_ARGC).view(1)[0] = argc;
        ptr[ptr[ptr[u8]]](args + _PyArgv_BYTES_ARGV).view(1)[0] = argv;
        return preinitialize_from_pyargv(src_config, args);
    }  def Py_PreInitializeFromArgs(
        src_config: ptr[u8], argc: i64, argv: ptr[ptr[i32]]
    ) -> PyStatus {
        slots: own LifecycleSlots = LifecycleSlots();
        args = ptr[u8](jacpy_stack_address(&mut slots));
        ptr[i32](args + _PyArgv_USE_BYTES_ARGV).view(1)[0] = 0;
        ptr[i64](args + _PyArgv_ARGC).view(1)[0] = argc;
        ptr[ptr[ptr[i32]]](args + _PyArgv_WCHAR_ARGV).view(1)[0] = argv;
        return preinitialize_from_pyargv(src_config, args);
    }  def Py_PreInitialize(src_config: ptr[u8]) -> PyStatus {
        return preinitialize_from_pyargv(src_config, ptr[u8]());
    }  def _Py_PreInitializeFromConfig(config: ptr[u8], args: ptr[u8]) -> PyStatus {
        return preinitialize_from_config(config, args);
    }  def Py_InitializeFromConfig(config: ptr[u8]) -> PyStatus {
        return initialize_from_config(config);
    }  def Py_InitializeEx(install_sigs: i32) {
        initialize_ex(install_sigs);
    }  def Py_Initialize {
        initialize_ex(1);
    }  def Py_FinalizeEx -> i32 {
        return py_finalize(runtime_ptr());
    }  def Py_Finalize {
        py_finalize(runtime_ptr());
    }  def Py_NewInterpreterFromConfig(
        tstate_p: ptr[ptr[PyThreadState]], config: ptr[u8]
    ) -> PyStatus {
        return new_interpreter(tstate_p, config, _PyInterpreterState_WHENCE_CAPI);
    }  def Py_NewInterpreter -> ptr[PyThreadState] {
        slots: own LifecycleSlots = LifecycleSlots();
        block = ptr[u8](jacpy_stack_address(&mut slots));
        tstate_p = ptr[ptr[PyThreadState]](block);
        config = block + 8;
        legacy_interpreter_config(config);
        status = new_interpreter(
            tstate_p, config, _PyInterpreterState_WHENCE_LEGACY_CAPI
        );
        if status_exception(status) {
            exit_status_exception(status);
        }
        return tstate_p.view(1)[0];
    }  def Py_EndInterpreter(tstate: ptr[PyThreadState]) {
        end_interpreter(tstate);
    }  def _Py_IsInterpreterFinalizing(interp: ptr[PyInterpreterState]) -> i32 {
        finalizing = runtime_get_finalizing(runtime_ptr());
        if not finalizing {
            finalizing = interp_get_finalizing(ptr[u8](interp));
        }
        if finalizing {
            return 1;
        }
        return 0;
    }  def _Py_DumpExtensionModules(fd: i32, interp: ptr[PyInterpreterState]) {
        dump_extension_modules(fd, ptr[u8](interp));
    }  def Py_FatalError(msg: ptr[u8]) {
        fatal_error(stderr_fd(), 1, ptr[u8](), msg, -1);
    }  def _Py_FatalErrorFunc(func: ptr[u8], msg: ptr[u8]) {
        fatal_error(stderr_fd(), 1, func, msg, -1);
    }  def _Py_FatalErrorFormat(func: ptr[u8], format: ptr[u8], *args: VaList) {
        stream = fatal_format_begin(func);
        vfprintf(stream, format, ptr(args));
        fatal_format_end(stream);
    }  def _Py_FatalRefcountErrorFunc(func: ptr[u8], msg: ptr[u8]) {
        stream = fatal_format_begin(func);
        fprintf(
            stream,
            ptr[u8]("%s: bug likely caused by a refcount error in a C extension"),
            msg
        );
        fatal_format_end(stream);
    }  def Py_ExitStatusException(status: PyStatus) {
        exit_status_exception(status);
    }  def Py_AtExit(func: ptr) -> i32 {
        runtime = runtime_ptr();
        mutex = ptr[PyMutex](runtime + _PyRuntimeState_ATEXIT_MUTEX);
        PyMutex_Lock(mutex);
        ncallbacks = ptr[i32](runtime + _PyRuntimeState_ATEXIT_NCALLBACKS);
        count = ncallbacks.view(1)[0];
        if i64(count) >= NEXITFUNCS {
            PyMutex_Unlock(mutex);
            return -1;
        }
        callbacks = ptr[ptr](runtime + _PyRuntimeState_ATEXIT_CALLBACKS);
        (callbacks + i64(count)).view(1)[0] = func;
        ncallbacks.view(1)[0] = count + 1;
        PyMutex_Unlock(mutex);
        return 0;
    }  def Py_Exit(sts: i32) {
        status = sts;
        tstate = current_tstate();
        if tstate and _PyThreadState_IsRunningMain(tstate) != 0 {
            _PyInterpreterState_SetNotRunningMain(tstate_interp(tstate));
        }
        if py_finalize(runtime_ptr()) < 0 {
            status = 120;
        }

        `exit(status);
    }  def Py_FdIsInteractive(fp: ptr, filename: ptr[u8]) -> i32 {
        if isatty(fileno(fp)) != 0 {
            return 1;
        }
        if ptr[i32](_Py_GetConfig() + PyConfig_INTERACTIVE).view(1)[0] == 0 {
            return 0;
        }
        if not filename
            or strcmp(filename, ptr[u8]("<stdin>")) == 0
            or strcmp(filename, ptr[u8]("???")) == 0 {
            return 1;
        }
        return 0;
    }  def _Py_FdIsInteractive(fp: ptr, filename: ptr[PyObject]) -> i32 {
        if isatty(fileno(fp)) != 0 {
            return 1;
        }
        if ptr[i32](_Py_GetConfig() + PyConfig_INTERACTIVE).view(1)[0] == 0 {
            return 0;
        }
        if not filename
            or PyUnicode_CompareWithASCIIString(filename, ptr[u8]("<stdin>")) == 0
            or PyUnicode_CompareWithASCIIString(filename, ptr[u8]("???")) == 0 {
            return 1;
        }
        return 0;
    }  def PyOS_getsig(sig: i32) -> ptr {
        slots: own LifecycleSlots = LifecycleSlots();
        context = ptr[u8](jacpy_stack_address(&mut slots));
        if sigaction(sig, ptr(), ptr(context)) == -1 {
            return ptr(SIG_ERR_VALUE);
        }
        return ptr[ptr](context + sigaction_SA_HANDLER).view(1)[0];
    }  def PyOS_setsig(sig: i32, handler: ptr) -> ptr {
        new_slots: own LifecycleSlots = LifecycleSlots();
        old_slots: own LifecycleSlots = LifecycleSlots();
        context = ptr[u8](jacpy_stack_address(&mut new_slots));
        ocontext = ptr[u8](jacpy_stack_address(&mut old_slots));
        ptr[ptr](context + sigaction_SA_HANDLER).view(1)[0] = handler;
        sigemptyset(ptr(context + sigaction_SA_MASK));

        ptr[i32](context + sigaction_SA_FLAGS).view(1)[0] = i32(SA_ONSTACK);
        if sigaction(sig, ptr(context), ptr(ocontext)) == -1 {
            return ptr(SIG_ERR_VALUE);
        }
        return ptr[ptr](ocontext + sigaction_SA_HANDLER).view(1)[0];
    }  def Py_FrozenMain(argc: i32, argv: ptr[ptr[u8]]) -> i32 {
        status = runtime_initialize();
        if status_exception(status) {
            exit_status_exception(status);
        }

        config = ptr[u8](calloc(u64(1), u64(PyConfig_SIZE)));
        if not config {
            exit_status_exception(status_no_memory(ptr[u8]("Py_FrozenMain")));
        }
        PyConfig_InitPythonConfig(config);

        ptr[i32](config + PyConfig_PATHCONFIG_WARNINGS).view(1)[0] = 0;

        ptr[i32](config + PyConfig_PARSE_ARGV).view(1)[0] = 0;

        status = PyConfig_SetBytesArgv(config, i64(argc), argv);
        if status_exception(status) {
            PyConfig_Clear(config);
            free(ptr(config));
            exit_status_exception(status);
        }

        inspect = 0;
        p = Py_GETENV(ptr[u8]("PYTHONINSPECT"));
        if p and p.view(1)[0] != u8(0) {
            inspect = 1;
        }

        status = initialize_from_config(config);
        PyConfig_Clear(config);
        free(ptr(config));
        if status_exception(status) {
            exit_status_exception(status);
        }

        interp = ptr[u8](PyInterpreterState_Get());
        if _PyInterpreterState_SetRunningMain(interp) < 0 {
            PyErr_Print();
            `exit(1);
        }

        if ptr[i32](_Py_GetConfig() + PyConfig_VERBOSE).view(1)[0] != 0 {
            fprintf(
                jacpy_stdio_stream(2),
                ptr[u8]("Python %s\n%s\n"),
                Py_GetVersion(),
                Py_GetCopyright()
            );
        }

        sts: i32 = 1;
        n = PyImport_ImportFrozenModule(ptr[u8]("__main__"));
        if n == 0 {
            fatal_error(
                stderr_fd(),
                1,
                ptr[u8]("Py_FrozenMain"),
                ptr[u8]("the __main__ module is not frozen"),
                -1
            );
        }
        if n < 0 {
            PyErr_Print();
            sts = 1;
        } else {
            sts = 0;
        }

        if inspect != 0 and isatty(fileno(jacpy_stdio_stream(0))) != 0 {
            sts = 0;
            run_result = PyRun_AnyFileExFlags(
                jacpy_stdio_stream(0), ptr[u8]("<stdin>"), 0, ptr()
            );
            if run_result != 0 {
                sts = 1;
            }
        }

        _PyInterpreterState_SetNotRunningMain(interp);

        if py_finalize(runtime_ptr()) < 0 {
            sts = 120;
        }
        return sts;
    }
}

glob:priv SIG_ERR_VALUE: Final[int] = -1,
     S_IFMT_BITS: Final[u64] = 0o170000,
     S_IFDIR_BITS: Final[u64] = 0o040000;

def:priv runtime_ptr -> ptr[u8];

def:priv rt_int(offset: i64) -> ptr[i32];

def:priv stderr_fd -> i32;

def:priv puts_fd(fd: i32, text: ptr[u8]);

def:priv status_ok -> PyStatus;

def:priv status_err(func: ptr[u8], msg: ptr[u8]) -> PyStatus;

def:priv status_no_memory(func: ptr[u8]) -> PyStatus;

def:priv status_exception(status: PyStatus) -> bool;

def:priv tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def:priv tstate_next(tstate: ptr[PyThreadState]) -> ptr[PyThreadState];

def:priv interp_runtime(interp: ptr[u8]) -> ptr[u8];

def:priv interp_config(interp: ptr[u8]) -> ptr[u8];

def:priv interp_builtins(interp: ptr[u8]) -> ptr[PyObject];

def:priv interp_sysdict(interp: ptr[u8]) -> ptr[PyObject];

def:priv is_main_interp(interp: ptr[u8]) -> bool;

def:priv config_int(config: ptr[u8], offset: i64) -> i32;

def:priv runtime_get_finalizing(runtime: ptr[u8]) -> ptr[PyThreadState];

def:priv runtime_set_finalizing(runtime: ptr[u8], tstate: ptr[PyThreadState]);

def:priv interp_get_finalizing(interp: ptr[u8]) -> ptr[PyThreadState];

def:priv interp_set_finalizing(interp: ptr[u8], tstate: ptr[PyThreadState]);

def:priv legacy_interpreter_config(config: ptr[u8]);

def:priv runtime_initialize -> PyStatus;

def:priv runtime_finalize;

def:priv legacy_locale_detected(warn: i32) -> i32;

def:priv emit_stderr_warning_for_legacy_locale(runtime: ptr[u8]);

def:priv target_locale(index: int) -> ptr[u8];

def:priv coerce_default_locale_settings(warn: i32, newloc: ptr[u8]) -> i32;

def:priv set_locale_from_env(category: i32) -> ptr[u8];

def:priv interpreter_update_config(
    tstate: ptr[PyThreadState], only_update_path_config: i32
) -> i32;

def:priv pyinit_core_reconfigure(
    runtime: ptr[u8], tstate_p: ptr[ptr[PyThreadState]], config: ptr[u8]
) -> PyStatus;

def:priv pycore_init_runtime(runtime: ptr[u8], config: ptr[u8]) -> PyStatus;

def:priv init_interp_settings(interp: ptr[u8], config: ptr[u8]) -> PyStatus;

def:priv init_interp_create_gil(tstate: ptr[PyThreadState], gil: i32);

def:priv builtins_dict_watcher(
    event: i32, dct: ptr[PyObject], key: ptr[PyObject], new_value: ptr[PyObject]
) -> i32;

def:priv pycore_create_interpreter(
    runtime: ptr[u8], src_config: ptr[u8], tstate_p: ptr[ptr[PyThreadState]]
) -> PyStatus;

def:priv pycore_init_global_objects(interp: ptr[u8]) -> PyStatus;

def:priv pycore_init_types(interp: ptr[u8]) -> PyStatus;

def:priv pycore_init_builtins_error(bimod: ptr[PyObject]) -> PyStatus;

def:priv pycore_init_builtins(tstate: ptr[PyThreadState]) -> PyStatus;

def:priv pycore_interp_init(tstate: ptr[PyThreadState]) -> PyStatus;

def:priv pyinit_config(
    runtime: ptr[u8], tstate_p: ptr[ptr[PyThreadState]], config: ptr[u8]
) -> PyStatus;

def:priv preinitialize_from_pyargv(src_config: ptr[u8], args: ptr[u8]) -> PyStatus;

def:priv preinitialize_from_config(config: ptr[u8], args: ptr[u8]) -> PyStatus;

def:priv pyinit_core(
    runtime: ptr[u8], src_config: ptr[u8], tstate_p: ptr[ptr[PyThreadState]]
) -> PyStatus;

def:priv pyinit_main_reconfigure(tstate: ptr[PyThreadState]) -> PyStatus;

def:priv init_interp_main(tstate: ptr[PyThreadState]) -> PyStatus;

def:priv pyinit_main(tstate: ptr[PyThreadState]) -> PyStatus;

def:priv initialize_from_config(config: ptr[u8]) -> PyStatus;

def:priv initialize_ex(install_sigs: i32);

def:priv sys_delete_name(index: int) -> ptr[u8];

def:priv sys_file_name(index: int) -> ptr[u8];

def:priv sys_file_orig_name(index: int) -> ptr[u8];

def:priv finalize_modules_delete_special(tstate: ptr[PyThreadState], verbose: i32);

def:priv store_module_weakref(
    weaklist: ptr[PyObject], name: ptr[PyObject], mod: ptr[PyObject]
);

def:priv clear_module(
    modules: ptr[PyObject],
    weaklist: ptr[PyObject],
    name: ptr[PyObject],
    mod: ptr[PyObject],
    verbose: i32
);

def:priv finalize_remove_modules(
    modules: ptr[PyObject], verbose: i32
) -> ptr[PyObject];

def:priv finalize_clear_modules_dict(modules: ptr[PyObject]);

def:priv finalize_restore_builtins(tstate: ptr[PyThreadState]);

def:priv finalize_modules_clear_weaklist(
    interp: ptr[u8], weaklist: ptr[PyObject], verbose: i32
);

def:priv finalize_clear_sys_builtins_dict(interp: ptr[u8], verbose: i32);

def:priv finalize_modules(tstate: ptr[PyThreadState]);

def:priv file_is_closed(fobj: ptr[PyObject]) -> i32;

def:priv flush_std_files -> i32;

def:priv finalize_interp_types(interp: ptr[u8]);

def:priv finalize_interp_clear(tstate: ptr[PyThreadState]);

def:priv finalize_interp_delete(interp: ptr[u8]);

def:priv resolve_final_tstate(runtime: ptr[u8]) -> ptr[PyThreadState];

def:priv py_finalize(runtime: ptr[u8]) -> i32;

def:priv new_interpreter(
    tstate_p: ptr[ptr[PyThreadState]], config: ptr[u8], whence: i64
) -> PyStatus;

def:priv new_interpreter_error(
    tstate_p: ptr[ptr[PyThreadState]],
    status: PyStatus,
    save_tstate: ptr[PyThreadState],
    tstate: ptr[PyThreadState],
    interp: ptr[u8]
) -> PyStatus;

def:priv end_interpreter(tstate: ptr[PyThreadState]);

def:priv first_subinterpreter(runtime: ptr[u8], main_interp: ptr[u8]) -> ptr[u8];

def:priv finalize_subinterpreters;

def:priv add_main_module(interp: ptr[u8]) -> PyStatus;

def:priv init_import_site -> PyStatus;

def:priv create_stdio_error(
    fd: i32,
    buf: ptr[PyObject],
    stream: ptr[PyObject],
    text: ptr[PyObject],
    raw: ptr[PyObject]
) -> ptr[PyObject];

def:priv create_stdio(
    config: ptr[u8],
    io: ptr[PyObject],
    fd: i32,
    write_mode: i32,
    name: ptr[u8],
    encoding: ptr[i32],
    errors: ptr[i32]
) -> ptr[PyObject];

def:priv init_set_builtins_open -> PyStatus;

def:priv init_sys_streams_error(iomod: ptr[PyObject]) -> PyStatus;

def:priv init_sys_streams(tstate: ptr[PyThreadState]) -> PyStatus;

def:priv fatal_error_dump_tracebacks(
    fd: i32, interp: ptr[u8], tstate: ptr[PyThreadState]
);

def:priv fatal_error_print_exc(tstate: ptr[PyThreadState]) -> i32;

def:priv fatal_error_dump_runtime(fd: i32, runtime: ptr[u8]);

def:priv fatal_error_exit(status: i32);

def:priv dump_extension_modules(fd: i32, interp: ptr[u8]);

def:priv fatal_error(fd: i32, header: i32, prefix: ptr[u8], msg: ptr[u8], status: i32);

def:priv fatal_format_begin(func: ptr[u8]) -> ptr;

def:priv fatal_format_end(stream: ptr);

def:priv exit_status_exception(status: PyStatus);

def:priv wait_for_thread_shutdown(tstate: ptr[PyThreadState]);

def:priv call_ll_exitfuncs(runtime: ptr[u8]);

impl runtime_ptr -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime));
}

impl rt_int(offset: i64) -> ptr[i32] {
    return ptr[i32](runtime_ptr() + offset);
}

impl stderr_fd -> i32 {
    return fileno(jacpy_stdio_stream(2));
}

impl puts_fd(fd: i32, text: ptr[u8]) {
    _Py_write_noraise(fd, ptr(text), strlen(text));
}

impl status_ok -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl status_err(func: ptr[u8], msg: ptr[u8]) -> PyStatus {
    return PyStatus(_type=_PyStatus_TYPE_ERROR, func=func, err_msg=msg, exitcode=0);
}

impl status_no_memory(func: ptr[u8]) -> PyStatus {
    return status_err(func, ptr[u8]("memory allocation failed"));
}

impl status_exception(status: PyStatus) -> bool {
    return status._type != _PyStatus_TYPE_OK;
}

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl tstate_next(tstate: ptr[PyThreadState]) -> ptr[PyThreadState] {
    return ptr[ptr[PyThreadState]](ptr[u8](tstate) + PyThreadState_NEXT).view(1)[0];
}

impl interp_runtime(interp: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
}

impl interp_config(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_CONFIG;
}

impl interp_builtins(interp: ptr[u8]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](interp + PyInterpreterState_BUILTINS).view(1)[0];
}

impl interp_sysdict(interp: ptr[u8]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](interp + PyInterpreterState_SYSDICT).view(1)[0];
}

impl is_main_interp(interp: ptr[u8]) -> bool {
    return interp == ptr[u8](_PyInterpreterState_Main());
}

impl config_int(config: ptr[u8], offset: i64) -> i32 {
    return ptr[i32](config + offset).view(1)[0];
}

impl runtime_get_finalizing(runtime: ptr[u8]) -> ptr[PyThreadState] {
    return ptr[PyThreadState](
        __atomic_load_i64(int(runtime) + _PyRuntimeState_FINALIZING, 0)
    );
}

impl runtime_set_finalizing(runtime: ptr[u8], tstate: ptr[PyThreadState]) {
    __atomic_store_i64(int(runtime) + _PyRuntimeState_FINALIZING, i64(int(tstate)), 0);
    if not tstate {
        __atomic_store_i64(int(runtime) + _PyRuntimeState_FINALIZING_ID, i64(0), 0);
    } else {
        thread_id = ptr[i64](ptr[u8](tstate) + PyThreadState_THREAD_ID).view(1)[0];
        __atomic_store_i64(int(runtime) + _PyRuntimeState_FINALIZING_ID, thread_id, 0);
    }
}

impl interp_get_finalizing(interp: ptr[u8]) -> ptr[PyThreadState] {
    return ptr[PyThreadState](
        __atomic_load_i64(int(interp) + PyInterpreterState_FINALIZING, 0)
    );
}

impl interp_set_finalizing(interp: ptr[u8], tstate: ptr[PyThreadState]) {
    __atomic_store_i64(
        int(interp) + PyInterpreterState_FINALIZING, i64(int(tstate)), 0
    );
    if not tstate {
        __atomic_store_i64(int(interp) + PyInterpreterState_FINALIZING_ID, i64(0), 0);
    } else {
        thread_id = ptr[i64](ptr[u8](tstate) + PyThreadState_THREAD_ID).view(1)[0];
        __atomic_store_i64(
            int(interp) + PyInterpreterState_FINALIZING_ID, thread_id, 0
        );
    }
}

impl legacy_interpreter_config(config: ptr[u8]) {
    ptr[i32](config + PyInterpreterConfig_USE_MAIN_OBMALLOC).view(1)[0] = 1;
    ptr[i32](config + PyInterpreterConfig_ALLOW_FORK).view(1)[0] = 1;
    ptr[i32](config + PyInterpreterConfig_ALLOW_EXEC).view(1)[0] = 1;
    ptr[i32](config + PyInterpreterConfig_ALLOW_THREADS).view(1)[0] = 1;
    ptr[i32](config + PyInterpreterConfig_ALLOW_DAEMON_THREADS).view(1)[0] = 1;
    ptr[i32](config + PyInterpreterConfig_CHECK_MULTI_INTERP_EXTENSIONS).view(1)[0] = _PyInterpreterConfig_LEGACY_CHECK_MULTI_INTERP_EXTENSIONS;
    ptr[i32](config + PyInterpreterConfig_GIL_FIELD).view(1)[0] = PyInterpreterConfig_SHARED_GIL;
}

impl runtime_initialize -> PyStatus {
    flag = addressof(runtime_initialized);
    if flag.view(1)[0] != 0 {
        return status_ok();
    }
    flag.view(1)[0] = 1;

    return _PyRuntimeState_Init(runtime_ptr());
}

impl runtime_finalize {
    _PyRuntimeState_Fini(runtime_ptr());
    addressof(runtime_initialized).view(1)[0] = 0;
}

impl legacy_locale_detected(warn: i32) -> i32 {
    if warn == 0 {
        locale_override = getenv(ptr[u8]("LC_ALL"));
        if locale_override and locale_override.view(1)[0] != u8(0) {
            return 0;
        }
    }

    ctype_loc = setlocale(LC_CTYPE, ptr[u8]());
    if ctype_loc and strcmp(ctype_loc, ptr[u8]("C")) == 0 {
        return 1;
    }
    return 0;
}

impl emit_stderr_warning_for_legacy_locale(runtime: ptr[u8]) {
    warn = ptr[i32](runtime + _PyRuntimeState_PRECONFIG_COERCE_C_LOCALE_WARN).view(1)[
        0
    ];
    if warn != 0 and legacy_locale_detected(1) != 0 {
        PySys_FormatStderr(
            ptr[u8]("%s"),
            ptr[u8](
                "Python runtime initialized with LC_CTYPE=C (a locale with default ASCII encoding), which may cause Unicode compatibility problems. Using C.UTF-8, C.utf8, or UTF-8 (if available) as alternative Unicode-compatible locales is recommended.\n"
            )
        );
    }
}

impl target_locale(index: int) -> ptr[u8] {
    if index == 0 {
        return ptr[u8]("C.UTF-8");
    }
    if index == 1 {
        return ptr[u8]("C.utf8");
    }
    return ptr[u8]("UTF-8");
}

impl coerce_default_locale_settings(warn: i32, newloc: ptr[u8]) -> i32 {
    set_locale_from_env(LC_ALL);

    if setenv(ptr[u8]("LC_CTYPE"), newloc, 1) != 0 {
        fprintf(
            jacpy_stdio_stream(2),
            ptr[u8]("Error setting LC_CTYPE, skipping C locale coercion\n")
        );
        return 0;
    }
    if warn != 0 {
        fprintf(
            jacpy_stdio_stream(2),
            ptr[u8](
                "Python detected LC_CTYPE=C: LC_CTYPE coerced to %.20s (set another locale or PYTHONCOERCECLOCALE=0 to disable this locale coercion behavior).\n"
            ),
            newloc
        );
    }

    set_locale_from_env(LC_ALL);
    return 1;
}

impl set_locale_from_env(category: i32) -> ptr[u8] {
    res = setlocale(category, ptr[u8](""));
    _Py_ResetForceASCII();
    return res;
}

impl interpreter_update_config(
    tstate: ptr[PyThreadState], only_update_path_config: i32
) -> i32 {
    interp = tstate_interp(tstate);
    config = interp_config(interp);

    if only_update_path_config == 0 {
        status = _PyConfig_Write(config, interp_runtime(interp));
        if status_exception(status) {
            _PyErr_SetFromPyStatus(status);
            return -1;
        }
    }

    if is_main_interp(interp) {
        path_status = _PyPathConfig_UpdateGlobal(config);
        if status_exception(path_status) {
            _PyErr_SetFromPyStatus(path_status);
            return -1;
        }
    }

    ptr[i32](interp + PyInterpreterState_LONG_MAX_STR_DIGITS).view(1)[0] = config_int(
        config, PyConfig_INT_MAX_STR_DIGITS
    );

    if _PySys_UpdateConfig(tstate) < 0 {
        return -1;
    }
    return 0;
}

impl pyinit_core_reconfigure(
    runtime: ptr[u8], tstate_p: ptr[ptr[PyThreadState]], config: ptr[u8]
) -> PyStatus {
    tstate = current_tstate();
    if not tstate {
        return status_err(
            ptr[u8]("pyinit_core_reconfigure"), ptr[u8]("failed to read thread state")
        );
    }
    tstate_p.view(1)[0] = tstate;

    interp = tstate_interp(tstate);
    if not interp {
        return status_err(
            ptr[u8]("pyinit_core_reconfigure"), ptr[u8]("can't make main interpreter")
        );
    }

    status = _PyConfig_Write(config, runtime);
    if status_exception(status) {
        return status;
    }

    status = _PyConfig_Copy(interp_config(interp), config);
    if status_exception(status) {
        return status;
    }
    interp_cfg = _PyInterpreterState_GetConfig(interp);

    if config_int(interp_cfg, PyConfig_INSTALL_IMPORTLIB) != 0 {
        status = _PyPathConfig_UpdateGlobal(interp_cfg);
        if status_exception(status) {
            return status;
        }
    }
    return status_ok();
}

impl pycore_init_runtime(runtime: ptr[u8], config: ptr[u8]) -> PyStatus {
    if ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] != 0 {
        return status_err(
            ptr[u8]("pycore_init_runtime"),
            ptr[u8]("main interpreter already initialized")
        );
    }

    status = _PyConfig_Write(config, runtime);
    if status_exception(status) {
        return status;
    }

    runtime_set_finalizing(runtime, ptr[PyThreadState]());

    _Py_InitVersion();
    _Py_DumpTraceback_Init();

    status = _Py_HashRandomization_Init(config);
    if status_exception(status) {
        return status;
    }

    status = _PyImport_Init();
    if status_exception(status) {
        return status;
    }

    status = _PyInterpreterState_Enable(runtime);
    if status_exception(status) {
        return status;
    }
    return status_ok();
}

impl init_interp_settings(interp: ptr[u8], config: ptr[u8]) -> PyStatus {
    flags = ptr[u64](interp + PyInterpreterState_FEATURE_FLAGS);

    if config_int(config, PyInterpreterConfig_USE_MAIN_OBMALLOC) != 0 {
        flags.view(1)[0] = flags.view(1)[0] | Py_RTFLAGS_USE_MAIN_OBMALLOC;
    } elif config_int(config, PyInterpreterConfig_CHECK_MULTI_INTERP_EXTENSIONS) == 0 {
        return status_err(
            ptr[u8]("init_interp_settings"),
            ptr[u8](
                "per-interpreter obmalloc does not support single-phase init extension modules"
            )
        );
    }

    if config_int(config, PyInterpreterConfig_ALLOW_FORK) != 0 {
        flags.view(1)[0] = flags.view(1)[0] | Py_RTFLAGS_FORK;
    }
    if config_int(config, PyInterpreterConfig_ALLOW_EXEC) != 0 {
        flags.view(1)[0] = flags.view(1)[0] | Py_RTFLAGS_EXEC;
    }

    if config_int(config, PyInterpreterConfig_ALLOW_THREADS) != 0 {
        flags.view(1)[0] = flags.view(1)[0] | Py_RTFLAGS_THREADS;
    }
    if config_int(config, PyInterpreterConfig_ALLOW_DAEMON_THREADS) != 0 {
        flags.view(1)[0] = flags.view(1)[0] | Py_RTFLAGS_DAEMON_THREADS;
    }

    if config_int(config, PyInterpreterConfig_CHECK_MULTI_INTERP_EXTENSIONS) != 0 {
        flags.view(1)[0] = flags.view(1)[0] | Py_RTFLAGS_MULTI_INTERP_EXTENSIONS;
    }

    gil = config_int(config, PyInterpreterConfig_GIL_FIELD);
    if gil != PyInterpreterConfig_DEFAULT_GIL
        and gil != PyInterpreterConfig_SHARED_GIL
        and gil != PyInterpreterConfig_OWN_GIL {
        return status_err(
            ptr[u8]("init_interp_settings"),
            ptr[u8]("invalid interpreter config 'gil' value")
        );
    }

    return status_ok();
}

impl init_interp_create_gil(tstate: ptr[PyThreadState], gil: i32) {
    _PyEval_FiniGIL(tstate_interp(tstate));

    _PyGILState_SetTstate(tstate);

    own_gil: i32 = 0;
    if gil == PyInterpreterConfig_OWN_GIL {
        own_gil = 1;
    }

    _PyEval_InitGIL(tstate, own_gil);
}

impl builtins_dict_watcher(
    event: i32, dct: ptr[PyObject], key: ptr[PyObject], new_value: ptr[PyObject]
) -> i32 {
    interp = current_interp();

    counter = interp + PyInterpreterState_RARE_BUILTIN_DICT;
    value = counter.view(1)[0];
    if value < u8(255) {
        counter.view(1)[0] = value + u8(1);
    }
    return 0;
}

impl pycore_create_interpreter(
    runtime: ptr[u8], src_config: ptr[u8], tstate_p: ptr[ptr[PyThreadState]]
) -> PyStatus {
    interp = ptr[u8]();
    status = _PyInterpreterState_New(ptr[PyThreadState](), &mut interp);
    if status_exception(status) {
        return status;
    }
    _PyInterpreterState_SetWhence(interp, _PyInterpreterState_WHENCE_RUNTIME);
    ptr[i32](interp + PyInterpreterState_READY).view(1)[0] = 1;

    status = _PyConfig_Copy(interp_config(interp), src_config);
    if status_exception(status) {
        return status;
    }

    status = _PyGILState_Init(interp);
    if status_exception(status) {
        return status;
    }

    slots: own LifecycleSlots = LifecycleSlots();
    config = ptr[u8](jacpy_stack_address(&mut slots));
    legacy_interpreter_config(config);

    ptr[i32](config + PyInterpreterConfig_GIL_FIELD).view(1)[0] = PyInterpreterConfig_OWN_GIL;
    ptr[i32](config + PyInterpreterConfig_CHECK_MULTI_INTERP_EXTENSIONS).view(1)[0] = 0;
    status = init_interp_settings(interp, config);
    if status_exception(status) {
        return status;
    }

    status = _PyObject_InitState(interp);
    if status_exception(status) {
        return status;
    }

    if _PyMem_init_obmalloc(interp) < 0 {
        return status_no_memory(ptr[u8]("pycore_create_interpreter"));
    }

    status = _PyTraceMalloc_Init();
    if status_exception(status) {
        return status;
    }

    tstate = _PyThreadState_New(interp, _PyThreadState_WHENCE_INIT);
    if not tstate {
        return status_err(
            ptr[u8]("pycore_create_interpreter"), ptr[u8]("can't make first thread")
        );
    }
    ptr[ptr[PyThreadState]](runtime + _PyRuntimeState_MAIN_TSTATE).view(1)[0] = tstate;
    _PyThreadState_Bind(tstate);

    init_interp_create_gil(tstate, config_int(config, PyInterpreterConfig_GIL_FIELD));

    tstate_p.view(1)[0] = tstate;
    return status_ok();
}

impl pycore_init_global_objects(interp: ptr[u8]) -> PyStatus {
    _PyFloat_InitState(interp);

    status = _PyUnicode_InitGlobalObjects(interp);
    if status_exception(status) {
        return status;
    }

    _PyUnicode_InitState(interp);

    if is_main_interp(interp) {
        _Py_GetConstant_Init();
    }

    return status_ok();
}

impl pycore_init_types(interp: ptr[u8]) -> PyStatus {
    status = _PyTypes_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyLong_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyUnicode_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyFloat_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    if _PyExc_InitTypes(interp) < 0 {
        return status_err(
            ptr[u8]("pycore_init_types"),
            ptr[u8]("failed to initialize an exception type")
        );
    }

    status = _PyExc_InitGlobalObjects(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyExc_InitState(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyErr_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyContext_Init(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyXI_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyInterpolation_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyDateTime_InitTypes(interp);
    if status_exception(status) {
        return status;
    }

    return status_ok();
}

impl pycore_init_builtins_error(bimod: ptr[PyObject]) -> PyStatus {
    object_xdecref(bimod);
    return status_err(
        ptr[u8]("pycore_init_builtins"), ptr[u8]("can't initialize builtins module")
    );
}

impl pycore_init_builtins(tstate: ptr[PyThreadState]) -> PyStatus {
    interp = tstate_interp(tstate);

    bimod = _PyBuiltin_Init(interp);
    if not bimod {
        return pycore_init_builtins_error(bimod);
    }

    modules = _PyImport_GetModules(interp);
    if _PyImport_FixupBuiltin(tstate, bimod, ptr[u8]("builtins"), modules) < 0 {
        return pycore_init_builtins_error(bimod);
    }

    builtins_dict = PyModule_GetDict(bimod);
    if not builtins_dict {
        return pycore_init_builtins_error(bimod);
    }
    ptr[ptr[PyObject]](interp + PyInterpreterState_BUILTINS).view(1)[0] = object_new_ref(
        builtins_dict
    );

    isinstance_fn = PyDict_GetItemWithError(builtins_dict, py_id(_Py_ID_isinstance));
    if not isinstance_fn {
        return pycore_init_builtins_error(bimod);
    }
    ptr[ptr[PyObject]](interp + PyInterpreterState_CALLABLE_CACHE_ISINSTANCE).view(1)[
        0
    ] = isinstance_fn;

    len_fn = PyDict_GetItemWithError(builtins_dict, py_id(_Py_ID_len));
    if not len_fn {
        return pycore_init_builtins_error(bimod);
    }
    ptr[ptr[PyObject]](interp + PyInterpreterState_CALLABLE_CACHE_LEN).view(1)[0] = len_fn;

    all_fn = PyDict_GetItemWithError(builtins_dict, py_id(_Py_ID_all));
    if not all_fn {
        return pycore_init_builtins_error(bimod);
    }

    any_fn = PyDict_GetItemWithError(builtins_dict, py_id(_Py_ID_any));
    if not any_fn {
        return pycore_init_builtins_error(bimod);
    }

    consts = ptr[ptr[PyObject]](interp + PyInterpreterState_COMMON_CONSTS);
    (consts + i64(CONSTANT_ASSERTIONERROR)).view(1)[0] = PyExc_AssertionError;
    (consts + i64(CONSTANT_NOTIMPLEMENTEDERROR)).view(1)[0] = PyExc_NotImplementedError;
    (consts + i64(CONSTANT_BUILTIN_TUPLE)).view(1)[0] = ptr[PyObject](
        addressof(PyTuple_Type)
    );
    (consts + i64(CONSTANT_BUILTIN_ALL)).view(1)[0] = all_fn;
    (consts + i64(CONSTANT_BUILTIN_ANY)).view(1)[0] = any_fn;

    list_append = _PyType_Lookup(
        ptr[PyTypeObject](addressof(PyList_Type)), py_id(_Py_ID_append)
    );
    if not list_append {
        return pycore_init_builtins_error(bimod);
    }
    ptr[ptr[PyObject]](interp + PyInterpreterState_CALLABLE_CACHE_LIST_APPEND).view(1)[
        0
    ] = list_append;

    object_getattribute = _PyType_Lookup(
        ptr[PyTypeObject](addressof(PyBaseObject_Type)), py_id(_Py_ID___getattribute__)
    );
    if not object_getattribute {
        return pycore_init_builtins_error(bimod);
    }
    ptr[ptr[PyObject]](
        interp + PyInterpreterState_CALLABLE_CACHE_OBJECT_GETATTRIBUTE
    ).view(
        1
    )[0] = object_getattribute;

    if _PyBuiltins_AddExceptions(bimod) < 0 {
        return status_err(
            ptr[u8]("pycore_init_builtins"),
            ptr[u8]("failed to add exceptions to builtins")
        );
    }

    builtins_copy = PyDict_Copy(interp_builtins(interp));
    ptr[ptr[PyObject]](interp + PyInterpreterState_BUILTINS_COPY).view(1)[0] = builtins_copy;
    if not builtins_copy {
        return pycore_init_builtins_error(bimod);
    }
    object_decref(bimod);

    if _PyImport_InitDefaultImportFunc(interp) < 0 {
        return pycore_init_builtins_error(bimod);
    }

    return status_ok();
}

impl pycore_interp_init(tstate: ptr[PyThreadState]) -> PyStatus {
    hard_limit = ptr[u64](ptr[u8](tstate) + _PyThreadStateImpl_C_STACK_HARD_LIMIT);
    if hard_limit.view(1)[0] == u64(0) {
        _Py_InitializeRecursionLimits(tstate);
    }
    interp = tstate_interp(tstate);

    status = pycore_init_global_objects(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyCode_Init(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyDtoa_Init(interp);
    if status_exception(status) {
        return status;
    }

    status = _PyGC_Init(interp);
    if status_exception(status) {
        return status;
    }

    sysmod = NULL;
    status = pycore_init_types(interp);
    if status_exception(status) {
        return status;
    }

    if _PyWarnings_InitState(interp) < 0 {
        return status_err(
            ptr[u8]("pycore_interp_init"), ptr[u8]("can't initialize warnings")
        );
    }

    status = _PyAtExit_Init(interp);
    if status_exception(status) {
        return status;
    }

    status = _PySys_Create(tstate, &mut sysmod);
    if status_exception(status) {
        object_xdecref(sysmod);
        return status;
    }

    status = pycore_init_builtins(tstate);
    if status_exception(status) {
        object_xdecref(sysmod);
        return status;
    }

    status = _PyXI_Init(interp);
    if status_exception(status) {
        object_xdecref(sysmod);
        return status;
    }

    config = _PyInterpreterState_GetConfig(interp);

    status = _PyImport_InitCore(
        tstate, sysmod, config_int(config, PyConfig_INSTALL_IMPORTLIB)
    );

    object_xdecref(sysmod);
    return status;
}

impl pyinit_config(
    runtime: ptr[u8], tstate_p: ptr[ptr[PyThreadState]], config: ptr[u8]
) -> PyStatus {
    status = pycore_init_runtime(runtime, config);
    if status_exception(status) {
        return status;
    }

    status = pycore_create_interpreter(runtime, config, tstate_p);
    if status_exception(status) {
        return status;
    }
    tstate = tstate_p.view(1)[0];

    status = pycore_interp_init(tstate);
    if status_exception(status) {
        return status;
    }

    ptr[i32](runtime + _PyRuntimeState_CORE_INITIALIZED).view(1)[0] = 1;
    return status_ok();
}

impl preinitialize_from_pyargv(src_config: ptr[u8], args: ptr[u8]) -> PyStatus {
    if not src_config {
        return status_err(
            ptr[u8]("_Py_PreInitializeFromPyArgv"),
            ptr[u8]("preinitialization config is NULL")
        );
    }

    status = runtime_initialize();
    if status_exception(status) {
        return status;
    }
    runtime = runtime_ptr();

    if ptr[i32](runtime + _PyRuntimeState_PREINITIALIZED).view(1)[0] != 0 {
        return status_ok();
    }

    ptr[i32](runtime + _PyRuntimeState_PREINITIALIZING).view(1)[0] = 1;

    slots: own LifecycleSlots = LifecycleSlots();
    config = ptr[u8](jacpy_stack_address(&mut slots));

    status = _PyPreConfig_InitFromPreConfig(config, src_config);
    if status_exception(status) {
        return status;
    }

    status = _PyPreConfig_Read(config, args);
    if status_exception(status) {
        return status;
    }

    status = _PyPreConfig_Write(config);
    if status_exception(status) {
        return status;
    }

    ptr[i32](runtime + _PyRuntimeState_PREINITIALIZING).view(1)[0] = 0;
    ptr[i32](runtime + _PyRuntimeState_PREINITIALIZED).view(1)[0] = 1;
    return status_ok();
}

impl preinitialize_from_config(config: ptr[u8], args: ptr[u8]) -> PyStatus {
    status = runtime_initialize();
    if status_exception(status) {
        return status;
    }
    runtime = runtime_ptr();

    if ptr[i32](runtime + _PyRuntimeState_PREINITIALIZED).view(1)[0] != 0 {
        return status_ok();
    }

    preconfig_slots: own LifecycleSlots = LifecycleSlots();
    preconfig = ptr[u8](jacpy_stack_address(&mut preconfig_slots));

    _PyPreConfig_InitFromConfig(preconfig, config);

    if config_int(config, PyConfig_PARSE_ARGV) == 0 {
        return preinitialize_from_pyargv(preconfig, ptr[u8]());
    } elif not args {
        args_slots: own LifecycleSlots = LifecycleSlots();
        config_args = ptr[u8](jacpy_stack_address(&mut args_slots));
        argv = config + PyConfig_ARGV;
        ptr[i32](config_args + _PyArgv_USE_BYTES_ARGV).view(1)[0] = 0;
        ptr[i64](config_args + _PyArgv_ARGC).view(1)[0] = ptr[i64](
            argv + PyWideStringList_LENGTH
        ).view(
            1
        )[0];
        ptr[ptr](config_args + _PyArgv_WCHAR_ARGV).view(1)[0] = ptr[ptr](
            argv + PyWideStringList_ITEMS
        ).view(
            1
        )[0];
        return preinitialize_from_pyargv(preconfig, config_args);
    }
    return preinitialize_from_pyargv(preconfig, args);
}

impl pyinit_core(
    runtime: ptr[u8], src_config: ptr[u8], tstate_p: ptr[ptr[PyThreadState]]
) -> PyStatus {
    status = preinitialize_from_config(src_config, ptr[u8]());
    if status_exception(status) {
        return status;
    }

    config = ptr[u8](calloc(u64(1), u64(PyConfig_SIZE)));
    if not config {
        return status_no_memory(ptr[u8]("pyinit_core"));
    }
    PyConfig_InitPythonConfig(config);

    status = _PyConfig_Copy(config, src_config);
    if not status_exception(status) {
        status = _PyConfig_Read(config, 0);
        if not status_exception(status) {
            if ptr[i32](runtime + _PyRuntimeState_CORE_INITIALIZED).view(1)[0] == 0 {
                status = pyinit_config(runtime, tstate_p, config);
            } else {
                status = pyinit_core_reconfigure(runtime, tstate_p, config);
            }
        }
    }

    PyConfig_Clear(config);
    free(ptr(config));
    return status;
}

impl pyinit_main_reconfigure(tstate: ptr[PyThreadState]) -> PyStatus {
    if interpreter_update_config(tstate, 0) < 0 {
        return status_err(
            ptr[u8]("pyinit_main_reconfigure"), ptr[u8]("fail to reconfigure Python")
        );
    }
    return status_ok();
}

impl init_interp_main(tstate: ptr[PyThreadState]) -> PyStatus {
    interp = tstate_interp(tstate);
    is_main = is_main_interp(interp);
    config = _PyInterpreterState_GetConfig(interp);

    if config_int(config, PyConfig_INSTALL_IMPORTLIB) == 0 {
        if is_main {
            ptr[i32](interp_runtime(interp) + _PyRuntimeState_INITIALIZED).view(1)[0] = 1;
        }
        return status_ok();
    }

    status = _PyConfig_InitImportConfig(interp_config(interp));
    if status_exception(status) {
        return status;
    }

    if interpreter_update_config(tstate, 1) < 0 {
        return status_err(
            ptr[u8]("init_interp_main"), ptr[u8]("failed to update the Python config")
        );
    }

    status = _PyImport_InitExternal(tstate);
    if status_exception(status) {
        return status;
    }

    if is_main {
        status = _PyFaulthandler_Init(config_int(config, PyConfig_FAULTHANDLER));
        if status_exception(status) {
            return status;
        }
    }

    status = _PyUnicode_InitEncodings(tstate);
    if status_exception(status) {
        return status;
    }

    if is_main {
        if _PySignal_Init(config_int(config, PyConfig_INSTALL_SIGNAL_HANDLERS)) < 0 {
            return status_err(
                ptr[u8]("init_interp_main"), ptr[u8]("can't initialize signals")
            );
        }

        tracemalloc = config_int(config, PyConfig_TRACEMALLOC);
        if tracemalloc != 0 {
            if _PyTraceMalloc_Start(tracemalloc) < 0 {
                return status_err(
                    ptr[u8]("init_interp_main"), ptr[u8]("can't start tracemalloc")
                );
            }
        }
    }

    status = init_sys_streams(tstate);
    if status_exception(status) {
        return status;
    }

    status = init_set_builtins_open();
    if status_exception(status) {
        return status;
    }

    status = jacpy_apple_streams(tstate);
    if status_exception(status) {
        return status;
    }

    status = add_main_module(interp);
    if status_exception(status) {
        return status;
    }

    if is_main {
        warnoptions = NULL;
        if _PySys_GetOptionalAttrString(ptr[u8]("warnoptions"), &mut warnoptions) < 0 {
            return status_err(
                ptr[u8]("init_interp_main"), ptr[u8]("can't initialize warnings")
            );
        }
        if warnoptions and list_check(warnoptions) and PyList_Size(warnoptions) > 0 {
            warnings_module = PyImport_ImportModule(ptr[u8]("warnings"));
            if not warnings_module {
                fprintf(
                    jacpy_stdio_stream(2),
                    ptr[u8]("'import warnings' failed; traceback:\n")
                );
                _PyErr_Print(tstate);
            }
            object_xdecref(warnings_module);
        }
        object_xdecref(warnoptions);

        ptr[i32](interp_runtime(interp) + _PyRuntimeState_INITIALIZED).view(1)[0] = 1;
    }

    if config_int(config, PyConfig_SITE_IMPORT) != 0 {
        status = init_import_site();
        if status_exception(status) {
            return status;
        }
    }

    if is_main {
        emit_stderr_warning_for_legacy_locale(interp_runtime(interp));
    }

    if not is_main {
        sys_path_0 = ptr[ptr[i32]](config + PyConfig_SYS_PATH_0).view(1)[0];
        if sys_path_0 {
            path0 = PyUnicode_FromWideChar(sys_path_0, -1);
            if not path0 {
                return status_err(
                    ptr[u8]("init_interp_main"), ptr[u8]("can't initialize sys.path[0]")
                );
            }
            sysdict = interp_sysdict(interp);
            if not sysdict {
                object_decref(path0);
                return status_err(
                    ptr[u8]("init_interp_main"), ptr[u8]("can't initialize sys.path[0]")
                );
            }
            sys_path = PyDict_GetItemWithError(sysdict, py_id(_Py_ID_path));
            if not sys_path {
                object_decref(path0);
                return status_err(
                    ptr[u8]("init_interp_main"), ptr[u8]("can't initialize sys.path[0]")
                );
            }
            res = PyList_Insert(sys_path, 0, path0);
            object_decref(path0);
            if res != 0 {
                return status_err(
                    ptr[u8]("init_interp_main"), ptr[u8]("can't initialize sys.path[0]")
                );
            }
        }
    }

    ptr[ptr](interp + PyInterpreterState_DICT_WATCHERS).view(1)[0] = ptr(
        builtins_dict_watcher
    );
    if PyDict_Watch(0, interp_builtins(interp)) != 0 {
        return status_err(
            ptr[u8]("init_interp_main"), ptr[u8]("failed to set builtin dict watcher")
        );
    }

    return status_ok();
}

impl pyinit_main(tstate: ptr[PyThreadState]) -> PyStatus {
    runtime = interp_runtime(tstate_interp(tstate));
    if ptr[i32](runtime + _PyRuntimeState_CORE_INITIALIZED).view(1)[0] == 0 {
        return status_err(
            ptr[u8]("pyinit_main"), ptr[u8]("runtime core not initialized")
        );
    }

    if ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] != 0 {
        return pyinit_main_reconfigure(tstate);
    }

    status = init_interp_main(tstate);
    if status_exception(status) {
        return status;
    }
    return status_ok();
}

impl initialize_from_config(config: ptr[u8]) -> PyStatus {
    if not config {
        return status_err(
            ptr[u8]("Py_InitializeFromConfig"), ptr[u8]("initialization config is NULL")
        );
    }

    status = runtime_initialize();
    if status_exception(status) {
        return status;
    }
    runtime = runtime_ptr();

    slots: own LifecycleSlots = LifecycleSlots();
    tstate_p = ptr[ptr[PyThreadState]](jacpy_stack_address(&mut slots));
    status = pyinit_core(runtime, config, tstate_p);
    if status_exception(status) {
        return status;
    }
    tstate = tstate_p.view(1)[0];
    interp_cfg = _PyInterpreterState_GetConfig(tstate_interp(tstate));

    if config_int(interp_cfg, PyConfig_INIT_MAIN) != 0 {
        status = pyinit_main(tstate);
        if status_exception(status) {
            return status;
        }
    }

    return status_ok();
}

impl initialize_ex(install_sigs: i32) {
    status = runtime_initialize();
    if status_exception(status) {
        exit_status_exception(status);
    }
    runtime = runtime_ptr();

    if ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] != 0 {
        return;
    }

    config = ptr[u8](calloc(u64(1), u64(PyConfig_SIZE)));
    if not config {
        exit_status_exception(status_no_memory(ptr[u8]("Py_InitializeEx")));
    }
    _PyConfig_InitCompatConfig(config);

    ptr[i32](config + PyConfig_INSTALL_SIGNAL_HANDLERS).view(1)[0] = install_sigs;

    status = initialize_from_config(config);
    PyConfig_Clear(config);
    free(ptr(config));
    if status_exception(status) {
        exit_status_exception(status);
    }
}

impl sys_delete_name(index: int) -> ptr[u8] {
    if index == 0 {
        return ptr[u8]("path");
    }
    if index == 1 {
        return ptr[u8]("argv");
    }
    if index == 2 {
        return ptr[u8]("ps1");
    }
    if index == 3 {
        return ptr[u8]("ps2");
    }
    if index == 4 {
        return ptr[u8]("last_exc");
    }
    if index == 5 {
        return ptr[u8]("last_type");
    }
    if index == 6 {
        return ptr[u8]("last_value");
    }
    if index == 7 {
        return ptr[u8]("last_traceback");
    }
    if index == 8 {
        return ptr[u8]("__interactivehook__");
    }
    return ptr[u8]("meta_path");
}

impl sys_file_name(index: int) -> ptr[u8] {
    if index == 0 {
        return ptr[u8]("stdin");
    }
    if index == 1 {
        return ptr[u8]("stdout");
    }
    return ptr[u8]("stderr");
}

impl sys_file_orig_name(index: int) -> ptr[u8] {
    if index == 0 {
        return ptr[u8]("__stdin__");
    }
    if index == 1 {
        return ptr[u8]("__stdout__");
    }
    return ptr[u8]("__stderr__");
}

impl finalize_modules_delete_special(tstate: ptr[PyThreadState], verbose: i32) {
    interp = tstate_interp(tstate);
    if verbose != 0 {
        PySys_WriteStderr(ptr[u8]("# clear builtins._\n"));
    }
    if PyDict_SetItemString(interp_builtins(interp), ptr[u8]("_"), Py_None) < 0 {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while setting builtin variable _")
        );
    }

    for i in range(10) {
        name = sys_delete_name(i);
        if _PySys_ClearAttrString(interp, name, verbose) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing sys.%s"), name
            );
        }
    }
    for i in range(3) {
        name = sys_file_name(i);
        orig_name = sys_file_orig_name(i);
        if verbose != 0 {
            PySys_WriteStderr(ptr[u8]("# restore sys.%s\n"), name);
        }
        value = NULL;
        if PyDict_GetItemStringRef(interp_sysdict(interp), orig_name, &mut value) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while restoring sys.%s"), name
            );
        }
        if not value {
            value = object_new_ref(Py_None);
        }
        if PyDict_SetItemString(interp_sysdict(interp), name, value) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while restoring sys.%s"), name
            );
        }
        object_decref(value);
    }
}

impl store_module_weakref(
    weaklist: ptr[PyObject], name: ptr[PyObject], mod: ptr[PyObject]
) {
    if weaklist {
        wr = PyWeakref_NewRef(mod, NULL);
        if wr {
            tup = PyTuple_Pack(2, name, wr);
            if not tup or PyList_Append(weaklist, tup) < 0 {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while removing modules")
                );
            }
            object_xdecref(tup);
            object_decref(wr);
        } else {
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored while removing modules"));
        }
    }
}

impl clear_module(
    modules: ptr[PyObject],
    weaklist: ptr[PyObject],
    name: ptr[PyObject],
    mod: ptr[PyObject],
    verbose: i32
) {
    if module_check(mod) {
        if verbose != 0 and unicode_check(name) {
            PySys_FormatStderr(ptr[u8]("# cleanup[2] removing %U\n"), name);
        }
        store_module_weakref(weaklist, name, mod);
        if PyObject_SetItem(modules, name, Py_None) < 0 {
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored while removing modules"));
        }
    }
}

impl finalize_remove_modules(modules: ptr[PyObject], verbose: i32) -> ptr[PyObject] {
    weaklist = PyList_New(0);
    if not weaklist {
        PyErr_FormatUnraisable(ptr[u8]("Exception ignored while removing modules"));
    }

    if dict_check_exact(modules) {
        pos: i64 = 0;
        key = NULL;
        value = NULL;
        while PyDict_Next(modules, &mut pos, &mut key, &mut value) != 0 {
            clear_module(modules, weaklist, key, value, verbose);
        }
    } else {
        iterator = PyObject_GetIter(modules);
        if not iterator {
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored while removing modules"));
        } else {
            key = PyIter_Next(iterator);
            while key {
                value = PyObject_GetItem(modules, key);
                if not value {
                    PyErr_FormatUnraisable(
                        ptr[u8]("Exception ignored while removing modules")
                    );
                    object_decref(key);
                    key = PyIter_Next(iterator);
                    continue;
                }
                clear_module(modules, weaklist, key, value, verbose);
                object_decref(value);
                object_decref(key);
                key = PyIter_Next(iterator);
            }
            if PyErr_Occurred() {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while removing modules")
                );
            }
            object_decref(iterator);
        }
    }

    return weaklist;
}

impl finalize_clear_modules_dict(modules: ptr[PyObject]) {
    if dict_check_exact(modules) {
        PyDict_Clear(modules);
    } else {
        if not PyObject_CallMethodObjArgs(modules, py_id(_Py_ID_clear), NULL) {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while clearing sys.modules")
            );
        }
    }
}

impl finalize_restore_builtins(tstate: ptr[PyThreadState]) {
    interp = tstate_interp(tstate);
    builtins = interp_builtins(interp);
    dct = PyDict_Copy(builtins);
    if not dct {
        PyErr_FormatUnraisable(ptr[u8]("Exception ignored while restoring builtins"));
    }
    PyDict_Clear(builtins);
    builtins_copy = ptr[ptr[PyObject]](interp + PyInterpreterState_BUILTINS_COPY).view(
        1
    )[0];
    if PyDict_Update(builtins, builtins_copy) != 0 {
        PyErr_FormatUnraisable(ptr[u8]("Exception ignored while restoring builtins"));
    }
    object_xdecref(dct);
}

impl finalize_modules_clear_weaklist(
    interp: ptr[u8], weaklist: ptr[PyObject], verbose: i32
) {
    items = ptr[PyListObject](weaklist).view(1)[0].ob_item;
    i = object_size(weaklist) - 1;
    while i >= 0 {
        tup = (items + i).view(1)[0];
        i -= 1;
        name = tuple_get_item(tup, 0);
        mod = weakref_get_ref(tuple_get_item(tup, 1));
        if not mod {
            continue;
        }
        dct = module_get_dict(mod);
        if dct == interp_builtins(interp) or dct == interp_sysdict(interp) {
            object_decref(mod);
            continue;
        }
        if verbose != 0 and unicode_check(name) {
            PySys_FormatStderr(ptr[u8]("# cleanup[3] wiping %U\n"), name);
        }
        _PyModule_Clear(mod);
        object_decref(mod);
    }
}

impl finalize_clear_sys_builtins_dict(interp: ptr[u8], verbose: i32) {
    if verbose != 0 {
        PySys_FormatStderr(ptr[u8]("# cleanup[3] wiping sys\n"));
    }
    _PyModule_ClearDict(interp_sysdict(interp));

    if verbose != 0 {
        PySys_FormatStderr(ptr[u8]("# cleanup[3] wiping builtins\n"));
    }
    _PyModule_ClearDict(interp_builtins(interp));
}

impl finalize_modules(tstate: ptr[PyThreadState]) {
    interp = tstate_interp(tstate);

    (interp + PyInterpreterState_JIT).view(1)[0] = u8(0);

    if PyDict_Unwatch(0, interp_builtins(interp)) < 0 {
        PyErr_Clear();
    }
    modules = _PyImport_GetModules(interp);
    if not modules {
        return;
    }
    verbose = config_int(_PyInterpreterState_GetConfig(interp), PyConfig_VERBOSE);

    finalize_modules_delete_special(tstate, verbose);

    weaklist = finalize_remove_modules(modules, verbose);

    finalize_clear_modules_dict(modules);

    finalize_restore_builtins(tstate);

    _PyGC_CollectNoFail(tstate);

    _PyGC_DumpShutdownStats(interp);

    if weaklist {
        finalize_modules_clear_weaklist(interp, weaklist, verbose);
        object_decref(weaklist);
    }

    finalize_clear_sys_builtins_dict(interp, verbose);

    _PyImport_ClearModulesByIndex(interp);

    _PyImport_ClearModules(interp);

    _PyGC_CollectNoFail(tstate);
}

impl file_is_closed(fobj: ptr[PyObject]) -> i32 {
    tmp = PyObject_GetAttrString(fobj, ptr[u8]("closed"));
    if not tmp {
        PyErr_Clear();
        return 0;
    }
    r = PyObject_IsTrue(tmp);
    object_decref(tmp);
    if r < 0 {
        PyErr_Clear();
    }
    if r > 0 {
        return 1;
    }
    return 0;
}

impl flush_std_files -> i32 {
    status: i32 = 0;

    file = NULL;
    if _PySys_GetOptionalAttr(py_id(_Py_ID_stdout), &mut file) < 0 {
        status = -1;
    } elif file and file != Py_None and file_is_closed(file) == 0 {
        if _PyFile_Flush(file) < 0 {
            status = -1;
        }
    }
    if status < 0 {
        PyErr_FormatUnraisable(ptr[u8]("Exception ignored while flushing sys.stdout"));
    }
    object_xdecref(file);

    file = NULL;
    if _PySys_GetOptionalAttr(py_id(_Py_ID_stderr), &mut file) < 0 {
        PyErr_Clear();
        status = -1;
    } elif file and file != Py_None and file_is_closed(file) == 0 {
        if _PyFile_Flush(file) < 0 {
            PyErr_Clear();
            status = -1;
        }
    }
    object_xdecref(file);

    return status;
}

impl finalize_interp_types(interp: ptr[u8]) {
    _PyTypes_FiniExtTypes(interp);
    _PyUnicode_FiniTypes(interp);
    _PySys_FiniTypes(interp);
    _PyXI_FiniTypes(interp);
    _PyExc_Fini(interp);
    _PyFloat_FiniType(interp);
    _PyLong_FiniTypes(interp);
    _PyThread_FiniType(interp);
    _PyErr_FiniTypes(interp);
    _PyTypes_FiniTypes(interp);

    _PyTypes_Fini(interp);

    _PyCode_Fini(interp);

    _PyUnicode_ClearInterned(interp);

    _PyUnicode_Fini(interp);

    freelists = tstate_interp(current_tstate()) + PyInterpreterState_FREELISTS;
    _PyObject_ClearFreeLists(freelists, 1);
}

impl finalize_interp_clear(tstate: ptr[PyThreadState]) {
    interp = tstate_interp(tstate);
    is_main = is_main_interp(interp);

    _PyXI_Fini(interp);
    _PyExc_ClearExceptionGroupType(interp);
    _Py_clear_generic_types(interp);

    _PyInterpreterState_Clear(tstate);

    if is_main {
        _PySys_ClearAuditHooks(tstate);
    }

    if is_main {
        _Py_HashRandomization_Fini();
        _PyArg_Fini();
        _Py_ClearFileSystemEncoding();
        _PyPerfTrampoline_Fini();
    }

    finalize_interp_types(tstate_interp(tstate));

    _PyDtoa_Fini(tstate_interp(tstate));

    _PyMem_FiniDelayed(tstate_interp(tstate));

    _PyThreadState_ClearMimallocHeaps(tstate);
}

impl finalize_interp_delete(interp: ptr[u8]) {
    _PyGILState_Fini(interp);

    PyInterpreterState_Delete(interp);
}

impl resolve_final_tstate(runtime: ptr[u8]) -> ptr[PyThreadState] {
    main_tstate = ptr[ptr[PyThreadState]](runtime + _PyRuntimeState_MAIN_TSTATE).view(1)[
        0
    ];
    main_interp = ptr[u8](_PyInterpreterState_Main());

    tstate = current_tstate();
    if _Py_IsMainThread() != 0 {
        if tstate != main_tstate {
            PyThreadState_Swap(main_tstate);
        }
    } else {
        if not is_main_interp(tstate_interp(tstate)) {
            main_tstate = _PyThreadState_New(main_interp, _PyThreadState_WHENCE_FINI);
            if main_tstate {
                _PyThreadState_Bind(main_tstate);
                PyThreadState_Swap(main_tstate);
            } else {
                main_tstate = tstate;
            }
        }
    }

    return main_tstate;
}

impl py_finalize(runtime: ptr[u8]) -> i32 {
    status: i32 = 0;

    if ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] == 0 {
        return status;
    }

    tstate = resolve_final_tstate(runtime);
    interp = tstate_interp(tstate);

    ptr[i32](interp + PyInterpreterState_FINALIZING_FLAG).view(1)[0] = 1;

    wait_for_thread_shutdown(tstate);

    _Py_FinishPendingCalls(tstate);

    _PyAtExit_Call(tstate_interp(tstate));

    finalize_subinterpreters();

    malloc_stats = config_int(
        interp_config(tstate_interp(tstate)), PyConfig_MALLOC_STATS
    );

    _PyEval_StopTheWorldAll(ptr[_PyRuntimeState](runtime));

    interp_set_finalizing(tstate_interp(tstate), tstate);
    runtime_set_finalizing(runtime, tstate);
    ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] = 0;
    ptr[i32](runtime + _PyRuntimeState_CORE_INITIALIZED).view(1)[0] = 0;

    lst = _PyThreadState_RemoveExcept(tstate);
    p = lst;
    while p {
        _PyThreadState_SetShuttingDown(p);
        p = tstate_next(p);
    }
    _PyEval_StartTheWorldAll(ptr[_PyRuntimeState](runtime));

    _PyThreadState_DeleteList(lst, 0);

    if flush_std_files() < 0 {
        status = -1;
    }

    _PySignal_Fini();

    PyGC_Collect();

    _PyImport_FiniExternal(tstate_interp(tstate));
    finalize_modules(tstate);

    _PyEval_Fini();

    if flush_std_files() < 0 {
        status = -1;
    }

    _PyTraceMalloc_Fini();

    _PyImport_FiniCore(tstate_interp(tstate));
    _PyImport_Fini();

    _PyFaulthandler_Fini();

    _PyHash_Fini();

    finalize_interp_clear(tstate);

    if malloc_stats != 0 {
        _PyObject_DebugMallocStats(jacpy_stdio_stream(2));
    }

    finalize_interp_delete(tstate_interp(tstate));

    _Py_FinalizeAllocatedBlocks(runtime);

    call_ll_exitfuncs(runtime);

    runtime_finalize();
    return status;
}

impl new_interpreter(
    tstate_p: ptr[ptr[PyThreadState]], config: ptr[u8], whence: i64
) -> PyStatus {
    status = runtime_initialize();
    if status_exception(status) {
        return status;
    }
    runtime = runtime_ptr();

    if ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] == 0 {
        return status_err(
            ptr[u8]("new_interpreter"), ptr[u8]("Py_Initialize must be called first")
        );
    }

    ptr[i32](runtime + _PyRuntimeState_GILSTATE_CHECK_ENABLED).view(1)[0] = 0;

    save_tstate = current_tstate();
    tstate = ptr[PyThreadState]();
    interp = ptr[u8]();
    status = _PyInterpreterState_New(save_tstate, &mut interp);
    if not interp {
        return new_interpreter_error(tstate_p, status, save_tstate, tstate, interp);
    }
    _PyInterpreterState_SetWhence(interp, whence);
    ptr[i32](interp + PyInterpreterState_READY).view(1)[0] = 1;

    if save_tstate {
        _PyThreadState_Detach(save_tstate);
    }

    src_config = ptr[u8]();
    if save_tstate {
        src_config = _PyInterpreterState_GetConfig(tstate_interp(save_tstate));
    } else {
        src_config = _PyInterpreterState_GetConfig(ptr[u8](_PyInterpreterState_Main()));
    }

    status = _PyConfig_Copy(interp_config(interp), src_config);
    if status_exception(status) {
        return new_interpreter_error(tstate_p, status, save_tstate, tstate, interp);
    }

    status = init_interp_settings(interp, config);
    if status_exception(status) {
        return new_interpreter_error(tstate_p, status, save_tstate, tstate, interp);
    }

    status = _PyObject_InitState(interp);
    if status_exception(status) {
        return status;
    }

    if _PyMem_init_obmalloc(interp) < 0 {
        return new_interpreter_error(
            tstate_p,
            status_no_memory(ptr[u8]("new_interpreter")),
            save_tstate,
            tstate,
            interp
        );
    }

    tstate = _PyThreadState_New(interp, _PyThreadState_WHENCE_INIT);
    if not tstate {
        return new_interpreter_error(
            tstate_p,
            status_no_memory(ptr[u8]("new_interpreter")),
            save_tstate,
            tstate,
            interp
        );
    }

    _PyThreadState_Bind(tstate);
    init_interp_create_gil(tstate, config_int(config, PyInterpreterConfig_GIL_FIELD));

    status = pycore_interp_init(tstate);
    if status_exception(status) {
        return new_interpreter_error(tstate_p, status, save_tstate, tstate, interp);
    }

    status = init_interp_main(tstate);
    if status_exception(status) {
        return new_interpreter_error(tstate_p, status, save_tstate, tstate, interp);
    }

    tstate_p.view(1)[0] = tstate;
    return status_ok();
}

impl new_interpreter_error(
    tstate_p: ptr[ptr[PyThreadState]],
    status: PyStatus,
    save_tstate: ptr[PyThreadState],
    tstate: ptr[PyThreadState],
    interp: ptr[u8]
) -> PyStatus {
    tstate_p.view(1)[0] = ptr[PyThreadState]();
    if tstate {
        end_interpreter(tstate);
    } elif interp {
        PyInterpreterState_Delete(interp);
    }
    if save_tstate {
        _PyThreadState_Attach(save_tstate);
    }
    return status;
}

impl end_interpreter(tstate: ptr[PyThreadState]) {
    interp = tstate_interp(tstate);

    if tstate != current_tstate() {
        fatal_error(
            stderr_fd(),
            1,
            ptr[u8]("Py_EndInterpreter"),
            ptr[u8]("thread is not current"),
            -1
        );
    }
    if ptr[ptr](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0] {
        fatal_error(
            stderr_fd(),
            1,
            ptr[u8]("Py_EndInterpreter"),
            ptr[u8]("thread still has a frame"),
            -1
        );
    }
    ptr[i32](interp + PyInterpreterState_FINALIZING_FLAG).view(1)[0] = 1;

    wait_for_thread_shutdown(tstate);

    _Py_FinishPendingCalls(tstate);

    _PyAtExit_Call(tstate_interp(tstate));
    runtime = interp_runtime(interp);
    _PyEval_StopTheWorldAll(ptr[_PyRuntimeState](runtime));

    interp_set_finalizing(interp, tstate);

    lst = _PyThreadState_RemoveExcept(tstate);
    p = lst;
    while p {
        _PyThreadState_SetShuttingDown(p);
        p = tstate_next(p);
    }

    _PyEval_StartTheWorldAll(ptr[_PyRuntimeState](runtime));
    _PyThreadState_DeleteList(lst, 0);

    _PyImport_FiniExternal(tstate_interp(tstate));
    finalize_modules(tstate);
    _PyImport_FiniCore(tstate_interp(tstate));

    finalize_interp_clear(tstate);
    finalize_interp_delete(tstate_interp(tstate));
}

impl first_subinterpreter(runtime: ptr[u8], main_interp: ptr[u8]) -> ptr[u8] {
    jacpy_runtime_head_lock();
    interp = ptr[ptr[u8]](runtime + _PyRuntimeState_INTERPRETERS_HEAD).view(1)[0];
    if interp == main_interp {
        interp = ptr[ptr[u8]](interp + PyInterpreterState_NEXT).view(1)[0];
    }
    jacpy_runtime_head_unlock();
    return interp;
}

impl finalize_subinterpreters {
    final_tstate = current_tstate();
    main_interp = ptr[u8](_PyInterpreterState_Main());
    runtime = interp_runtime(main_interp);

    interp = first_subinterpreter(runtime, main_interp);

    if not interp {
        return;
    }

    PyErr_WarnEx(
        PyExc_RuntimeWarning,
        ptr[u8]("remaining subinterpreters; close them with Interpreter.close()"),
        0
    );

    _PyThreadState_Detach(final_tstate);

    while interp {
        tstate = _PyThreadState_NewBound(interp, _PyThreadState_WHENCE_FINI);
        if not tstate {
            fatal_error(
                stderr_fd(),
                1,
                ptr[u8]("finalize_subinterpreters"),
                ptr[u8]("thread state allocation failed"),
                -1
            );
        }

        _PyThreadState_Attach(tstate);

        end_interpreter(tstate);

        interp = first_subinterpreter(runtime, main_interp);
    }

    _PyThreadState_Attach(final_tstate);
}

impl add_main_module(interp: ptr[u8]) -> PyStatus {
    m = PyImport_AddModuleObject(py_id(_Py_ID___main__));
    if not m {
        return status_err(
            ptr[u8]("add_main_module"), ptr[u8]("can't create __main__ module")
        );
    }

    d = PyModule_GetDict(m);

    has_builtins = PyDict_ContainsString(d, ptr[u8]("__builtins__"));
    if has_builtins < 0 {
        return status_err(
            ptr[u8]("add_main_module"), ptr[u8]("Failed to test __main__.__builtins__")
        );
    }
    if has_builtins == 0 {
        bimod = PyImport_ImportModule(ptr[u8]("builtins"));
        if not bimod {
            return status_err(
                ptr[u8]("add_main_module"),
                ptr[u8]("Failed to retrieve builtins module")
            );
        }
        if PyDict_SetItemString(d, ptr[u8]("__builtins__"), bimod) < 0 {
            return status_err(
                ptr[u8]("add_main_module"),
                ptr[u8]("Failed to initialize __main__.__builtins__")
            );
        }
        object_decref(bimod);
    }

    loader = NULL;
    if PyDict_GetItemStringRef(d, ptr[u8]("__loader__"), &mut loader) < 0 {
        return status_err(
            ptr[u8]("add_main_module"), ptr[u8]("Failed to test __main__.__loader__")
        );
    }
    has_loader = True;
    if not loader or loader == Py_None {
        has_loader = False;
    }
    object_xdecref(loader);
    if not has_loader {
        builtin_loader = _PyImport_GetImportlibLoader(
            interp, ptr[u8]("BuiltinImporter")
        );
        if not builtin_loader {
            return status_err(
                ptr[u8]("add_main_module"),
                ptr[u8]("Failed to retrieve BuiltinImporter")
            );
        }
        if PyDict_SetItemString(d, ptr[u8]("__loader__"), builtin_loader) < 0 {
            return status_err(
                ptr[u8]("add_main_module"),
                ptr[u8]("Failed to initialize __main__.__loader__")
            );
        }
        object_decref(builtin_loader);
    }
    return status_ok();
}

impl init_import_site -> PyStatus {
    m = PyImport_ImportModule(ptr[u8]("site"));
    if not m {
        return status_err(
            ptr[u8]("init_import_site"), ptr[u8]("Failed to import the site module")
        );
    }
    object_decref(m);
    return status_ok();
}

impl create_stdio_error(
    fd: i32,
    buf: ptr[PyObject],
    stream: ptr[PyObject],
    text: ptr[PyObject],
    raw: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(buf);
    object_xdecref(stream);
    object_xdecref(text);
    object_xdecref(raw);

    if PyErr_ExceptionMatches(PyExc_OSError) != 0 and _Py_IsValidFD(fd) == 0 {
        PyErr_Clear();
        return object_new_ref(Py_None);
    }
    return NULL;
}

impl create_stdio(
    config: ptr[u8],
    io: ptr[PyObject],
    fd: i32,
    write_mode: i32,
    name: ptr[u8],
    encoding: ptr[i32],
    errors: ptr[i32]
) -> ptr[PyObject] {
    buffered_stdio = config_int(config, PyConfig_BUFFERED_STDIO);

    if _Py_IsValidFD(fd) == 0 {
        return object_new_ref(Py_None);
    }

    buffering: i32 = -1;
    if buffered_stdio == 0 and write_mode != 0 {
        buffering = 0;
    }
    mode = ptr[u8]("rb");
    if write_mode != 0 {
        mode = ptr[u8]("wb");
    }
    buf = _PyObject_CallMethod(
        io,
        py_id(_Py_ID_open),
        ptr[u8]("isiOOOO"),
        fd,
        mode,
        buffering,
        Py_None,
        Py_None,
        Py_None,
        ptr[PyObject](addressof(_Py_FalseStruct))
    );
    if not buf {
        return create_stdio_error(fd, NULL, NULL, NULL, NULL);
    }

    raw = NULL;
    if buffering != 0 {
        raw = PyObject_GetAttr(buf, py_id(_Py_ID_raw));
        if not raw {
            return create_stdio_error(fd, buf, NULL, NULL, NULL);
        }
    } else {
        raw = object_new_ref(buf);
    }

    text = PyUnicode_FromString(name);
    if not text or PyObject_SetAttr(raw, py_id(_Py_ID_name), text) < 0 {
        return create_stdio_error(fd, buf, NULL, text, raw);
    }
    res = PyObject_CallMethodObjArgs(raw, py_id(_Py_ID_isatty), NULL);
    if not res {
        return create_stdio_error(fd, buf, NULL, text, raw);
    }
    is_tty = PyObject_IsTrue(res);
    object_decref(res);
    if is_tty == -1 {
        return create_stdio_error(fd, buf, NULL, text, raw);
    }
    write_through = ptr[PyObject](addressof(_Py_FalseStruct));
    if buffered_stdio == 0 {
        write_through = ptr[PyObject](addressof(_Py_TrueStruct));
    }
    line_buffering = ptr[PyObject](addressof(_Py_FalseStruct));
    if buffered_stdio != 0 and (is_tty != 0 or fd == stderr_fd()) {
        line_buffering = ptr[PyObject](addressof(_Py_TrueStruct));
    }

    object_decref(raw);
    object_decref(text);

    newline = ptr[u8]("\n");

    encoding_str = PyUnicode_FromWideChar(encoding, -1);
    if not encoding_str {
        object_decref(buf);
        return create_stdio_error(fd, NULL, NULL, NULL, NULL);
    }

    errors_str = PyUnicode_FromWideChar(errors, -1);
    if not errors_str {
        object_decref(buf);
        object_decref(encoding_str);
        return create_stdio_error(fd, NULL, NULL, NULL, NULL);
    }

    stream = _PyObject_CallMethod(
        io,
        py_id(_Py_ID_TextIOWrapper),
        ptr[u8]("OOOsOO"),
        buf,
        encoding_str,
        errors_str,
        newline,
        line_buffering,
        write_through
    );
    object_decref(buf);
    object_decref(encoding_str);
    object_decref(errors_str);
    if not stream {
        return create_stdio_error(fd, NULL, NULL, NULL, NULL);
    }

    stream_mode = ptr[u8]("r");
    if write_mode != 0 {
        stream_mode = ptr[u8]("w");
    }
    mode_text = PyUnicode_FromString(stream_mode);
    if not mode_text or PyObject_SetAttr(stream, py_id(_Py_ID_mode), mode_text) < 0 {
        return create_stdio_error(fd, NULL, stream, mode_text, NULL);
    }
    object_decref(mode_text);
    return stream;
}

impl init_set_builtins_open -> PyStatus {
    bimod = PyImport_ImportModule(ptr[u8]("builtins"));
    if not bimod {
        return status_err(
            ptr[u8]("init_set_builtins_open"), ptr[u8]("can't initialize io.open")
        );
    }

    wrapper = PyImport_ImportModuleAttrString(ptr[u8]("_io"), ptr[u8]("open"));
    if not wrapper {
        object_decref(bimod);
        return status_err(
            ptr[u8]("init_set_builtins_open"), ptr[u8]("can't initialize io.open")
        );
    }

    if PyObject_SetAttrString(bimod, ptr[u8]("open"), wrapper) == -1 {
        object_decref(wrapper);
        object_decref(bimod);
        return status_err(
            ptr[u8]("init_set_builtins_open"), ptr[u8]("can't initialize io.open")
        );
    }
    object_decref(wrapper);
    object_decref(bimod);
    return status_ok();
}

impl init_sys_streams_error(iomod: ptr[PyObject]) -> PyStatus {
    object_xdecref(iomod);
    return status_err(
        ptr[u8]("init_sys_streams"), ptr[u8]("can't initialize sys standard streams")
    );
}

impl init_sys_streams(tstate: ptr[PyThreadState]) -> PyStatus {
    config = _PyInterpreterState_GetConfig(tstate_interp(tstate));
    encoding = ptr[ptr[i32]](config + PyConfig_STDIO_ENCODING).view(1)[0];
    errors = ptr[ptr[i32]](config + PyConfig_STDIO_ERRORS).view(1)[0];

    sb = _Py_stat_struct();
    if _Py_fstat_noraise(fileno(jacpy_stdio_stream(0)), &mut sb) == 0
        and (u64(sb.st_mode) & S_IFMT_BITS) == S_IFDIR_BITS {
        return status_err(
            ptr[u8]("init_sys_streams"),
            ptr[u8]("<stdin> is a directory, cannot continue")
        );
    }

    iomod = PyImport_ImportModule(ptr[u8]("_io"));
    if not iomod {
        return init_sys_streams_error(iomod);
    }

    fd = fileno(jacpy_stdio_stream(0));
    std = create_stdio(config, iomod, fd, 0, ptr[u8]("<stdin>"), encoding, errors);
    if not std {
        return init_sys_streams_error(iomod);
    }
    PySys_SetObject(ptr[u8]("__stdin__"), std);
    _PySys_SetAttr(py_id(_Py_ID_stdin), std);
    object_decref(std);

    fd = fileno(jacpy_stdio_stream(1));
    std = create_stdio(config, iomod, fd, 1, ptr[u8]("<stdout>"), encoding, errors);
    if not std {
        return init_sys_streams_error(iomod);
    }
    PySys_SetObject(ptr[u8]("__stdout__"), std);
    _PySys_SetAttr(py_id(_Py_ID_stdout), std);
    object_decref(std);

    fd = fileno(jacpy_stdio_stream(2));
    std = create_stdio(
        config,
        iomod,
        fd,
        1,
        ptr[u8]("<stderr>"),
        encoding,
        ptr[i32](addressof(BACKSLASHREPLACE_W))
    );
    if not std {
        return init_sys_streams_error(iomod);
    }

    encoding_attr = PyObject_GetAttrString(std, ptr[u8]("encoding"));
    if encoding_attr {
        std_encoding = PyUnicode_AsUTF8(encoding_attr);
        if std_encoding {
            codec_info = _PyCodec_Lookup(std_encoding);
            object_xdecref(codec_info);
        }
        object_decref(encoding_attr);
    }

    _PyErr_Clear(tstate);

    if PySys_SetObject(ptr[u8]("__stderr__"), std) < 0 {
        object_decref(std);
        return init_sys_streams_error(iomod);
    }
    if _PySys_SetAttr(py_id(_Py_ID_stderr), std) < 0 {
        object_decref(std);
        return init_sys_streams_error(iomod);
    }
    object_decref(std);

    object_xdecref(iomod);
    return status_ok();
}

impl fatal_error_dump_tracebacks(fd: i32, interp: ptr[u8], tstate: ptr[PyThreadState]) {
    puts_fd(fd, ptr[u8]("\n"));

    _Py_DumpTracebackThreads(fd, interp, tstate);
}

impl fatal_error_print_exc(tstate: ptr[PyThreadState]) -> i32 {
    exc = _PyErr_GetRaisedException(tstate);
    if not exc {
        return 0;
    }

    ferr = NULL;
    if _PySys_GetOptionalAttr(py_id(_Py_ID_stderr), &mut ferr) < 0 {
        _PyErr_Clear(tstate);
    }
    if not ferr or ferr == Py_None {
        object_xdecref(ferr);
        object_decref(exc);
        return 0;
    }

    PyErr_DisplayException(exc);

    tb = PyException_GetTraceback(exc);
    has_tb: i32 = 0;
    if tb and tb != Py_None {
        has_tb = 1;
    }
    object_xdecref(tb);
    object_decref(exc);

    if _PyFile_Flush(ferr) < 0 {
        _PyErr_Clear(tstate);
    }
    object_decref(ferr);

    return has_tb;
}

impl fatal_error_dump_runtime(fd: i32, runtime: ptr[u8]) {
    puts_fd(fd, ptr[u8]("Python runtime state: "));
    finalizing = runtime_get_finalizing(runtime);
    if finalizing {
        puts_fd(fd, ptr[u8]("finalizing (tstate=0x"));
        _Py_DumpHexadecimal(fd, u64.wrap(int(finalizing)), 16);
        puts_fd(fd, ptr[u8](")"));
    } elif ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] != 0 {
        puts_fd(fd, ptr[u8]("initialized"));
    } elif ptr[i32](runtime + _PyRuntimeState_CORE_INITIALIZED).view(1)[0] != 0 {
        puts_fd(fd, ptr[u8]("core initialized"));
    } elif ptr[i32](runtime + _PyRuntimeState_PREINITIALIZED).view(1)[0] != 0 {
        puts_fd(fd, ptr[u8]("preinitialized"));
    } elif ptr[i32](runtime + _PyRuntimeState_PREINITIALIZING).view(1)[0] != 0 {
        puts_fd(fd, ptr[u8]("preinitializing"));
    } else {
        puts_fd(fd, ptr[u8]("unknown"));
    }
    puts_fd(fd, ptr[u8]("\n"));
}

impl fatal_error_exit(status: i32) {
    if status < 0 {
        abort();
    } else {
        `exit(status);
    }
}

impl dump_extension_modules(fd: i32, interp: ptr[u8]) {
    if not interp {
        return;
    }
    modules = _PyImport_GetModules(interp);
    if not modules or not dict_check(modules) {
        return;
    }

    pos: i64 = 0;
    key = NULL;
    value = NULL;
    hash_unused: i64 = 0;

    stdlib_module_names = NULL;
    sysdict = interp_sysdict(interp);
    if sysdict {
        pos = 0;
        while _PyDict_Next(sysdict, &mut pos, &mut key, &mut value, &mut hash_unused)
            != 0 {
            if unicode_check(key)
                and PyUnicode_CompareWithASCIIString(
                    key, ptr[u8]("stdlib_module_names")
                )
                    == 0 {
                stdlib_module_names = value;
                break;
            }
        }
    }

    if stdlib_module_names and not frozenset_check(stdlib_module_names) {
        stdlib_module_names = NULL;
    }

    header = True;
    count: i64 = 0;
    pos = 0;
    while _PyDict_Next(modules, &mut pos, &mut key, &mut value, &mut hash_unused)
        != 0 {
        if not unicode_check(key) {
            continue;
        }
        if _PyModule_IsExtension(value) == 0 {
            continue;
        }

        if stdlib_module_names {
            is_stdlib_ext = False;

            i: i64 = 0;
            item = NULL;
            hash: i64 = 0;

            while _PySet_NextEntry(stdlib_module_names, &mut i, &mut item, &mut hash)
                != 0 {
                if unicode_check(item) and PyUnicode_Compare(key, item) == 0 {
                    is_stdlib_ext = True;
                    break;
                }
            }
            if is_stdlib_ext {
                continue;
            }
        }

        if header {
            puts_fd(fd, ptr[u8]("\nExtension modules: "));
            header = False;
        } else {
            puts_fd(fd, ptr[u8](", "));
        }

        _Py_DumpASCII(fd, key);
        count += 1;
    }

    if count != 0 {
        puts_fd(fd, ptr[u8](" (total: "));
        _Py_DumpDecimal(fd, u64(count));
        puts_fd(fd, ptr[u8](")"));
        puts_fd(fd, ptr[u8]("\n"));
    }
}

impl fatal_error(fd: i32, header: i32, prefix: ptr[u8], msg: ptr[u8], status: i32) {
    reentrant = addressof(fatal_error_reentrant);
    if reentrant.view(1)[0] != 0 {
        fatal_error_exit(status);
    }
    reentrant.view(1)[0] = 1;

    if header != 0 {
        puts_fd(fd, ptr[u8]("Fatal Python error: "));
        if prefix {
            puts_fd(fd, prefix);
            puts_fd(fd, ptr[u8](": "));
        }
        if msg {
            puts_fd(fd, msg);
        } else {
            puts_fd(fd, ptr[u8]("<message not set>"));
        }
        puts_fd(fd, ptr[u8]("\n"));
    }

    fatal_error_dump_runtime(fd, runtime_ptr());

    tstate = current_tstate();
    interp = ptr[u8]();
    tss_tstate = PyGILState_GetThisThreadState();
    if tstate {
        interp = tstate_interp(tstate);
    } elif tss_tstate {
        interp = tstate_interp(tss_tstate);
    }
    has_tstate_and_gil = False;
    if tss_tstate and tss_tstate == tstate {
        has_tstate_and_gil = True;
    }

    if has_tstate_and_gil {
        if fatal_error_print_exc(tss_tstate) == 0 {
            fatal_error_dump_tracebacks(fd, interp, tss_tstate);
        }
    } else {
        fatal_error_dump_tracebacks(fd, interp, tss_tstate);
    }

    dump_extension_modules(fd, interp);

    _PyFaulthandler_Fini();

    if has_tstate_and_gil {
        flush_std_files();
    }

    fatal_error_exit(status);
}

impl fatal_format_begin(func: ptr[u8]) -> ptr {
    reentrant = addressof(fatal_format_reentrant);
    if reentrant.view(1)[0] != 0 {
        fatal_error_exit(-1);
    }
    reentrant.view(1)[0] = 1;

    stream = jacpy_stdio_stream(2);
    fd = fileno(stream);
    puts_fd(fd, ptr[u8]("Fatal Python error: "));
    if func {
        puts_fd(fd, func);
        puts_fd(fd, ptr[u8](": "));
    }
    return stream;
}

impl fatal_format_end(stream: ptr) {
    fputs(ptr[u8]("\n"), stream);
    fflush(stream);

    fatal_error(fileno(stream), 0, ptr[u8](), ptr[u8](), -1);
}

impl exit_status_exception(status: PyStatus) {
    if status._type == _PyStatus_TYPE_EXIT {
        `exit(status.exitcode);
    } elif status._type == _PyStatus_TYPE_ERROR {
        fatal_error(stderr_fd(), 1, status.func, status.err_msg, 1);
    } else {
        fatal_error(
            stderr_fd(),
            1,
            ptr[u8](),
            ptr[u8]("Py_ExitStatusException() must not be called on success"),
            -1
        );
    }
}

impl wait_for_thread_shutdown(tstate: ptr[PyThreadState]) {
    threading = PyImport_GetModule(py_id(_Py_ID_threading));
    if not threading {
        if exception_raised(tstate) {
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored on threading shutdown"));
        }

        return;
    }
    result = PyObject_CallMethodObjArgs(threading, py_id(_Py_ID__shutdown), NULL);
    if not result {
        PyErr_FormatUnraisable(ptr[u8]("Exception ignored on threading shutdown"));
    } else {
        object_decref(result);
    }
    object_decref(threading);
}

impl call_ll_exitfuncs(runtime: ptr[u8]) {
    mutex = ptr[PyMutex](runtime + _PyRuntimeState_ATEXIT_MUTEX);
    ncallbacks = ptr[i32](runtime + _PyRuntimeState_ATEXIT_NCALLBACKS);
    callbacks = ptr[ptr](runtime + _PyRuntimeState_ATEXIT_CALLBACKS);
    call = ptr[ExitFuncCall](
        __thread_local_block("jac_interpreter_lifecycle_exit_call", 8)
    );

    PyMutex_Lock(mutex);
    while ncallbacks.view(1)[0] > 0 {
        index = ncallbacks.view(1)[0] - 1;
        ncallbacks.view(1)[0] = index;
        slot = callbacks + i64(index);
        exitfunc = slot.view(1)[0];
        slot.view(1)[0] = ptr();

        PyMutex_Unlock(mutex);
        call.view(1)[0].func = int(exitfunc);
        call.view(1)[0].func();
        PyMutex_Lock(mutex);
    }
    PyMutex_Unlock(mutex);

    fflush(jacpy_stdio_stream(1));
    fflush(jacpy_stdio_stream(2));
}
