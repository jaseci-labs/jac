import from c {
    obj _PyPathConfig {
        has program_full_path: ptr[i32] = ptr[i32](),
            prefix: ptr[i32] = ptr[i32](),
            exec_prefix: ptr[i32] = ptr[i32](),
            stdlib_dir: ptr[i32] = ptr[i32](),
            module_search_path: ptr[i32] = ptr[i32](),
            calculated_module_search_path: ptr[i32] = ptr[i32](),
            program_name: ptr[i32] = ptr[i32](),
            home: ptr[i32] = ptr[i32](),
            _is_python_build: i32 = 0;
    }  def wcslen(text: ptr[i32]) -> u64;  def wcscmp(
        left: ptr[i32], right: ptr[i32]
    ) -> i32;  def wcscpy(target: ptr[i32], source: ptr[i32]) -> ptr[i32];  def wcsncpy(
        target: ptr[i32], source: ptr[i32], count: u64
    ) -> ptr[i32];  def wcschr(text: ptr[i32], ch: i32) -> ptr[i32];  def wcsrchr(
        text: ptr[i32], ch: i32
    ) -> ptr[i32];  def _PyMem_DefaultRawMalloc(size: u64) -> ptr;  def _PyMem_DefaultRawFree(
        block: ptr
    );  def _PyMem_DefaultRawWcsdup(text: ptr[i32]) -> ptr[i32];  def PyConfig_SetString(
        config: ptr[u8], config_str: ptr[ptr[i32]], text: ptr[i32]
    ) -> PyStatus;  def _Py_FatalErrorFunc(func: ptr[u8], msg: ptr[u8]);  def _Py_wgetcwd(
        buf: ptr[i32], buflen: u64
    ) -> ptr[i32];  def _Py_wreadlink(
        path: ptr[i32], buf: ptr[i32], buflen: u64
    ) -> i32;  def _Py_wrealpath(
        path: ptr[i32], resolved_path: ptr[i32], resolved_path_len: u64
    ) -> ptr[i32];  glob _Py_path_config: _PyPathConfig = _PyPathConfig(); glob:priv EMPTY_W:
             list[i32] = [i32(0)],
         MODULE_ARG_W: list[i32] = [i32(45), i32(109), i32(0)],
         COMMAND_ARG_W: list[i32] = [i32(45), i32(99), i32(0)]; def _PyPathConfig_GetGlobalModuleSearchPath -> ptr[
        i32
    ] {
        return path_config().view(1)[0].module_search_path;
    }  def _PyPathConfig_ClearGlobal {
        clear_global();
    }  def _PyPathConfig_ReadGlobal(config: ptr[u8]) -> PyStatus {
        status = status_ok();
        g = path_config();

        status = read_global_string(config, PyConfig_PREFIX, g.view(1)[0].prefix);
        if status_exception(status) {
            return status;
        }
        status = read_global_string(
            config, PyConfig_EXEC_PREFIX, g.view(1)[0].exec_prefix
        );
        if status_exception(status) {
            return status;
        }
        status = read_global_string(
            config, PyConfig_STDLIB_DIR, g.view(1)[0].stdlib_dir
        );
        if status_exception(status) {
            return status;
        }
        status = read_global_string(
            config, PyConfig_PROGRAM_NAME, g.view(1)[0].program_name
        );
        if status_exception(status) {
            return status;
        }
        status = read_global_string(config, PyConfig_HOME, g.view(1)[0].home);
        if status_exception(status) {
            return status;
        }
        status = read_global_string(
            config, PyConfig_EXECUTABLE, g.view(1)[0].program_full_path
        );
        if status_exception(status) {
            return status;
        }
        is_python_build = g.view(1)[0]._is_python_build;
        target = ptr[i32](config + PyConfig_IS_PYTHON_BUILD);
        if is_python_build >= 0 and target.view(1)[0] <= 0 {
            target.view(1)[0] = is_python_build;
        }

        return status;
    }  def _PyPathConfig_UpdateGlobal(config: ptr[u8]) -> PyStatus {
        g = path_config();

        source = config_string(config, PyConfig_PREFIX);
        if source {
            _PyMem_DefaultRawFree(ptr(g.view(1)[0].prefix));
            g.view(1)[0].prefix = _PyMem_DefaultRawWcsdup(source);
            if not g.view(1)[0].prefix {
                return update_global_no_memory();
            }
        }
        source = config_string(config, PyConfig_EXEC_PREFIX);
        if source {
            _PyMem_DefaultRawFree(ptr(g.view(1)[0].exec_prefix));
            g.view(1)[0].exec_prefix = _PyMem_DefaultRawWcsdup(source);
            if not g.view(1)[0].exec_prefix {
                return update_global_no_memory();
            }
        }
        source = config_string(config, PyConfig_STDLIB_DIR);
        if source {
            _PyMem_DefaultRawFree(ptr(g.view(1)[0].stdlib_dir));
            g.view(1)[0].stdlib_dir = _PyMem_DefaultRawWcsdup(source);
            if not g.view(1)[0].stdlib_dir {
                return update_global_no_memory();
            }
        }
        source = config_string(config, PyConfig_PROGRAM_NAME);
        if source {
            _PyMem_DefaultRawFree(ptr(g.view(1)[0].program_name));
            g.view(1)[0].program_name = _PyMem_DefaultRawWcsdup(source);
            if not g.view(1)[0].program_name {
                return update_global_no_memory();
            }
        }
        source = config_string(config, PyConfig_HOME);
        if source {
            _PyMem_DefaultRawFree(ptr(g.view(1)[0].home));
            g.view(1)[0].home = _PyMem_DefaultRawWcsdup(source);
            if not g.view(1)[0].home {
                return update_global_no_memory();
            }
        }
        source = config_string(config, PyConfig_EXECUTABLE);
        if source {
            _PyMem_DefaultRawFree(ptr(g.view(1)[0].program_full_path));
            g.view(1)[0].program_full_path = _PyMem_DefaultRawWcsdup(source);
            if not g.view(1)[0].program_full_path {
                return update_global_no_memory();
            }
        }
        is_python_build = ptr[i32](config + PyConfig_IS_PYTHON_BUILD).view(1)[0];
        if is_python_build > 0 {
            g.view(1)[0]._is_python_build = is_python_build;
        }

        _PyMem_DefaultRawFree(ptr(g.view(1)[0].module_search_path));
        g.view(1)[0].module_search_path = ptr[i32]();
        _PyMem_DefaultRawFree(ptr(g.view(1)[0].calculated_module_search_path));
        g.view(1)[0].calculated_module_search_path = ptr[i32]();

        paths = config + PyConfig_MODULE_SEARCH_PATHS;
        length = ptr[i64](paths + PyWideStringList_LENGTH).view(1)[0];
        items = ptr[ptr[ptr[i32]]](paths + PyWideStringList_ITEMS).view(1)[0];

        cch: u64 = 1;
        for i in range(length) {
            cch = cch + u64(1) + wcslen((items + i).view(1)[0]);
        }

        path = ptr[i32](_PyMem_DefaultRawMalloc(u64(4) * cch));
        if not path {
            return update_global_no_memory();
        }
        end: i64 = 0;
        for i in range(length) {
            item = (items + i).view(1)[0];
            wcscpy(path + end, item);
            end = end + i64(wcslen(item));
            (path + end).view(1)[0] = DELIM;
            end = end + 1;
            (path + end).view(1)[0] = 0;
        }

        while True {
            (path + end).view(1)[0] = 0;
            if end == 0 {
                break;
            }
            end = end - 1;
            if (path + end).view(1)[0] != DELIM {
                break;
            }
        }
        g.view(1)[0].calculated_module_search_path = path;

        return status_ok();
    }  def Py_SetPath(path: ptr[i32]) {
        if not path {
            clear_global();
            return;
        }
        g = path_config();

        _PyMem_DefaultRawFree(ptr(g.view(1)[0].prefix));
        _PyMem_DefaultRawFree(ptr(g.view(1)[0].exec_prefix));
        _PyMem_DefaultRawFree(ptr(g.view(1)[0].stdlib_dir));
        _PyMem_DefaultRawFree(ptr(g.view(1)[0].module_search_path));
        _PyMem_DefaultRawFree(ptr(g.view(1)[0].calculated_module_search_path));

        empty = ptr[i32](addressof(EMPTY_W));
        g.view(1)[0].prefix = _PyMem_DefaultRawWcsdup(empty);
        g.view(1)[0].exec_prefix = _PyMem_DefaultRawWcsdup(empty);

        if g.view(1)[0].home {
            g.view(1)[0].stdlib_dir = _PyMem_DefaultRawWcsdup(g.view(1)[0].home);
        } else {
            g.view(1)[0].stdlib_dir = _PyMem_DefaultRawWcsdup(empty);
        }
        g.view(1)[0].module_search_path = _PyMem_DefaultRawWcsdup(path);
        g.view(1)[0].calculated_module_search_path = ptr[i32]();

        if not g.view(1)[0].prefix
            or not g.view(1)[0].exec_prefix
            or not g.view(1)[0].stdlib_dir
            or not g.view(1)[0].module_search_path {
            _Py_FatalErrorFunc(ptr[u8]("Py_SetPath"), ptr[u8]("out of memory"));
        }
    }  def Py_SetPythonHome(home: ptr[i32]) {
        has_value = False;
        if home and home.view(1)[0] != 0 {
            has_value = True;
        }
        g = path_config();

        _PyMem_DefaultRawFree(ptr(g.view(1)[0].home));
        g.view(1)[0].home = ptr[i32]();

        if has_value {
            g.view(1)[0].home = _PyMem_DefaultRawWcsdup(home);
        }

        if has_value and not g.view(1)[0].home {
            _Py_FatalErrorFunc(ptr[u8]("Py_SetPythonHome"), ptr[u8]("out of memory"));
        }
    }  def Py_SetProgramName(program_name: ptr[i32]) {
        has_value = False;
        if program_name and program_name.view(1)[0] != 0 {
            has_value = True;
        }
        g = path_config();

        _PyMem_DefaultRawFree(ptr(g.view(1)[0].program_name));
        g.view(1)[0].program_name = ptr[i32]();

        if has_value {
            g.view(1)[0].program_name = _PyMem_DefaultRawWcsdup(program_name);
        }

        if has_value and not g.view(1)[0].program_name {
            _Py_FatalErrorFunc(ptr[u8]("Py_SetProgramName"), ptr[u8]("out of memory"));
        }
    }  def Py_GetPath -> ptr[i32] {
        g = path_config();

        if g.view(1)[0].module_search_path {
            return g.view(1)[0].module_search_path;
        }

        return g.view(1)[0].calculated_module_search_path;
    }  def _Py_GetStdlibDir -> ptr[i32] {
        stdlib_dir = path_config().view(1)[0].stdlib_dir;
        if stdlib_dir and stdlib_dir.view(1)[0] != 0 {
            return stdlib_dir;
        }
        return ptr[i32]();
    }  def Py_GetPrefix -> ptr[i32] {
        return path_config().view(1)[0].prefix;
    }  def Py_GetExecPrefix -> ptr[i32] {
        return path_config().view(1)[0].exec_prefix;
    }  def Py_GetProgramFullPath -> ptr[i32] {
        return path_config().view(1)[0].program_full_path;
    }  def Py_GetPythonHome -> ptr[i32] {
        return path_config().view(1)[0].home;
    }  def Py_GetProgramName -> ptr[i32] {
        return path_config().view(1)[0].program_name;
    }  def _PyPathConfig_ComputeSysPath0(
        argv: ptr[u8], path0_p: ptr[ptr[PyObject]]
    ) -> i32 {
        length = ptr[i64](argv + PyWideStringList_LENGTH).view(1)[0];
        if length == 0 {
            return 0;
        }

        items = ptr[ptr[ptr[i32]]](argv + PyWideStringList_ITEMS).view(1)[0];
        argv0 = items.view(1)[0];
        have_module_arg = wcscmp(argv0, ptr[i32](addressof(MODULE_ARG_W))) == 0;
        have_script_arg = not have_module_arg
            and wcscmp(argv0, ptr[i32](addressof(COMMAND_ARG_W))) != 0;

        path0 = argv0;
        n: i64 = 0;

        block = ptr[i32](PyMem_RawMalloc(u64(4) * u64(4 * MAXPATHLEN + 2)));
        if not block {
            PyErr_NoMemory();
            return -1;
        }
        fullpath = block;
        link = block + MAXPATHLEN;
        path0copy = link + (MAXPATHLEN + 1);

        if have_module_arg {
            if not _Py_wgetcwd(fullpath, u64(MAXPATHLEN)) {
                PyMem_RawFree(ptr(block));
                return 0;
            }
            path0 = fullpath;
            n = i64(wcslen(path0));
        }

        nr: i32 = 0;
        if have_script_arg {
            nr = _Py_wreadlink(path0, link, u64(MAXPATHLEN + 1));
        }
        if nr > 0 {
            (link + i64(nr)).view(1)[0] = 0;
            if link.view(1)[0] == SEP {
                path0 = link;
            } elif wcschr(link, SEP) {
                q = wcsrchr(path0, SEP);
                if not q {
                    path0 = link;
                } else {
                    wcsncpy(path0copy, path0, u64(MAXPATHLEN));
                    q = wcsrchr(path0copy, SEP);
                    wcsncpy(q + 1, link, u64(MAXPATHLEN));
                    (q + (MAXPATHLEN + 1)).view(1)[0] = 0;
                    path0 = path0copy;
                }
            }
        }

        p = ptr[i32]();
        if have_script_arg {
            if _Py_wrealpath(path0, fullpath, u64(MAXPATHLEN)) {
                path0 = fullpath;
            }
            p = wcsrchr(path0, SEP);
        }
        if p {
            n = i64((int(p) - int(path0)) // 4) + 1;
            if n > 1 {
                n = n - 1;
            }
        }

        path0_obj = PyUnicode_FromWideChar(path0, n);
        PyMem_RawFree(ptr(block));
        if not path0_obj {
            return -1;
        }

        path0_p.view(1)[0] = path0_obj;
        return 1;
    }
}

glob:priv DELIM: Final[i32] = 58,
     SEP: Final[i32] = 47;

def:priv path_config -> ptr[_PyPathConfig];

def:priv status_ok -> PyStatus;

def:priv status_exception(status: PyStatus) -> bool;

def:priv update_global_no_memory -> PyStatus;

def:priv config_string(config: ptr[u8], offset: i64) -> ptr[i32];

def:priv read_global_string(config: ptr[u8], offset: i64, value: ptr[i32]) -> PyStatus;

def:priv clear_global;

impl path_config -> ptr[_PyPathConfig] {
    return addressof(_Py_path_config);
}

impl status_ok -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl status_exception(status: PyStatus) -> bool {
    return status._type != _PyStatus_TYPE_OK;
}

impl update_global_no_memory -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_ERROR,
        func=ptr[u8]("_PyPathConfig_UpdateGlobal"),
        err_msg=ptr[u8]("memory allocation failed"),
        exitcode=0
    );
}

impl config_string(config: ptr[u8], offset: i64) -> ptr[i32] {
    return ptr[ptr[i32]](config + offset).view(1)[0];
}

impl read_global_string(config: ptr[u8], offset: i64, value: ptr[i32]) -> PyStatus {
    field = ptr[ptr[i32]](config + offset);
    if value and not field.view(1)[0] {
        return PyConfig_SetString(config, field, value);
    }
    return status_ok();
}

impl clear_global {
    g = path_config();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].program_full_path));
    g.view(1)[0].program_full_path = ptr[i32]();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].prefix));
    g.view(1)[0].prefix = ptr[i32]();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].exec_prefix));
    g.view(1)[0].exec_prefix = ptr[i32]();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].stdlib_dir));
    g.view(1)[0].stdlib_dir = ptr[i32]();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].module_search_path));
    g.view(1)[0].module_search_path = ptr[i32]();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].calculated_module_search_path));
    g.view(1)[0].calculated_module_search_path = ptr[i32]();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].program_name));
    g.view(1)[0].program_name = ptr[i32]();
    _PyMem_DefaultRawFree(ptr(g.view(1)[0].home));
    g.view(1)[0].home = ptr[i32]();
    g.view(1)[0]._is_python_build = 0;
}
