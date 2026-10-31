def:priv add_errcode(
    module_dict: ptr[PyObject], error_dict: ptr[PyObject], name: str, code: i64
) -> bool;

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "errno",
         "This module makes available standard errno system symbols.\n\nThe value of each symbol is the corresponding integer value,\ne.g., on most systems, errno.ENOENT equals the integer 2.\n\nThe dictionary errno.errorcode maps numeric codes to symbol names,\ne.g., errno.errorcode[2] could be the string 'ENOENT'.\n\nSymbols that are not relevant to the underlying system are not defined.\n\nTo map error codes to error messages, use the function os.strerror(),\ne.g. os.strerror(2) could return 'No such file or directory'.",
         [],
         ModuleHooks(execute=execute)
     );

def:pub PyInit_errno -> ptr[PyObject];

impl add_errcode(
    module_dict: ptr[PyObject], error_dict: ptr[PyObject], name: str, code: i64
) -> bool {
    text = jacpy_unicode_from_text(name);
    number = PyLong_FromLong(code);
    ok = bool(text)
        and bool(number)
        and PyDict_SetItem(module_dict, text, number) == 0
        and PyDict_SetItem(error_dict, number, text) == 0;
    jacpy_release(text);
    jacpy_release(number);
    return ok;
}

impl execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError,
            "errno has no errno_constants.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    module_dict = PyModule_GetDict(module);
    if not module_dict {
        return i32(-1);
    }
    error_dict = PyDict_New();
    if not error_dict {
        return i32(-1);
    }
    if PyDict_SetItemString(module_dict, ptr[u8]("errorcode"), error_dict) < 0 {
        jacpy_release(error_dict);
        return i32(-1);
    }
    for (name, code) in CONSTANTS {
        if not add_errcode(module_dict, error_dict, name, code) {
            jacpy_release(error_dict);
            return i32(-1);
        }
    }
    jacpy_release(error_dict);
    return i32(0);
}

impl PyInit_errno -> ptr[PyObject] {
    return definition.initialize();
}
