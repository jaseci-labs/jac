import from c {
    def PyObject_Length(o: ptr[PyObject]) -> i64;  def _Py_strhex(
        argbuf: ptr[u8], arglen: i64
    ) -> ptr[PyObject] {
        return strhex_impl(argbuf, arglen, NULL, 0, False);
    }  def _Py_strhex_bytes(argbuf: ptr[u8], arglen: i64) -> ptr[PyObject] {
        return strhex_impl(argbuf, arglen, NULL, 0, True);
    }  def _Py_strhex_with_sep(
        argbuf: ptr[u8], arglen: i64, sep: ptr[PyObject], bytes_per_group: i32
    ) -> ptr[PyObject] {
        return strhex_impl(argbuf, arglen, sep, bytes_per_group, False);
    }  def _Py_strhex_bytes_with_sep(
        argbuf: ptr[u8], arglen: i64, sep: ptr[PyObject], bytes_per_group: i32
    ) -> ptr[PyObject] {
        return strhex_impl(argbuf, arglen, sep, bytes_per_group, True);
    }
}

glob:priv PY_SSIZE_T_MAX: Final[i64] = 0x7fffffffffffffff;

def hex_digit(v: u8) -> u8;

def strhex_impl(
    argbuf: ptr[u8],
    arglen: i64,
    sep: ptr[PyObject],
    bytes_per_sep_group: i32,
    return_bytes: bool
) -> ptr[PyObject];

impl hex_digit(v: u8) -> u8 {
    return (ptr[u8]("0123456789abcdef") + i64(v)).view(1)[0];
}

impl strhex_impl(
    argbuf: ptr[u8],
    arglen: i64,
    sep: ptr[PyObject],
    bytes_per_sep_group: i32,
    return_bytes: bool
) -> ptr[PyObject] {
    sep_char: u8 = u8(0);
    group = bytes_per_sep_group;
    if sep {
        seplen = PyObject_Length(sep);
        if seplen < 0 {
            return NULL;
        }
        if seplen != 1 {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("sep must be length 1."));
            return NULL;
        }
        if unicode_check(sep) {
            if uo_kind(sep) != 1 {
                PyErr_SetString(PyExc_ValueError, ptr[u8]("sep must be ASCII."));
                return NULL;
            }
            sep_char = u8.wrap(uo_read_char(sep, 0));
        } elif bytes_check(sep) {
            sep_char = bytes_data(sep).view(1)[0];
        } else {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("sep must be str or bytes."));
            return NULL;
        }
        if sep_char > u8(127) and not return_bytes {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("sep must be ASCII."));
            return NULL;
        }
    } else {
        group = 0;
    }
    abs_bytes_per_sep: i64 = i64(group);
    if abs_bytes_per_sep < 0 {
        abs_bytes_per_sep = -abs_bytes_per_sep;
    }
    resultlen: i64 = 0;
    if group != 0 and arglen > 0 {
        resultlen = (arglen - 1) // abs_bytes_per_sep;
    }
    if arglen >= PY_SSIZE_T_MAX // 2 - resultlen {
        return PyErr_NoMemory();
    }
    resultlen += arglen * 2;

    if abs_bytes_per_sep >= arglen {
        group = 0;
        abs_bytes_per_sep = 0;
    }

    retval = NULL;
    retbuf = ptr[u8]();
    if return_bytes {
        retval = PyBytes_FromStringAndSize(ptr[u8](), resultlen);
        if not retval {
            return NULL;
        }
        retbuf = bytes_data(retval);
    } else {
        retval = PyUnicode_New(resultlen, u32(127));
        if not retval {
            return NULL;
        }
        retbuf = uo_data(retval);
    }

    i: i64 = 0;
    j: i64 = 0;
    if group == 0 {
        while i < arglen {
            c = (argbuf + i).view(1)[0];
            (retbuf + j).view(1)[0] = hex_digit(c >> u8(4));
            (retbuf + j + 1).view(1)[0] = hex_digit(c & u8(0x0f));
            j += 2;
            i += 1;
        }
    } else {
        chunks = (arglen - 1) // abs_bytes_per_sep;
        if group < 0 {
            chunk: i64 = 0;
            while chunk < chunks {
                k: i64 = 0;
                while k < abs_bytes_per_sep {
                    c = (argbuf + i).view(1)[0];
                    i += 1;
                    (retbuf + j).view(1)[0] = hex_digit(c >> u8(4));
                    (retbuf + j + 1).view(1)[0] = hex_digit(c & u8(0x0f));
                    j += 2;
                    k += 1;
                }
                (retbuf + j).view(1)[0] = sep_char;
                j += 1;
                chunk += 1;
            }
            while i < arglen {
                c = (argbuf + i).view(1)[0];
                i += 1;
                (retbuf + j).view(1)[0] = hex_digit(c >> u8(4));
                (retbuf + j + 1).view(1)[0] = hex_digit(c & u8(0x0f));
                j += 2;
            }
        } else {
            i = arglen - 1;
            j = resultlen - 1;
            chunk: i64 = 0;
            while chunk < chunks {
                k: i64 = 0;
                while k < abs_bytes_per_sep {
                    c = (argbuf + i).view(1)[0];
                    i -= 1;
                    (retbuf + j).view(1)[0] = hex_digit(c & u8(0x0f));
                    (retbuf + j - 1).view(1)[0] = hex_digit(c >> u8(4));
                    j -= 2;
                    k += 1;
                }
                (retbuf + j).view(1)[0] = sep_char;
                j -= 1;
                chunk += 1;
            }
            while i >= 0 {
                c = (argbuf + i).view(1)[0];
                i -= 1;
                (retbuf + j).view(1)[0] = hex_digit(c & u8(0x0f));
                (retbuf + j - 1).view(1)[0] = hex_digit(c >> u8(4));
                j -= 2;
            }
        }
    }
    return retval;
}
