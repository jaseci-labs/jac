def _sysconfig_config_vars_impl(module: ptr[PyObject]) -> ptr[PyObject];

impl _sysconfig_config_vars_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    config = PyDict_New();
    if not config {
        return NULL;
    }
    for name in ["Py_GIL_DISABLED", "Py_DEBUG"] {
        zero = PyLong_FromLong(0);
        if not zero or dict_set_text(config, name, zero) < 0 {
            jacpy_release(zero);
            jacpy_release(config);
            return NULL;
        }
        jacpy_release(zero);
    }
    return config;
}
