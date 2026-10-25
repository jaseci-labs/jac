import from c {
    def PyUnicode_FromStringAndSize(u: ptr[u8], size: i64) -> ptr[PyObject];
}

glob:priv UCHAR_MAX: i64 = 255,
     SHRT_MAX: i64 = 32767,
     SHRT_MIN: i64 = -32768,
     USHRT_MAX: i64 = 65535,
     INT_MAX: i64 = 2147483647,
     INT_MIN: i64 = -2147483648,
     UINT_MAX: u64 = 4294967295,
     ULONG_ALL: u64 = 0xFFFFFFFFFFFFFFFF;

def char_value(addr: ptr[u8]) -> i64;

def set_error_text(exception: ptr[PyObject], text: ptr[u8]);

def member_get_object(
    addr: ptr[u8], obj_addr: ptr[u8], l: ptr[PyMemberDef]
) -> ptr[PyObject];

def warn_negative_unsigned -> i32;

import from c {
    def PyMember_GetOne(obj_addr: ptr[u8], l: ptr[PyMemberDef]) -> ptr[PyObject] {
        if (l.view(1)[0].flags & Py_RELATIVE_OFFSET) != 0 {
            PyErr_SetString(
                PyExc_SystemError, "PyMember_GetOne used with Py_RELATIVE_OFFSET"
            );
            return NULL;
        }
        addr = obj_addr + l.view(1)[0].offset;
        kind = l.view(1)[0].type_;
        v = NULL;
        if kind == Py_T_BOOL {
            v = PyBool_FromLong(char_value(addr));
        } elif kind == Py_T_BYTE {
            v = PyLong_FromLong(char_value(addr));
        } elif kind == Py_T_UBYTE {
            v = PyLong_FromUnsignedLong(u64(addr.view(1)[0]));
        } elif kind == Py_T_SHORT {
            v = PyLong_FromLong(i64(ptr[i16](addr).view(1)[0]));
        } elif kind == Py_T_USHORT {
            v = PyLong_FromUnsignedLong(u64(ptr[u16](addr).view(1)[0]));
        } elif kind == Py_T_INT {
            v = PyLong_FromLong(i64(ptr[i32](addr).view(1)[0]));
        } elif kind == Py_T_UINT {
            v = PyLong_FromUnsignedLong(u64(ptr[u32](addr).view(1)[0]));
        } elif kind == Py_T_LONG {
            v = PyLong_FromLong(ptr[i64](addr).view(1)[0]);
        } elif kind == Py_T_ULONG {
            v = PyLong_FromUnsignedLong(ptr[u64](addr).view(1)[0]);
        } elif kind == Py_T_PYSSIZET {
            v = PyLong_FromSsize_t(ptr[i64](addr).view(1)[0]);
        } elif kind == Py_T_FLOAT {
            v = PyFloat_FromDouble(f64(ptr[f32](addr).view(1)[0]));
        } elif kind == Py_T_DOUBLE {
            v = PyFloat_FromDouble(ptr[f64](addr).view(1)[0]);
        } elif kind == Py_T_STRING {
            text = ptr[ptr[u8]](addr).view(1)[0];
            if not text {
                v = object_new_ref(Py_None);
            } else {
                v = PyUnicode_FromString(text);
            }
        } elif kind == Py_T_STRING_INPLACE {
            v = PyUnicode_FromString(addr);
        } elif kind == Py_T_CHAR {
            v = PyUnicode_FromStringAndSize(addr, 1);
        } elif kind == _Py_T_OBJECT {
            v = ptr[ptr[PyObject]](addr).view(1)[0];
            if v {
                object_incref(v);
            }
            if not v {
                v = Py_None;
            }
        } elif kind == Py_T_OBJECT_EX {
            v = member_get_object(addr, obj_addr, l);
            if v {
                object_incref(v);
            }
        } elif kind == Py_T_LONGLONG {
            v = PyLong_FromLongLong(ptr[i64](addr).view(1)[0]);
        } elif kind == Py_T_ULONGLONG {
            v = PyLong_FromUnsignedLongLong(ptr[u64](addr).view(1)[0]);
        } elif kind == _Py_T_NONE {
            v = object_new_ref(Py_None);
        } else {
            PyErr_SetString(PyExc_SystemError, "bad memberdescr type");
            v = NULL;
        }
        return v;
    }  def PyMember_SetOne(
        addr: ptr[u8], l: ptr[PyMemberDef], v: ptr[PyObject]
    ) -> i32 {
        if (l.view(1)[0].flags & Py_RELATIVE_OFFSET) != 0 {
            PyErr_SetString(
                PyExc_SystemError, "PyMember_SetOne used with Py_RELATIVE_OFFSET"
            );
            return -1;
        }
        field = addr + l.view(1)[0].offset;
        kind = l.view(1)[0].type_;
        if (l.view(1)[0].flags & Py_READONLY) != 0 {
            PyErr_SetString(PyExc_AttributeError, "readonly attribute");
            return -1;
        }
        if not v and kind != Py_T_OBJECT_EX and kind != _Py_T_OBJECT {
            PyErr_SetString(PyExc_TypeError, "can't delete numeric/char attribute");
            return -1;
        }
        if kind == Py_T_BOOL {
            if not bool_check(v) {
                PyErr_SetString(PyExc_TypeError, "attribute value type must be bool");
                return -1;
            }
            if v == py_true() {
                field.view(1)[0] = 1;
            } else {
                field.view(1)[0] = 0;
            }
        } elif kind == Py_T_BYTE {
            long_val = PyLong_AsLong(v);
            if long_val == -1 and PyErr_Occurred() {
                return -1;
            }
            field.view(1)[0] = u8.wrap(long_val);
            if long_val > CHAR_MAX or long_val < CHAR_MIN {
                if PyErr_WarnEx(PyExc_RuntimeWarning, "Truncation of value to char", 1)
                    < 0 {
                    return -1;
                }
            }
        } elif kind == Py_T_UBYTE {
            long_val = PyLong_AsLong(v);
            if long_val == -1 and PyErr_Occurred() {
                return -1;
            }
            field.view(1)[0] = u8.wrap(long_val);
            if long_val > UCHAR_MAX or long_val < 0 {
                if PyErr_WarnEx(
                    PyExc_RuntimeWarning, "Truncation of value to unsigned char", 1
                )
                    < 0 {
                    return -1;
                }
            }
        } elif kind == Py_T_SHORT {
            long_val = PyLong_AsLong(v);
            if long_val == -1 and PyErr_Occurred() {
                return -1;
            }
            ptr[i16](field).view(1)[0] = i16.wrap(long_val);
            if long_val > SHRT_MAX or long_val < SHRT_MIN {
                if PyErr_WarnEx(PyExc_RuntimeWarning, "Truncation of value to short", 1)
                    < 0 {
                    return -1;
                }
            }
        } elif kind == Py_T_USHORT {
            long_val = PyLong_AsLong(v);
            if long_val == -1 and PyErr_Occurred() {
                return -1;
            }
            ptr[u16](field).view(1)[0] = u16.wrap(long_val);
            if long_val > USHRT_MAX or long_val < 0 {
                if PyErr_WarnEx(
                    PyExc_RuntimeWarning, "Truncation of value to unsigned short", 1
                )
                    < 0 {
                    return -1;
                }
            }
        } elif kind == Py_T_INT {
            long_val = PyLong_AsLong(v);
            if long_val == -1 and PyErr_Occurred() {
                return -1;
            }
            ptr[i32](field).view(1)[0] = i32.wrap(long_val);
            if long_val > INT_MAX or long_val < INT_MIN {
                if PyErr_WarnEx(PyExc_RuntimeWarning, "Truncation of value to int", 1)
                    < 0 {
                    return -1;
                }
            }
        } elif kind == Py_T_UINT {
            index = _PyNumber_Index(v);
            if not index {
                return -1;
            }
            if long_is_negative(index) {
                long_val = PyLong_AsLong(index);
                object_decref(index);
                if long_val == -1 and PyErr_Occurred() {
                    return -1;
                }
                ptr[u32](field).view(1)[0] = u32.wrap(long_val);
                if warn_negative_unsigned() < 0 {
                    return -1;
                }
            } else {
                ulong_val = PyLong_AsUnsignedLong(index);
                object_decref(index);
                if ulong_val == ULONG_ALL and PyErr_Occurred() {
                    return -1;
                }
                ptr[u32](field).view(1)[0] = u32.wrap(ulong_val);
                if ulong_val > UINT_MAX {
                    if PyErr_WarnEx(
                        PyExc_RuntimeWarning, "Truncation of value to unsigned int", 1
                    )
                        < 0 {
                        return -1;
                    }
                }
            }
        } elif kind == Py_T_LONG {
            long_val = PyLong_AsLong(v);
            if long_val == -1 and PyErr_Occurred() {
                return -1;
            }
            ptr[i64](field).view(1)[0] = long_val;
        } elif kind == Py_T_ULONG {
            index = _PyNumber_Index(v);
            if not index {
                return -1;
            }
            if long_is_negative(index) {
                long_val = PyLong_AsLong(index);
                object_decref(index);
                if long_val == -1 and PyErr_Occurred() {
                    return -1;
                }
                ptr[u64](field).view(1)[0] = u64.wrap(long_val);
                if warn_negative_unsigned() < 0 {
                    return -1;
                }
            } else {
                ulong_val = PyLong_AsUnsignedLong(index);
                object_decref(index);
                if ulong_val == ULONG_ALL and PyErr_Occurred() {
                    return -1;
                }
                ptr[u64](field).view(1)[0] = ulong_val;
            }
        } elif kind == Py_T_PYSSIZET {
            ssize_val = PyLong_AsSsize_t(v);
            if ssize_val == -1 and PyErr_Occurred() {
                return -1;
            }
            ptr[i64](field).view(1)[0] = ssize_val;
        } elif kind == Py_T_FLOAT {
            double_val = PyFloat_AsDouble(v);
            if double_val == -1.0 and PyErr_Occurred() {
                return -1;
            }
            ptr[f32](field).view(1)[0] = f32(double_val);
        } elif kind == Py_T_DOUBLE {
            double_val = PyFloat_AsDouble(v);
            if double_val == -1.0 and PyErr_Occurred() {
                return -1;
            }
            ptr[f64](field).view(1)[0] = double_val;
        } elif kind == _Py_T_OBJECT or kind == Py_T_OBJECT_EX {
            slot = ptr[ptr[PyObject]](field);
            oldv = slot.view(1)[0];
            if v {
                object_incref(v);
            }
            slot.view(1)[0] = v;
            if not v and not oldv and kind == Py_T_OBJECT_EX {
                set_error_text(PyExc_AttributeError, l.view(1)[0].name);
                return -1;
            }
            object_xdecref(oldv);
        } elif kind == Py_T_CHAR {
            size: i64 = 0;
            text = PyUnicode_AsUTF8AndSize(v, &mut size);
            if not text or size != 1 {
                PyErr_BadArgument();
                return -1;
            }
            field.view(1)[0] = text.view(1)[0];
        } elif kind == Py_T_STRING or kind == Py_T_STRING_INPLACE {
            PyErr_SetString(PyExc_TypeError, "readonly attribute");
            return -1;
        } elif kind == Py_T_LONGLONG {
            value = PyLong_AsLongLong(v);
            if value == -1 and PyErr_Occurred() {
                return -1;
            }
            ptr[i64](field).view(1)[0] = value;
        } elif kind == Py_T_ULONGLONG {
            index = _PyNumber_Index(v);
            if not index {
                return -1;
            }
            if long_is_negative(index) {
                long_val = PyLong_AsLong(index);
                object_decref(index);
                if long_val == -1 and PyErr_Occurred() {
                    return -1;
                }
                ptr[u64](field).view(1)[0] = u64.wrap(long_val);
                if warn_negative_unsigned() < 0 {
                    return -1;
                }
            } else {
                ulonglong_val = PyLong_AsUnsignedLongLong(index);
                object_decref(index);
                if ulonglong_val == ULONG_ALL and PyErr_Occurred() {
                    return -1;
                }
                ptr[u64](field).view(1)[0] = ulonglong_val;
            }
        } else {
            PyErr_Format(
                PyExc_SystemError, "bad memberdescr type for %s", l.view(1)[0].name
            );
            return -1;
        }
        return 0;
    }
}

impl char_value(addr: ptr[u8]) -> i64 {
    if CHAR_MIN < 0 {
        return i64(ptr[i8](addr).view(1)[0]);
    }
    return i64(addr.view(1)[0]);
}

impl set_error_text(exception: ptr[PyObject], text: ptr[u8]) {
    value = PyUnicode_FromString(text);
    if value {
        PyErr_SetObject(exception, value);
        object_decref(value);
    }
}

impl member_get_object(
    addr: ptr[u8], obj_addr: ptr[u8], l: ptr[PyMemberDef]
) -> ptr[PyObject] {
    v = ptr[ptr[PyObject]](addr).view(1)[0];
    if not v {
        PyErr_Format(
            PyExc_AttributeError,
            "'%T' object has no attribute '%s'",
            ptr[PyObject](obj_addr),
            l.view(1)[0].name
        );
    }
    return v;
}

impl warn_negative_unsigned -> i32 {
    if PyErr_WarnEx(
        PyExc_RuntimeWarning, "Writing negative value into unsigned field", 1
    )
        < 0 {
        return -1;
    }
    return 0;
}
