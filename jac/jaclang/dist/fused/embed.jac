import os;
import from .report { die }
import from _dl_native { dlopen, dlsym, dl_error, RTLD_NOW, RTLD_GLOBAL, SHLIB_EXT }
import from ._libc { peek, poke, c_string, c_alloc_string }

glob PY_VER: str = "3.14",
     PY_VER_COMPACT: str = "314";

import from c {
    def malloc(size: int) -> int;  def free(ptr: int) -> None;  obj PyApi {
        has PyInitConfig_Create: Callable[[], int] = 0,
            PyInitConfig_Free: Callable[[int], None] = 0,
            PyInitConfig_GetError: Callable[[int, int], i32] = 0,
            PyInitConfig_GetExitCode: Callable[[int, int], i32] = 0,
            PyInitConfig_SetInt: Callable[[int, str, int], i32] = 0,
            PyInitConfig_SetStr: Callable[[int, str, str], i32] = 0,
            PyInitConfig_SetStrList: Callable[[int, str, int, int], i32] = 0,
            Py_InitializeFromInitConfig: Callable[[int], i32] = 0,
            PyRun_SimpleString: Callable[[str], i32] = 0,
            Py_FinalizeEx: Callable[[], i32] = 0,
            Py_Finalize: Callable[[], None] = 0,
            Py_RunMain: Callable[[], i32] = 0,
            PyImport_AddModule: Callable[[str], int] = 0,
            PyModule_GetDict: Callable[[int], int] = 0,
            PyRun_String: Callable[[str, i32, int, int], int] = 0,
            PyLong_AsLong: Callable[[int], int] = 0,
            PyEval_SaveThread: Callable[[], int] = 0,
            PyEval_RestoreThread: Callable[[int], None] = 0,
            PyGILState_Ensure: Callable[[], i32] = 0,
            PyGILState_Release: Callable[[i32], None] = 0,
            PyObject_CallOneArg: Callable[[int, int], int] = 0,
            PyUnicode_FromString: Callable[[str], int] = 0,
            PyUnicode_AsUTF8: Callable[[int], int] = 0,
            Py_DecRef: Callable[[int], None] = 0;
    }
}

obj Embed {
    has handle: int = 0,
        rt: str = "",
        exe_path: str = "",
        api: PyApi = PyApi();

    def sym(name: str) -> int {
        return dlsym(self.handle, name);
    }

    def need(name: str) -> int {
        p = dlsym(self.handle, name);
        if p == 0 {
            die(f"libpython missing symbol: {name}");
            return 0;
        }
        return p;
    }

    def bind_api {
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

    def check(cfg: int, rc: int, what: str) {
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

    def init_interpreter(argv: list[str], parse_argv: bool) -> int {
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
            cfg,
            a.PyInitConfig_SetStr(cfg, "program_name", self.exe_path),
            "program_name"
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
            a.PyInitConfig_SetInt(cfg, "user_site_directory", 0),
            "user_site_directory"
        );
        self.check(
            cfg, a.PyInitConfig_SetInt(cfg, "write_bytecode", 0), "write_bytecode"
        );

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
}

obj CStrArray {
    has ptrs: int = 0,
        count: int = 0;

    def init(items: list[str]) {
        self.count = len(items);
        self.ptrs = malloc(8 * (self.count + 1));
        i = 0;
        for s in items {
            poke(self.ptrs + 8 * i, c_alloc_string(s).to_bytes(8, "little"));
            i += 1;
        }
        poke(self.ptrs + 8 * i, (0).to_bytes(8, "little"));
    }

    def release {
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
}

def:pub open_tree(rt: str, exe_path: str) -> Embed {
    os.environ["JAC_STANDALONE"] = "1";
    os.environ["JAC_EXECUTABLE"] = exe_path;

    ca_bundle = rt + "/python/floor/cacert.pem";
    if not os.environ.get("SSL_CERT_FILE", "")
        and not os.environ.get("SSL_CERT_DIR", "")
        and os.path.isfile(ca_bundle) {
        os.environ["SSL_CERT_FILE"] = ca_bundle;
    }
    libpath = f"{rt}/python/lib/libpython{PY_VER}{SHLIB_EXT}";
    handle = dlopen(libpath, i32(RTLD_NOW | RTLD_GLOBAL));
    if handle == 0 {
        die(f"cannot load the bundled interpreter {libpath}: {dl_error()}");
    }
    emb = Embed(handle=handle, rt=rt, exe_path=exe_path);
    emb.bind_api();
    return emb;
}
