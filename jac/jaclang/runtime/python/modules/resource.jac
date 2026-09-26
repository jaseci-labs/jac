"""Process resource usage and limits.

Derived from CPython 3.14.6 Modules/resource.c; see ../LICENSE.cpython.
Record layouts come from resource_records.<os>.jac and the limit and usage
constants from resource_constants.<os>.jac.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_SetFromErrno,
    PyFloat_FromDouble,
    PyLong_FromLong,
    PyLong_FromUnsignedLongLong,
    PyLong_IsNegative,
    PyNumber_Index,
    PyObject,
    PySequence_Tuple,
    PyStructSequence_New,
    PyStructSequence_SetItem,
    PySys_AuditTuple,
    PyTuple_GetItem,
    PyTuple_Size,
    Py_NewRef,
    jacpy_errno,
    jacpy_exception_type,
    jacpy_long_u64_checked,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error, object_tuple }
import from jaclang.runtime.python.bindings.converters { borrowed_none, convert_int }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.modules.resource_records {
    rusage,
    rlimit,
    timeval,
    prlimit
}
import from jaclang.runtime.python.modules.resource_constants {
    RLIM_INFINITY,
    RLIM_NLIMITS
}
import from c {
    def getrusage(who: i32, usage: &mut rusage) -> i32;  def getrlimit(
        resource: i32, limit: &mut rlimit
    ) -> i32;  def setrlimit(resource: i32, limit: &mut rlimit) -> i32;  def getpagesize -> i32;
}

glob:priv EINVAL: i32 = 22,
     EPERM: i32 = 1;

def convert_pid_t(value: ptr[PyObject], fname: str, label: str) -> i32 {
    return convert_int(value);
}

def:priv seconds(value: timeval) -> f64 {
    return f64(value.tv_sec) + f64(value.tv_usec) * 0.000001;
}

def:priv os_error -> ptr[PyObject] {
    PyErr_SetFromErrno(jacpy_exception_type("OSError"));
    return NULL;
}

def resource_getrusage_impl(module: ptr[PyObject], who: i32) -> ptr[PyObject] {
    usage = rusage();
    if getrusage(who, &mut usage) == -1 {
        if jacpy_errno() == EINVAL {
            object_error("ValueError", "invalid who parameter");
            return NULL;
        }
        return os_error();
    }
    result = PyStructSequence_New(jacpy_binding_state_get(module, 0));
    if not result {
        return NULL;
    }
    fields = [
        PyFloat_FromDouble(seconds(usage.ru_utime)),
        PyFloat_FromDouble(seconds(usage.ru_stime)),
        PyLong_FromLong(usage.ru_maxrss),
        PyLong_FromLong(usage.ru_ixrss),
        PyLong_FromLong(usage.ru_idrss),
        PyLong_FromLong(usage.ru_isrss),
        PyLong_FromLong(usage.ru_minflt),
        PyLong_FromLong(usage.ru_majflt),
        PyLong_FromLong(usage.ru_nswap),
        PyLong_FromLong(usage.ru_inblock),
        PyLong_FromLong(usage.ru_oublock),
        PyLong_FromLong(usage.ru_msgsnd),
        PyLong_FromLong(usage.ru_msgrcv),
        PyLong_FromLong(usage.ru_nsignals),
        PyLong_FromLong(usage.ru_nvcsw),
        PyLong_FromLong(usage.ru_nivcsw)
    ];
    failed = False;
    for index in range(len(fields)) {
        if fields[index] {
            PyStructSequence_SetItem(result, i64(index), fields[index]);
        } else {
            failed = True;
        }
    }
    if failed {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

# py2rlim(): any int in rlim_t's range; negatives only as RLIM_INFINITY.
def:priv py2rlim(value: ptr[PyObject]) -> tuple[bool, u64] {
    index = PyNumber_Index(value);
    if not index {
        return (False, u64(0));
    }
    negative = PyLong_IsNegative(index) == 1;
    number = u64(0);
    status = jacpy_long_u64_checked(index, &mut number);
    jacpy_release(index);
    if status < 0 {
        return (False, u64(0));
    }
    if negative and (number != u64.wrap(RLIM_INFINITY) or status > 0) {
        object_error("ValueError", "Cannot convert negative int");
        return (False, u64(0));
    }
    if status > 0 {
        object_error("OverflowError", "Python int too large to convert to C rlim_t");
        return (False, u64(0));
    }
    return (True, number);
}

def:priv py2rlimit(limits: ptr[PyObject], out: &mut rlimit) -> bool {
    pair = PySequence_Tuple(limits);
    if not pair {
        return False;
    }
    ok = False;
    if PyTuple_Size(pair) != 2 {
        object_error("ValueError", "expected a tuple of 2 integers");
    } else {
        (current_ok, current) = py2rlim(PyTuple_GetItem(pair, 0));
        if current_ok {
            (maximum_ok, maximum) = py2rlim(PyTuple_GetItem(pair, 1));
            if maximum_ok {
                out.rlim_cur = current;
                out.rlim_max = maximum;
                ok = True;
            }
        }
    }
    jacpy_release(pair);
    return ok;
}

# rlim2py(): RLIM_INFINITY is signed (-1 on Linux); other limits are unsigned.
def:priv rlim2py(value: u64) -> ptr[PyObject] {
    if value == u64.wrap(RLIM_INFINITY) {
        return PyLong_FromLong(RLIM_INFINITY);
    }
    return PyLong_FromUnsignedLongLong(value);
}

def:priv rlimit2py(limit: rlimit) -> ptr[PyObject] {
    current = rlim2py(limit.rlim_cur);
    if not current {
        return NULL;
    }
    maximum = rlim2py(limit.rlim_max);
    if not maximum {
        jacpy_release(current);
        return NULL;
    }
    result = object_tuple([current, maximum]);
    jacpy_release(current);
    jacpy_release(maximum);
    return result;
}

def:priv valid_resource(resource: i32) -> bool {
    if resource < 0 or i64(resource) >= RLIM_NLIMITS {
        object_error("ValueError", "invalid resource specified");
        return False;
    }
    return True;
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

def resource_getrlimit_impl(module: ptr[PyObject], resource: i32) -> ptr[PyObject] {
    if not valid_resource(resource) {
        return NULL;
    }
    limit = rlimit();
    if getrlimit(resource, &mut limit) == -1 {
        return os_error();
    }
    return rlimit2py(limit);
}

def resource_setrlimit_impl(
    module: ptr[PyObject], resource: i32, limits: ptr[PyObject]
) -> ptr[PyObject] {
    if not valid_resource(resource) {
        return NULL;
    }
    shown = Py_NewRef(limits or borrowed_none());
    if not audit("resource.setrlimit", [PyLong_FromLong(i64(resource)), shown]) {
        return NULL;
    }
    limit = rlimit();
    if not py2rlimit(limits, &mut limit) {
        return NULL;
    }
    if setrlimit(resource, &mut limit) == -1 {
        error = jacpy_errno();
        if error == EINVAL {
            object_error("ValueError", "current limit exceeds maximum limit");
        } elif error == EPERM {
            object_error("ValueError", "not allowed to raise maximum limit");
        } else {
            return os_error();
        }
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

def resource_prlimit_impl(
    module: ptr[PyObject], pid: i32, resource: i32, limits: ptr[PyObject]
) -> ptr[PyObject] {
    if not valid_resource(resource) {
        return NULL;
    }
    shown = Py_NewRef(limits or borrowed_none());
    if not audit(
        "resource.prlimit",
        [PyLong_FromLong(i64(pid)), PyLong_FromLong(i64(resource)), shown]
    ) {
        return NULL;
    }
    old_limit = rlimit();
    status = i32(0);
    if limits != borrowed_none() {
        new_limit = pin(rlimit());
        if not py2rlimit(limits, &mut new_limit.value) {
            return NULL;
        }
        status = prlimit(pid, resource, &mut new_limit, &mut old_limit);
    } else {
        status = prlimit(pid, resource, None, &mut old_limit);
    }
    if status == -1 {
        if jacpy_errno() == EINVAL {
            object_error("ValueError", "current limit exceeds maximum limit");
            return NULL;
        }
        return os_error();
    }
    return rlimit2py(old_limit);
}

def resource_getpagesize_impl(module: ptr[PyObject]) -> i32 {
    return getpagesize();
}
