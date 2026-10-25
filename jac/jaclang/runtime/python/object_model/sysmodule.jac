import from c {
    obj SysStack {
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
            w15: u64 = u64(0);
    }  obj SysAuditHookEntry {
        has next: ptr = ptr(),
            hookCFunction: Callable[[ptr[u8], ptr[PyObject], ptr], i32] = 0,
            userData: ptr = ptr();
    }  obj SysPreinitEntry {
        has value: ptr[i32] = ptr[i32](),
            next: ptr = ptr();
    }  obj SysWideStringList {
        has length: i64 = 0,
            items: ptr[ptr[i32]] = ptr[ptr[i32]]();
    }  obj SysHashFuncDef {
        has hash: ptr = ptr(),
            name: ptr[u8] = ptr[u8](),
            hash_bits: i32 = 0,
            seed_bits: i32 = 0;
    }  obj SysStatics {
        has preinit_warnoptions: ptr = ptr(),
            preinit_xoptions: ptr = ptr(),
            perf_map: ptr = ptr(),
            map_lock: ptr = ptr();
    }  def jacpy_stack_address(slots: &mut SysStack) -> int;  def jacpy_stdio_stream(
        stream: i32
    ) -> ptr;  def strlen(s: ptr[u8]) -> u64;  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  def strrchr(text: ptr[u8], character: i32) -> ptr[u8];  def wcschr(
        text: ptr[i32], character: i32
    ) -> ptr[i32];  def wcscmp(left: ptr[i32], right: ptr[i32]) -> i32;  def wcslen(
        text: ptr[i32]
    ) -> u64;  def access(path: ptr[u8], mode: i32) -> i32;  def getpid -> i32;  def open(
        path: ptr[u8], flags: i32, *args: any
    ) -> i32;  def close(fd: i32) -> i32;  def fdopen(fd: i32, mode: ptr[u8]) -> ptr;  def fopen(
        path: ptr[u8], mode: ptr[u8]
    ) -> ptr;  def fclose(stream: ptr) -> i32;  def fflush(stream: ptr) -> i32;  def fread(
        buffer: ptr, size: u64, count: u64, stream: ptr
    ) -> u64;  def fwrite(data: ptr, size: u64, count: u64, stream: ptr) -> u64;  def feof(
        stream: ptr
    ) -> i32;  def ferror(stream: ptr) -> i32;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  def fputc(character: i32, stream: ptr) -> i32;  def fileno(
        stream: ptr
    ) -> i32;  def fprintf(stream: ptr, format: ptr[u8], *args: any) -> i32;  def snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def Py_GETENV(name: ptr[u8]) -> ptr[u8];  def _Py_FatalErrorFunc(
        func: ptr[u8], message: ptr[u8]
    );  def Py_VaBuildValue(format: ptr[u8], va: ptr) -> ptr[PyObject];  def PyOS_vsnprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], va: ptr
    ) -> i32;  def PyUnicode_FromFormatV(
        format: ptr[u8], vargs: VaList
    ) -> ptr[PyObject];  def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyErr_Display(
        exc: ptr[PyObject], value: ptr[PyObject], tb: ptr[PyObject]
    );  def PyRun_AnyFileExFlags(
        fp: ptr, filename: ptr[u8], closeit: i32, flags: ptr[PyCompilerFlags]
    ) -> i32;  def PyWideStringList_Append(list_: ptr, item: ptr[i32]) -> PyStatus;  def Py_GetVersion -> ptr[
        u8
    ];  def Py_GetPlatform -> ptr[u8];  def Py_GetCopyright -> ptr[u8];  def _Py_gitidentifier -> ptr[
        u8
    ];  def _Py_gitversion -> ptr[u8];  def _PyConfig_CreateXOptionsDict(
        config: ptr[u8]
    ) -> ptr[PyObject];  def _PyWideStringList_AsList(
        list_: ptr[u8]
    ) -> ptr[PyObject];  def _Py_GetStdlibDir -> ptr[i32];  def _PyPathConfig_ComputeSysPath0(
        argv: ptr, path0: &mut ptr[PyObject]
    ) -> i32;  def _PyRuntime_Initialize -> PyStatus;  def _PyDumpExecutors(
        out: ptr
    ) -> i32;  def _PyImport_InitModules(interp: ptr[u8]) -> ptr[PyObject];  def _PyImport_FixupBuiltin(
        tstate: ptr[PyThreadState],
        mod: ptr[PyObject],
        name: ptr[u8],
        modules: ptr[PyObject]
    ) -> i32;  def _PyImport_GetBuiltinModuleNames -> ptr[PyObject];  def _PyImport_GetDLOpenFlags(
        interp: ptr[u8]
    ) -> i32;  def _PyImport_SetDLOpenFlags(interp: ptr[u8], new_val: i32);  def _PyThread_CurrentFrames -> ptr[
        PyObject
    ];  def _PyThread_CurrentExceptions -> ptr[PyObject];  def _PyInterpreterState_GetConfig(
        interp: ptr[u8]
    ) -> ptr[u8];  def _Py_GetConfig -> ptr[u8];  def Py_IsFinalizing -> i32;  def PyFile_NewStdPrinter(
        fd: i32
    ) -> ptr[PyObject];  def PyFile_WriteObject(
        v: ptr[PyObject], f: ptr[PyObject], flags: i32
    ) -> i32;  def PyFloat_GetInfo -> ptr[PyObject];  def PyLong_GetInfo -> ptr[
        PyObject
    ];  def PyThread_GetInfo -> ptr[PyObject];  def PyHash_GetFuncDef -> ptr;  def PyMapping_GetItemString(
        o: ptr[PyObject], key: ptr[u8]
    ) -> ptr[PyObject];  def PyFunction_GetModule(op: ptr[PyObject]) -> ptr[PyObject];  def PyUnstable_IsImmortal(
        op: ptr[PyObject]
    ) -> i32;  def PyThreadState_EnterTracing(tstate: ptr[PyThreadState]);  def PyThreadState_LeaveTracing(
        tstate: ptr[PyThreadState]
    );  def PyType_ClearCache -> u32;  def PyStructSequence_New(
        type_object: ptr[PyObject]
    ) -> ptr[PyObject];  def PyStructSequence_SetItem(
        op: ptr[PyObject], index: i64, value: ptr[PyObject]
    );  def PyStructSequence_GetItem(op: ptr[PyObject], index: i64) -> ptr[PyObject];  def _PyStructSequence_InitBuiltinWithFlags(
        interp: ptr, type: ptr[PyObject], desc: ptr[PyStructSequence_Desc], flags: u64
    ) -> i32;  def _PyStructSequence_FiniBuiltin(interp: ptr, type: ptr[PyObject]);  def _PyModule_CreateInitialized(
        module: ptr[PyModuleDef], module_api_version: i32
    ) -> ptr[PyObject];  def _PyNamespace_New(kwds: ptr[PyObject]) -> ptr[PyObject];  def _Py_CreateMonitoringObject -> ptr[
        PyObject
    ];  def _PyErr_Clear(tstate: ptr[PyThreadState]);  def _PyErr_ExceptionMatches(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    ) -> i32;  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format_: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  def _PyErr_SetString(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], message: ptr[u8]
    );  def _PyErr_GetRaisedException(tstate: ptr[PyThreadState]) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyErr_NoMemory(tstate: ptr) -> ptr[PyObject];  def _PyErr_GetTopmostException(
        tstate: ptr[PyThreadState]
    ) -> ptr[u8];  def _PyErr_StackItemToExcInfoTuple(
        err_info: ptr[u8]
    ) -> ptr[PyObject];  def _PyErr_WriteUnraisableDefaultHook(
        args: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_SetTrace(
        tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
    ) -> i32;  def _PyEval_SetTraceAllThreads(
        interp: ptr[u8], func: ptr, arg: ptr[PyObject]
    ) -> i32;  def _PyEval_SetProfile(
        tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
    ) -> i32;  def _PyEval_SetProfileAllThreads(
        interp: ptr[u8], func: ptr, arg: ptr[PyObject]
    ) -> i32;  def _PyEval_CallTracing(
        func: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_GetAsyncGenFinalizer -> ptr[PyObject];  def _PyEval_GetAsyncGenFirstiter -> ptr[
        PyObject
    ];  def _PyEval_SetAsyncGenFinalizer(finalizer: ptr[PyObject]) -> i32;  def _PyEval_SetAsyncGenFirstiter(
        firstiter: ptr[PyObject]
    ) -> i32;  def _PyEval_GetCoroutineOriginTrackingDepth -> i32;  def _PyEval_SetCoroutineOriginTrackingDepth(
        depth: i32
    ) -> i32;  def _PyEval_GetSwitchInterval -> u64;  def _PyEval_SetSwitchInterval(
        microseconds: u64
    );  def Py_GetRecursionLimit -> i32;  def Py_SetRecursionLimit(new_limit: i32);  def _PyMem_RawStrdup(
        str_: ptr[u8]
    ) -> ptr[u8];  def _PyMem_DefaultRawCalloc(nelem: u64, elsize: u64) -> ptr;  def _PyMem_DefaultRawFree(
        ptr_: ptr
    );  def _PyMem_DefaultRawWcsdup(str_: ptr[i32]) -> ptr[i32];  def _PyObject_DebugMallocStats(
        out: ptr
    ) -> i32;  def _PyObject_DebugTypeStats(out: ptr);  def _Py_GetGlobalAllocatedBlocks -> i64;  def _PyUnicode_InternImmortal(
        interp: ptr[u8], p: &mut ptr[PyObject]
    );  def _PyUnicode_InternMortal(interp: ptr[u8], p: &mut ptr[PyObject]);  def _PyUnicode_InternedSize -> i64;  def _PyUnicode_InternedSize_Immortal -> i64;  def _PyPerfTrampoline_Init(
        activate: i32
    ) -> i32;  def _PySysRemoteDebug_SendExec(
        pid: i32, tid: i32, path: ptr[u8]
    ) -> i32;  glob Py_IsolatedFlag: i32; glob:priv sys_statics: SysStatics = SysStatics(),
         sys_utf8_wide: list[i32] = [
             i32(117),
             i32(116),
             i32(102),
             i32(45),
             i32(56),
             i32(0)
         ],
         sys_empty_wide: list[i32] = [i32(0)],
         sys_empty_argv: list[ptr[i32]] = [ptr[i32]()],
         addaudithook_keywords: list[ptr[u8]] = [ptr[u8]("hook"), ptr[u8]()],
         addaudithook_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(addaudithook_keywords), fname=ptr[u8]("addaudithook")
         ),
         coroutine_depth_keywords: list[ptr[u8]] = [ptr[u8]("depth"), ptr[u8]()],
         coroutine_depth_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(coroutine_depth_keywords),
             fname=ptr[u8]("set_coroutine_origin_tracking_depth")
         ),
         max_str_digits_keywords: list[ptr[u8]] = [ptr[u8]("maxdigits"), ptr[u8]()],
         max_str_digits_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(max_str_digits_keywords),
             fname=ptr[u8]("set_int_max_str_digits")
         ),
         interned_size_keywords: list[ptr[u8]] = [ptr[u8]("_only_immortal"), ptr[u8]()],
         interned_size_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(interned_size_keywords),
             fname=ptr[u8]("getunicodeinternedsize")
         ),
         remote_exec_keywords: list[ptr[u8]] = [
             ptr[u8]("pid"),
             ptr[u8]("script"),
             ptr[u8]()
         ],
         remote_exec_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(remote_exec_keywords), fname=ptr[u8]("remote_exec")
         ),
         dump_tracelets_keywords: list[ptr[u8]] = [ptr[u8]("outpath"), ptr[u8]()],
         dump_tracelets_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(dump_tracelets_keywords),
             fname=ptr[u8]("_dump_tracelets")
         ),
         framemodulename_keywords: list[ptr[u8]] = [ptr[u8]("depth"), ptr[u8]()],
         framemodulename_parser: _PyArg_Parser = _PyArg_Parser(
             keywords=addressof(framemodulename_keywords),
             fname=ptr[u8]("_getframemodulename")
         ),
         asyncgen_hooks_keywords: list[ptr[u8]] = [
             ptr[u8]("firstiter"),
             ptr[u8]("finalizer"),
             ptr[u8]()
         ],
         getsizeof_keywords: list[ptr[u8]] = [
             ptr[u8]("object"),
             ptr[u8]("default"),
             ptr[u8]()
         ],
         asyncgen_hooks_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("firstiter"),
                 doc=ptr[u8]("Hook to intercept first iteration")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("finalizer"),
                 doc=ptr[u8]("Hook to intercept finalization")
             ),
             PyStructSequence_Field()
         ],
         asyncgen_hooks_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("asyncgen_hooks"),
             doc=ptr[u8](
                 "asyncgen_hooks\n"
                 "\n"
                 "A named tuple providing information about asynchronous\n"
                 "generators hooks.  The attributes are read only."
             ),
             fields=addressof(asyncgen_hooks_fields),
             n_in_sequence=2
         ),
         AsyncGenHooksType: PyTypeObject = PyTypeObject(),
         hash_info_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("width"),
                 doc=ptr[u8]("width of the type used for hashing, in bits")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("modulus"),
                 doc=ptr[u8](
                     "prime number giving the modulus on which the hash "
                     "function is based"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("inf"),
                 doc=ptr[u8]("value to be used for hash of a positive infinity")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("nan"), doc=ptr[u8]("value to be used for hash of a nan")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("imag"),
                 doc=ptr[u8](
                     "multiplier used for the imaginary part of a complex number"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("algorithm"),
                 doc=ptr[u8](
                     "name of the algorithm for hashing of str, bytes and "
                     "memoryviews"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("hash_bits"),
                 doc=ptr[u8]("internal output size of hash algorithm")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("seed_bits"), doc=ptr[u8]("seed size of hash algorithm")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("cutoff"), doc=ptr[u8]("small string optimization cutoff")
             ),
             PyStructSequence_Field()
         ],
         hash_info_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("sys.hash_info"),
             doc=ptr[u8](
                 "hash_info\n"
                 "\n"
                 "A named tuple providing parameters used for computing\n"
                 "hashes. The attributes are read only."
             ),
             fields=addressof(hash_info_fields),
             n_in_sequence=9
         ),
         Hash_InfoType: PyTypeObject = PyTypeObject(),
         flags_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(name=ptr[u8]("debug"), doc=ptr[u8]("-d")),
             PyStructSequence_Field(name=ptr[u8]("inspect"), doc=ptr[u8]("-i")),
             PyStructSequence_Field(name=ptr[u8]("interactive"), doc=ptr[u8]("-i")),
             PyStructSequence_Field(name=ptr[u8]("optimize"), doc=ptr[u8]("-O or -OO")),
             PyStructSequence_Field(
                 name=ptr[u8]("dont_write_bytecode"), doc=ptr[u8]("-B")
             ),
             PyStructSequence_Field(name=ptr[u8]("no_user_site"), doc=ptr[u8]("-s")),
             PyStructSequence_Field(name=ptr[u8]("no_site"), doc=ptr[u8]("-S")),
             PyStructSequence_Field(
                 name=ptr[u8]("ignore_environment"), doc=ptr[u8]("-E")
             ),
             PyStructSequence_Field(name=ptr[u8]("verbose"), doc=ptr[u8]("-v")),
             PyStructSequence_Field(name=ptr[u8]("bytes_warning"), doc=ptr[u8]("-b")),
             PyStructSequence_Field(name=ptr[u8]("quiet"), doc=ptr[u8]("-q")),
             PyStructSequence_Field(
                 name=ptr[u8]("hash_randomization"), doc=ptr[u8]("-R")
             ),
             PyStructSequence_Field(name=ptr[u8]("isolated"), doc=ptr[u8]("-I")),
             PyStructSequence_Field(name=ptr[u8]("dev_mode"), doc=ptr[u8]("-X dev")),
             PyStructSequence_Field(name=ptr[u8]("utf8_mode"), doc=ptr[u8]("-X utf8")),
             PyStructSequence_Field(
                 name=ptr[u8]("warn_default_encoding"),
                 doc=ptr[u8]("-X warn_default_encoding")
             ),
             PyStructSequence_Field(name=ptr[u8]("safe_path"), doc=ptr[u8]("-P")),
             PyStructSequence_Field(
                 name=ptr[u8]("int_max_str_digits"),
                 doc=ptr[u8]("-X int_max_str_digits")
             ),
             PyStructSequence_Field(name=ptr[u8]("gil"), doc=ptr[u8]("-X gil")),
             PyStructSequence_Field(
                 name=ptr[u8]("thread_inherit_context"),
                 doc=ptr[u8]("-X thread_inherit_context")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("context_aware_warnings"),
                 doc=ptr[u8]("-X context_aware_warnings")
             ),
             PyStructSequence_Field()
         ],
         flags_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("sys.flags"),
             doc=ptr[u8](
                 "sys.flags\n"
                 "\n"
                 "Flags provided through command line arguments or environment vars."
             ),
             fields=addressof(flags_fields),
             n_in_sequence=18
         ),
         FlagsType: PyTypeObject = PyTypeObject(),
         version_info_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("major"), doc=ptr[u8]("Major release number")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("minor"), doc=ptr[u8]("Minor release number")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("micro"), doc=ptr[u8]("Patch release number")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("releaselevel"),
                 doc=ptr[u8]("'alpha', 'beta', 'candidate', or 'final'")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("serial"), doc=ptr[u8]("Serial release number")
             ),
             PyStructSequence_Field()
         ],
         version_info_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("sys.version_info"),
             doc=ptr[u8](
                 "sys.version_info\n" "\n" "Version information as a named tuple."
             ),
             fields=addressof(version_info_fields),
             n_in_sequence=5
         ),
         VersionInfoType: PyTypeObject = PyTypeObject(),
         stdlib_module_names: list[ptr[u8]] = [
             ptr[u8]("__future__"),
             ptr[u8]("_abc"),
             ptr[u8]("_aix_support"),
             ptr[u8]("_android_support"),
             ptr[u8]("_apple_support"),
             ptr[u8]("_ast"),
             ptr[u8]("_ast_unparse"),
             ptr[u8]("_asyncio"),
             ptr[u8]("_bisect"),
             ptr[u8]("_blake2"),
             ptr[u8]("_bz2"),
             ptr[u8]("_codecs"),
             ptr[u8]("_codecs_cn"),
             ptr[u8]("_codecs_hk"),
             ptr[u8]("_codecs_iso2022"),
             ptr[u8]("_codecs_jp"),
             ptr[u8]("_codecs_kr"),
             ptr[u8]("_codecs_tw"),
             ptr[u8]("_collections"),
             ptr[u8]("_collections_abc"),
             ptr[u8]("_colorize"),
             ptr[u8]("_compat_pickle"),
             ptr[u8]("_contextvars"),
             ptr[u8]("_csv"),
             ptr[u8]("_ctypes"),
             ptr[u8]("_curses"),
             ptr[u8]("_curses_panel"),
             ptr[u8]("_datetime"),
             ptr[u8]("_dbm"),
             ptr[u8]("_decimal"),
             ptr[u8]("_elementtree"),
             ptr[u8]("_frozen_importlib"),
             ptr[u8]("_frozen_importlib_external"),
             ptr[u8]("_functools"),
             ptr[u8]("_gdbm"),
             ptr[u8]("_hashlib"),
             ptr[u8]("_heapq"),
             ptr[u8]("_hmac"),
             ptr[u8]("_imp"),
             ptr[u8]("_interpchannels"),
             ptr[u8]("_interpqueues"),
             ptr[u8]("_interpreters"),
             ptr[u8]("_io"),
             ptr[u8]("_ios_support"),
             ptr[u8]("_json"),
             ptr[u8]("_locale"),
             ptr[u8]("_lsprof"),
             ptr[u8]("_lzma"),
             ptr[u8]("_markupbase"),
             ptr[u8]("_md5"),
             ptr[u8]("_multibytecodec"),
             ptr[u8]("_multiprocessing"),
             ptr[u8]("_opcode"),
             ptr[u8]("_opcode_metadata"),
             ptr[u8]("_operator"),
             ptr[u8]("_osx_support"),
             ptr[u8]("_overlapped"),
             ptr[u8]("_pickle"),
             ptr[u8]("_posixshmem"),
             ptr[u8]("_posixsubprocess"),
             ptr[u8]("_py_abc"),
             ptr[u8]("_py_warnings"),
             ptr[u8]("_pydatetime"),
             ptr[u8]("_pydecimal"),
             ptr[u8]("_pyio"),
             ptr[u8]("_pylong"),
             ptr[u8]("_pyrepl"),
             ptr[u8]("_queue"),
             ptr[u8]("_random"),
             ptr[u8]("_remote_debugging"),
             ptr[u8]("_scproxy"),
             ptr[u8]("_sha1"),
             ptr[u8]("_sha2"),
             ptr[u8]("_sha3"),
             ptr[u8]("_signal"),
             ptr[u8]("_sitebuiltins"),
             ptr[u8]("_socket"),
             ptr[u8]("_sqlite3"),
             ptr[u8]("_sre"),
             ptr[u8]("_ssl"),
             ptr[u8]("_stat"),
             ptr[u8]("_statistics"),
             ptr[u8]("_string"),
             ptr[u8]("_strptime"),
             ptr[u8]("_struct"),
             ptr[u8]("_suggestions"),
             ptr[u8]("_symtable"),
             ptr[u8]("_sysconfig"),
             ptr[u8]("_thread"),
             ptr[u8]("_threading_local"),
             ptr[u8]("_tkinter"),
             ptr[u8]("_tokenize"),
             ptr[u8]("_tracemalloc"),
             ptr[u8]("_types"),
             ptr[u8]("_typing"),
             ptr[u8]("_uuid"),
             ptr[u8]("_warnings"),
             ptr[u8]("_weakref"),
             ptr[u8]("_weakrefset"),
             ptr[u8]("_winapi"),
             ptr[u8]("_wmi"),
             ptr[u8]("_zoneinfo"),
             ptr[u8]("_zstd"),
             ptr[u8]("abc"),
             ptr[u8]("annotationlib"),
             ptr[u8]("antigravity"),
             ptr[u8]("argparse"),
             ptr[u8]("array"),
             ptr[u8]("ast"),
             ptr[u8]("asyncio"),
             ptr[u8]("atexit"),
             ptr[u8]("base64"),
             ptr[u8]("bdb"),
             ptr[u8]("binascii"),
             ptr[u8]("bisect"),
             ptr[u8]("builtins"),
             ptr[u8]("bz2"),
             ptr[u8]("cProfile"),
             ptr[u8]("calendar"),
             ptr[u8]("cmath"),
             ptr[u8]("cmd"),
             ptr[u8]("code"),
             ptr[u8]("codecs"),
             ptr[u8]("codeop"),
             ptr[u8]("collections"),
             ptr[u8]("colorsys"),
             ptr[u8]("compileall"),
             ptr[u8]("compression"),
             ptr[u8]("concurrent"),
             ptr[u8]("configparser"),
             ptr[u8]("contextlib"),
             ptr[u8]("contextvars"),
             ptr[u8]("copy"),
             ptr[u8]("copyreg"),
             ptr[u8]("csv"),
             ptr[u8]("ctypes"),
             ptr[u8]("curses"),
             ptr[u8]("dataclasses"),
             ptr[u8]("datetime"),
             ptr[u8]("dbm"),
             ptr[u8]("decimal"),
             ptr[u8]("difflib"),
             ptr[u8]("dis"),
             ptr[u8]("doctest"),
             ptr[u8]("email"),
             ptr[u8]("encodings"),
             ptr[u8]("ensurepip"),
             ptr[u8]("enum"),
             ptr[u8]("errno"),
             ptr[u8]("faulthandler"),
             ptr[u8]("fcntl"),
             ptr[u8]("filecmp"),
             ptr[u8]("fileinput"),
             ptr[u8]("fnmatch"),
             ptr[u8]("fractions"),
             ptr[u8]("ftplib"),
             ptr[u8]("functools"),
             ptr[u8]("gc"),
             ptr[u8]("genericpath"),
             ptr[u8]("getopt"),
             ptr[u8]("getpass"),
             ptr[u8]("gettext"),
             ptr[u8]("glob"),
             ptr[u8]("graphlib"),
             ptr[u8]("grp"),
             ptr[u8]("gzip"),
             ptr[u8]("hashlib"),
             ptr[u8]("heapq"),
             ptr[u8]("hmac"),
             ptr[u8]("html"),
             ptr[u8]("http"),
             ptr[u8]("idlelib"),
             ptr[u8]("imaplib"),
             ptr[u8]("importlib"),
             ptr[u8]("inspect"),
             ptr[u8]("io"),
             ptr[u8]("ipaddress"),
             ptr[u8]("itertools"),
             ptr[u8]("json"),
             ptr[u8]("keyword"),
             ptr[u8]("linecache"),
             ptr[u8]("locale"),
             ptr[u8]("logging"),
             ptr[u8]("lzma"),
             ptr[u8]("mailbox"),
             ptr[u8]("marshal"),
             ptr[u8]("math"),
             ptr[u8]("mimetypes"),
             ptr[u8]("mmap"),
             ptr[u8]("modulefinder"),
             ptr[u8]("msvcrt"),
             ptr[u8]("multiprocessing"),
             ptr[u8]("netrc"),
             ptr[u8]("nt"),
             ptr[u8]("ntpath"),
             ptr[u8]("nturl2path"),
             ptr[u8]("numbers"),
             ptr[u8]("opcode"),
             ptr[u8]("operator"),
             ptr[u8]("optparse"),
             ptr[u8]("os"),
             ptr[u8]("pathlib"),
             ptr[u8]("pdb"),
             ptr[u8]("pickle"),
             ptr[u8]("pickletools"),
             ptr[u8]("pkgutil"),
             ptr[u8]("platform"),
             ptr[u8]("plistlib"),
             ptr[u8]("poplib"),
             ptr[u8]("posix"),
             ptr[u8]("posixpath"),
             ptr[u8]("pprint"),
             ptr[u8]("profile"),
             ptr[u8]("pstats"),
             ptr[u8]("pty"),
             ptr[u8]("pwd"),
             ptr[u8]("py_compile"),
             ptr[u8]("pyclbr"),
             ptr[u8]("pydoc"),
             ptr[u8]("pydoc_data"),
             ptr[u8]("pyexpat"),
             ptr[u8]("queue"),
             ptr[u8]("quopri"),
             ptr[u8]("random"),
             ptr[u8]("re"),
             ptr[u8]("readline"),
             ptr[u8]("reprlib"),
             ptr[u8]("resource"),
             ptr[u8]("rlcompleter"),
             ptr[u8]("runpy"),
             ptr[u8]("sched"),
             ptr[u8]("secrets"),
             ptr[u8]("select"),
             ptr[u8]("selectors"),
             ptr[u8]("shelve"),
             ptr[u8]("shlex"),
             ptr[u8]("shutil"),
             ptr[u8]("signal"),
             ptr[u8]("site"),
             ptr[u8]("smtplib"),
             ptr[u8]("socket"),
             ptr[u8]("socketserver"),
             ptr[u8]("sqlite3"),
             ptr[u8]("sre_compile"),
             ptr[u8]("sre_constants"),
             ptr[u8]("sre_parse"),
             ptr[u8]("ssl"),
             ptr[u8]("stat"),
             ptr[u8]("statistics"),
             ptr[u8]("string"),
             ptr[u8]("stringprep"),
             ptr[u8]("struct"),
             ptr[u8]("subprocess"),
             ptr[u8]("symtable"),
             ptr[u8]("sys"),
             ptr[u8]("sysconfig"),
             ptr[u8]("syslog"),
             ptr[u8]("tabnanny"),
             ptr[u8]("tarfile"),
             ptr[u8]("tempfile"),
             ptr[u8]("termios"),
             ptr[u8]("textwrap"),
             ptr[u8]("this"),
             ptr[u8]("threading"),
             ptr[u8]("time"),
             ptr[u8]("timeit"),
             ptr[u8]("tkinter"),
             ptr[u8]("token"),
             ptr[u8]("tokenize"),
             ptr[u8]("tomllib"),
             ptr[u8]("trace"),
             ptr[u8]("traceback"),
             ptr[u8]("tracemalloc"),
             ptr[u8]("tty"),
             ptr[u8]("turtle"),
             ptr[u8]("turtledemo"),
             ptr[u8]("types"),
             ptr[u8]("typing"),
             ptr[u8]("unicodedata"),
             ptr[u8]("unittest"),
             ptr[u8]("urllib"),
             ptr[u8]("uuid"),
             ptr[u8]("venv"),
             ptr[u8]("warnings"),
             ptr[u8]("wave"),
             ptr[u8]("weakref"),
             ptr[u8]("webbrowser"),
             ptr[u8]("winreg"),
             ptr[u8]("winsound"),
             ptr[u8]("wsgiref"),
             ptr[u8]("xml"),
             ptr[u8]("xmlrpc"),
             ptr[u8]("zipapp"),
             ptr[u8]("zipfile"),
             ptr[u8]("zipimport"),
             ptr[u8]("zlib"),
             ptr[u8]("zoneinfo")
         ],
         sys_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("addaudithook"),
                 ml_meth=ptr(sys_addaudithook),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "addaudithook($module, /, hook)\n"
                     "--\n"
                     "\n"
                     "Adds a new audit hook callback."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("audit"),
                 ml_meth=ptr(sys_audit),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "audit($module, event, /, *args)\n"
                     "--\n"
                     "\n"
                     "Passes the event to any audit hooks that are attached."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("breakpointhook"),
                 ml_meth=ptr(sys_breakpointhook),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "breakpointhook($module, /, *args, **kwargs)\n"
                     "--\n"
                     "\n"
                     "This hook function is called by built-in breakpoint().\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_clear_internal_caches"),
                 ml_meth=ptr(sys__clear_internal_caches),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_clear_internal_caches($module, /)\n"
                     "--\n"
                     "\n"
                     "Clear all internal performance-related caches."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_clear_type_cache"),
                 ml_meth=ptr(sys__clear_type_cache),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_clear_type_cache($module, /)\n"
                     "--\n"
                     "\n"
                     "Clear the internal type lookup cache."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_current_frames"),
                 ml_meth=ptr(sys__current_frames),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_current_frames($module, /)\n"
                     "--\n"
                     "\n"
                     "Return a dict mapping each thread's thread id to its current stack frame.\n"
                     "\n"
                     "This function should be used for specialized purposes only."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_current_exceptions"),
                 ml_meth=ptr(sys__current_exceptions),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_current_exceptions($module, /)\n"
                     "--\n"
                     "\n"
                     "Return a dict mapping each thread's identifier to its current raised exception.\n"
                     "\n"
                     "This function should be used for specialized purposes only."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("displayhook"),
                 ml_meth=ptr(sys_displayhook),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "displayhook($module, object, /)\n"
                     "--\n"
                     "\n"
                     "Print an object to sys.stdout and also save it in builtins._"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exception"),
                 ml_meth=ptr(sys_exception),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "exception($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the current exception.\n"
                     "\n"
                     "Return the most recent exception caught by an except clause\n"
                     "in the current stack frame or in an older stack frame, or None\n"
                     "if no such exception exists."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exc_info"),
                 ml_meth=ptr(sys_exc_info),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "exc_info($module, /)\n"
                     "--\n"
                     "\n"
                     "Return current exception information: (type, value, traceback).\n"
                     "\n"
                     "Return information about the most recent exception caught by an except\n"
                     "clause in the current stack frame or in an older stack frame."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("excepthook"),
                 ml_meth=ptr(sys_excepthook),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "excepthook($module, exctype, value, traceback, /)\n"
                     "--\n"
                     "\n"
                     "Handle an exception by displaying it with a traceback on sys.stderr."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exit"),
                 ml_meth=ptr(sys_exit),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "exit($module, status=None, /)\n"
                     "--\n"
                     "\n"
                     "Exit the interpreter by raising SystemExit(status).\n"
                     "\n"
                     "If the status is omitted or None, it defaults to zero (i.e., success).\n"
                     "If the status is an integer, it will be used as the system exit status.\n"
                     "If it is another kind of object, it will be printed and the system\n"
                     "exit status will be one (i.e., failure)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getdefaultencoding"),
                 ml_meth=ptr(sys_getdefaultencoding),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getdefaultencoding($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the current default encoding used by the Unicode implementation."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getdlopenflags"),
                 ml_meth=ptr(sys_getdlopenflags),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getdlopenflags($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the current value of the flags that are used for dlopen calls.\n"
                     "\n"
                     "The flag constants are defined in the os module."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getallocatedblocks"),
                 ml_meth=ptr(sys_getallocatedblocks),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getallocatedblocks($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the number of memory blocks currently allocated."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getunicodeinternedsize"),
                 ml_meth=ptr(sys_getunicodeinternedsize),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "getunicodeinternedsize($module, /, *, _only_immortal=False)\n"
                     "--\n"
                     "\n"
                     "Return the number of elements of the unicode interned dictionary"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getfilesystemencoding"),
                 ml_meth=ptr(sys_getfilesystemencoding),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getfilesystemencoding($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the encoding used to convert Unicode filenames to OS filenames."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getfilesystemencodeerrors"),
                 ml_meth=ptr(sys_getfilesystemencodeerrors),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getfilesystemencodeerrors($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the error mode used Unicode to OS filename conversion."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getrefcount"),
                 ml_meth=ptr(sys_getrefcount),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "getrefcount($module, object, /)\n"
                     "--\n"
                     "\n"
                     "Return the reference count of object.\n"
                     "\n"
                     "The count returned is generally one higher than you might expect,\n"
                     "because it includes the (temporary) reference as an argument to\n"
                     "getrefcount()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getrecursionlimit"),
                 ml_meth=ptr(sys_getrecursionlimit),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getrecursionlimit($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the current value of the recursion limit.\n"
                     "\n"
                     "The recursion limit is the maximum depth of the Python interpreter\n"
                     "stack.  This limit prevents infinite recursion from causing an overflow\n"
                     "of the C stack and crashing Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getsizeof"),
                 ml_meth=ptr(sys_getsizeof),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "getsizeof(object [, default]) -> int\n"
                     "\n"
                     "Return the size of object in bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_getframe"),
                 ml_meth=ptr(sys__getframe),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "_getframe($module, depth=0, /)\n"
                     "--\n"
                     "\n"
                     "Return a frame object from the call stack.\n"
                     "\n"
                     "If optional integer depth is given, return the frame object that many\n"
                     "calls below the top of the stack.  If that is deeper than the call\n"
                     "stack, ValueError is raised.  The default for depth is zero, returning\n"
                     "the frame at the top of the call stack.\n"
                     "\n"
                     "This function should be used for internal and specialized purposes\n"
                     "only."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_getframemodulename"),
                 ml_meth=ptr(sys__getframemodulename),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "_getframemodulename($module, /, depth=0)\n"
                     "--\n"
                     "\n"
                     "Return the name of the module for a calling frame.\n"
                     "\n"
                     "The default depth returns the module containing the call to this API.\n"
                     "A more typical use in a library will pass a depth of 1 to get the user's\n"
                     "module rather than the library module.\n"
                     "\n"
                     "If no frame, module, or name can be found, returns None."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_is_immortal"),
                 ml_meth=ptr(sys__is_immortal),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "_is_immortal($module, op, /)\n"
                     "--\n"
                     "\n"
                     "Return True if the given object is \"immortal\" per PEP 683.\n"
                     "\n"
                     "This function should be used for specialized purposes only."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("intern"),
                 ml_meth=ptr(sys_intern),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "intern($module, string, /)\n"
                     "--\n"
                     "\n"
                     "``Intern'' the given string.\n"
                     "\n"
                     "This enters the string in the (global) table of interned strings whose\n"
                     "purpose is to speed up dictionary lookups. Return the string itself or\n"
                     "the previously interned string object with the same value."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_is_interned"),
                 ml_meth=ptr(sys__is_interned),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "_is_interned($module, string, /)\n"
                     "--\n"
                     "\n"
                     "Return True if the given string is \"interned\"."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_finalizing"),
                 ml_meth=ptr(sys_is_finalizing),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_finalizing($module, /)\n"
                     "--\n"
                     "\n"
                     "Return True if Python is exiting."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setswitchinterval"),
                 ml_meth=ptr(sys_setswitchinterval),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "setswitchinterval($module, interval, /)\n"
                     "--\n"
                     "\n"
                     "Set the ideal thread switching delay inside the Python interpreter.\n"
                     "\n"
                     "The actual frequency of switching threads can be lower if the\n"
                     "interpreter executes long sequences of uninterruptible code\n"
                     "(this is implementation-specific and workload-dependent).\n"
                     "\n"
                     "The parameter must represent the desired switching delay in seconds\n"
                     "A typical value is 0.005 (5 milliseconds)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getswitchinterval"),
                 ml_meth=ptr(sys_getswitchinterval),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getswitchinterval($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the current thread switch interval; see sys.setswitchinterval()."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setdlopenflags"),
                 ml_meth=ptr(sys_setdlopenflags),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "setdlopenflags($module, flags, /)\n"
                     "--\n"
                     "\n"
                     "Set the flags used by the interpreter for dlopen calls.\n"
                     "\n"
                     "This is used, for example, when the interpreter loads extension\n"
                     "modules. Among other things, this will enable a lazy resolving of\n"
                     "symbols when importing a module, if called as sys.setdlopenflags(0).\n"
                     "To share symbols across extension modules, call as\n"
                     "sys.setdlopenflags(os.RTLD_GLOBAL).  Symbolic names for the flag\n"
                     "modules can be found in the os module (RTLD_xxx constants, e.g.\n"
                     "os.RTLD_LAZY)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setprofile"),
                 ml_meth=ptr(sys_setprofile),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "setprofile($module, function, /)\n"
                     "--\n"
                     "\n"
                     "Set the profiling function.\n"
                     "\n"
                     "It will be called on each function call and return.  See the profiler\n"
                     "chapter in the library manual."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_setprofileallthreads"),
                 ml_meth=ptr(sys__setprofileallthreads),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "_setprofileallthreads($module, function, /)\n"
                     "--\n"
                     "\n"
                     "Set the profiling function in all running threads belonging to the current interpreter.\n"
                     "\n"
                     "It will be called on each function call and return.  See the profiler\n"
                     "chapter in the library manual."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("getprofile"),
                 ml_meth=ptr(sys_getprofile),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "getprofile($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the profiling function set with sys.setprofile.\n"
                     "\n"
                     "See the profiler chapter in the library manual."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("setrecursionlimit"),
                 ml_meth=ptr(sys_setrecursionlimit),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "setrecursionlimit($module, limit, /)\n"
                     "--\n"
                     "\n"
                     "Set the maximum depth of the Python interpreter stack to n.\n"
                     "\n"
                     "This limit prevents infinite recursion from causing an overflow of the C\n"
                     "stack and crashing Python.  The highest possible limit is platform-\n"
                     "dependent."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("settrace"),
                 ml_meth=ptr(sys_settrace),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "settrace($module, function, /)\n"
                     "--\n"
                     "\n"
                     "Set the global debug tracing function.\n"
                     "\n"
                     "It will be called on each function call.  See the debugger chapter\n"
                     "in the library manual."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_settraceallthreads"),
                 ml_meth=ptr(sys__settraceallthreads),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "_settraceallthreads($module, function, /)\n"
                     "--\n"
                     "\n"
                     "Set the global debug tracing function in all running threads belonging to the current interpreter.\n"
                     "\n"
                     "It will be called on each function call. See the debugger chapter\n"
                     "in the library manual."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("gettrace"),
                 ml_meth=ptr(sys_gettrace),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "gettrace($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the global debug tracing function set with sys.settrace.\n"
                     "\n"
                     "See the debugger chapter in the library manual."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("call_tracing"),
                 ml_meth=ptr(sys_call_tracing),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "call_tracing($module, func, args, /)\n"
                     "--\n"
                     "\n"
                     "Call func(*args), while tracing is enabled.\n"
                     "\n"
                     "The tracing state is saved, and restored afterwards.  This is intended\n"
                     "to be called from a debugger from a checkpoint, to recursively debug\n"
                     "some other code."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_debugmallocstats"),
                 ml_meth=ptr(sys__debugmallocstats),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_debugmallocstats($module, /)\n"
                     "--\n"
                     "\n"
                     "Print summary info to stderr about the state of pymalloc's structures.\n"
                     "\n"
                     "In Py_DEBUG mode, also perform some expensive internal consistency\n"
                     "checks."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_coroutine_origin_tracking_depth"),
                 ml_meth=ptr(sys_set_coroutine_origin_tracking_depth),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "set_coroutine_origin_tracking_depth($module, /, depth)\n"
                     "--\n"
                     "\n"
                     "Enable or disable origin tracking for coroutine objects in this thread.\n"
                     "\n"
                     "Coroutine objects will track 'depth' frames of traceback information\n"
                     "about where they came from, available in their cr_origin attribute.\n"
                     "\n"
                     "Set a depth of 0 to disable."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_coroutine_origin_tracking_depth"),
                 ml_meth=ptr(sys_get_coroutine_origin_tracking_depth),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_coroutine_origin_tracking_depth($module, /)\n"
                     "--\n"
                     "\n"
                     "Check status of origin tracking for coroutine objects in this thread."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_asyncgen_hooks"),
                 ml_meth=ptr(sys_set_asyncgen_hooks),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "set_asyncgen_hooks([firstiter] [, finalizer])\n"
                     "\n"
                     "Set a finalizer for async generators objects."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_asyncgen_hooks"),
                 ml_meth=ptr(sys_get_asyncgen_hooks),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_asyncgen_hooks($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the installed asynchronous generators hooks.\n"
                     "\n"
                     "This returns a namedtuple of the form (firstiter, finalizer)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("activate_stack_trampoline"),
                 ml_meth=ptr(sys_activate_stack_trampoline),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "activate_stack_trampoline($module, backend, /)\n"
                     "--\n"
                     "\n"
                     "Activate stack profiler trampoline *backend*."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("deactivate_stack_trampoline"),
                 ml_meth=ptr(sys_deactivate_stack_trampoline),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "deactivate_stack_trampoline($module, /)\n"
                     "--\n"
                     "\n"
                     "Deactivate the current stack profiler trampoline backend.\n"
                     "\n"
                     "If no stack profiler is activated, this function has no effect."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_stack_trampoline_active"),
                 ml_meth=ptr(sys_is_stack_trampoline_active),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_stack_trampoline_active($module, /)\n"
                     "--\n"
                     "\n"
                     "Return *True* if a stack profiler trampoline is active."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_remote_debug_enabled"),
                 ml_meth=ptr(sys_is_remote_debug_enabled),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_remote_debug_enabled($module, /)\n"
                     "--\n"
                     "\n"
                     "Return True if remote debugging is enabled, False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("remote_exec"),
                 ml_meth=ptr(sys_remote_exec),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "remote_exec($module, /, pid, script)\n"
                     "--\n"
                     "\n"
                     "Executes a file containing Python code in a given remote Python process.\n"
                     "\n"
                     "This function returns immediately, and the code will be executed by the\n"
                     "target process's main thread at the next available opportunity,\n"
                     "similarly to how signals are handled.  There is no interface to\n"
                     "determine when the code has been executed.  The caller is responsible\n"
                     "for making sure that the file still exists whenever the remote process\n"
                     "tries to read it and that it hasn't been overwritten.\n"
                     "\n"
                     "The remote process must be running a CPython interpreter of the same\n"
                     "major and minor version as the local process.  If either the local or\n"
                     "remote interpreter is pre-release (alpha, beta, or release candidate)\n"
                     "then the local and remote interpreters must be the same exact version.\n"
                     "\n"
                     "Args:\n"
                     "     pid (int): The process ID of the target Python process.\n"
                     "     script (str|bytes): The path to a file containing\n"
                     "         the Python code to be executed."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("unraisablehook"),
                 ml_meth=ptr(sys_unraisablehook),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "unraisablehook($module, unraisable, /)\n"
                     "--\n"
                     "\n"
                     "Handle an unraisable exception.\n"
                     "\n"
                     "The unraisable argument has the following attributes:\n"
                     "\n"
                     "* exc_type: Exception type.\n"
                     "* exc_value: Exception value, can be None.\n"
                     "* exc_traceback: Exception traceback, can be None.\n"
                     "* err_msg: Error message, can be None.\n"
                     "* object: Object causing the exception, can be None."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_int_max_str_digits"),
                 ml_meth=ptr(sys_get_int_max_str_digits),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "get_int_max_str_digits($module, /)\n"
                     "--\n"
                     "\n"
                     "Return the maximum string digits limit for non-binary int<->str conversions."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set_int_max_str_digits"),
                 ml_meth=ptr(sys_set_int_max_str_digits),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "set_int_max_str_digits($module, /, maxdigits)\n"
                     "--\n"
                     "\n"
                     "Set the maximum string digits limit for non-binary int<->str conversions."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_baserepl"),
                 ml_meth=ptr(sys__baserepl),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_baserepl($module, /)\n"
                     "--\n"
                     "\n"
                     "Private function for getting the base REPL"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_get_cpu_count_config"),
                 ml_meth=ptr(sys__get_cpu_count_config),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_get_cpu_count_config($module, /)\n"
                     "--\n"
                     "\n"
                     "Private function for getting PyConfig.cpu_count"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_clear_type_descriptors"),
                 ml_meth=ptr(sys__clear_type_descriptors),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "_clear_type_descriptors($module, type, /)\n"
                     "--\n"
                     "\n"
                     "Private function for clearing certain descriptors from a type's dictionary.\n"
                     "\n"
                     "See gh-135228 for context."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_is_gil_enabled"),
                 ml_meth=ptr(sys__is_gil_enabled),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "_is_gil_enabled($module, /)\n"
                     "--\n"
                     "\n"
                     "Return True if the GIL is currently enabled and False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_dump_tracelets"),
                 ml_meth=ptr(sys__dump_tracelets),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "_dump_tracelets($module, /, outpath)\n"
                     "--\n"
                     "\n"
                     "Dump the graph of tracelets in graphviz format"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         sysmodule: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("sys"),
             m_doc=ptr[u8](
                 "This module provides access to some objects used or maintained by the\n"
                 "interpreter and to functions that interact strongly with the interpreter.\n"
                 "\n"
                 "Dynamic objects:\n"
                 "\n"
                 "argv -- command line arguments; argv[0] is the script pathname if known\n"
                 "path -- module search path; path[0] is the script directory, else ''\n"
                 "modules -- dictionary of loaded modules\n"
                 "\n"
                 "displayhook -- called to show results in an interactive session\n"
                 "excepthook -- called to handle any uncaught exception other than SystemExit\n"
                 "  To customize printing in an interactive session or to install a custom\n"
                 "  top-level exception handler, assign other functions to replace these.\n"
                 "\n"
                 "stdin -- standard input file object; used by input()\n"
                 "stdout -- standard output file object; used by print()\n"
                 "stderr -- standard error object; used for error messages\n"
                 "  By assigning other file objects (or objects that behave like files)\n"
                 "  to these, it is possible to redirect all of the interpreter's I/O.\n"
                 "\n"
                 "last_exc - the last uncaught exception\n"
                 "  Only available in an interactive session after a\n"
                 "  traceback has been printed.\n"
                 "last_type -- type of last uncaught exception\n"
                 "last_value -- value of last uncaught exception\n"
                 "last_traceback -- traceback of last uncaught exception\n"
                 "  These three are the (deprecated) legacy representation of last_exc.\n"
                 "\n"
                 "Static objects:\n"
                 "\n"
                 "builtin_module_names -- tuple of module names built into this interpreter\n"
                 "copyright -- copyright notice pertaining to this interpreter\n"
                 "exec_prefix -- prefix used to find the machine-specific Python library\n"
                 "executable -- absolute path of the executable binary of the Python interpreter\n"
                 "float_info -- a named tuple with information about the float implementation.\n"
                 "float_repr_style -- string indicating the style of repr() output for floats\n"
                 "hash_info -- a named tuple with information about the hash algorithm.\n"
                 "hexversion -- version information encoded as a single integer\n"
                 "implementation -- Python implementation information.\n"
                 "int_info -- a named tuple with information about the int implementation.\n"
                 "maxsize -- the largest supported length of containers.\n"
                 "maxunicode -- the value of the largest Unicode code point\n"
                 "platform -- platform identifier\n"
                 "prefix -- prefix used to find the Python library\n"
                 "thread_info -- a named tuple with information about the thread implementation.\n"
                 "version -- the version of this interpreter as a string\n"
                 "version_info -- version information as a named tuple\n"
                 "__stdin__ -- the original stdin; don't touch!\n"
                 "__stdout__ -- the original stdout; don't touch!\n"
                 "__stderr__ -- the original stderr; don't touch!\n"
                 "__displayhook__ -- the original displayhook; don't touch!\n"
                 "__excepthook__ -- the original excepthook; don't touch!\n"
                 "\n"
                 "Functions:\n"
                 "\n"
                 "displayhook() -- print an object to the screen, and save it in builtins._\n"
                 "excepthook() -- print an exception and its traceback to sys.stderr\n"
                 "exception() -- return the current thread's active exception\n"
                 "exc_info() -- return information about the current thread's active exception\n"
                 "exit() -- exit the interpreter by raising SystemExit\n"
                 "getdlopenflags() -- returns flags to be used for dlopen() calls\n"
                 "getprofile() -- get the global profiling function\n"
                 "getrefcount() -- return the reference count for an object (plus one :-)\n"
                 "getrecursionlimit() -- return the max recursion depth for the interpreter\n"
                 "getsizeof() -- return the size of an object in bytes\n"
                 "gettrace() -- get the global debug tracing function\n"
                 "setdlopenflags() -- set the flags to be used for dlopen() calls\n"
                 "setprofile() -- set the global profiling function\n"
                 "setrecursionlimit() -- set the max recursion depth for the interpreter\n"
                 "settrace() -- set the global debug tracing function\n"
             ),
             m_size=-1,
             m_methods=addressof(sys_methods)
         ),
         jit_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("is_available"),
                 ml_meth=ptr(_jit_is_available),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_available($module, /)\n"
                     "--\n"
                     "\n"
                     "Return True if the current Python executable supports JIT compilation, and False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_enabled"),
                 ml_meth=ptr(_jit_is_enabled),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_enabled($module, /)\n"
                     "--\n"
                     "\n"
                     "Return True if JIT compilation is enabled for the current Python process (implies sys._jit.is_available()), and False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_active"),
                 ml_meth=ptr(_jit_is_active),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_active($module, /)\n"
                     "--\n"
                     "\n"
                     "Return True if the topmost Python frame is currently executing JIT code (implies sys._jit.is_enabled()), and False otherwise."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         jit_module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("sys._jit"),
             m_doc=ptr[u8]("Utilities for observing just-in-time compilation."),
             m_size=-1,
             m_methods=addressof(jit_methods)
         ); glob _PySys_ImplName: ptr[u8] = ptr[u8]("cpython"),
         _PySys_ImplCacheTag: ptr[u8] = ptr[u8]("cpython-314"); def _PySys_GetRequiredAttr(
        name: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not unicode_check(name) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("attribute name must be string, not '%.200s'"),
                object_type(name).view(1)[0].tp_name
            );
            return NULL;
        }
        tstate = thread_state();
        sysdict = interp_sysdict(tstate_interp(tstate));
        if not sysdict {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("no sys module"));
            return NULL;
        }
        value = NULL;
        if PyDict_GetItemRef(sysdict, name, &mut value) == 0 {
            PyErr_Format(PyExc_RuntimeError, ptr[u8]("lost sys.%U"), name);
        }
        return value;
    }  def _PySys_GetRequiredAttrString(name: ptr[u8]) -> ptr[PyObject] {
        tstate = thread_state();
        sysdict = interp_sysdict(tstate_interp(tstate));
        if not sysdict {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("no sys module"));
            return NULL;
        }
        value = NULL;
        if PyDict_GetItemStringRef(sysdict, name, &mut value) == 0 {
            PyErr_Format(PyExc_RuntimeError, ptr[u8]("lost sys.%s"), name);
        }
        return value;
    }  def _PySys_GetOptionalAttr(
        name: ptr[PyObject], value: ptr[ptr[PyObject]]
    ) -> i32 {
        (status, result) = sys_optional_attr(name);
        value.view(1)[0] = result;
        return status;
    }  def _PySys_GetOptionalAttrString(
        name: ptr[u8], value: ptr[ptr[PyObject]]
    ) -> i32 {
        (status, result) = sys_optional_attr_string(name);
        value.view(1)[0] = result;
        return status;
    }  def PySys_GetObject(name: ptr[u8]) -> ptr[PyObject] {
        tstate = thread_state();
        sysdict = interp_sysdict(tstate_interp(tstate));
        if not sysdict {
            return NULL;
        }
        exc = _PyErr_GetRaisedException(tstate);
        value = NULL;
        PyDict_GetItemStringRef(sysdict, name, &mut value);
        if exception_raised(tstate) {
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored in PySys_GetObject()"));
        }
        _PyErr_SetRaisedException(tstate, exc);
        object_xdecref(value);
        return value;
    }  def _PySys_SetAttr(key: ptr[PyObject], v: ptr[PyObject]) -> i32 {
        return sys_set_object(current_interp(), key, v);
    }  def PySys_SetObject(name: ptr[u8], v: ptr[PyObject]) -> i32 {
        return sys_set_object_str(current_interp(), name, v);
    }  def _PySys_ClearAttrString(interp: ptr[u8], name: ptr[u8], verbose: i32) -> i32 {
        if verbose != 0 {
            sys_write_stderr_text(ptr[u8]("# clear sys.%s\n"), name);
        }
        if PyDict_SetItemString(interp_sysdict(interp), name, Py_None) < 0 {
            return -1;
        }
        return 0;
    }  def _PySys_Audit(
        tstate: ptr[PyThreadState], event: ptr[u8], argFormat: ptr[u8], *vargs: VaList
    ) -> i32 {
        return sys_audit_tstate(tstate, event, argFormat, vargs);
    }  def PySys_Audit(event: ptr[u8], argFormat: ptr[u8], *vargs: VaList) -> i32 {
        return sys_audit_tstate(thread_state(), event, argFormat, vargs);
    }  def PySys_AuditTuple(event: ptr[u8], args: ptr[PyObject]) -> i32 {
        if not args {
            return sys_audit_values(thread_state(), event, AUDIT_NO_ARGS, NULL, 0);
        }
        if not tuple_check(args) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("args must be tuple, got %s"),
                object_type(args).view(1)[0].tp_name
            );
            return -1;
        }
        return sys_audit_values(thread_state(), event, AUDIT_OBJECT, args, 0);
    }  def _PySys_ClearAuditHooks(ts: ptr[PyThreadState]) {
        if not ts {
            return;
        }
        interp = tstate_interp(ts);
        runtime = interp_runtime(interp);
        finalizing = ptr[PyThreadState](
            __atomic_load_i64(int(runtime) + _PyRuntimeState_FINALIZING, 0)
        );
        if finalizing != ts {
            return;
        }
        config = _PyInterpreterState_GetConfig(interp);
        if config_int(config, PyConfig_VERBOSE) != 0 {
            sys_write_stderr_text(ptr[u8]("# clear sys.audit hooks\n"), ptr[u8]());
        }
        sys_audit_values(
            ts, ptr[u8]("cpython._PySys_ClearAuditHooks"), AUDIT_NO_ARGS, NULL, 0
        );
        _PyErr_Clear(ts);
        head = ptr[ptr[u8]](runtime + _PyRuntimeState_AUDIT_HOOKS_HEAD);
        e = ptr[SysAuditHookEntry](head.view(1)[0]);
        head.view(1)[0] = ptr[u8]();
        while e {
            n = ptr[SysAuditHookEntry](e.view(1)[0].next);
            PyMem_RawFree(ptr(e));
            e = n;
        }
    }  def PySys_AddAuditHook(hook: ptr, userData: ptr) -> i32 {
        runtime = ptr[u8](addressof(_PyRuntime));
        tstate = ptr[PyThreadState]();
        if ptr[i32](runtime + _PyRuntimeState_INITIALIZED).view(1)[0] != 0 {
            tstate = thread_state();
        }
        if tstate {
            if sys_audit_values(
                tstate, ptr[u8]("sys.addaudithook"), AUDIT_NO_ARGS, NULL, 0
            )
                < 0 {
                if _PyErr_ExceptionMatches(tstate, PyExc_RuntimeError) != 0 {
                    _PyErr_Clear(tstate);
                    return 0;
                }
                return -1;
            }
        }
        e = ptr[SysAuditHookEntry](PyMem_RawMalloc(u64(24)));
        if not e {
            if tstate {
                _PyErr_NoMemory(ptr(tstate));
            }
            return -1;
        }
        e.view(1)[0].next = ptr();
        e.view(1)[0].hookCFunction = int(hook);
        e.view(1)[0].userData = userData;
        mutex = ptr[PyMutex](runtime + _PyRuntimeState_AUDIT_HOOKS_MUTEX);
        PyMutex_Lock(mutex);
        add_audit_hook_entry_unlocked(runtime, e);
        PyMutex_Unlock(mutex);
        return 0;
    }  def _PySys_GetSizeOf(o: ptr[PyObject]) -> u64 {
        tstate = thread_state();
        if PyType_Ready(ptr[PyObject](object_type(o))) < 0 {
            return ~u64(0);
        }
        method = _PyObject_LookupSpecial(o, py_id(_Py_ID___sizeof__));
        res = NULL;
        if not method {
            if not exception_raised(tstate) {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8]("Type %.100s doesn't define __sizeof__"),
                    object_type(o).view(1)[0].tp_name
                );
            }
        } else {
            res = PyObject_CallNoArgs(method);
            object_decref(method);
        }
        if not res {
            return ~u64(0);
        }
        size = PyLong_AsSsize_t(res);
        object_decref(res);
        if size == -1 and exception_raised(tstate) {
            return ~u64(0);
        }
        if size < 0 {
            _PyErr_SetString(
                tstate, PyExc_ValueError, ptr[u8]("__sizeof__() should return >= 0")
            );
            return ~u64(0);
        }
        presize: i64 = 0;
        if not object_is_type(o, ptr[PyTypeObject](addressof(PyType_Type)))
            or type_has_feature(ptr[PyTypeObject](o), Py_TPFLAGS_HEAPTYPE) {
            presize = type_preheader_size(object_type(o));
        }
        return u64(size) + u64(presize);
    }  def PyUnstable_PerfMapState_Init -> i32 {
        slots: own SysStack = SysStack();
        filename = ptr[u8](jacpy_stack_address(&mut slots));
        pid = getpid();
        flags = O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_CLOEXEC;
        snprintf(filename, u64(99), ptr[u8]("/tmp/perf-%jd.map"), i64(pid));
        fd = open(filename, flags, i32(384));
        if fd == -1 {
            return -1;
        }
        statics = addressof(sys_statics);
        statics.view(1)[0].perf_map = fdopen(fd, ptr[u8]("a"));
        if not statics.view(1)[0].perf_map {
            close(fd);
            return -1;
        }
        statics.view(1)[0].map_lock = PyThread_allocate_lock();
        if not statics.view(1)[0].map_lock {
            fclose(statics.view(1)[0].perf_map);
            return -2;
        }
        return 0;
    }  def PyUnstable_WritePerfMapEntry(
        code_addr: ptr, code_size: u32, entry_name: ptr[u8]
    ) -> i32 {
        statics = addressof(sys_statics);
        if not statics.view(1)[0].perf_map {
            ret = PyUnstable_PerfMapState_Init();
            if ret != 0 {
                return ret;
            }
        }
        PyThread_acquire_lock(statics.view(1)[0].map_lock, 1);
        fprintf(
            statics.view(1)[0].perf_map,
            ptr[u8]("%lx %x %s\n"),
            u64(int(code_addr)),
            code_size,
            entry_name
        );
        fflush(statics.view(1)[0].perf_map);
        PyThread_release_lock(statics.view(1)[0].map_lock);
        return 0;
    }  def PyUnstable_PerfMapState_Fini {
        statics = addressof(sys_statics);
        if statics.view(1)[0].perf_map {
            PyThread_acquire_lock(statics.view(1)[0].map_lock, 1);
            fclose(statics.view(1)[0].perf_map);
            PyThread_release_lock(statics.view(1)[0].map_lock);
            PyThread_free_lock(statics.view(1)[0].map_lock);
            statics.view(1)[0].perf_map = ptr();
        }
    }  def PyUnstable_CopyPerfMapFile(parent_filename: ptr[u8]) -> i32 {
        statics = addressof(sys_statics);
        if not statics.view(1)[0].perf_map {
            ret = PyUnstable_PerfMapState_Init();
            if ret != 0 {
                return ret;
            }
        }
        from_ = fopen(parent_filename, ptr[u8]("r"));
        if not from_ {
            return -1;
        }
        buf = PyMem_RawMalloc(u64(4096));
        if not buf {
            fclose(from_);
            return -1;
        }
        PyThread_acquire_lock(statics.view(1)[0].map_lock, 1);
        result: i32 = 0;
        while True {
            bytes_read = fread(buf, u64(1), u64(4096), from_);
            if bytes_read == u64(0) {
                if ferror(from_) != 0 {
                    result = -1;
                }
                break;
            }
            bytes_written = fwrite(
                buf, u64(1), bytes_read, statics.view(1)[0].perf_map
            );
            if bytes_written < bytes_read {
                result = -1;
                break;
            }
            if fflush(statics.view(1)[0].perf_map) != 0 {
                result = -1;
                break;
            }
            if bytes_read < u64(4096) and feof(from_) != 0 {
                break;
            }
        }
        fclose(from_);
        PyThread_release_lock(statics.view(1)[0].map_lock);
        PyMem_RawFree(buf);
        return result;
    }  def _PySys_ReadPreinitWarnOptions(options: ptr) -> PyStatus {
        ent = preinit_head(False);
        while ent {
            status = PyWideStringList_Append(options, ent.view(1)[0].value);
            if status._type != _PyStatus_TYPE_OK {
                return status;
            }
            ent = ptr[SysPreinitEntry](ent.view(1)[0].next);
        }
        _clear_preinit_entries(False);
        return status_ok();
    }  def _PySys_ReadPreinitXOptions(config: ptr[u8]) -> PyStatus {
        ent = preinit_head(True);
        while ent {
            status = PyWideStringList_Append(
                ptr(config + PyConfig_XOPTIONS), ent.view(1)[0].value
            );
            if status._type != _PyStatus_TYPE_OK {
                return status;
            }
            ent = ptr[SysPreinitEntry](ent.view(1)[0].next);
        }
        _clear_preinit_entries(True);
        return status_ok();
    }  def PySys_ResetWarnOptions {
        tstate = thread_state();
        if not tstate {
            _clear_preinit_entries(False);
            return;
        }
        (status, warnoptions) = sys_optional_attr(py_id(_Py_ID_warnoptions));
        if status < 0 {
            PyErr_Clear();
            return;
        }
        if warnoptions and list_check(warnoptions) {
            PyList_SetSlice(warnoptions, 0, object_size(warnoptions), NULL);
        }
        object_xdecref(warnoptions);
    }  def PySys_AddWarnOptionUnicode(option: ptr[PyObject]) {
        tstate = thread_state();
        ensure_tstate_not_null(ptr[u8]("PySys_AddWarnOptionUnicode"), tstate);
        if _PySys_AddWarnOptionWithError(tstate, option) < 0 {
            _PyErr_Clear(tstate);
        }
    }  def PySys_AddWarnOption(s: ptr[i32]) {
        tstate = thread_state();
        if not tstate {
            _append_preinit_entry(False, s);
            return;
        }
        unicode = PyUnicode_FromWideChar(s, -1);
        if not unicode {
            return;
        }
        PySys_AddWarnOptionUnicode(unicode);
        object_decref(unicode);
    }  def PySys_HasWarnOptions -> i32 {
        (status, warnoptions) = sys_optional_attr(py_id(_Py_ID_warnoptions));
        if status < 0 {
            PyErr_Clear();
            return 0;
        }
        r: i32 = 0;
        if warnoptions and list_check(warnoptions) and object_size(warnoptions) > 0 {
            r = 1;
        }
        object_xdecref(warnoptions);
        return r;
    }  def PySys_AddXOption(s: ptr[i32]) {
        tstate = thread_state();
        if not tstate {
            _append_preinit_entry(True, s);
            return;
        }
        if _PySys_AddXOptionWithError(s) < 0 {
            _PyErr_Clear(tstate);
        }
    }  def PySys_GetXOptions -> ptr[PyObject] {
        opts = get_xoptions(thread_state());
        object_xdecref(opts);
        return opts;
    }  def _PySys_SetFlagObj(pos: i64, value: ptr[PyObject]) -> i32 {
        flags = _PySys_GetRequiredAttrString(ptr[u8]("flags"));
        if not flags {
            return -1;
        }
        sys_set_flag(flags, pos, value);
        object_decref(flags);
        return 0;
    }  def _PySys_UpdateConfig(tstate: ptr[PyThreadState]) -> i32 {
        interp = tstate_interp(tstate);
        sysdict = interp_sysdict(interp);
        config = _PyInterpreterState_GetConfig(interp);
        if config_int(config, PyConfig_MODULE_SEARCH_PATHS_SET) != 0 {
            if not set_sys(
                sysdict,
                ptr[u8]("path"),
                _PyWideStringList_AsList(config + PyConfig_MODULE_SEARCH_PATHS)
            ) {
                return -1;
            }
        }
        if not copy_wstr(sysdict, ptr[u8]("executable"), config, PyConfig_EXECUTABLE)
            or not copy_wstr(
                sysdict, ptr[u8]("_base_executable"), config, PyConfig_BASE_EXECUTABLE
            )
            or not copy_wstr(sysdict, ptr[u8]("prefix"), config, PyConfig_PREFIX)
            or not copy_wstr(
                sysdict, ptr[u8]("base_prefix"), config, PyConfig_BASE_PREFIX
            )
            or not copy_wstr(
                sysdict, ptr[u8]("exec_prefix"), config, PyConfig_EXEC_PREFIX
            )
            or not copy_wstr(
                sysdict, ptr[u8]("base_exec_prefix"), config, PyConfig_BASE_EXEC_PREFIX
            )
            or not copy_wstr(
                sysdict, ptr[u8]("platlibdir"), config, PyConfig_PLATLIBDIR
            ) {
            return -1;
        }
        pycache_prefix = config_wstr(config, PyConfig_PYCACHE_PREFIX);
        if pycache_prefix {
            if not set_sys(
                sysdict,
                ptr[u8]("pycache_prefix"),
                PyUnicode_FromWideChar(pycache_prefix, -1)
            ) {
                return -1;
            }
        } elif PyDict_SetItemString(sysdict, ptr[u8]("pycache_prefix"), Py_None) < 0 {
            return -1;
        }
        if not set_sys(
            sysdict, ptr[u8]("argv"), _PyWideStringList_AsList(config + PyConfig_ARGV)
        )
            or not set_sys(
                sysdict,
                ptr[u8]("orig_argv"),
                _PyWideStringList_AsList(config + PyConfig_ORIG_ARGV)
            )
            or not set_sys(
                sysdict,
                ptr[u8]("warnoptions"),
                _PyWideStringList_AsList(config + PyConfig_WARNOPTIONS)
            )
            or not set_sys(
                sysdict, ptr[u8]("_xoptions"), _PyConfig_CreateXOptionsDict(config)
            ) {
            return -1;
        }
        stdlibdir = _Py_GetStdlibDir();
        if stdlibdir {
            if not set_sys(
                sysdict, ptr[u8]("_stdlib_dir"), PyUnicode_FromWideChar(stdlibdir, -1)
            ) {
                return -1;
            }
        } elif PyDict_SetItemString(sysdict, ptr[u8]("_stdlib_dir"), Py_None) < 0 {
            return -1;
        }
        flags = _PySys_GetRequiredAttrString(ptr[u8]("flags"));
        if not flags {
            return -1;
        }
        if set_flags_from_config(interp, flags) < 0 {
            object_decref(flags);
            return -1;
        }
        object_decref(flags);
        if not set_sys(
            sysdict,
            ptr[u8]("dont_write_bytecode"),
            PyBool_FromLong(not_flag(config_int(config, PyConfig_WRITE_BYTECODE)))
        ) {
            return -1;
        }
        if exception_raised(tstate) {
            return -1;
        }
        return 0;
    }  def _PySys_Create(
        tstate: ptr[PyThreadState], sysmod_p: ptr[ptr[PyObject]]
    ) -> PyStatus {
        interp = tstate_interp(tstate);
        modules = _PyImport_InitModules(interp);
        if not modules {
            return create_error();
        }
        sysmod = _PyModule_CreateInitialized(
            ptr[PyModuleDef](addressof(sysmodule)), PYTHON_API_VERSION
        );
        if not sysmod {
            return status_err(
                ptr[u8]("_PySys_Create"), ptr[u8]("failed to create a module object")
            );
        }
        sysdict = PyModule_GetDict(sysmod);
        if not sysdict {
            return create_error();
        }
        ptr[ptr[PyObject]](interp + PyInterpreterState_SYSDICT).view(1)[0] = object_new_ref(
            sysdict
        );
        sysdict_copy = PyDict_Copy(sysdict);
        ptr[ptr[PyObject]](interp + PyInterpreterState_SYSDICT_COPY).view(1)[0] = sysdict_copy;
        if not sysdict_copy {
            return create_error();
        }
        if PyDict_SetItemString(sysdict, ptr[u8]("modules"), modules) < 0 {
            return create_error();
        }
        status = _PySys_SetPreliminaryStderr(sysdict);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        status = _PySys_InitCore(tstate, sysdict);
        if status._type != _PyStatus_TYPE_OK {
            return status;
        }
        if _PyImport_FixupBuiltin(tstate, sysmod, ptr[u8]("sys"), modules) < 0 {
            return create_error();
        }
        monitoring = _Py_CreateMonitoringObject();
        if not monitoring {
            return create_error();
        }
        err = PyDict_SetItemString(sysdict, ptr[u8]("monitoring"), monitoring);
        object_decref(monitoring);
        if err < 0 {
            return create_error();
        }
        jit = _PyModule_CreateInitialized(
            ptr[PyModuleDef](addressof(jit_module)), PYTHON_API_VERSION
        );
        if not jit {
            return create_error();
        }
        err = PyDict_SetItemString(sysdict, ptr[u8]("_jit"), jit);
        object_decref(jit);
        if err != 0 {
            return create_error();
        }
        sysmod_p.view(1)[0] = sysmod;
        return status_ok();
    }  def _PySys_FiniTypes(interp: ptr[u8]) {
        _PyStructSequence_FiniBuiltin(
            ptr(interp), ptr[PyObject](addressof(VersionInfoType))
        );
        _PyStructSequence_FiniBuiltin(ptr(interp), ptr[PyObject](addressof(FlagsType)));
        _PyStructSequence_FiniBuiltin(
            ptr(interp), ptr[PyObject](addressof(Hash_InfoType))
        );
        _PyStructSequence_FiniBuiltin(
            ptr(interp), ptr[PyObject](addressof(AsyncGenHooksType))
        );
    }  def PySys_SetPath(path: ptr[i32]) {
        v = makepathobject(path, i32(58));
        if not v {
            _Py_FatalErrorFunc(
                ptr[u8]("PySys_SetPath"), ptr[u8]("can't create sys.path")
            );
        }
        if sys_set_object(current_interp(), py_id(_Py_ID_path), v) != 0 {
            _Py_FatalErrorFunc(
                ptr[u8]("PySys_SetPath"), ptr[u8]("can't assign sys.path")
            );
        }
        object_decref(v);
    }  def PySys_SetArgvEx(argc: i32, argv: ptr[ptr[i32]], updatepath: i32) {
        tstate = thread_state();
        count = argc;
        items = argv;
        if count < 1 or not items {
            items = empty_argv();
            count = 1;
        }
        av = make_sys_argv(count, items);
        if not av {
            _Py_FatalErrorFunc(
                ptr[u8]("PySys_SetArgvEx"), ptr[u8]("no mem for sys.argv")
            );
        }
        if sys_set_object_str(tstate_interp(tstate), ptr[u8]("argv"), av) != 0 {
            object_decref(av);
            _Py_FatalErrorFunc(
                ptr[u8]("PySys_SetArgvEx"), ptr[u8]("can't assign sys.argv")
            );
        }
        object_decref(av);
        if updatepath != 0 {
            sys_update_path0(count, items);
        }
    }  def PySys_SetArgv(argc: i32, argv: ptr[ptr[i32]]) {
        updatepath: i32 = 0;
        if Py_IsolatedFlag == 0 {
            updatepath = 1;
        }
        PySys_SetArgvEx(argc, argv, updatepath);
    }  def PySys_WriteStdout(format: ptr[u8], *va: VaList) {
        sys_write(py_id(_Py_ID_stdout), jacpy_stdio_stream(1), format, va);
    }  def PySys_WriteStderr(format: ptr[u8], *va: VaList) {
        sys_write(py_id(_Py_ID_stderr), jacpy_stdio_stream(2), format, va);
    }  def PySys_FormatStdout(format: ptr[u8], *va: VaList) {
        sys_format(py_id(_Py_ID_stdout), jacpy_stdio_stream(1), format, va);
    }  def PySys_FormatStderr(format: ptr[u8], *va: VaList) {
        sys_format(py_id(_Py_ID_stderr), jacpy_stdio_stream(2), format, va);
    }  def _PySys_SetIntMaxStrDigits(maxdigits: i32) -> i32 {
        if maxdigits != 0 and maxdigits < _PY_LONG_MAX_STR_DIGITS_THRESHOLD {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("maxdigits must be >= %d or 0 for unlimited"),
                _PY_LONG_MAX_STR_DIGITS_THRESHOLD
            );
            return -1;
        }
        if _PySys_SetFlagInt(SYS_FLAGS_INT_MAX_STR_DIGITS, maxdigits) < 0 {
            return -1;
        }
        interp = current_interp();
        ptr[i32](interp + PyInterpreterState_LONG_MAX_STR_DIGITS).view(1)[0] = maxdigits;
        ptr[i32](interp + PyInterpreterState_CONFIG_INT_MAX_STR_DIGITS).view(1)[0] = maxdigits;
        return 0;
    }
}

glob:priv SYS_FLAGS_INT_MAX_STR_DIGITS: Final[i64] = 17,
     AUDIT_NO_ARGS: Final[i32] = 0,
     AUDIT_OBJECT: Final[i32] = 1,
     AUDIT_TUPLE_OBJECT: Final[i32] = 2,
     AUDIT_INT: Final[i32] = 3,
     AUDIT_INT_OBJECT: Final[i32] = 4,
     STDLIB_MODULE_NAMES_COUNT: Final[i64] = 297,
     PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF;

def interp_sysdict(interp: ptr[u8]) -> ptr[PyObject];

def tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def interp_runtime(interp: ptr[u8]) -> ptr[u8];

def config_int(config: ptr[u8], offset: i64) -> i32;

def config_wstr(config: ptr[u8], offset: i64) -> ptr[i32];

def not_flag(value: i32) -> i64;

def none_ref -> ptr[PyObject];

def tp_name_of(op: ptr[PyObject]) -> ptr[u8];

def sys_optional_attr(name: ptr[PyObject]) -> (i32, ptr[PyObject]);

def sys_optional_attr_string(name: ptr[u8]) -> (i32, ptr[PyObject]);

def sys_set_object(interp: ptr[u8], key: ptr[PyObject], v: ptr[PyObject]) -> i32;

def sys_set_object_str(interp: ptr[u8], name: ptr[u8], v: ptr[PyObject]) -> i32;

def should_audit(interp: ptr[u8]) -> bool;

def call_method_one_arg(
    obj_: ptr[PyObject], name: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def audit_call_hooks(
    ts: ptr[PyThreadState], interp: ptr[u8], event: ptr[u8], eventArgs: ptr[PyObject]
) -> i32;

def sys_audit_finish(
    ts: ptr[PyThreadState],
    interp: ptr[u8],
    event: ptr[u8],
    eventArgs_in: ptr[PyObject],
    exc: ptr[PyObject]
) -> i32;

def sys_audit_tstate(
    ts: ptr[PyThreadState], event: ptr[u8], argFormat: ptr[u8], vargs: VaList
) -> i32;

def sys_audit_values(
    ts: ptr[PyThreadState], event: ptr[u8], kind: i32, obj_: ptr[PyObject], n: i32
) -> i32;

def add_audit_hook_entry_unlocked(runtime: ptr[u8], ent: ptr[SysAuditHookEntry]);

def sys_addaudithook_impl(module: ptr[PyObject], hook: ptr[PyObject]) -> ptr[PyObject];

def sys_addaudithook(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_audit_impl(
    module: ptr[PyObject], event: ptr[u8], args: ptr[PyObject]
) -> ptr[PyObject];

def sys_audit(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def breakpointhook_warn(tstate: ptr[PyThreadState], envar: ptr[u8]) -> ptr[PyObject];

def sys_breakpointhook(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, keywords: ptr[PyObject]
) -> ptr[PyObject];

def sys_displayhook_unencodable(outf: ptr[PyObject], o: ptr[PyObject]) -> i32;

def displayhook_write_encoded(
    outf: ptr[PyObject], o: ptr[PyObject], stdout_encoding: ptr[PyObject]
) -> i32;

def sys_displayhook(module: ptr[PyObject], o: ptr[PyObject]) -> ptr[PyObject];

def sys_excepthook_impl(
    module: ptr[PyObject],
    exctype: ptr[PyObject],
    value: ptr[PyObject],
    traceback: ptr[PyObject]
) -> ptr[PyObject];

def sys_excepthook(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def sys_exception_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_exception(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def sys_exc_info_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_exc_info(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def sys_unraisablehook(
    module: ptr[PyObject], unraisable: ptr[PyObject]
) -> ptr[PyObject];

def sys_exit_impl(module: ptr[PyObject], status: ptr[PyObject]) -> ptr[PyObject];

def sys_exit(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def get_utf8_unicode -> ptr[PyObject];

def sys_getdefaultencoding_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_getdefaultencoding(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_getfilesystemencoding_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_getfilesystemencoding(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_getfilesystemencodeerrors_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_getfilesystemencodeerrors(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_intern_impl(module: ptr[PyObject], s: ptr[PyObject]) -> ptr[PyObject];

def sys_intern(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sys__is_interned_impl(module: ptr[PyObject], string: ptr[PyObject]) -> i32;

def sys__is_interned(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sys__is_immortal_impl(module: ptr[PyObject], op: ptr[PyObject]) -> i32;

def sys__is_immortal(module: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject];

def what_string(what: i32) -> ptr[PyObject];

def frame_trace_slot(frame: ptr[PyObject]) -> ptr[ptr[PyObject]];

def call_trampoline(
    tstate: ptr[PyThreadState],
    callback: ptr[PyObject],
    frame: ptr[PyObject],
    what: i32,
    arg: ptr[PyObject]
) -> ptr[PyObject];

def profile_trampoline(
    self_: ptr[PyObject], frame: ptr[PyObject], what: i32, arg: ptr[PyObject]
) -> i32;

def trace_trampoline(
    self_: ptr[PyObject], frame: ptr[PyObject], what: i32, arg: ptr[PyObject]
) -> i32;

def sys_settrace(module: ptr[PyObject], function: ptr[PyObject]) -> ptr[PyObject];

def sys__settraceallthreads(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def sys_gettrace_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_gettrace(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def sys_setprofile(module: ptr[PyObject], function: ptr[PyObject]) -> ptr[PyObject];

def sys__setprofileallthreads(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def sys_getprofile_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_getprofile(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def sys_setswitchinterval_impl(module: ptr[PyObject], interval: f64) -> ptr[PyObject];

def sys_setswitchinterval(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sys_getswitchinterval_impl(module: ptr[PyObject]) -> f64;

def sys_getswitchinterval(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_setrecursionlimit_impl(module: ptr[PyObject], new_limit: i32) -> ptr[PyObject];

def sys_setrecursionlimit(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sys_set_coroutine_origin_tracking_depth_impl(
    module: ptr[PyObject], depth: i32
) -> ptr[PyObject];

def sys_set_coroutine_origin_tracking_depth(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_get_coroutine_origin_tracking_depth_impl(module: ptr[PyObject]) -> i32;

def sys_get_coroutine_origin_tracking_depth(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_set_asyncgen_hooks(
    module: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject];

def sys_get_asyncgen_hooks_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_get_asyncgen_hooks(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def struct_seq_put(seq: ptr[PyObject], pos: i64, item: ptr[PyObject]) -> bool;

def get_hash_info(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def sys_getrecursionlimit_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_getrecursionlimit(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_setdlopenflags_impl(module: ptr[PyObject], new_val: i32) -> ptr[PyObject];

def sys_setdlopenflags(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sys_getdlopenflags_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_getdlopenflags(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def sys_get_int_max_str_digits_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_get_int_max_str_digits(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_set_int_max_str_digits_impl(
    module: ptr[PyObject], maxdigits: i32
) -> ptr[PyObject];

def sys_set_int_max_str_digits(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_getsizeof(
    module: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def sys_getrefcount_impl(module: ptr[PyObject], object_: ptr[PyObject]) -> i64;

def sys_getrefcount(module: ptr[PyObject], object_: ptr[PyObject]) -> ptr[PyObject];

def sys_getallocatedblocks_impl(module: ptr[PyObject]) -> i64;

def sys_getallocatedblocks(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_getunicodeinternedsize_impl(module: ptr[PyObject], _only_immortal: i32) -> i64;

def sys_getunicodeinternedsize(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys__getframe_impl(module: ptr[PyObject], depth: i32) -> ptr[PyObject];

def sys__getframe(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def sys__current_frames_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys__current_frames(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys__current_exceptions_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys__current_exceptions(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_call_tracing_impl(
    module: ptr[PyObject], func: ptr[PyObject], funcargs: ptr[PyObject]
) -> ptr[PyObject];

def sys_call_tracing(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def sys__debugmallocstats_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys__debugmallocstats(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys__clear_type_cache_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys__clear_type_cache(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys__clear_internal_caches_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys__clear_internal_caches(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_is_finalizing_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_is_finalizing(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def sys_activate_stack_trampoline_impl(
    module: ptr[PyObject], backend: ptr[u8]
) -> ptr[PyObject];

def sys_activate_stack_trampoline(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def sys_deactivate_stack_trampoline_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_deactivate_stack_trampoline(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_is_stack_trampoline_active_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_is_stack_trampoline_active(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_is_remote_debug_enabled_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys_is_remote_debug_enabled(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys_remote_exec_impl(
    module: ptr[PyObject], pid: i32, script: ptr[PyObject]
) -> ptr[PyObject];

def sys_remote_exec(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys__dump_tracelets_impl(
    module: ptr[PyObject], outpath: ptr[PyObject]
) -> ptr[PyObject];

def sys__dump_tracelets(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys__getframemodulename_impl(module: ptr[PyObject], depth: i32) -> ptr[PyObject];

def sys__getframemodulename(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys__get_cpu_count_config_impl(module: ptr[PyObject]) -> i32;

def sys__get_cpu_count_config(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def sys__baserepl_impl(module: ptr[PyObject]) -> ptr[PyObject];

def sys__baserepl(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def sys__clear_type_descriptors_impl(
    module: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def sys__clear_type_descriptors(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def sys__is_gil_enabled_impl(module: ptr[PyObject]) -> i32;

def sys__is_gil_enabled(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def list_builtin_module_names -> ptr[PyObject];

def list_stdlib_module_names -> ptr[PyObject];

def preinit_head(xoptions: bool) -> ptr[SysPreinitEntry];

def set_preinit_head(xoptions: bool, ent: ptr[SysPreinitEntry]);

def _alloc_preinit_entry(value: ptr[i32]) -> ptr[SysPreinitEntry];

def _append_preinit_entry(xoptions: bool, value: ptr[i32]) -> i32;

def _clear_preinit_entries(xoptions: bool);

def get_warnoptions(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def _PySys_AddWarnOptionWithError(
    tstate: ptr[PyThreadState], option: ptr[PyObject]
) -> i32;

def get_xoptions(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def _PySys_AddXOptionWithError(s: ptr[i32]) -> i32;

def sys_set_flag(flags: ptr[PyObject], pos: i64, value: ptr[PyObject]);

def _PySys_SetFlagInt(pos: i64, value: i32) -> i32;

def set_flag_value(flags: ptr[PyObject], pos: i64, value: ptr[PyObject]) -> bool;

def set_flag_int(flags: ptr[PyObject], pos: i64, value: i64) -> bool;

def set_flags_from_config(interp: ptr[u8], flags: ptr[PyObject]) -> i32;

def make_flags(interp: ptr[u8]) -> ptr[PyObject];

def release_level_name -> ptr[u8];

def make_version_info(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def multiarch_name -> ptr[u8];

def impl_info_put(
    impl_info: ptr[PyObject], key: ptr[u8], value: ptr[PyObject]
) -> bool;

def make_impl_info(version_info: ptr[PyObject]) -> ptr[PyObject];

def set_sys(sysdict: ptr[PyObject], key: ptr[u8], v: ptr[PyObject]) -> bool;

def set_sys_from_string(sysdict: ptr[PyObject], key: ptr[u8], value: ptr[u8]) -> bool;

def copy_sys_attr(sysdict: ptr[PyObject], tokey: ptr[u8], fromkey: ptr[u8]) -> bool;

def copy_wstr(
    sysdict: ptr[PyObject], key: ptr[u8], config: ptr[u8], offset: i64
) -> bool;

def ensure_info_type(
    interp: ptr[u8], type: ptr[PyTypeObject], desc: ptr[PyStructSequence_Desc]
) -> bool;

def init_core_error -> PyStatus;

def init_core_type_error -> PyStatus;

def _PySys_InitCore(tstate: ptr[PyThreadState], sysdict: ptr[PyObject]) -> PyStatus;

def _PySys_SetPreliminaryStderr(sysdict: ptr[PyObject]) -> PyStatus;

def create_error -> PyStatus;

def _jit_is_available_impl(module: ptr[PyObject]) -> i32;

def _jit_is_available(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def _jit_is_enabled_impl(module: ptr[PyObject]) -> i32;

def _jit_is_enabled(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def _jit_is_active_impl(module: ptr[PyObject]) -> i32;

def _jit_is_active(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def makepathobject(path: ptr[i32], delim: i32) -> ptr[PyObject];

def make_sys_argv(argc: i32, argv: ptr[ptr[i32]]) -> ptr[PyObject];

def empty_argv -> ptr[ptr[i32]];

def sys_update_path0(argc: i32, argv: ptr[ptr[i32]]);

def sys_pyfile_write_unicode(unicode: ptr[PyObject], file: ptr[PyObject]) -> i32;

def sys_pyfile_write(text: ptr[u8], file: ptr[PyObject]) -> i32;

def sys_write(key: ptr[PyObject], fp: ptr, format: ptr[u8], va: VaList);

def sys_write_stderr_text(format: ptr[u8], text: ptr[u8]);

def sys_write_buffer(
    tstate: ptr[PyThreadState],
    key: ptr[PyObject],
    fp: ptr,
    buffer: ptr[u8],
    written: i32
);

def sys_format(key: ptr[PyObject], fp: ptr, format: ptr[u8], va: VaList);

impl interp_sysdict(interp: ptr[u8]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](interp + PyInterpreterState_SYSDICT).view(1)[0];
}

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl interp_runtime(interp: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
}

impl config_int(config: ptr[u8], offset: i64) -> i32 {
    return ptr[i32](config + offset).view(1)[0];
}

impl config_wstr(config: ptr[u8], offset: i64) -> ptr[i32] {
    return ptr[ptr[i32]](config + offset).view(1)[0];
}

impl not_flag(value: i32) -> i64 {
    if value == 0 {
        return 1;
    }
    return 0;
}

impl none_ref -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl tp_name_of(op: ptr[PyObject]) -> ptr[u8] {
    return object_type(op).view(1)[0].tp_name;
}

impl sys_optional_attr(name: ptr[PyObject]) -> (i32, ptr[PyObject]) {
    if not unicode_check(name) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("attribute name must be string, not '%.200s'"),
            tp_name_of(name)
        );
        return (i32(-1), NULL);
    }
    sysdict = interp_sysdict(tstate_interp(thread_state()));
    if not sysdict {
        return (i32(0), NULL);
    }
    value = NULL;
    status = PyDict_GetItemRef(sysdict, name, &mut value);
    return (status, value);
}

impl sys_optional_attr_string(name: ptr[u8]) -> (i32, ptr[PyObject]) {
    sysdict = interp_sysdict(tstate_interp(thread_state()));
    if not sysdict {
        return (i32(0), NULL);
    }
    value = NULL;
    status = PyDict_GetItemStringRef(sysdict, name, &mut value);
    return (status, value);
}

impl sys_set_object(interp: ptr[u8], key: ptr[PyObject], v: ptr[PyObject]) -> i32 {
    if not key {
        return -1;
    }
    sd = interp_sysdict(interp);
    if not sd {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("no sys module"));
        return -1;
    }
    if not v {
        if PyDict_Pop(sd, key, None) < 0 {
            return -1;
        }
        return 0;
    }
    return PyDict_SetItem(sd, key, v);
}

impl sys_set_object_str(interp: ptr[u8], name: ptr[u8], v: ptr[PyObject]) -> i32 {
    key = PyUnicode_InternFromString(name) if v else PyUnicode_FromString(name);
    r = sys_set_object(interp, key, v);
    object_xdecref(key);
    return r;
}

impl should_audit(interp: ptr[u8]) -> bool {
    if not interp {
        return False;
    }
    runtime = interp_runtime(interp);
    if ptr[ptr[u8]](runtime + _PyRuntimeState_AUDIT_HOOKS_HEAD).view(1)[0] {
        return True;
    }
    if ptr[ptr[PyObject]](interp + PyInterpreterState_AUDIT_HOOKS).view(1)[0] {
        return True;
    }
    return False;
}

impl call_method_one_arg(
    obj_: ptr[PyObject], name: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = obj_;
    stack.view(2)[1] = arg;
    return PyObject_VectorcallMethod(
        name, stack, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl audit_call_hooks(
    ts: ptr[PyThreadState], interp: ptr[u8], event: ptr[u8], eventArgs: ptr[PyObject]
) -> i32 {
    runtime = interp_runtime(interp);
    e = ptr[SysAuditHookEntry](
        ptr[ptr[u8]](runtime + _PyRuntimeState_AUDIT_HOOKS_HEAD).view(1)[0]
    );
    while e {
        if e.view(1)[0].hookCFunction(event, eventArgs, e.view(1)[0].userData) < 0 {
            return -1;
        }
        e = ptr[SysAuditHookEntry](e.view(1)[0].next);
    }
    audit_hooks = ptr[ptr[PyObject]](interp + PyInterpreterState_AUDIT_HOOKS).view(1)[
        0
    ];
    if not audit_hooks {
        return 0;
    }
    eventName = PyUnicode_FromString(event);
    if not eventName {
        return -1;
    }
    hooks = PyObject_GetIter(audit_hooks);
    if not hooks {
        object_decref(eventName);
        return -1;
    }
    PyThreadState_EnterTracing(ts);
    slots: own SysStack = SysStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    hook = PyIter_Next(hooks);
    while hook {
        o = NULL;
        canTrace = PyObject_GetOptionalAttr(hook, py_id(_Py_ID___cantrace__), &mut o);
        if o {
            canTrace = PyObject_IsTrue(o);
            object_decref(o);
        }
        if canTrace < 0 {
            break;
        }
        if canTrace != 0 {
            PyThreadState_LeaveTracing(ts);
        }
        stack.view(2)[0] = eventName;
        stack.view(2)[1] = eventArgs;
        o = vectorcall_tstate(ts, hook, stack, u64(2), NULL);
        if canTrace != 0 {
            PyThreadState_EnterTracing(ts);
        }
        if not o {
            break;
        }
        object_decref(o);
        object_decref(hook);
        hook = PyIter_Next(hooks);
    }
    PyThreadState_LeaveTracing(ts);
    object_xdecref(hook);
    object_decref(hooks);
    object_decref(eventName);
    if exception_raised(ts) {
        return -1;
    }
    return 0;
}

impl sys_audit_finish(
    ts: ptr[PyThreadState],
    interp: ptr[u8],
    event: ptr[u8],
    eventArgs_in: ptr[PyObject],
    exc: ptr[PyObject]
) -> i32 {
    eventArgs = eventArgs_in;
    if eventArgs and not tuple_check(eventArgs) {
        argTuple = PyTuple_Pack(1, eventArgs);
        object_decref(eventArgs);
        eventArgs = argTuple;
    }
    res: i32 = -1;
    if eventArgs {
        res = audit_call_hooks(ts, interp, event, eventArgs);
        object_decref(eventArgs);
    }
    if res == 0 {
        _PyErr_SetRaisedException(ts, exc);
    } else {
        object_xdecref(exc);
    }
    return res;
}

impl sys_audit_tstate(
    ts: ptr[PyThreadState], event: ptr[u8], argFormat: ptr[u8], vargs: VaList
) -> i32 {
    if not ts {
        return 0;
    }
    interp = tstate_interp(ts);
    if not should_audit(interp) {
        return 0;
    }
    exc = _PyErr_GetRaisedException(ts);
    eventArgs = NULL;
    if argFormat and argFormat.view(1)[0] != u8(0) {
        eventArgs = Py_VaBuildValue(argFormat, ptr(vargs));
    } else {
        eventArgs = PyTuple_New(0);
    }
    return sys_audit_finish(ts, interp, event, eventArgs, exc);
}

impl sys_audit_values(
    ts: ptr[PyThreadState], event: ptr[u8], kind: i32, obj_: ptr[PyObject], n: i32
) -> i32 {
    if not ts {
        return 0;
    }
    interp = tstate_interp(ts);
    if not should_audit(interp) {
        return 0;
    }
    exc = _PyErr_GetRaisedException(ts);
    eventArgs = NULL;
    if kind == AUDIT_OBJECT {
        eventArgs = Py_BuildValue(ptr[u8]("O"), obj_);
    } elif kind == AUDIT_TUPLE_OBJECT {
        eventArgs = Py_BuildValue(ptr[u8]("(O)"), obj_);
    } elif kind == AUDIT_INT {
        eventArgs = Py_BuildValue(ptr[u8]("i"), n);
    } elif kind == AUDIT_INT_OBJECT {
        eventArgs = Py_BuildValue(ptr[u8]("iO"), n, obj_);
    } else {
        eventArgs = PyTuple_New(0);
    }
    return sys_audit_finish(ts, interp, event, eventArgs, exc);
}

impl add_audit_hook_entry_unlocked(runtime: ptr[u8], ent: ptr[SysAuditHookEntry]) {
    head = ptr[ptr[u8]](runtime + _PyRuntimeState_AUDIT_HOOKS_HEAD);
    if not head.view(1)[0] {
        head.view(1)[0] = ptr[u8](ent);
    } else {
        last = ptr[SysAuditHookEntry](head.view(1)[0]);
        while last.view(1)[0].next {
            last = ptr[SysAuditHookEntry](last.view(1)[0].next);
        }
        last.view(1)[0].next = ptr(ent);
    }
}

impl sys_addaudithook_impl(
    module: ptr[PyObject], hook: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    if sys_audit_values(tstate, ptr[u8]("sys.addaudithook"), AUDIT_NO_ARGS, NULL, 0)
        < 0 {
        if _PyErr_ExceptionMatches(tstate, PyExc_Exception) != 0 {
            _PyErr_Clear(tstate);
            return none_ref();
        }
        return NULL;
    }
    interp = tstate_interp(tstate);
    slot = ptr[ptr[PyObject]](interp + PyInterpreterState_AUDIT_HOOKS);
    if not slot.view(1)[0] {
        hooks = PyList_New(0);
        slot.view(1)[0] = hooks;
        if not hooks {
            return NULL;
        }
        PyObject_GC_UnTrack(ptr(hooks));
    }
    if PyList_Append(slot.view(1)[0], hook) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_addaudithook(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(addaudithook_parser),
        1,
        1,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut slots))
    );
    if not fast {
        return NULL;
    }
    return sys_addaudithook_impl(module, arg_at(fast, 0));
}

impl sys_audit_impl(
    module: ptr[PyObject], event: ptr[u8], args: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    ensure_tstate_not_null(ptr[u8]("sys_audit_impl"), tstate);
    if not should_audit(tstate_interp(tstate)) {
        return none_ref();
    }
    res = sys_audit_values(tstate, event, AUDIT_OBJECT, args, 0);
    if res < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_audit(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("audit"), nargs, 1, PY_SSIZE_T_MAX) == 0 {
        return NULL;
    }
    first = arg_at(args, 0);
    if not unicode_check(first) {
        _PyArg_BadArgument(
            ptr[u8]("audit"), ptr[u8]("argument 1"), ptr[u8]("str"), first
        );
        return NULL;
    }
    event_length: i64 = 0;
    event = PyUnicode_AsUTF8AndSize(first, &mut event_length);
    if not event {
        return NULL;
    }
    if strlen(event) != u64(event_length) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("embedded null character"));
        return NULL;
    }
    clinic_args = _PyTuple_FromArray(args + 1, nargs - 1);
    if not clinic_args {
        return NULL;
    }
    return_value = sys_audit_impl(module, event, clinic_args);
    object_decref(clinic_args);
    return return_value;
}

impl breakpointhook_warn(tstate: ptr[PyThreadState], envar: ptr[u8]) -> ptr[PyObject] {
    _PyErr_Clear(tstate);
    status = PyErr_WarnFormat(
        PyExc_RuntimeWarning,
        0,
        ptr[u8]("Ignoring unimportable $PYTHONBREAKPOINT: \"%s\""),
        envar
    );
    PyMem_RawFree(ptr(envar));
    if status < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_breakpointhook(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, keywords: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    envar = Py_GETENV(ptr[u8]("PYTHONBREAKPOINT"));
    if not envar or strlen(envar) == u64(0) {
        envar = ptr[u8]("pdb.set_trace");
    } elif strcmp(envar, ptr[u8]("0")) == 0 {
        return none_ref();
    }
    envar = _PyMem_RawStrdup(envar);
    if not envar {
        _PyErr_NoMemory(ptr(tstate));
        return NULL;
    }
    last_dot = strrchr(envar, i32(46));
    attrname = ptr[u8]();
    modulepath = NULL;
    if not last_dot {
        modulepath = PyUnicode_FromString(ptr[u8]("builtins"));
        attrname = envar;
    } elif last_dot != envar {
        modulepath = PyUnicode_FromStringAndSize(
            envar, i64(int(last_dot) - int(envar))
        );
        attrname = last_dot + 1;
    } else {
        return breakpointhook_warn(tstate, envar);
    }
    if not modulepath {
        PyMem_RawFree(ptr(envar));
        return NULL;
    }
    module_obj = PyImport_Import(modulepath);
    object_decref(modulepath);
    if not module_obj {
        if _PyErr_ExceptionMatches(tstate, PyExc_ImportError) != 0 {
            return breakpointhook_warn(tstate, envar);
        }
        PyMem_RawFree(ptr(envar));
        return NULL;
    }
    hook = PyObject_GetAttrString(module_obj, attrname);
    object_decref(module_obj);
    if not hook {
        if _PyErr_ExceptionMatches(tstate, PyExc_AttributeError) != 0 {
            return breakpointhook_warn(tstate, envar);
        }
        PyMem_RawFree(ptr(envar));
        return NULL;
    }
    PyMem_RawFree(ptr(envar));
    retval = PyObject_Vectorcall(hook, args, u64(nargs), keywords);
    object_decref(hook);
    return retval;
}

impl sys_displayhook_unencodable(outf: ptr[PyObject], o: ptr[PyObject]) -> i32 {
    stdout_encoding = PyObject_GetAttr(outf, py_id(_Py_ID_encoding));
    if not stdout_encoding {
        return -1;
    }
    ret = displayhook_write_encoded(outf, o, stdout_encoding);
    object_decref(stdout_encoding);
    return ret;
}

impl displayhook_write_encoded(
    outf: ptr[PyObject], o: ptr[PyObject], stdout_encoding: ptr[PyObject]
) -> i32 {
    stdout_encoding_str = PyUnicode_AsUTF8(stdout_encoding);
    if not stdout_encoding_str {
        return -1;
    }
    repr_str = PyObject_Repr(o);
    if not repr_str {
        return -1;
    }
    encoded = PyUnicode_AsEncodedString(
        repr_str, stdout_encoding_str, ptr[u8]("backslashreplace")
    );
    object_decref(repr_str);
    if not encoded {
        return -1;
    }
    buffer = NULL;
    if PyObject_GetOptionalAttr(outf, py_id(_Py_ID_buffer), &mut buffer) < 0 {
        object_decref(encoded);
        return -1;
    }
    if buffer {
        result = call_method_one_arg(buffer, py_id(_Py_ID_write), encoded);
        object_decref(buffer);
        object_decref(encoded);
        if not result {
            return -1;
        }
        object_decref(result);
    } else {
        escaped_str = PyUnicode_FromEncodedObject(
            encoded, stdout_encoding_str, ptr[u8]("strict")
        );
        object_decref(encoded);
        if PyFile_WriteObject(escaped_str, outf, Py_PRINT_RAW) != 0 {
            object_xdecref(escaped_str);
            return -1;
        }
        object_xdecref(escaped_str);
    }
    return 0;
}

impl sys_displayhook(module: ptr[PyObject], o: ptr[PyObject]) -> ptr[PyObject] {
    tstate = thread_state();
    builtins = PyImport_GetModule(py_id(_Py_ID_builtins));
    if not builtins {
        if not exception_raised(tstate) {
            _PyErr_SetString(
                tstate, PyExc_RuntimeError, ptr[u8]("lost builtins module")
            );
        }
        return NULL;
    }
    object_decref(builtins);
    if o == Py_None {
        return none_ref();
    }
    if PyObject_SetAttr(builtins, latin1_char(u32(95)), Py_None) != 0 {
        return NULL;
    }
    outf = _PySys_GetRequiredAttr(py_id(_Py_ID_stdout));
    if not outf {
        return NULL;
    }
    if outf == Py_None {
        _PyErr_SetString(tstate, PyExc_RuntimeError, ptr[u8]("lost sys.stdout"));
        object_decref(outf);
        return NULL;
    }
    if PyFile_WriteObject(o, outf, 0) != 0 {
        if _PyErr_ExceptionMatches(tstate, PyExc_UnicodeEncodeError) != 0 {
            _PyErr_Clear(tstate);
            err = sys_displayhook_unencodable(outf, o);
            if err != 0 {
                object_decref(outf);
                return NULL;
            }
        } else {
            object_decref(outf);
            return NULL;
        }
    }
    if PyFile_WriteObject(latin1_char(u32(10)), outf, Py_PRINT_RAW) != 0 {
        object_decref(outf);
        return NULL;
    }
    object_decref(outf);
    if PyObject_SetAttr(builtins, latin1_char(u32(95)), o) != 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_excepthook_impl(
    module: ptr[PyObject],
    exctype: ptr[PyObject],
    value: ptr[PyObject],
    traceback: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_Display(NULL, value, traceback);
    return none_ref();
}

impl sys_excepthook(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("excepthook"), nargs, 3, 3) == 0 {
        return NULL;
    }
    return sys_excepthook_impl(
        module, arg_at(args, 0), arg_at(args, 1), arg_at(args, 2)
    );
}

impl sys_exception_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    err_info = _PyErr_GetTopmostException(thread_state());
    exc_value = ptr[ptr[PyObject]](err_info + _PyErr_StackItem_EXC_VALUE).view(1)[0];
    if exc_value {
        return object_new_ref(exc_value);
    }
    return none_ref();
}

impl sys_exception(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return sys_exception_impl(module);
}

impl sys_exc_info_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    err_info = _PyErr_GetTopmostException(thread_state());
    return _PyErr_StackItemToExcInfoTuple(err_info);
}

impl sys_exc_info(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return sys_exc_info_impl(module);
}

impl sys_unraisablehook(
    module: ptr[PyObject], unraisable: ptr[PyObject]
) -> ptr[PyObject] {
    return _PyErr_WriteUnraisableDefaultHook(unraisable);
}

impl sys_exit_impl(module: ptr[PyObject], status: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetObject(PyExc_SystemExit, status);
    return NULL;
}

impl sys_exit(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("exit"), nargs, 0, 1) == 0 {
        return NULL;
    }
    status = Py_None;
    if nargs >= 1 {
        status = arg_at(args, 0);
    }
    return sys_exit_impl(module, status);
}

impl get_utf8_unicode -> ptr[PyObject] {
    return object_new_ref(py_id(_Py_STR_utf_8));
}

impl sys_getdefaultencoding_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return get_utf8_unicode();
}

impl sys_getdefaultencoding(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_getdefaultencoding_impl(module);
}

impl sys_getfilesystemencoding_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = current_interp();
    config = _PyInterpreterState_GetConfig(interp);
    encoding = config_wstr(config, PyConfig_FILESYSTEM_ENCODING);
    if wcscmp(encoding, addressof(sys_utf8_wide)) == 0 {
        return get_utf8_unicode();
    }
    u = PyUnicode_FromWideChar(encoding, -1);
    if not u {
        return NULL;
    }
    _PyUnicode_InternImmortal(interp, &mut u);
    return u;
}

impl sys_getfilesystemencoding(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_getfilesystemencoding_impl(module);
}

impl sys_getfilesystemencodeerrors_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = current_interp();
    config = _PyInterpreterState_GetConfig(interp);
    u = PyUnicode_FromWideChar(config_wstr(config, PyConfig_FILESYSTEM_ERRORS), -1);
    if not u {
        return NULL;
    }
    _PyUnicode_InternImmortal(interp, &mut u);
    return u;
}

impl sys_getfilesystemencodeerrors(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_getfilesystemencodeerrors_impl(module);
}

impl sys_intern_impl(module: ptr[PyObject], s: ptr[PyObject]) -> ptr[PyObject] {
    if unicode_check_exact(s) {
        interp = current_interp();
        object_incref(s);
        interned = s;
        _PyUnicode_InternMortal(interp, &mut interned);
        return interned;
    }
    PyErr_Format(PyExc_TypeError, ptr[u8]("can't intern %.400s"), tp_name_of(s));
    return NULL;
}

impl sys_intern(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(arg) {
        _PyArg_BadArgument(ptr[u8]("intern"), ptr[u8]("argument"), ptr[u8]("str"), arg);
        return NULL;
    }
    return sys_intern_impl(module, arg);
}

impl sys__is_interned_impl(module: ptr[PyObject], string: ptr[PyObject]) -> i32 {
    if unicode_is_interned(string) {
        return 1;
    }
    return 0;
}

impl sys__is_interned(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(arg) {
        _PyArg_BadArgument(
            ptr[u8]("_is_interned"), ptr[u8]("argument"), ptr[u8]("str"), arg
        );
        return NULL;
    }
    return_value = sys__is_interned_impl(module, arg);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl sys__is_immortal_impl(module: ptr[PyObject], op: ptr[PyObject]) -> i32 {
    return PyUnstable_IsImmortal(op);
}

impl sys__is_immortal(module: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject] {
    return_value = sys__is_immortal_impl(module, op);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl what_string(what: i32) -> ptr[PyObject] {
    if what == 0 {
        return py_id(_Py_ID_call);
    }
    if what == 1 {
        return py_id(_Py_ID_exception);
    }
    if what == 2 {
        return py_id(_Py_ID_line);
    }
    if what == 3 {
        return py_id(_Py_ID_return);
    }
    if what == 4 {
        return py_id(_Py_ID_c_call);
    }
    if what == 5 {
        return py_id(_Py_ID_c_exception);
    }
    if what == 6 {
        return py_id(_Py_ID_c_return);
    }
    return py_id(_Py_ID_opcode);
}

impl frame_trace_slot(frame: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](frame) + PyFrameObject_TRACE);
}

impl call_trampoline(
    tstate: ptr[PyThreadState],
    callback: ptr[PyObject],
    frame: ptr[PyObject],
    what: i32,
    arg: ptr[PyObject]
) -> ptr[PyObject] {
    value = arg;
    if not value {
        value = Py_None;
    }
    slots: own SysStack = SysStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(3)[0] = frame;
    stack.view(3)[1] = what_string(what);
    stack.view(3)[2] = value;
    return vectorcall_tstate(tstate, callback, stack, u64(3), NULL);
}

impl profile_trampoline(
    self_: ptr[PyObject], frame: ptr[PyObject], what: i32, arg: ptr[PyObject]
) -> i32 {
    tstate = thread_state();
    result = call_trampoline(tstate, self_, frame, what, arg);
    if not result {
        _PyEval_SetProfile(tstate, ptr(), NULL);
        return -1;
    }
    object_decref(result);
    return 0;
}

impl trace_trampoline(
    self_: ptr[PyObject], frame: ptr[PyObject], what: i32, arg: ptr[PyObject]
) -> i32 {
    slot = frame_trace_slot(frame);
    callback = self_;
    if what != PyTrace_CALL {
        callback = slot.view(1)[0];
    }
    if not callback {
        return 0;
    }
    tstate = thread_state();
    result = call_trampoline(tstate, callback, frame, what, arg);
    if not result {
        _PyEval_SetTrace(tstate, ptr(), NULL);
        old = slot.view(1)[0];
        slot.view(1)[0] = NULL;
        object_xdecref(old);
        return -1;
    }
    if result != Py_None {
        old = slot.view(1)[0];
        slot.view(1)[0] = result;
        object_xdecref(old);
    } else {
        object_decref(result);
    }
    return 0;
}

impl sys_settrace(module: ptr[PyObject], function: ptr[PyObject]) -> ptr[PyObject] {
    tstate = thread_state();
    if function == Py_None {
        if _PyEval_SetTrace(tstate, ptr(), NULL) < 0 {
            return NULL;
        }
    } elif _PyEval_SetTrace(tstate, ptr(trace_trampoline), function) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys__settraceallthreads(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    argument = NULL;
    func = ptr();
    if arg != Py_None {
        func = ptr(trace_trampoline);
        argument = arg;
    }
    if _PyEval_SetTraceAllThreads(current_interp(), func, argument) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_gettrace_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    tstate = thread_state();
    temp = ptr[ptr[PyObject]](ptr[u8](tstate) + PyThreadState_C_TRACEOBJ).view(1)[0];
    if not temp {
        temp = Py_None;
    }
    return object_new_ref(temp);
}

impl sys_gettrace(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return sys_gettrace_impl(module);
}

impl sys_setprofile(module: ptr[PyObject], function: ptr[PyObject]) -> ptr[PyObject] {
    tstate = thread_state();
    if function == Py_None {
        if _PyEval_SetProfile(tstate, ptr(), NULL) < 0 {
            return NULL;
        }
    } elif _PyEval_SetProfile(tstate, ptr(profile_trampoline), function) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys__setprofileallthreads(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    argument = NULL;
    func = ptr();
    if arg != Py_None {
        func = ptr(profile_trampoline);
        argument = arg;
    }
    if _PyEval_SetProfileAllThreads(current_interp(), func, argument) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_getprofile_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    tstate = thread_state();
    temp = ptr[ptr[PyObject]](ptr[u8](tstate) + PyThreadState_C_PROFILEOBJ).view(1)[0];
    if not temp {
        temp = Py_None;
    }
    return object_new_ref(temp);
}

impl sys_getprofile(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return sys_getprofile_impl(module);
}

impl sys_setswitchinterval_impl(module: ptr[PyObject], interval: f64) -> ptr[PyObject] {
    if interval <= 0.0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("switch interval must be strictly positive")
        );
        return NULL;
    }
    _PyEval_SetSwitchInterval(u64(1e6 * interval));
    return none_ref();
}

impl sys_setswitchinterval(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    interval = PyFloat_AsDouble(arg);
    if interval == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    return sys_setswitchinterval_impl(module, interval);
}

impl sys_getswitchinterval_impl(module: ptr[PyObject]) -> f64 {
    return 1e-6 * f64(_PyEval_GetSwitchInterval());
}

impl sys_getswitchinterval(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return_value = sys_getswitchinterval_impl(module);
    if return_value == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    return PyFloat_FromDouble(return_value);
}

impl sys_setrecursionlimit_impl(
    module: ptr[PyObject], new_limit: i32
) -> ptr[PyObject] {
    tstate = thread_state();
    if new_limit < 1 {
        _PyErr_SetString(
            tstate,
            PyExc_ValueError,
            ptr[u8]("recursion limit must be greater or equal than 1")
        );
        return NULL;
    }
    limit = ptr[i32](ptr[u8](tstate) + PyThreadState_PY_RECURSION_LIMIT).view(1)[0];
    remaining = ptr[i32](ptr[u8](tstate) + PyThreadState_PY_RECURSION_REMAINING).view(1)[
        0
    ];
    depth = limit - remaining;
    if depth >= new_limit {
        _PyErr_Format(
            tstate,
            PyExc_RecursionError,
            ptr[u8](
                "cannot set the recursion limit to %i at "
                "the recursion depth %i: the limit is too low"
            ),
            new_limit,
            depth
        );
        return NULL;
    }
    Py_SetRecursionLimit(new_limit);
    return none_ref();
}

impl sys_setrecursionlimit(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    new_limit = PyLong_AsInt(arg);
    if new_limit == -1 and PyErr_Occurred() {
        return NULL;
    }
    return sys_setrecursionlimit_impl(module, new_limit);
}

impl sys_set_coroutine_origin_tracking_depth_impl(
    module: ptr[PyObject], depth: i32
) -> ptr[PyObject] {
    if _PyEval_SetCoroutineOriginTrackingDepth(depth) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_set_coroutine_origin_tracking_depth(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(coroutine_depth_parser),
        1,
        1,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut slots))
    );
    if not fast {
        return NULL;
    }
    depth = PyLong_AsInt(arg_at(fast, 0));
    if depth == -1 and PyErr_Occurred() {
        return NULL;
    }
    return sys_set_coroutine_origin_tracking_depth_impl(module, depth);
}

impl sys_get_coroutine_origin_tracking_depth_impl(module: ptr[PyObject]) -> i32 {
    return _PyEval_GetCoroutineOriginTrackingDepth();
}

impl sys_get_coroutine_origin_tracking_depth(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return_value = sys_get_coroutine_origin_tracking_depth_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromLong(i64(return_value));
}

impl sys_set_asyncgen_hooks(
    module: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    firstiter = NULL;
    finalizer = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kw,
        ptr[u8]("|OO"),
        ptr(addressof(asyncgen_hooks_keywords)),
        &mut firstiter,
        &mut finalizer
    )
        == 0 {
        return NULL;
    }
    if finalizer and finalizer != Py_None {
        if PyCallable_Check(finalizer) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("callable finalizer expected, got %.50s"),
                tp_name_of(finalizer)
            );
            return NULL;
        }
    }
    if firstiter and firstiter != Py_None {
        if PyCallable_Check(firstiter) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("callable firstiter expected, got %.50s"),
                tp_name_of(firstiter)
            );
            return NULL;
        }
    }
    cur_finalizer = _PyEval_GetAsyncGenFinalizer();
    if finalizer and finalizer != Py_None {
        if _PyEval_SetAsyncGenFinalizer(finalizer) < 0 {
            return NULL;
        }
    } elif finalizer == Py_None and _PyEval_SetAsyncGenFinalizer(NULL) < 0 {
        return NULL;
    }
    if firstiter and firstiter != Py_None {
        if _PyEval_SetAsyncGenFirstiter(firstiter) < 0 {
            _PyEval_SetAsyncGenFinalizer(cur_finalizer);
            return NULL;
        }
    } elif firstiter == Py_None and _PyEval_SetAsyncGenFirstiter(NULL) < 0 {
        _PyEval_SetAsyncGenFinalizer(cur_finalizer);
        return NULL;
    }
    return none_ref();
}

impl sys_get_asyncgen_hooks_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    firstiter = _PyEval_GetAsyncGenFirstiter();
    finalizer = _PyEval_GetAsyncGenFinalizer();
    res = PyStructSequence_New(ptr[PyObject](addressof(AsyncGenHooksType)));
    if not res {
        return NULL;
    }
    if not firstiter {
        firstiter = Py_None;
    }
    if not finalizer {
        finalizer = Py_None;
    }
    PyStructSequence_SetItem(res, 0, object_new_ref(firstiter));
    PyStructSequence_SetItem(res, 1, object_new_ref(finalizer));
    return res;
}

impl sys_get_asyncgen_hooks(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_get_asyncgen_hooks_impl(module);
}

impl struct_seq_put(seq: ptr[PyObject], pos: i64, item: ptr[PyObject]) -> bool {
    if not item {
        return False;
    }
    PyStructSequence_SetItem(seq, pos, item);
    return True;
}

impl get_hash_info(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    hash_info = PyStructSequence_New(ptr[PyObject](addressof(Hash_InfoType)));
    if not hash_info {
        return NULL;
    }
    hashfunc = ptr[SysHashFuncDef](PyHash_GetFuncDef());
    if not struct_seq_put(hash_info, 0, PyLong_FromLong(64))
        or not struct_seq_put(hash_info, 1, PyLong_FromSsize_t(_PyHASH_MODULUS))
        or not struct_seq_put(hash_info, 2, PyLong_FromLong(_PyHASH_INF))
        or not struct_seq_put(hash_info, 3, PyLong_FromLong(0))
        or not struct_seq_put(hash_info, 4, PyLong_FromLong(_PyHASH_IMAG))
        or not struct_seq_put(
            hash_info, 5, PyUnicode_FromString(hashfunc.view(1)[0].name)
        )
        or not struct_seq_put(
            hash_info, 6, PyLong_FromLong(i64(hashfunc.view(1)[0].hash_bits))
        )
        or not struct_seq_put(
            hash_info, 7, PyLong_FromLong(i64(hashfunc.view(1)[0].seed_bits))
        )
        or not struct_seq_put(hash_info, 8, PyLong_FromLong(Py_HASH_CUTOFF)) {
        object_decref(hash_info);
        return NULL;
    }
    return hash_info;
}

impl sys_getrecursionlimit_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(Py_GetRecursionLimit()));
}

impl sys_getrecursionlimit(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_getrecursionlimit_impl(module);
}

impl sys_setdlopenflags_impl(module: ptr[PyObject], new_val: i32) -> ptr[PyObject] {
    _PyImport_SetDLOpenFlags(current_interp(), new_val);
    return none_ref();
}

impl sys_setdlopenflags(module: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    new_val = PyLong_AsInt(arg);
    if new_val == -1 and PyErr_Occurred() {
        return NULL;
    }
    return sys_setdlopenflags_impl(module, new_val);
}

impl sys_getdlopenflags_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(_PyImport_GetDLOpenFlags(current_interp())));
}

impl sys_getdlopenflags(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_getdlopenflags_impl(module);
}

impl sys_get_int_max_str_digits_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = current_interp();
    return PyLong_FromLong(
        i64(ptr[i32](interp + PyInterpreterState_LONG_MAX_STR_DIGITS).view(1)[0])
    );
}

impl sys_get_int_max_str_digits(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_get_int_max_str_digits_impl(module);
}

impl sys_set_int_max_str_digits_impl(
    module: ptr[PyObject], maxdigits: i32
) -> ptr[PyObject] {
    if _PySys_SetIntMaxStrDigits(maxdigits) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_set_int_max_str_digits(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(max_str_digits_parser),
        1,
        1,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut slots))
    );
    if not fast {
        return NULL;
    }
    maxdigits = PyLong_AsInt(arg_at(fast, 0));
    if maxdigits == -1 and PyErr_Occurred() {
        return NULL;
    }
    return sys_set_int_max_str_digits_impl(module, maxdigits);
}

impl sys_getsizeof(
    module: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    o = NULL;
    dflt = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O|O:getsizeof"),
        ptr(addressof(getsizeof_keywords)),
        &mut o,
        &mut dflt
    )
        == 0 {
        return NULL;
    }
    size = _PySys_GetSizeOf(o);
    if size == ~u64(0) and exception_raised(tstate) {
        if dflt and _PyErr_ExceptionMatches(tstate, PyExc_TypeError) != 0 {
            _PyErr_Clear(tstate);
            return object_new_ref(dflt);
        }
        return NULL;
    }
    return PyLong_FromSize_t(size);
}

impl sys_getrefcount_impl(module: ptr[PyObject], object_: ptr[PyObject]) -> i64 {
    return object_refcount(object_);
}

impl sys_getrefcount(module: ptr[PyObject], object_: ptr[PyObject]) -> ptr[PyObject] {
    return_value = sys_getrefcount_impl(module, object_);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(return_value);
}

impl sys_getallocatedblocks_impl(module: ptr[PyObject]) -> i64 {
    return _Py_GetGlobalAllocatedBlocks();
}

impl sys_getallocatedblocks(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return_value = sys_getallocatedblocks_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(return_value);
}

impl sys_getunicodeinternedsize_impl(
    module: ptr[PyObject], _only_immortal: i32
) -> i64 {
    if _only_immortal != 0 {
        return _PyUnicode_InternedSize_Immortal();
    }
    return _PyUnicode_InternedSize();
}

impl sys_getunicodeinternedsize(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    noptargs = nargs + kwnames_size(kwnames);
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(interned_size_parser),
        0,
        0,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut slots))
    );
    if not fast {
        return NULL;
    }
    only_immortal: i32 = 0;
    if noptargs != 0 {
        only_immortal = PyObject_IsTrue(arg_at(fast, 0));
        if only_immortal < 0 {
            return NULL;
        }
    }
    return_value = sys_getunicodeinternedsize_impl(module, only_immortal);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromSsize_t(return_value);
}

impl sys__getframe_impl(module: ptr[PyObject], depth: i32) -> ptr[PyObject] {
    tstate = thread_state();
    frame = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0];
    remaining: i32 = depth;
    if frame {
        while remaining > 0 {
            frame = frame_first_complete(
                frame_ptr(frame, _PyInterpreterFrame_PREVIOUS)
            );
            if not frame {
                break;
            }
            remaining -= 1;
        }
    }
    if not frame {
        _PyErr_SetString(
            tstate, PyExc_ValueError, ptr[u8]("call stack is not deep enough")
        );
        return NULL;
    }
    pyFrame = object_xnewref(frame_get_frame_object(frame));
    if pyFrame
        and sys_audit_values(
            tstate, ptr[u8]("sys._getframe"), AUDIT_TUPLE_OBJECT, pyFrame, 0
        )
            < 0 {
        object_decref(pyFrame);
        return NULL;
    }
    return pyFrame;
}

impl sys__getframe(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("_getframe"), nargs, 0, 1) == 0 {
        return NULL;
    }
    depth: i32 = 0;
    if nargs >= 1 {
        depth = PyLong_AsInt(arg_at(args, 0));
        if depth == -1 and PyErr_Occurred() {
            return NULL;
        }
    }
    return sys__getframe_impl(module, depth);
}

impl sys__current_frames_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyThread_CurrentFrames();
}

impl sys__current_frames(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys__current_frames_impl(module);
}

impl sys__current_exceptions_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyThread_CurrentExceptions();
}

impl sys__current_exceptions(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys__current_exceptions_impl(module);
}

impl sys_call_tracing_impl(
    module: ptr[PyObject], func: ptr[PyObject], funcargs: ptr[PyObject]
) -> ptr[PyObject] {
    return _PyEval_CallTracing(func, funcargs);
}

impl sys_call_tracing(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("call_tracing"), nargs, 2, 2) == 0 {
        return NULL;
    }
    func = arg_at(args, 0);
    funcargs = arg_at(args, 1);
    if not tuple_check(funcargs) {
        _PyArg_BadArgument(
            ptr[u8]("call_tracing"), ptr[u8]("argument 2"), ptr[u8]("tuple"), funcargs
        );
        return NULL;
    }
    return sys_call_tracing_impl(module, func, funcargs);
}

impl sys__debugmallocstats_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    err = jacpy_stdio_stream(2);
    if _PyObject_DebugMallocStats(err) != 0 {
        fputc(i32(10), err);
    }
    _PyObject_DebugTypeStats(err);
    return none_ref();
}

impl sys__debugmallocstats(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys__debugmallocstats_impl(module);
}

impl sys__clear_type_cache_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        ptr[u8](
            "sys._clear_type_cache() is deprecated and"
            " scheduled for removal in a future version."
            " Use sys._clear_internal_caches() instead."
        ),
        1
    )
        < 0 {
        return NULL;
    }
    PyType_ClearCache();
    return none_ref();
}

impl sys__clear_type_cache(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys__clear_type_cache_impl(module);
}

impl sys__clear_internal_caches_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    PyType_ClearCache();
    return none_ref();
}

impl sys__clear_internal_caches(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys__clear_internal_caches_impl(module);
}

impl sys_is_finalizing_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(Py_IsFinalizing()));
}

impl sys_is_finalizing(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return sys_is_finalizing_impl(module);
}

impl sys_activate_stack_trampoline_impl(
    module: ptr[PyObject], backend: ptr[u8]
) -> ptr[PyObject] {
    PyErr_SetString(PyExc_ValueError, ptr[u8]("perf trampoline not available"));
    return NULL;
}

impl sys_activate_stack_trampoline(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    if not unicode_check(arg) {
        _PyArg_BadArgument(
            ptr[u8]("activate_stack_trampoline"),
            ptr[u8]("argument"),
            ptr[u8]("str"),
            arg
        );
        return NULL;
    }
    backend_length: i64 = 0;
    backend = PyUnicode_AsUTF8AndSize(arg, &mut backend_length);
    if not backend {
        return NULL;
    }
    if strlen(backend) != u64(backend_length) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("embedded null character"));
        return NULL;
    }
    return sys_activate_stack_trampoline_impl(module, backend);
}

impl sys_deactivate_stack_trampoline_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if _PyPerfTrampoline_Init(0) < 0 {
        return NULL;
    }
    return none_ref();
}

impl sys_deactivate_stack_trampoline(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_deactivate_stack_trampoline_impl(module);
}

impl sys_is_stack_trampoline_active_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(0);
}

impl sys_is_stack_trampoline_active(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_is_stack_trampoline_active_impl(module);
}

impl sys_is_remote_debug_enabled_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(0);
}

impl sys_is_remote_debug_enabled(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return sys_is_remote_debug_enabled_impl(module);
}

impl sys_remote_exec_impl(
    module: ptr[PyObject], pid: i32, script: ptr[PyObject]
) -> ptr[PyObject] {
    path = NULL;
    if PyUnicode_FSConverter(script, &mut path) == 0 {
        return NULL;
    }
    if sys_audit_values(
        thread_state(), ptr[u8]("sys.remote_exec"), AUDIT_INT_OBJECT, script, pid
    )
        < 0 {
        return NULL;
    }
    debugger_script_path = PyBytes_AsString(path);
    if access(debugger_script_path, F_OK | R_OK) != 0 {
        err = i32(jacpy_errno());
        if err == ENOENT {
            PyErr_SetString(
                PyExc_FileNotFoundError, ptr[u8]("Script file does not exist")
            );
        } elif err == EACCES {
            PyErr_SetString(
                PyExc_PermissionError, ptr[u8]("Script file cannot be read")
            );
        } else {
            PyErr_SetFromErrno(PyExc_OSError);
        }
        object_decref(path);
        return NULL;
    }
    if _PySysRemoteDebug_SendExec(pid, 0, debugger_script_path) < 0 {
        object_decref(path);
        return NULL;
    }
    object_decref(path);
    return none_ref();
}

impl sys_remote_exec(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(remote_exec_parser),
        2,
        2,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut slots))
    );
    if not fast {
        return NULL;
    }
    pid = PyLong_AsInt(arg_at(fast, 0));
    if pid == -1 and PyErr_Occurred() {
        return NULL;
    }
    return sys_remote_exec_impl(module, pid, arg_at(fast, 1));
}

impl sys__dump_tracelets_impl(
    module: ptr[PyObject], outpath: ptr[PyObject]
) -> ptr[PyObject] {
    out = Py_fopen(outpath, ptr[u8]("wb"));
    if not out {
        return NULL;
    }
    err = _PyDumpExecutors(ptr(out));
    fclose(ptr(out));
    if err != 0 {
        return NULL;
    }
    return none_ref();
}

impl sys__dump_tracelets(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(dump_tracelets_parser),
        1,
        1,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut slots))
    );
    if not fast {
        return NULL;
    }
    return sys__dump_tracelets_impl(module, arg_at(fast, 0));
}

impl sys__getframemodulename_impl(module: ptr[PyObject], depth: i32) -> ptr[PyObject] {
    if sys_audit_values(
        thread_state(), ptr[u8]("sys._getframemodulename"), AUDIT_INT, NULL, depth
    )
        < 0 {
        return NULL;
    }
    f = ptr[ptr[u8]](ptr[u8](thread_state()) + PyThreadState_CURRENT_FRAME).view(1)[0];
    remaining: i64 = i64(depth);
    while f {
        if not frame_is_incomplete(f) {
            more = remaining > 0;
            remaining -= 1;
            if not more {
                break;
            }
        }
        f = frame_ptr(f, _PyInterpreterFrame_PREVIOUS);
    }
    if not f {
        return none_ref();
    }
    funcobj = ptr[u64](f + _PyInterpreterFrame_F_FUNCOBJ).view(1)[0];
    if stackref_is_null(funcobj) {
        return none_ref();
    }
    r = PyFunction_GetModule(stackref_borrow(funcobj));
    if not r {
        PyErr_Clear();
        r = Py_None;
    }
    return object_new_ref(r);
}

impl sys__getframemodulename(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    noptargs = nargs + kwnames_size(kwnames);
    fast = unpack_keywords(
        args,
        nargs,
        kwnames,
        addressof(framemodulename_parser),
        0,
        1,
        0,
        0,
        ptr[ptr[PyObject]](jacpy_stack_address(&mut slots))
    );
    if not fast {
        return NULL;
    }
    depth: i32 = 0;
    if noptargs != 0 {
        depth = PyLong_AsInt(arg_at(fast, 0));
        if depth == -1 and PyErr_Occurred() {
            return NULL;
        }
    }
    return sys__getframemodulename_impl(module, depth);
}

impl sys__get_cpu_count_config_impl(module: ptr[PyObject]) -> i32 {
    return config_int(_Py_GetConfig(), PyConfig_CPU_COUNT);
}

impl sys__get_cpu_count_config(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return_value = sys__get_cpu_count_config_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromLong(i64(return_value));
}

impl sys__baserepl_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    slots: own SysStack = SysStack();
    cf = ptr[i32](jacpy_stack_address(&mut slots));
    cf.view(2)[0] = 0;
    cf.view(2)[1] = PY_MINOR_VERSION;
    PyRun_AnyFileExFlags(
        jacpy_stdio_stream(0), ptr[u8]("<stdin>"), 0, ptr[PyCompilerFlags](cf)
    );
    return none_ref();
}

impl sys__baserepl(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return sys__baserepl_impl(module);
}

impl sys__clear_type_descriptors_impl(
    module: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    typeobj = ptr[PyTypeObject](type);
    if type_has_feature(typeobj, Py_TPFLAGS_IMMUTABLETYPE) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("argument is immutable"));
        return NULL;
    }
    dct = _PyType_GetDict(type);
    dunder_dict = NULL;
    if PyDict_Pop(dct, py_id(_Py_ID___dict__), &mut dunder_dict) < 0 {
        return NULL;
    }
    dunder_weakref = NULL;
    if PyDict_Pop(dct, py_id(_Py_ID___weakref__), &mut dunder_weakref) < 0 {
        PyType_Modified(type);
        object_xdecref(dunder_dict);
        return NULL;
    }
    PyType_Modified(type);
    object_xdecref(dunder_dict);
    object_xdecref(dunder_weakref);
    return none_ref();
}

impl sys__clear_type_descriptors(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    type_type = ptr[PyTypeObject](addressof(PyType_Type));
    if not object_type_check(arg, type_type) {
        _PyArg_BadArgument(
            ptr[u8]("_clear_type_descriptors"),
            ptr[u8]("argument"),
            type_type.view(1)[0].tp_name,
            arg
        );
        return NULL;
    }
    return sys__clear_type_descriptors_impl(module, arg);
}

impl sys__is_gil_enabled_impl(module: ptr[PyObject]) -> i32 {
    return 1;
}

impl sys__is_gil_enabled(
    module: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return_value = sys__is_gil_enabled_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl list_builtin_module_names -> ptr[PyObject] {
    lst = _PyImport_GetBuiltinModuleNames();
    if not lst {
        return NULL;
    }
    if PyList_Sort(lst) != 0 {
        object_decref(lst);
        return NULL;
    }
    tup = PyList_AsTuple(lst);
    object_decref(lst);
    return tup;
}

impl list_stdlib_module_names -> ptr[PyObject] {
    names = PyTuple_New(STDLIB_MODULE_NAMES_COUNT);
    if not names {
        return NULL;
    }
    table = addressof(stdlib_module_names);
    for i in range(STDLIB_MODULE_NAMES_COUNT) {
        name = PyUnicode_FromString(table.view(STDLIB_MODULE_NAMES_COUNT)[i]);
        if not name {
            object_decref(names);
            return NULL;
        }
        tuple_set_item(names, i64(i), name);
    }
    st = PyObject_CallFunction(
        ptr[PyObject](addressof(PyFrozenSet_Type)), "(O)", names
    );
    object_decref(names);
    return st;
}

impl preinit_head(xoptions: bool) -> ptr[SysPreinitEntry] {
    statics = addressof(sys_statics);
    if xoptions {
        return ptr[SysPreinitEntry](statics.view(1)[0].preinit_xoptions);
    }
    return ptr[SysPreinitEntry](statics.view(1)[0].preinit_warnoptions);
}

impl set_preinit_head(xoptions: bool, ent: ptr[SysPreinitEntry]) {
    statics = addressof(sys_statics);
    if xoptions {
        statics.view(1)[0].preinit_xoptions = ptr(ent);
    } else {
        statics.view(1)[0].preinit_warnoptions = ptr(ent);
    }
}

impl _alloc_preinit_entry(value: ptr[i32]) -> ptr[SysPreinitEntry] {
    _PyRuntime_Initialize();
    pnode = ptr[SysPreinitEntry](_PyMem_DefaultRawCalloc(u64(1), u64(16)));
    if pnode {
        copy = _PyMem_DefaultRawWcsdup(value);
        pnode.view(1)[0].value = copy;
        if not copy {
            _PyMem_DefaultRawFree(ptr(pnode));
            pnode = ptr[SysPreinitEntry]();
        }
    }
    return pnode;
}

impl _append_preinit_entry(xoptions: bool, value: ptr[i32]) -> i32 {
    new_entry = _alloc_preinit_entry(value);
    if not new_entry {
        return -1;
    }
    last_entry = preinit_head(xoptions);
    if not last_entry {
        set_preinit_head(xoptions, new_entry);
    } else {
        while last_entry.view(1)[0].next {
            last_entry = ptr[SysPreinitEntry](last_entry.view(1)[0].next);
        }
        last_entry.view(1)[0].next = ptr(new_entry);
    }
    return 0;
}

impl _clear_preinit_entries(xoptions: bool) {
    current = preinit_head(xoptions);
    set_preinit_head(xoptions, ptr[SysPreinitEntry]());
    while current {
        next_entry = ptr[SysPreinitEntry](current.view(1)[0].next);
        _PyMem_DefaultRawFree(ptr(current.view(1)[0].value));
        _PyMem_DefaultRawFree(ptr(current));
        current = next_entry;
    }
}

impl get_warnoptions(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    (status, warnoptions) = sys_optional_attr(py_id(_Py_ID_warnoptions));
    if status < 0 {
        return NULL;
    }
    if not warnoptions or not list_check(warnoptions) {
        object_xdecref(warnoptions);
        warnoptions = PyList_New(0);
        if not warnoptions {
            return NULL;
        }
        if sys_set_object(tstate_interp(tstate), py_id(_Py_ID_warnoptions), warnoptions)
            != 0 {
            object_decref(warnoptions);
            return NULL;
        }
    }
    return warnoptions;
}

impl _PySys_AddWarnOptionWithError(
    tstate: ptr[PyThreadState], option: ptr[PyObject]
) -> i32 {
    warnoptions = get_warnoptions(tstate);
    if not warnoptions {
        return -1;
    }
    if PyList_Append(warnoptions, option) != 0 {
        object_decref(warnoptions);
        return -1;
    }
    object_decref(warnoptions);
    return 0;
}

impl get_xoptions(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    (status, xoptions) = sys_optional_attr(py_id(_Py_ID__xoptions));
    if status < 0 {
        return NULL;
    }
    if not xoptions or not dict_check(xoptions) {
        object_xdecref(xoptions);
        xoptions = PyDict_New();
        if not xoptions {
            return NULL;
        }
        if sys_set_object(tstate_interp(tstate), py_id(_Py_ID__xoptions), xoptions)
            != 0 {
            object_decref(xoptions);
            return NULL;
        }
    }
    return xoptions;
}

impl _PySys_AddXOptionWithError(s: ptr[i32]) -> i32 {
    opts = get_xoptions(thread_state());
    if not opts {
        return -1;
    }
    name = NULL;
    value = NULL;
    name_end = wcschr(s, i32(61));
    if not name_end {
        name = PyUnicode_FromWideChar(s, -1);
        if not name {
            object_decref(opts);
            return -1;
        }
        value = object_new_ref(py_true());
    } else {
        name = PyUnicode_FromWideChar(s, i64((int(name_end) - int(s)) // 4));
        if not name {
            object_decref(opts);
            return -1;
        }
        value = PyUnicode_FromWideChar(name_end + 1, -1);
        if not value {
            object_decref(name);
            object_decref(opts);
            return -1;
        }
    }
    if PyDict_SetItem(opts, name, value) < 0 {
        object_decref(name);
        object_decref(value);
        object_decref(opts);
        return -1;
    }
    object_decref(name);
    object_decref(value);
    object_decref(opts);
    return 0;
}

impl sys_set_flag(flags: ptr[PyObject], pos: i64, value: ptr[PyObject]) {
    old_value = PyStructSequence_GetItem(flags, pos);
    PyStructSequence_SetItem(flags, pos, object_new_ref(value));
    object_xdecref(old_value);
}

impl _PySys_SetFlagInt(pos: i64, value: i32) -> i32 {
    obj_ = PyLong_FromLong(i64(value));
    if not obj_ {
        return -1;
    }
    res = _PySys_SetFlagObj(pos, obj_);
    object_decref(obj_);
    return res;
}

impl set_flag_value(flags: ptr[PyObject], pos: i64, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    sys_set_flag(flags, pos, value);
    object_decref(value);
    return True;
}

impl set_flag_int(flags: ptr[PyObject], pos: i64, value: i64) -> bool {
    return set_flag_value(flags, pos, PyLong_FromLong(value));
}

impl set_flags_from_config(interp: ptr[u8], flags: ptr[PyObject]) -> i32 {
    utf8_mode = ptr[i32](
        interp_runtime(interp) + _PyRuntimeState_PRECONFIG_UTF8_MODE
    ).view(
        1
    )[0];
    config = _PyInterpreterState_GetConfig(interp);
    hash_randomization: i64 = 0;
    if config_int(config, PyConfig_USE_HASH_SEED) == 0
        or ptr[u64](config + PyConfig_HASH_SEED).view(1)[0] != u64(0) {
        hash_randomization = 1;
    }
    if not set_flag_int(flags, 0, i64(config_int(config, PyConfig_PARSER_DEBUG)))
        or not set_flag_int(flags, 1, i64(config_int(config, PyConfig_INSPECT)))
        or not set_flag_int(flags, 2, i64(config_int(config, PyConfig_INTERACTIVE)))
        or not set_flag_int(
            flags, 3, i64(config_int(config, PyConfig_OPTIMIZATION_LEVEL))
        )
        or not set_flag_int(
            flags, 4, not_flag(config_int(config, PyConfig_WRITE_BYTECODE))
        )
        or not set_flag_int(
            flags, 5, not_flag(config_int(config, PyConfig_USER_SITE_DIRECTORY))
        )
        or not set_flag_int(
            flags, 6, not_flag(config_int(config, PyConfig_SITE_IMPORT))
        )
        or not set_flag_int(
            flags, 7, not_flag(config_int(config, PyConfig_USE_ENVIRONMENT))
        )
        or not set_flag_int(flags, 8, i64(config_int(config, PyConfig_VERBOSE)))
        or not set_flag_int(flags, 9, i64(config_int(config, PyConfig_BYTES_WARNING)))
        or not set_flag_int(flags, 10, i64(config_int(config, PyConfig_QUIET)))
        or not set_flag_int(flags, 11, hash_randomization)
        or not set_flag_int(flags, 12, i64(config_int(config, PyConfig_ISOLATED)))
        or not set_flag_value(
            flags, 13, PyBool_FromLong(i64(config_int(config, PyConfig_DEV_MODE)))
        )
        or not set_flag_int(flags, 14, i64(utf8_mode))
        or not set_flag_int(
            flags, 15, i64(config_int(config, PyConfig_WARN_DEFAULT_ENCODING))
        )
        or not set_flag_value(
            flags, 16, PyBool_FromLong(i64(config_int(config, PyConfig_SAFE_PATH)))
        )
        or not set_flag_int(
            flags, 17, i64(config_int(config, PyConfig_INT_MAX_STR_DIGITS))
        )
        or not set_flag_int(flags, 18, 1)
        or not set_flag_int(
            flags, 19, i64(config_int(config, PyConfig_THREAD_INHERIT_CONTEXT))
        )
        or not set_flag_int(
            flags, 20, i64(config_int(config, PyConfig_CONTEXT_AWARE_WARNINGS))
        ) {
        return -1;
    }
    return 0;
}

impl make_flags(interp: ptr[u8]) -> ptr[PyObject] {
    flags = PyStructSequence_New(ptr[PyObject](addressof(FlagsType)));
    if not flags {
        return NULL;
    }
    if set_flags_from_config(interp, flags) < 0 {
        object_decref(flags);
        return NULL;
    }
    return flags;
}

impl release_level_name -> ptr[u8] {
    if PY_RELEASE_LEVEL == 0xA {
        return ptr[u8]("alpha");
    }
    if PY_RELEASE_LEVEL == 0xB {
        return ptr[u8]("beta");
    }
    if PY_RELEASE_LEVEL == 0xC {
        return ptr[u8]("candidate");
    }
    return ptr[u8]("final");
}

impl make_version_info(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    version_info = PyStructSequence_New(ptr[PyObject](addressof(VersionInfoType)));
    if not version_info {
        return NULL;
    }
    PyStructSequence_SetItem(version_info, 0, PyLong_FromLong(i64(PY_MAJOR_VERSION)));
    PyStructSequence_SetItem(version_info, 1, PyLong_FromLong(i64(PY_MINOR_VERSION)));
    PyStructSequence_SetItem(version_info, 2, PyLong_FromLong(i64(PY_MICRO_VERSION)));
    PyStructSequence_SetItem(
        version_info, 3, PyUnicode_FromString(release_level_name())
    );
    PyStructSequence_SetItem(version_info, 4, PyLong_FromLong(i64(PY_RELEASE_SERIAL)));
    if exception_raised(tstate) {
        object_decref(version_info);
        return NULL;
    }
    return version_info;
}

impl multiarch_name -> ptr[u8] {
    if SYS_PLATFORM_LINUX == 0 {
        return ptr[u8]("darwin");
    }
    if SYS_ARCH_X86_64 != 0 {
        return ptr[u8]("x86_64-linux-gnu");
    }
    return ptr[u8]("aarch64-linux-gnu");
}

impl impl_info_put(
    impl_info: ptr[PyObject], key: ptr[u8], value: ptr[PyObject]
) -> bool {
    if not value {
        return False;
    }
    res = PyDict_SetItemString(impl_info, key, value);
    object_decref(value);
    return res >= 0;
}

impl make_impl_info(version_info: ptr[PyObject]) -> ptr[PyObject] {
    impl_info = PyDict_New();
    if not impl_info {
        return NULL;
    }
    if not impl_info_put(
        impl_info,
        ptr[u8]("name"),
        PyUnicode_FromString(addressof(_PySys_ImplName).view(1)[0])
    )
        or not impl_info_put(
            impl_info,
            ptr[u8]("cache_tag"),
            PyUnicode_FromString(addressof(_PySys_ImplCacheTag).view(1)[0])
        )
        or PyDict_SetItemString(impl_info, ptr[u8]("version"), version_info) < 0
        or not impl_info_put(
            impl_info, ptr[u8]("hexversion"), PyLong_FromLong(i64(PY_VERSION_HEX))
        )
        or not impl_info_put(
            impl_info, ptr[u8]("_multiarch"), PyUnicode_FromString(multiarch_name())
        )
        or PyDict_SetItemString(
            impl_info, ptr[u8]("supports_isolated_interpreters"), py_true()
        )
            < 0 {
        object_decref(impl_info);
        return NULL;
    }
    ns = _PyNamespace_New(impl_info);
    object_decref(impl_info);
    return ns;
}

impl set_sys(sysdict: ptr[PyObject], key: ptr[u8], v: ptr[PyObject]) -> bool {
    if not v {
        return False;
    }
    res = PyDict_SetItemString(sysdict, key, v);
    object_decref(v);
    return res >= 0;
}

impl set_sys_from_string(sysdict: ptr[PyObject], key: ptr[u8], value: ptr[u8]) -> bool {
    return set_sys(sysdict, key, PyUnicode_FromString(value));
}

impl copy_sys_attr(sysdict: ptr[PyObject], tokey: ptr[u8], fromkey: ptr[u8]) -> bool {
    return set_sys(sysdict, tokey, PyMapping_GetItemString(sysdict, fromkey));
}

impl copy_wstr(
    sysdict: ptr[PyObject], key: ptr[u8], config: ptr[u8], offset: i64
) -> bool {
    wstr = config_wstr(config, offset);
    if not wstr {
        return True;
    }
    return set_sys(sysdict, key, PyUnicode_FromWideChar(wstr, -1));
}

impl ensure_info_type(
    interp: ptr[u8], type: ptr[PyTypeObject], desc: ptr[PyStructSequence_Desc]
) -> bool {
    return _PyStructSequence_InitBuiltinWithFlags(
        ptr(interp), ptr[PyObject](type), desc, Py_TPFLAGS_DISALLOW_INSTANTIATION
    )
        >= 0;
}

impl init_core_error -> PyStatus {
    return status_err(
        ptr[u8]("_PySys_InitCore"), ptr[u8]("can't initialize sys module")
    );
}

impl init_core_type_error -> PyStatus {
    return status_err(
        ptr[u8]("_PySys_InitCore"), ptr[u8]("failed to initialize a type")
    );
}

impl _PySys_InitCore(tstate: ptr[PyThreadState], sysdict: ptr[PyObject]) -> PyStatus {
    interp = tstate_interp(tstate);
    if not copy_sys_attr(sysdict, ptr[u8]("__displayhook__"), ptr[u8]("displayhook"))
        or not copy_sys_attr(sysdict, ptr[u8]("__excepthook__"), ptr[u8]("excepthook"))
        or not copy_sys_attr(
            sysdict, ptr[u8]("__breakpointhook__"), ptr[u8]("breakpointhook")
        )
        or not copy_sys_attr(
            sysdict, ptr[u8]("__unraisablehook__"), ptr[u8]("unraisablehook")
        )
        or not set_sys_from_string(sysdict, ptr[u8]("version"), Py_GetVersion())
        or not set_sys(sysdict, ptr[u8]("hexversion"), PyLong_FromLong(i64(PY_VERSION_HEX)))
        or not set_sys(
            sysdict,
            ptr[u8]("_git"),
            Py_BuildValue(
                ptr[u8]("(szz)"),
                ptr[u8]("CPython"),
                _Py_gitidentifier(),
                _Py_gitversion()
            )
        )
        or not set_sys_from_string(sysdict, ptr[u8]("_framework"), ptr[u8](""))
        or not set_sys(
            sysdict, ptr[u8]("api_version"), PyLong_FromLong(i64(PYTHON_API_VERSION))
        )
        or not set_sys_from_string(sysdict, ptr[u8]("copyright"), Py_GetCopyright())
        or not set_sys_from_string(sysdict, ptr[u8]("platform"), Py_GetPlatform())
        or not set_sys(sysdict, ptr[u8]("maxsize"), PyLong_FromSsize_t(PY_SSIZE_T_MAX))
        or not set_sys(sysdict, ptr[u8]("float_info"), PyFloat_GetInfo())
        or not set_sys(sysdict, ptr[u8]("int_info"), PyLong_GetInfo()) {
        return init_core_error();
    }
    if _PyStructSequence_InitBuiltinWithFlags(
        ptr(interp),
        ptr[PyObject](addressof(Hash_InfoType)),
        addressof(hash_info_desc),
        u64(0)
    )
        < 0 {
        return init_core_type_error();
    }
    if not set_sys(sysdict, ptr[u8]("hash_info"), get_hash_info(tstate))
        or not set_sys(sysdict, ptr[u8]("maxunicode"), PyLong_FromLong(0x10FFFF))
        or not set_sys(
            sysdict, ptr[u8]("builtin_module_names"), list_builtin_module_names()
        )
        or not set_sys(
            sysdict, ptr[u8]("stdlib_module_names"), list_stdlib_module_names()
        )
        or not set_sys_from_string(sysdict, ptr[u8]("byteorder"), ptr[u8]("little"))
        or not set_sys_from_string(sysdict, ptr[u8]("abiflags"), ptr[u8]("")) {
        return init_core_error();
    }
    if not ensure_info_type(
        interp, addressof(VersionInfoType), addressof(version_info_desc)
    ) {
        return init_core_type_error();
    }
    version_info = make_version_info(tstate);
    if not set_sys(sysdict, ptr[u8]("version_info"), version_info)
        or not set_sys(
            sysdict, ptr[u8]("implementation"), make_impl_info(version_info)
        ) {
        return init_core_error();
    }
    if not ensure_info_type(interp, addressof(FlagsType), addressof(flags_desc)) {
        return init_core_type_error();
    }
    if not set_sys(sysdict, ptr[u8]("flags"), make_flags(interp))
        or not set_sys_from_string(
            sysdict, ptr[u8]("float_repr_style"), ptr[u8]("short")
        )
        or not set_sys(sysdict, ptr[u8]("thread_info"), PyThread_GetInfo()) {
        return init_core_error();
    }
    if _PyStructSequence_InitBuiltinWithFlags(
        ptr(interp),
        ptr[PyObject](addressof(AsyncGenHooksType)),
        addressof(asyncgen_hooks_desc),
        u64(0)
    )
        < 0 {
        return init_core_type_error();
    }
    if not set_sys(sysdict, ptr[u8]("meta_path"), PyList_New(0))
        or not set_sys(sysdict, ptr[u8]("path_importer_cache"), PyDict_New())
        or not set_sys(sysdict, ptr[u8]("path_hooks"), PyList_New(0)) {
        return init_core_error();
    }
    if exception_raised(tstate) {
        return init_core_error();
    }
    return status_ok();
}

impl _PySys_SetPreliminaryStderr(sysdict: ptr[PyObject]) -> PyStatus {
    pstderr = PyFile_NewStdPrinter(fileno(jacpy_stdio_stream(2)));
    if pstderr {
        if PyDict_SetItem(sysdict, py_id(_Py_ID_stderr), pstderr) >= 0
            and PyDict_SetItemString(sysdict, ptr[u8]("__stderr__"), pstderr) >= 0 {
            object_decref(pstderr);
            return status_ok();
        }
    }
    object_xdecref(pstderr);
    return status_err(
        ptr[u8]("_PySys_SetPreliminaryStderr"), ptr[u8]("can't set preliminary stderr")
    );
}

impl create_error -> PyStatus {
    return status_err(ptr[u8]("_PySys_Create"), ptr[u8]("can't initialize sys module"));
}

impl _jit_is_available_impl(module: ptr[PyObject]) -> i32 {
    return 0;
}

impl _jit_is_available(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return_value = _jit_is_available_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl _jit_is_enabled_impl(module: ptr[PyObject]) -> i32 {
    return i32(ptr[u8](current_interp() + PyInterpreterState_JIT).view(1)[0]);
}

impl _jit_is_enabled(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return_value = _jit_is_enabled_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl _jit_is_active_impl(module: ptr[PyObject]) -> i32 {
    executor = ptr[ptr[PyObject]](
        ptr[u8](thread_state()) + PyThreadState_CURRENT_EXECUTOR
    ).view(
        1
    )[0];
    if executor {
        return 1;
    }
    return 0;
}

impl _jit_is_active(module: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return_value = _jit_is_active_impl(module);
    if return_value == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyBool_FromLong(i64(return_value));
}

impl makepathobject(path: ptr[i32], delim: i32) -> ptr[PyObject] {
    n: i64 = 1;
    p = wcschr(path, delim);
    while p {
        n += 1;
        p = wcschr(p + 1, delim);
    }
    v = PyList_New(n);
    if not v {
        return NULL;
    }
    items = ptr[PyListObject](v).view(1)[0].ob_item;
    i: i64 = 0;
    cur = path;
    while True {
        p = wcschr(cur, delim);
        if not p {
            p = cur + i64(wcslen(cur));
        }
        w = PyUnicode_FromWideChar(cur, i64((int(p) - int(cur)) // 4));
        if not w {
            object_decref(v);
            return NULL;
        }
        (items + i).view(1)[0] = w;
        if p.view(1)[0] == 0 {
            break;
        }
        cur = p + 1;
        i += 1;
    }
    return v;
}

impl make_sys_argv(argc: i32, argv: ptr[ptr[i32]]) -> ptr[PyObject] {
    lst = PyList_New(i64(argc));
    if not lst {
        return NULL;
    }
    items = ptr[PyListObject](lst).view(1)[0].ob_item;
    for i in range(i64(argc)) {
        v = PyUnicode_FromWideChar((argv + i).view(1)[0], -1);
        if not v {
            object_decref(lst);
            return NULL;
        }
        (items + i).view(1)[0] = v;
    }
    return lst;
}

impl empty_argv -> ptr[ptr[i32]] {
    argv = addressof(sys_empty_argv);
    argv.view(1)[0] = addressof(sys_empty_wide);
    return argv;
}

impl sys_update_path0(argc: i32, argv: ptr[ptr[i32]]) {
    slots: own SysStack = SysStack();
    argv_list = ptr[SysWideStringList](jacpy_stack_address(&mut slots));
    argv_list.view(1)[0].length = i64(argc);
    argv_list.view(1)[0].items = argv;
    path0 = NULL;
    if _PyPathConfig_ComputeSysPath0(ptr(argv_list), &mut path0) != 0 {
        if not path0 {
            _Py_FatalErrorFunc(
                ptr[u8]("PySys_SetArgvEx"), ptr[u8]("can't compute path0 from argv")
            );
        }
        (status, sys_path) = sys_optional_attr(py_id(_Py_ID_path));
        if status < 0 {
            _Py_FatalErrorFunc(
                ptr[u8]("PySys_SetArgvEx"), ptr[u8]("can't get sys.path")
            );
        } elif sys_path {
            if PyList_Insert(sys_path, 0, path0) < 0 {
                _Py_FatalErrorFunc(
                    ptr[u8]("PySys_SetArgvEx"),
                    ptr[u8]("can't prepend path0 to sys.path")
                );
            }
            object_decref(sys_path);
        }
        object_decref(path0);
    }
}

impl sys_pyfile_write_unicode(unicode: ptr[PyObject], file: ptr[PyObject]) -> i32 {
    if not file {
        return -1;
    }
    result = call_method_one_arg(file, py_id(_Py_ID_write), unicode);
    if not result {
        return -1;
    }
    object_decref(result);
    return 0;
}

impl sys_pyfile_write(text: ptr[u8], file: ptr[PyObject]) -> i32 {
    if not file {
        return -1;
    }
    unicode = PyUnicode_FromString(text);
    if not unicode {
        return -1;
    }
    err = sys_pyfile_write_unicode(unicode, file);
    object_decref(unicode);
    return err;
}

impl sys_write(key: ptr[PyObject], fp: ptr, format: ptr[u8], va: VaList) {
    tstate = thread_state();
    exc = _PyErr_GetRaisedException(tstate);
    buffer = ptr[u8](PyMem_RawMalloc(u64(1001)));
    if buffer {
        written = PyOS_vsnprintf(buffer, u64(1001), format, ptr(va));
        sys_write_buffer(tstate, key, fp, buffer, written);
    }
    _PyErr_SetRaisedException(tstate, exc);
}

impl sys_write_stderr_text(format: ptr[u8], text: ptr[u8]) {
    tstate = thread_state();
    exc = _PyErr_GetRaisedException(tstate);
    buffer = ptr[u8](PyMem_RawMalloc(u64(1001)));
    if buffer {
        written = snprintf(buffer, u64(1001), format, text);
        sys_write_buffer(
            tstate, py_id(_Py_ID_stderr), jacpy_stdio_stream(2), buffer, written
        );
    }
    _PyErr_SetRaisedException(tstate, exc);
}

impl sys_write_buffer(
    tstate: ptr[PyThreadState],
    key: ptr[PyObject],
    fp: ptr,
    buffer: ptr[u8],
    written: i32
) {
    file = _PySys_GetRequiredAttr(key);
    if sys_pyfile_write(buffer, file) != 0 {
        _PyErr_Clear(tstate);
        fputs(buffer, fp);
    }
    if written < 0 or written >= 1001 {
        truncated = ptr[u8]("... truncated");
        if sys_pyfile_write(truncated, file) != 0 {
            fputs(truncated, fp);
        }
    }
    object_xdecref(file);
    PyMem_RawFree(ptr(buffer));
}

impl sys_format(key: ptr[PyObject], fp: ptr, format: ptr[u8], va: VaList) {
    tstate = thread_state();
    exc = _PyErr_GetRaisedException(tstate);
    message = PyUnicode_FromFormatV(format, va);
    if message {
        file = _PySys_GetRequiredAttr(key);
        if sys_pyfile_write_unicode(message, file) != 0 {
            _PyErr_Clear(tstate);
            utf8 = PyUnicode_AsUTF8(message);
            if utf8 {
                fputs(utf8, fp);
            }
        }
        object_xdecref(file);
        object_decref(message);
    }
    _PyErr_SetRaisedException(tstate, exc);
}
