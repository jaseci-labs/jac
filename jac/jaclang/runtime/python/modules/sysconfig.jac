import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_New,
    PyDict_SetItemString,
    PyLong_FromLong,
    PyObject,
    jacpy_release
}

"""Build variables for sysconfig; derived from CPython 3.14.6 Modules/_sysconfig.c.

Release runtimes are neither free-threaded nor debug builds.
"""
def _sysconfig_config_vars_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    config = PyDict_New();
    if not config {
        return NULL;
    }
    for name in ["Py_GIL_DISABLED", "Py_DEBUG"] {
        zero = PyLong_FromLong(0);
        if not zero or PyDict_SetItemString(config, name, zero) < 0 {
            jacpy_release(zero);
            jacpy_release(config);
            return NULL;
        }
        jacpy_release(zero);
    }
    return config;
}
