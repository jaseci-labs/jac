"""Unix system logger interface.

Derived from CPython 3.14.6 Modules/syslogmodule.c; see ../LICENSE.cpython.
The logger is process-wide, so the open flag and the ident string it keeps
alive are process globals, and only the main interpreter may open or close it.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Clear,
    PyErr_Occurred,
    PyInterpreterState_Get,
    PyInterpreterState_Main,
    PyList_GetItem,
    PyList_Size,
    PyLong_FromLong,
    PyObject,
    PySys_AuditTuple,
    PyUnicode_AsUTF8,
    PyUnicode_FindChar,
    PyUnicode_FromString,
    PyUnicode_GetLength,
    PyUnicode_Substring,
    Py_NewRef,
    _PySys_GetOptionalAttrString,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_syslog
}
import from jaclang.runtime.python.capi { object_error, object_tuple }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.modules.syslog_constants { LOG_USER, LOG_INFO }
import from c {
    def openlog(ident: ptr[u8], option: i32, facility: i32);  def closelog;  def setlogmask(
        mask: i32
    ) -> i32;
}

glob:priv ident_object: ptr[PyObject] = NULL,
     log_open: bool = False;

def:priv is_main_interpreter -> bool {
    return PyInterpreterState_Get() == PyInterpreterState_Main();
}

# The script name from sys.argv[0], as openlog()'s default ident.
def:priv syslog_get_argv -> ptr[PyObject] {
    argv = NULL;
    if _PySys_GetOptionalAttrString("argv", &mut argv) <= 0 {
        return NULL;
    }
    count = PyList_Size(argv);
    if count <= 0 {
        if count == -1 {
            PyErr_Clear();
        }
        jacpy_release(argv);
        return NULL;
    }
    script = PyList_GetItem(argv, 0);
    if script {
        script = Py_NewRef(script);
    }
    jacpy_release(argv);
    if not script {
        PyErr_Clear();
        return NULL;
    }
    if jacpy_is_unicode(script) == 0 {
        jacpy_release(script);
        return NULL;
    }
    length = PyUnicode_GetLength(script);
    if length == 0 {
        jacpy_release(script);
        return NULL;
    }
    slash = PyUnicode_FindChar(script, u32(47), 0, length, -1);
    if slash == -2 {
        PyErr_Clear();
        jacpy_release(script);
        return NULL;
    }
    if slash != -1 {
        tail = PyUnicode_Substring(script, slash + 1, length);
        jacpy_release(script);
        return tail;
    }
    return script;
}

def:priv audit(event: str, values: list[ptr[PyObject]]) -> bool {
    arguments = object_tuple(values);
    for value in values {
        jacpy_release(value);
    }
    status = PySys_AuditTuple(event, arguments);
    jacpy_release(arguments);
    return status >= 0;
}

def syslog_openlog_impl(
    module: ptr[PyObject], ident: ptr[PyObject], logopt: i64, facility: i64
) -> ptr[PyObject] {
    if not is_main_interpreter() {
        object_error("RuntimeError", "subinterpreter can't use syslog.openlog()");
        return NULL;
    }
    name = NULL;
    if ident {
        name = Py_NewRef(ident);
    } else {
        name = syslog_get_argv();
        if not name and PyErr_Occurred() {
            return NULL;
        }
    }
    text = ptr[u8]();
    if name {
        text = PyUnicode_AsUTF8(name);
        if text.is_null() {
            jacpy_release(name);
            return NULL;
        }
    }
    shown = Py_NewRef(name or borrowed_none());
    if not audit(
        "syslog.openlog", [shown, PyLong_FromLong(logopt), PyLong_FromLong(facility)]
    ) {
        jacpy_release(name);
        return NULL;
    }
    openlog(text, i32(logopt), i32(facility));
    log_open = True;
    previous = ident_object;
    ident_object = name;
    jacpy_release(previous);
    return Py_NewRef(borrowed_none());
}

def syslog_syslog_impl(
    module: ptr[PyObject], group_left_1: i32, priority: i32, message: str
) -> ptr[PyObject] {
    if not audit(
        "syslog.syslog", [PyLong_FromLong(i64(priority)), PyUnicode_FromString(message)]
    ) {
        return NULL;
    }
    if not log_open {
        if not is_main_interpreter() {
            object_error(
                "RuntimeError",
                "subinterpreter can't use syslog.syslog() until the syslog is opened by the main interpreter"
            );
            return NULL;
        }
        opened = syslog_openlog_impl(module, NULL, 0, LOG_USER);
        if not opened {
            return NULL;
        }
        jacpy_release(opened);
    }
    # Keep the ident alive while the message is logged: openlog() keeps a
    # pointer to its UTF-8 buffer rather than a copy.
    ident = Py_NewRef(ident_object) if ident_object else NULL;
    jacpy_syslog(priority, message);
    jacpy_release(ident);
    return Py_NewRef(borrowed_none());
}

def syslog_closelog_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    if not is_main_interpreter() {
        object_error("RuntimeError", "subinterpreter can't use syslog.closelog()");
        return NULL;
    }
    if not audit("syslog.closelog", []) {
        return NULL;
    }
    if log_open {
        closelog();
        previous = ident_object;
        ident_object = NULL;
        jacpy_release(previous);
        log_open = False;
    }
    return Py_NewRef(borrowed_none());
}

def syslog_setlogmask_impl(module: ptr[PyObject], maskpri: i64) -> i64 {
    if not audit("syslog.setlogmask", [PyLong_FromLong(maskpri)]) {
        return -1;
    }
    return i64(setlogmask(i32(maskpri)));
}

def syslog_LOG_MASK_impl(module: ptr[PyObject], pri: i64) -> i64 {
    return 1 << pri;
}

def syslog_LOG_UPTO_impl(module: ptr[PyObject], pri: i64) -> i64 {
    return (1 << (pri + 1)) - 1;
}

def default_priority -> i32 {
    return i32(LOG_INFO);
}
