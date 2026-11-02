import from c {
    obj ExtModuleLoaderInfo {
        has filename: ptr[PyObject] = ptr[PyObject](),
            filename_encoded: ptr[PyObject] = ptr[PyObject](),
            name: ptr[PyObject] = ptr[PyObject](),
            name_encoded: ptr[PyObject] = ptr[PyObject](),
            path: ptr[PyObject] = ptr[PyObject](),
            origin: i32 = 0,
            hook_prefix: ptr[u8] = ptr[u8](),
            newcontext: ptr[u8] = ptr[u8]();
    }  obj ExtModuleLoaderResult {
        has module_def: ptr[u8] = ptr[u8](),
            module: ptr[PyObject] = ptr[PyObject](),
            kind: i32 = 0,
            err: ptr[u8] = ptr[u8](),
            err_kind: i32 = 0,
            err_exc: ptr[PyObject] = ptr[PyObject]();
    }  obj ModInitCall {
        has call: Callable[[], ptr[PyObject]] = 0;
    }  def dlopen(path: ptr[u8], flags: i32) -> ptr;  def dlsym(
        handle: ptr, symbol: ptr[u8]
    ) -> ptr;  def dlerror -> ptr[u8];  def strchr(
        text: ptr[u8], character: i32
    ) -> ptr[u8];  def fileno(stream: ptr[FILE]) -> i32;  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def _PyObject_CallMethod(
        obj_: ptr[PyObject], name: ptr[PyObject], format: ptr[u8], *args: any
    ) -> ptr[PyObject];  def _PyImport_SwapPackageContext(
        newcontext: ptr[u8]
    ) -> ptr[u8];  def _PyImport_GetDLOpenFlags(interp: ptr[u8]) -> i32;  glob:priv ascii_only_prefix:
             ptr[u8] = ptr[u8]("PyInit"),
         nonascii_prefix: ptr[u8] = ptr[u8]("PyInitU");
}

glob EXT_MODULE_KIND_UNKNOWN: Final[i32] = 0,
     EXT_MODULE_KIND_SINGLEPHASE: Final[i32] = 1,
     EXT_MODULE_KIND_MULTIPHASE: Final[i32] = 2,
     EXT_MODULE_KIND_INVALID: Final[i32] = 3,
     EXT_MODULE_ORIGIN_CORE: Final[i32] = 1,
     EXT_MODULE_ORIGIN_BUILTIN: Final[i32] = 2,
     EXT_MODULE_ORIGIN_DYNAMIC: Final[i32] = 3;

glob:priv RESULT_EXCEPTION: Final[i32] = 0,
     RESULT_ERR_MISSING: Final[i32] = 1,
     RESULT_ERR_UNREPORTED_EXC: Final[i32] = 2,
     RESULT_ERR_UNINITIALIZED: Final[i32] = 3,
     RESULT_ERR_NONASCII_NOT_MULTIPHASE: Final[i32] = 4,
     RESULT_ERR_NOT_MODULE: Final[i32] = 5,
     RESULT_ERR_MISSING_DEF: Final[i32] = 6,
     FUNCNAME_SIZE: Final[u64] = 258,
     PATHBUF_SIZE: Final[u64] = 260;

def get_encoded_name(name_in: ptr[PyObject]) -> tuple[ptr[PyObject], ptr[u8]];

def result_set_error(res: ptr[ExtModuleLoaderResult], kind: i32);

import from c {
    def _Py_ext_module_loader_info_clear(info: ptr[ExtModuleLoaderInfo]) {
        old = info.view(1)[0].filename;
        info.view(1)[0].filename = NULL;
        object_xdecref(old);
        old = info.view(1)[0].filename_encoded;
        info.view(1)[0].filename_encoded = NULL;
        object_xdecref(old);
        old = info.view(1)[0].name;
        info.view(1)[0].name = NULL;
        object_xdecref(old);
        old = info.view(1)[0].name_encoded;
        info.view(1)[0].name_encoded = NULL;
        object_xdecref(old);
    }  def _Py_ext_module_loader_info_init(
        p_info: ptr[ExtModuleLoaderInfo],
        name: ptr[PyObject],
        filename: ptr[PyObject],
        origin: i32
    ) -> i32 {
        if not unicode_check(name) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("module name must be a string"));
            return -1;
        }
        info_name = object_new_ref(name);

        (name_encoded, hook_prefix) = get_encoded_name(info_name);
        if not name_encoded {
            object_decref(info_name);
            return -1;
        }

        newcontext = PyUnicode_AsUTF8(info_name);
        if not newcontext {
            object_decref(info_name);
            object_decref(name_encoded);
            return -1;
        }

        info_filename = NULL;
        filename_encoded = NULL;
        path = info_name;
        if filename {
            if not unicode_check(filename) {
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("module filename must be a string")
                );
                object_decref(info_name);
                object_decref(name_encoded);
                return -1;
            }
            info_filename = object_new_ref(filename);

            filename_encoded = PyUnicode_EncodeFSDefault(info_filename);
            if not filename_encoded {
                object_decref(info_filename);
                object_decref(info_name);
                object_decref(name_encoded);
                return -1;
            }

            path = info_filename;
        }

        p_info.view(1)[0].filename = info_filename;
        p_info.view(1)[0].filename_encoded = filename_encoded;
        p_info.view(1)[0].name = info_name;
        p_info.view(1)[0].name_encoded = name_encoded;
        p_info.view(1)[0].path = path;
        p_info.view(1)[0].origin = origin;
        p_info.view(1)[0].hook_prefix = hook_prefix;
        p_info.view(1)[0].newcontext = newcontext;
        return 0;
    }  def _Py_ext_module_loader_info_init_for_builtin(
        info: ptr[ExtModuleLoaderInfo], name: ptr[PyObject]
    ) -> i32 {
        name_encoded = PyUnicode_AsEncodedString(name, ptr[u8]("ascii"), ptr[u8]());
        if not name_encoded {
            return -1;
        }

        info.view(1)[0].filename = NULL;
        info.view(1)[0].filename_encoded = NULL;
        info.view(1)[0].name = object_new_ref(name);
        info.view(1)[0].name_encoded = name_encoded;
        info.view(1)[0].path = name;
        info.view(1)[0].origin = EXT_MODULE_ORIGIN_BUILTIN;
        info.view(1)[0].hook_prefix = ptr[ptr[u8]](addressof(ascii_only_prefix)).view(1)[
            0
        ];
        info.view(1)[0].newcontext = ptr[u8]();
        return 0;
    }  def _Py_ext_module_loader_info_init_for_core(
        info: ptr[ExtModuleLoaderInfo], name: ptr[PyObject]
    ) -> i32 {
        if _Py_ext_module_loader_info_init_for_builtin(info, name) < 0 {
            return -1;
        }
        info.view(1)[0].origin = EXT_MODULE_ORIGIN_CORE;
        return 0;
    }  def _Py_ext_module_loader_info_init_from_spec(
        p_info: ptr[ExtModuleLoaderInfo], spec: ptr[PyObject]
    ) -> i32 {
        name = PyObject_GetAttrString(spec, ptr[u8]("name"));
        if not name {
            return -1;
        }
        filename = PyObject_GetAttrString(spec, ptr[u8]("origin"));
        if not filename {
            object_decref(name);
            return -1;
        }
        err = _Py_ext_module_loader_info_init(
            p_info, name, filename, EXT_MODULE_ORIGIN_DYNAMIC
        );
        object_decref(name);
        object_decref(filename);
        return err;
    }  def _Py_ext_module_loader_result_clear(res: ptr[ExtModuleLoaderResult]) {
        res.view(1)[0].module_def = ptr[u8]();
        res.view(1)[0].module = NULL;
        res.view(1)[0].kind = 0;
        res.view(1)[0].err = ptr[u8]();
        res.view(1)[0].err_kind = 0;
        res.view(1)[0].err_exc = NULL;
    }  def _Py_ext_module_loader_result_apply_error(
        res: ptr[ExtModuleLoaderResult], name: ptr[u8]
    ) {
        err_kind = res.view(1)[0].err_kind;
        err_exc = res.view(1)[0].err_exc;
        res.view(1)[0].err = ptr[u8]();

        _Py_ext_module_loader_result_clear(res);

        msg = ptr[u8]();
        if err_kind == RESULT_EXCEPTION {
            msg = ptr[u8]();
        } elif err_kind == RESULT_ERR_MISSING {
            msg = ptr[u8]("initialization of %s failed without raising an exception");
        } elif err_kind == RESULT_ERR_UNREPORTED_EXC {
            msg = ptr[u8]("initialization of %s raised unreported exception");
        } elif err_kind == RESULT_ERR_UNINITIALIZED {
            msg = ptr[u8]("init function of %s returned uninitialized object");
        } elif err_kind == RESULT_ERR_NONASCII_NOT_MULTIPHASE {
            msg = ptr[u8]("initialization of %s did not return PyModuleDef");
        } elif err_kind == RESULT_ERR_NOT_MODULE {
            msg = ptr[u8]("initialization of %s did not return an extension module");
        } elif err_kind == RESULT_ERR_MISSING_DEF {
            msg = ptr[u8](
                "initialization of %s did not return a valid extension module"
            );
        } else {
            PyErr_Format(
                PyExc_SystemError,
                ptr[u8]("loading %s failed due to init function"),
                name
            );
            return;
        }

        if err_exc {
            PyErr_SetRaisedException(err_exc);
            if msg {
                _PyErr_FormatFromCause(PyExc_SystemError, msg, name);
            }
        } else {
            PyErr_Format(PyExc_SystemError, msg, name);
        }
    }  def _PyImport_GetModInitFunc(
        info: ptr[ExtModuleLoaderInfo], fp: ptr[FILE]
    ) -> ptr {
        name_buf = bytes_data(info.view(1)[0].name_encoded);
        path_buf = bytes_data(info.view(1)[0].filename_encoded);
        exportfunc = _PyImport_FindSharedFuncptr(
            info.view(1)[0].hook_prefix, name_buf, path_buf, fp
        );

        if not exportfunc {
            if not PyErr_Occurred() {
                msg = PyUnicode_FromFormat(
                    "dynamic module does not define module export function (%s_%s)",
                    info.view(1)[0].hook_prefix,
                    name_buf
                );
                if msg {
                    PyErr_SetImportError(
                        msg, info.view(1)[0].name, info.view(1)[0].filename
                    );
                    object_decref(msg);
                }
            }
            return ptr();
        }

        return exportfunc;
    }  def _PyImport_RunModInitFunc(
        p0: ptr, info: ptr[ExtModuleLoaderInfo], p_res: ptr[ExtModuleLoaderResult]
    ) -> i32 {
        _Py_ext_module_loader_result_clear(p_res);
        p_res.view(1)[0].kind = EXT_MODULE_KIND_UNKNOWN;

        oldcontext = _PyImport_SwapPackageContext(info.view(1)[0].newcontext);
        init_call = ModInitCall();
        init_call.call = int(p0);
        m = init_call.call();
        _PyImport_SwapPackageContext(oldcontext);

        failed = False;
        if not m {
            p_res.view(1)[0].kind = EXT_MODULE_KIND_SINGLEPHASE;
            if PyErr_Occurred() {
                result_set_error(p_res, RESULT_EXCEPTION);
            } else {
                result_set_error(p_res, RESULT_ERR_MISSING);
            }
            failed = True;
        } elif PyErr_Occurred() {
            p_res.view(1)[0].kind = EXT_MODULE_KIND_SINGLEPHASE;
            result_set_error(p_res, RESULT_ERR_UNREPORTED_EXC);
            m = NULL;
            failed = True;
        } elif int(object_type(m)) == 0 {
            result_set_error(p_res, RESULT_ERR_UNINITIALIZED);
            m = NULL;
            failed = True;
        } elif object_type_check(m, ptr[PyTypeObject](addressof(PyModuleDef_Type))) {
            p_res.view(1)[0].kind = EXT_MODULE_KIND_MULTIPHASE;
            p_res.view(1)[0].module_def = ptr[u8](m);
        } elif int(info.view(1)[0].hook_prefix)
            == int(ptr[ptr[u8]](addressof(nonascii_prefix)).view(1)[0]) {
            p_res.view(1)[0].kind = EXT_MODULE_KIND_MULTIPHASE;
            result_set_error(p_res, RESULT_ERR_NONASCII_NOT_MULTIPHASE);
            failed = True;
        } else {
            p_res.view(1)[0].kind = EXT_MODULE_KIND_SINGLEPHASE;
            p_res.view(1)[0].module = m;
            if not module_check(m) {
                result_set_error(p_res, RESULT_ERR_NOT_MODULE);
                failed = True;
            } else {
                p_res.view(1)[0].module_def = ptr[u8](
                    ptr[PyModuleObject](m).view(1)[0].md_def
                );
                if not p_res.view(1)[0].module_def {
                    PyErr_Clear();
                    result_set_error(p_res, RESULT_ERR_MISSING_DEF);
                    failed = True;
                }
            }
        }

        if not failed {
            return 0;
        }

        old = p_res.view(1)[0].module;
        p_res.view(1)[0].module = NULL;
        object_xdecref(old);
        p_res.view(1)[0].module_def = ptr[u8]();
        p_res.view(1)[0].err = ptr[u8](p_res);
        return -1;
    }  def _PyImport_FindSharedFuncptr(
        prefix: ptr[u8], shortname: ptr[u8], pathname_in: ptr[u8], fp: ptr[FILE]
    ) -> ptr {
        buffers = ptr[u8](PyMem_RawMalloc(FUNCNAME_SIZE + PATHBUF_SIZE));
        if not buffers {
            PyErr_NoMemory();
            return ptr();
        }
        funcname = buffers;
        pathbuf = buffers + i64(FUNCNAME_SIZE);
        pathname = pathname_in;

        if not strchr(pathname, i32(47)) {
            PyOS_snprintf(pathbuf, PATHBUF_SIZE, ptr[u8]("./%-.255s"), pathname);
            pathname = pathbuf;
        }

        PyOS_snprintf(
            funcname, FUNCNAME_SIZE, ptr[u8]("%.20s_%.200s"), prefix, shortname
        );

        if fp {
            status: own _Py_stat_struct = _Py_stat_struct();
            if _Py_fstat(fileno(fp), &mut status) == -1 {
                PyMem_RawFree(buffers);
                return ptr();
            }
        }

        dlopenflags = _PyImport_GetDLOpenFlags(current_interp());

        handle = dlopen(pathname, dlopenflags);

        if not handle {
            error = dlerror();
            if not error {
                error = ptr[u8]("unknown dlopen() error");
            }
            error_ob = PyUnicode_DecodeLocale(error, ptr[u8]("surrogateescape"));
            if not error_ob {
                PyMem_RawFree(buffers);
                return ptr();
            }
            mod_name = PyUnicode_FromString(shortname);
            if not mod_name {
                object_decref(error_ob);
                PyMem_RawFree(buffers);
                return ptr();
            }
            path = PyUnicode_DecodeFSDefault(pathname);
            if not path {
                object_decref(error_ob);
                object_decref(mod_name);
                PyMem_RawFree(buffers);
                return ptr();
            }
            PyErr_SetImportError(error_ob, mod_name, path);
            object_decref(error_ob);
            object_decref(mod_name);
            object_decref(path);
            PyMem_RawFree(buffers);
            return ptr();
        }
        p = dlsym(handle, funcname);
        PyMem_RawFree(buffers);
        return p;
    }
}

impl get_encoded_name(name_in: ptr[PyObject]) -> tuple[ptr[PyObject], ptr[u8]] {
    name = name_in;
    name_len = PyUnicode_GetLength(name);
    if name_len < 0 {
        return (NULL, ptr[u8]());
    }
    lastdot = PyUnicode_FindChar(name, u32(46), 0, name_len, i32(-1));
    if lastdot < -1 {
        return (NULL, ptr[u8]());
    } elif lastdot >= 0 {
        tmp = PyUnicode_Substring(name, lastdot + 1, name_len);
        if not tmp {
            return (NULL, ptr[u8]());
        }
        name = tmp;
    } else {
        object_incref(name);
    }

    hook_prefix = ptr[u8]();
    encoded = PyUnicode_AsEncodedString(name, ptr[u8]("ascii"), ptr[u8]());
    if encoded {
        hook_prefix = ptr[ptr[u8]](addressof(ascii_only_prefix)).view(1)[0];
    } else {
        if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) == 0 {
            object_decref(name);
            return (NULL, ptr[u8]());
        }
        PyErr_Clear();
        encoded = PyUnicode_AsEncodedString(name, ptr[u8]("punycode"), ptr[u8]());
        if not encoded {
            object_decref(name);
            return (NULL, ptr[u8]());
        }
        hook_prefix = ptr[ptr[u8]](addressof(nonascii_prefix)).view(1)[0];
    }

    modname = _PyObject_CallMethod(
        encoded, py_id(_Py_ID_replace), ptr[u8]("cc"), i32(45), i32(95)
    );
    if not modname {
        object_decref(name);
        object_decref(encoded);
        return (NULL, ptr[u8]());
    }

    object_decref(name);
    object_decref(encoded);
    return (modname, hook_prefix);
}

impl result_set_error(res: ptr[ExtModuleLoaderResult], kind: i32) {
    res.view(1)[0].err = ptr[u8](res);
    res.view(1)[0].err_kind = kind;
    res.view(1)[0].err_exc = PyErr_GetRaisedException();
    if kind == RESULT_ERR_UNINITIALIZED {
        res.view(1)[0].kind = EXT_MODULE_KIND_INVALID;
    }
}
