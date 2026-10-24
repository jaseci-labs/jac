import os;

import from _dl_native { dlopen, dlsym, dl_error, RTLD_NOW, RTLD_GLOBAL, SHLIB_EXT }

glob PY_VER: str = "3.14",
     PY_VER_COMPACT: str = "314",
     PYMEM_ALLOCATOR_MIMALLOC: int = 7;

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

    def sym(name: str) -> int;
    def need(name: str) -> int;
    def bind_api;
    def check(cfg: int, rc: int, what: str);
    def init_interpreter(argv: list[str], parse_argv: bool) -> int;
}

obj CStrArray {
    has ptrs: int = 0,
        count: int = 0;

    def init(items: list[str]);
    def release;
}

def:pub export_ca_bundle(rt: str);

def:pub open_tree(rt: str, exe_path: str) -> Embed;
