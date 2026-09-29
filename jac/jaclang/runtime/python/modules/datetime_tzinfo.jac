"""The datetime.tzinfo and datetime.timezone types of the _datetime module.

Modules/_datetimemodule.c's PyDateTime_TZInfo and PyDateTime_TimeZone
implementations in native Jac. `PyDateTime_TZInfoType`,
`PyDateTime_TimeZoneType` and the immortal `utc_timezone` (whose offset is
the immortal zero timedelta) are C data under their C names. See
../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    PyErr_Format,
    PyErr_SetString,
    PyExc_NotImplementedError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyObject,
    PyObject_CallNoArgs,
    PyObject_GenericGetAttr,
    PyObject_GetOptionalAttr,
    PyTuple_New,
    PyTuple_Pack,
    PyType_GenericNew,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    _PyObject_GetState
}
import from jaclang.runtime.python.layouts {
    PY_DATETIME_TZINFO_SIZE,
    PY_OBJECT_SIZE,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object
}
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.capi { boundary_failure }
import from jaclang.runtime.python.modules.datetime_objects {
    PyDateTime_TimeZone,
    Py_EQ,
    Py_NE,
    add_datetime_timedelta,
    call_dst,
    datetime_check,
    datetime_dst,
    datetime_tzinfo_of,
    datetime_utcoffset,
    delta_bool,
    delta_negative,
    delta_subtract,
    delta_type,
    has_tzinfo,
    new_timezone,
    not_implemented,
    td_days,
    td_microseconds,
    td_seconds,
    timezone_check,
    type_free,
    type_name_of,
    type_object,
    type_of,
    utc
}
import from jaclang.runtime.python.modules.datetime_delta {
    delta_hash,
    delta_richcompare,
    zero_delta
}
import from jaclang.runtime.python.layouts { PyDateTime_DateTime }

import from c {
    glob PyType_Type: PyTypeObject; glob PyDateTime_TZInfoType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("datetime.tzinfo"),
             tp_basicsize=PY_DATETIME_TZINFO_SIZE,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8]("Abstract base class for time zone info objects."),
             tp_new=PyType_GenericNew
         ),
         PyDateTime_TimeZoneType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("datetime.timezone"),
             tp_basicsize=PY_OBJECT_SIZE + 16,
             tp_dealloc=timezone_dealloc,
             tp_repr=timezone_repr,
             tp_hash=timezone_hash,
             tp_str=timezone_str,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_doc=ptr[u8]("Fixed offset from UTC implementation of tzinfo."),
             tp_richcompare=timezone_richcompare,
             tp_base=addressof(PyDateTime_TZInfoType),
             tp_new=timezone_new
         ),
         # The UTC timezone: timezone(timedelta(0)), immortal.
         utc_timezone: PyDateTime_TimeZone = PyDateTime_TimeZone(
             ob_base=_object(
                 ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                 ob_type=addressof(PyDateTime_TimeZoneType)
             ),
             offset=ptr[PyObject](addressof(zero_delta)),
             name=ptr[PyObject]()
         );
}

# ---------------------------------------------------------------------------
# tzinfo: a pure abstract base class, so it does nothing beyond raising
# NotImplementedError. For reasons having to do with pickling of subclasses,
# tzinfo objects can be instantiated.

def tzinfo_nogo(methodname: str) -> ptr[PyObject] {
    PyErr_Format(
        PyExc_NotImplementedError, "a tzinfo subclass must implement %s()", methodname
    );
    return NULL;
}

def tzinfo_tzname(self: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    return tzinfo_nogo("tzname");
}

def tzinfo_utcoffset(self: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    return tzinfo_nogo("utcoffset");
}

def tzinfo_dst(self: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    return tzinfo_nogo("dst");
}

def tzinfo_fromutc(self: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    if not datetime_check(dt) {
        PyErr_SetString(PyExc_TypeError, "fromutc: argument must be a datetime");
        return NULL;
    }
    if datetime_tzinfo_of(dt) != self {
        PyErr_SetString(PyExc_ValueError, "fromutc: dt.tzinfo is not self");
        return NULL;
    }
    off = datetime_utcoffset(dt, NULL);
    if not off {
        return NULL;
    }
    dst: ptr[PyObject] = NULL;
    delta: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    failed = True;
    if off == Py_None {
        PyErr_SetString(
            PyExc_ValueError, "fromutc: non-None utcoffset() result required"
        );
    } else {
        dst = datetime_dst(dt, NULL);
        if dst == Py_None {
            PyErr_SetString(
                PyExc_ValueError, "fromutc: non-None dst() result required"
            );
        } elif dst {
            delta = delta_subtract(off, dst);
            if delta {
                result = add_datetime_timedelta(dt, delta, 1);
            }
            if result {
                jacpy_release(dst);
                dst = call_dst(datetime_tzinfo_of(dt), result);
                if dst == Py_None {
                    PyErr_SetString(
                        PyExc_ValueError,
                        "fromutc: tz.dst() gave inconsistent results; cannot convert"
                    );
                } elif dst {
                    failed = False;
                    if delta_bool(dst) != 0 {
                        shifted = add_datetime_timedelta(result, dst, 1);
                        jacpy_release(result);
                        result = shifted;
                        failed = not result;
                    }
                }
            }
        }
    }
    jacpy_release(off);
    jacpy_release(dst);
    jacpy_release(delta);
    if failed {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""Pickle support, solely so that tzinfo subclasses can use pickling."""
def tzinfo_reduce(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    name = PyUnicode_InternFromString("__getinitargs__");
    if not name {
        return NULL;
    }
    getinitargs: ptr[PyObject] = NULL;
    status = PyObject_GetOptionalAttr(self, name, &mut getinitargs);
    jacpy_release(name);
    if status < 0 {
        return NULL;
    }
    args: ptr[PyObject] = NULL;
    if getinitargs {
        args = PyObject_CallNoArgs(getinitargs);
        jacpy_release(getinitargs);
    } else {
        args = PyTuple_New(0);
    }
    if not args {
        return NULL;
    }
    state = _PyObject_GetState(self);
    if not state {
        jacpy_release(args);
        return NULL;
    }
    return Py_BuildValue("(ONN)", type_of(self), args, state);
}

# ---------------------------------------------------------------------------
# timezone.

def timezone_offset(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyDateTime_TimeZone](op).view(1)[0].offset;
}

def timezone_name(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyDateTime_TimeZone](op).view(1)[0].name;
}

def timezone_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(
            name="timezone", types=[type_object(delta_type())]
        ).parse_keywords(
            args, kw, "O!|U", ["offset", "name"]
        );
    } except boundary_failure {
        return NULL;
    }
    return new_timezone(values[0].object, values[1].object);
}

def timezone_dealloc(op: ptr[PyObject]) {
    record = ptr[PyDateTime_TimeZone](op).view(1);
    offset = record[0].offset;
    record[0].offset = NULL;
    jacpy_release(offset);
    name = record[0].name;
    record[0].name = NULL;
    jacpy_release(name);
    type_free(op);
}

def timezone_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if int(op) != Py_EQ and int(op) != Py_NE {
        return not_implemented();
    }
    if not timezone_check(other) {
        return not_implemented();
    }
    return delta_richcompare(timezone_offset(self), timezone_offset(other), op);
}

def timezone_hash(op: ptr[PyObject]) -> i64 {
    return delta_hash(timezone_offset(op));
}

"""Check the argument passed to tzname, utcoffset, or dst: 0, or -1 with
TypeError."""
def timezone_check_argument(dt: ptr[PyObject], meth: str) -> int {
    if dt == Py_None or datetime_check(dt) {
        return 0;
    }
    PyErr_Format(
        PyExc_TypeError,
        "%s(dt) argument must be a datetime instance or None, not %.200s",
        meth,
        type_name_of(dt)
    );
    return -1;
}

def timezone_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    # Although timezone is not subclassable, it is convenient to use
    # Py_TYPE(self)->tp_name here.
    type_name = type_name_of(op);
    if op == utc() {
        return PyUnicode_FromFormat("%s.utc", type_name);
    }
    if not timezone_name(op) {
        return PyUnicode_FromFormat("%s(%R)", type_name, timezone_offset(op));
    }
    return PyUnicode_FromFormat(
        "%s(%R, %R)", type_name, timezone_offset(op), timezone_name(op)
    );
}

def timezone_str(op: ptr[PyObject]) -> ptr[PyObject] {
    if timezone_name(op) {
        return Py_NewRef(timezone_name(op));
    }
    offset = timezone_offset(op);
    if op == utc()
        or (
            td_days(offset) == 0
            and td_seconds(offset) == 0
            and td_microseconds(offset) == 0
        ) {
        return PyUnicode_FromString("UTC");
    }
    # Offset is normalized, so it is negative if days < 0
    sign = 43;
    if td_days(offset) < 0 {
        sign = 45;
        offset = delta_negative(offset);
        if not offset {
            return NULL;
        }
    } else {
        offset = Py_NewRef(offset);
    }
    # Offset is not negative here.
    microseconds = td_microseconds(offset);
    seconds = td_seconds(offset);
    jacpy_release(offset);
    minutes = seconds // 60;
    seconds = seconds % 60;
    hours = minutes // 60;
    minutes = minutes % 60;
    if microseconds != 0 {
        return PyUnicode_FromFormat(
            "UTC%c%02ld:%02ld:%02ld.%06ld",
            i32(sign),
            hours,
            minutes,
            seconds,
            microseconds
        );
    }
    if seconds != 0 {
        return PyUnicode_FromFormat(
            "UTC%c%02ld:%02ld:%02ld", i32(sign), hours, minutes, seconds
        );
    }
    return PyUnicode_FromFormat("UTC%c%02ld:%02ld", i32(sign), hours, minutes);
}

def timezone_tzname(op: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    if timezone_check_argument(dt, "tzname") == -1 {
        return NULL;
    }
    return timezone_str(op);
}

def timezone_utcoffset(op: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    if timezone_check_argument(dt, "utcoffset") == -1 {
        return NULL;
    }
    return Py_NewRef(timezone_offset(op));
}

def timezone_dst(op: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    if timezone_check_argument(dt, "dst") == -1 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def timezone_fromutc(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not datetime_check(arg) {
        PyErr_SetString(PyExc_TypeError, "fromutc: argument must be a datetime");
        return NULL;
    }
    if not has_tzinfo(arg) or ptr[PyDateTime_DateTime](arg).view(1)[0].tzinfo != op {
        PyErr_SetString(PyExc_ValueError, "fromutc: dt.tzinfo is not self");
        return NULL;
    }
    return add_datetime_timedelta(arg, timezone_offset(op), 1);
}

def timezone_getinitargs(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if not timezone_name(op) {
        return PyTuple_Pack(1, timezone_offset(op));
    }
    return PyTuple_Pack(2, timezone_offset(op), timezone_name(op));
}
