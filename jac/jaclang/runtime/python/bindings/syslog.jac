def:priv syslog_call(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "syslog",
         "",
         module_methods
             + [
                 MethodDefinition(
                     "syslog",
                     MethodCallbacks(positional=syslog_call),
                     "syslog([priority=LOG_INFO,] message)\nSend the string message to the system logger.",
                     flags=1
                 )
             ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit_syslog -> ptr[PyObject];

impl syslog_call(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        count = PyTuple_Size(args);
        if count == 1 {
            message = convert_str(
                PyTuple_GetItem(args, 0), "syslog", argument_label("", 1)
            );
            return syslog_syslog_impl(module, i32(0), default_priority(), message);
        }
        if count == 2 {
            priority = convert_int(PyTuple_GetItem(args, 0));
            message = convert_str(
                PyTuple_GetItem(args, 1), "syslog", argument_label("", 2)
            );
            return syslog_syslog_impl(module, i32(1), priority, message);
        }
        object_error(PyExc_TypeError, "syslog.syslog requires 1 to 2 arguments");
        return NULL;
    } except boundary_failure {
        return NULL;
    }
}

impl execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError,
            "syslog has no syslog_constants.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        if jacpy_module_add_int_text(module, name, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

impl PyInit_syslog -> ptr[PyObject] {
    return definition.initialize();
}
