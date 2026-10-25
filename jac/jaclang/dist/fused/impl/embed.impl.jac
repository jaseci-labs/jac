impl Embed.sym(name: str) -> int {
    return dlsym(self.handle, name);
}

impl Embed.need(name: str) -> int {
    p = dlsym(self.handle, name);
    if p == 0 {
        die(f"libpython missing symbol: {name}");
        return 0;
    }
    return p;
}

impl Embed.bind_api {
    a = self.api;
    a.PyInitConfig_Create = self.need("PyInitConfig_Create");
    a.PyInitConfig_Free = self.need("PyInitConfig_Free");
    a.PyInitConfig_GetError = self.need("PyInitConfig_GetError");
    a.PyInitConfig_GetExitCode = self.need("PyInitConfig_GetExitCode");
    a.PyInitConfig_SetInt = self.need("PyInitConfig_SetInt");
    a.PyInitConfig_SetStr = self.need("PyInitConfig_SetStr");
    a.PyInitConfig_SetStrList = self.need("PyInitConfig_SetStrList");
    a.Py_InitializeFromInitConfig = self.need("Py_InitializeFromInitConfig");
    a.PyRun_SimpleString = self.need("PyRun_SimpleString");
    a.Py_FinalizeEx = self.need("Py_FinalizeEx");
    a.Py_Finalize = self.need("Py_Finalize");
    a.Py_RunMain = self.need("Py_RunMain");
    a.PyImport_AddModule = self.need("PyImport_AddModule");
    a.PyModule_GetDict = self.need("PyModule_GetDict");
    a.PyRun_String = self.need("PyRun_String");
    a.PyLong_AsLong = self.need("PyLong_AsLong");
    a.PyEval_SaveThread = self.need("PyEval_SaveThread");
    a.PyEval_RestoreThread = self.need("PyEval_RestoreThread");
    a.PyGILState_Ensure = self.need("PyGILState_Ensure");
    a.PyGILState_Release = self.need("PyGILState_Release");
    a.PyObject_CallOneArg = self.need("PyObject_CallOneArg");
    a.PyUnicode_FromString = self.need("PyUnicode_FromString");
    a.PyUnicode_AsUTF8 = self.need("PyUnicode_AsUTF8");
    a.Py_DecRef = self.need("Py_DecRef");
}

impl Embed.check(cfg: int, rc: int, what: str) {
    if rc == 0 {
        return;
    }
    errp = malloc(8);
    poke(errp, (0).to_bytes(8, "little"));
    msg = what;
    if self.api.PyInitConfig_GetError(cfg, errp) != 0 {
        p = int.from_bytes(peek(errp, 8), "little");
        if p != 0 {
            msg = c_string(p);
        }
    }
    free(errp);
    self.api.PyInitConfig_Free(cfg);
    die(f"python init failed: {msg}");
}

impl Embed.init_interpreter(argv: list[str], parse_argv: bool) -> int {
    a = self.api;
    cfg = a.PyInitConfig_Create();
    if cfg == 0 {
        die("python init failed: PyInitConfig_Create");
        return 70;
    }
    pyhome = self.rt + "/python";

    search_paths = [
        self.rt + "/site",
        f"{pyhome}/lib/python{PY_VER}/lib-dynload",
        f"{pyhome}/lib/python{PY_VER_COMPACT}.zip",
        f"{pyhome}/lib/python{PY_VER}",
        f"{pyhome}/lib/python{PY_VER}/site-packages"
    ];
    self.check(
        cfg, a.PyInitConfig_SetStr(cfg, "program_name", self.exe_path), "program_name"
    );
    self.check(cfg, a.PyInitConfig_SetStr(cfg, "home", pyhome), "home");
    paths_arr = CStrArray(search_paths);
    self.check(
        cfg,
        a.PyInitConfig_SetStrList(
            cfg, "module_search_paths", len(search_paths), paths_arr.ptrs
        ),
        "module_search_paths"
    );

    self.check(
        cfg, a.PyInitConfig_SetInt(cfg, "use_environment", 0), "use_environment"
    );

    self.check(
        cfg,
        a.PyInitConfig_SetInt(cfg, "allocator", PYMEM_ALLOCATOR_MIMALLOC),
        "allocator"
    );
    self.check(
        cfg, a.PyInitConfig_SetInt(cfg, "user_site_directory", 0), "user_site_directory"
    );
    self.check(cfg, a.PyInitConfig_SetInt(cfg, "write_bytecode", 0), "write_bytecode");

    self.check(cfg, a.PyInitConfig_SetInt(cfg, "utf8_mode", 1), "utf8_mode");
    self.check(
        cfg, a.PyInitConfig_SetStr(cfg, "stdio_encoding", "utf-8"), "stdio_encoding"
    );

    self.check(
        cfg,
        a.PyInitConfig_SetInt(cfg, "install_signal_handlers", 1),
        "install_signal_handlers"
    );
    self.check(
        cfg, a.PyInitConfig_SetInt(cfg, "configure_c_stdio", 1), "configure_c_stdio"
    );
    self.check(cfg, a.PyInitConfig_SetInt(cfg, "isolated", 0), "isolated");
    argv_arr = CStrArray(argv);
    if len(argv) > 0 {
        self.check(
            cfg,
            a.PyInitConfig_SetStrList(cfg, "argv", len(argv), argv_arr.ptrs),
            "argv"
        );
    }

    self.check(
        cfg,
        a.PyInitConfig_SetInt(cfg, "parse_argv", 1 if parse_argv else 0),
        "parse_argv"
    );
    self.check(cfg, a.PyInitConfig_SetInt(cfg, "safe_path", 0), "safe_path");

    rc = a.Py_InitializeFromInitConfig(cfg);
    paths_arr.release();
    argv_arr.release();
    if rc != 0 {
        codep = malloc(4);
        poke(codep, (0).to_bytes(4, "little"));
        if a.PyInitConfig_GetExitCode(cfg, codep) != 0 {
            code = int.from_bytes(peek(codep, 4), "little") & 255;
            free(codep);
            a.PyInitConfig_Free(cfg);
            return code;
        }
        free(codep);
        self.check(cfg, rc, "Py_InitializeFromInitConfig");
    }
    a.PyInitConfig_Free(cfg);
    return -1;
}

impl CStrArray.init(items: list[str]) {
    self.count = len(items);
    self.ptrs = malloc(8 * (self.count + 1));
    i = 0;
    for s in items {
        poke(self.ptrs + 8 * i, c_alloc_string(s).to_bytes(8, "little"));
        i += 1;
    }
    poke(self.ptrs + 8 * i, (0).to_bytes(8, "little"));
}

impl CStrArray.release {
    i = 0;
    while i < self.count {
        free(int.from_bytes(peek(self.ptrs + 8 * i, 8), "little"));
        i += 1;
    }
    if self.ptrs != 0 {
        free(self.ptrs);
        self.ptrs = 0;
    }
    self.count = 0;
}

impl export_ca_bundle(rt: str) {
    ca_bundle = rt + "/python/floor/cacert.pem";
    if not os.environ.get("SSL_CERT_FILE", "")
        and not os.environ.get("SSL_CERT_DIR", "")
        and os.path.isfile(ca_bundle) {
        os.environ["SSL_CERT_FILE"] = ca_bundle;
    }
}

impl open_tree(rt: str, exe_path: str) -> Embed {
    os.environ["JAC_STANDALONE"] = "1";

    if not os.environ.get("MIMALLOC_PURGE_DELAY", "") {
        os.environ["MIMALLOC_PURGE_DELAY"] = "0";
    }

    export_ca_bundle(rt);
    libpath = f"{rt}/python/lib/libpython{PY_VER}{SHLIB_EXT}";
    handle = dlopen(libpath, i32(RTLD_NOW | RTLD_GLOBAL));
    if handle == 0 {
        die(f"cannot load the bundled interpreter {libpath}: {dl_error()}");
    }
    emb = Embed(handle=handle, rt=rt, exe_path=exe_path);
    emb.bind_api();
    return emb;
}
