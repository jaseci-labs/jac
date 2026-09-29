"""The syslog module: generated clinic tables, the hand-parsed syslog() and constants."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyModule_AddIntConstant,
    PyObject,
    PyTuple_GetItem,
    PyTuple_Size
}
import from jaclang.runtime.python.capi { boundary_failure, object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition
}
import from jaclang.runtime.python.bindings.converters {
    argument_label,
    convert_int,
    convert_str
}
import from jaclang.runtime.python.bindings.clinic.syslog { module_methods }
import from jaclang.runtime.python.modules.syslog {
    default_priority,
    syslog_syslog_impl
}
import from jaclang.runtime.python.modules.syslog_constants { PLATFORM, CONSTANTS }

# syslog([priority=LOG_INFO,] message): a clinic optional group, parsed as
# the generated C does, by argument count.
def:priv syslog_call(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
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
        object_error("TypeError", "syslog.syslog requires 1 to 2 arguments");
        return NULL;
    } except boundary_failure {
        return NULL;
    }
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            "ImportError",
            "syslog has no syslog_constants.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

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

def:pub PyInit_syslog -> ptr[PyObject] {
    return definition.initialize();
}
