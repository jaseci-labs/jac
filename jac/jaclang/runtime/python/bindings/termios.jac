"""The termios module: generated clinic tables, termios.error and the constants."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyExc_ImportError,
    PyLong_FromUnsignedLong,
    PyModule_AddIntConstant,
    PyObject
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_owned,
    add_state_owned,
    jacpy_binding_exception
}
import from jaclang.runtime.python.bindings.clinic.termios { module_methods }
import from jaclang.runtime.python.modules.termios_records { PLATFORM }
import from jaclang.runtime.python.modules.termios_constants { CONSTANTS }

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" or len(CONSTANTS) == 0 {
        object_error(
            PyExc_ImportError,
            "termios has no termios_records/termios_constants for this target platform"
        );
        return i32(-1);
    }
    error = jacpy_binding_exception("termios.error", NULL, "");
    if not add_state_owned(module, 0, "error", error) {
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        # gh-119770: ioctl() requests are unsigned; some are negative C longs
        # on macOS.
        if name.startswith("TIO") {
            if not add_owned(
                module, name, PyLong_FromUnsignedLong(u64.wrap(value) & u64(0xFFFFFFFF))
            ) {
                return i32(-1);
            }
        } elif PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "termios",
         "This module provides an interface to the Posix calls for tty I/O control.\nFor a complete description of these calls, see the Posix or Unix manual\npages. It is only available for those Unix versions that support Posix\ntermios style tty I/O control.\n\nAll functions in this module take a file descriptor fd as their first\nargument. This can be an integer file descriptor, such as returned by\nsys.stdin.fileno(), or a file object, such as sys.stdin itself.",
         module_methods,
         ModuleHooks(execute=execute),
         1
     );

def:pub PyInit_termios -> ptr[PyObject] {
    return definition.initialize();
}
