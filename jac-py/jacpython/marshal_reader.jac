# CPython 3.14 marshal reader (jac-py/PLAN.md §4 marshal transport).
# Acyclic leaf: imports objects only; consumed by ceval.jac and pyc_first.jac.

import from objects {
    PyObj,
    PyInt,
    PyStr,
    PyBytes,
    PyFloat,
    PyBool,
    PyNoneType,
    PySlice,
    PyComplex,
    PyTuple,
    PyList,
    PyDict,
    PySet,
    PyCode,
    py_none,
    py_error,
    bytes_value,
    tuple_value,
    str_value,
    str_values,
}

# ---------------- byte helpers ----------------
def bytes_to_str(bs: list[int]) -> str {
    s = "";
    for b in bs {
        s = s + chr(b);
    }
    return s;
}

# Decode a UTF-8 byte sequence (marshal TYPE_UNICODE/TYPE_INTERNED payloads) into
# a str of real codepoints. bytes_to_str is Latin-1 (one codepoint per byte) and
# is correct only for the ASCII subset; multi-byte chars (e.g. Devanagari digits)
# need this. Continuation/overlong validation is intentionally minimal: marshal
# streams come from CPython's own encoder, so the input is always well-formed.
def utf8_bytes_to_str(bs: list[int]) -> str {
    s = "";
    n = len(bs);
    i = 0;
    while i < n {
        b0 = bs[i];
        cp = 0;
        width = 1;
        if b0 < 0x80 {
            cp = b0;
        } elif (b0 & 0xE0) == 0xC0 {
            cp = b0 & 0x1F;
            width = 2;
        } elif (b0 & 0xF0) == 0xE0 {
            cp = b0 & 0x0F;
            width = 3;
        } else {
            cp = b0 & 0x07;
            width = 4;
        }
        k = 1;
        while k < width {
            cp = (cp << 6) | (bs[i + k] & 0x3F);
            k = k + 1;
        }
        s = s + chr(cp);
        i = i + width;
    }
    return s;
}

# IEEE754 double from 8 little-endian bytes (used if a float const appears).
def bytes_to_double(bs: list[int]) -> float {
    v = 0;
    i = 0;
    while i < 8 {
        v = v | (bs[i] << (8 * i));
        i = i + 1;
    }
    sign = (v >> 63) & 1;
    exp = (v >> 52) & 0x7FF;
    frac = v & 0xFFFFFFFFFFFFF;
    if exp == 0 {
        if frac == 0 {
            if sign == 1 {
                return -0.0;
            } else {
                return 0.0;
            }
        }
        return (1 - 2 * sign) * (frac / (2 ** 52)) * (2 ** (-1022));
    }
    if exp == 0x7FF {
        # exp all-ones: infinity (frac 0) or NaN. Build them by overflow /
        # inf-minus-inf -- `0.0 / 0.0` raises ZeroDivisionError in Jac.
        huge = 1e300 * 1e300;
        if frac == 0 {
            if sign == 1 {
                return -huge;
            } else {
                return huge;
            }
        }
        return huge - huge;
    }
    mant = 1.0 + frac / (2.0 ** 52.0);
    return (1 - 2 * sign) * mant * (2.0 ** (exp - 1023));
}

# ---------------- marshal reader ----------------
# Jac mis-parses `flags=` as a bare assignment inside Reader.read_code; build
# PyCode from a module-level helper instead (P0.10 compiler_slice oracle diff).
def pycode_from_marshal_fields(
    argcount: int,
    posonly: int,
    kwonly: int,
    stacksize: int,
    code_flags: int,
    co_code: list[int],
    consts: list[PyObj],
    names: list[str],
    varnames: list[str],
    cellvars: list[str],
    freevars: list[str],
    filename: str,
    name: str,
    qualname: str,
    firstlineno: int,
    linetable: list[int],
    exceptiontable: list[int],
) -> PyCode {
    return PyCode(
        t="code",
        argcount=argcount,
        posonlyargcount=posonly,
        kwonlyargcount=kwonly,
        stacksize=stacksize,
        flags=code_flags,
        co_code=co_code,
        consts=consts,
        names=names,
        varnames=varnames,
        cellvars=cellvars,
        freevars=freevars,
        filename=filename,
        name=name,
        qualname=qualname,
        firstlineno=firstlineno,
        linetable=linetable,
        exceptiontable=exceptiontable,
    );
}

obj Reader {
    has data: list[int],
        pos: int,
        refs: list[PyObj],
        bad: str = "";

    # Record the first corruption found in the stream; parsing degrades to
    # zero-fill afterwards and unmarshal() surfaces it as a ValueError
    # sentinel. Never silent: every failure carries a clear message.
    def fail(msg: str) {
        if self.bad == "" {
            self.bad = msg;
        }
    }

    def r_byte -> int {
        if self.pos >= len(self.data) {
            self.fail(
                "truncated stream: byte read past end at pos " + str(self.pos)
            );
            return 0;
        }
        b = self.data[self.pos];
        self.pos = self.pos + 1;
        return b & 0xFF;
    }

    def r_short -> int {
        lo = self.r_byte();
        hi = self.r_byte();
        return lo | (hi << 8);
    }

    def r_long -> int {
        b0 = self.r_byte();
        b1 = self.r_byte();
        b2 = self.r_byte();
        b3 = self.r_byte();
        x = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
        if x >= 0x80000000 {
            x = x - 0x100000000;
        }
        return x;
    }

    def r_double -> float {
        bs: list[int] = [];
        k = 0;
        while k < 8 {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return bytes_to_double(bs);
    }

    def r_object -> PyObj {
        code = self.r_byte();
        flag = code & 0x80;
        type_code = code & 0x7F;
        if flag != 0 {
            ref_index: int = len(self.refs);
            self.refs.append(py_none());
            o = self.read_type(type_code);
            self.refs[ref_index] = o;
        } else {
            o = self.read_type(type_code);
        }
        return o;
    }

    def read_type(type: int) -> PyObj {
        if type == 48 {
            return py_none();
        } elif type == 78 {
            return py_none();
        } elif type == 70 {
            return PyBool(t="bool", val=False);
        } elif type == 84 {
            return PyBool(t="bool", val=True);
        } elif type == 46 {
            return PyNoneType(t="ellipsis");
        } elif type == 105 {
            return PyInt(t="int", val=self.r_long());
        } elif type == 108 {
            return self.read_long();
        } elif type == 103 {
            return PyFloat(t="float", val=self.r_double());
        } elif type == 121 {
            return self.read_complex();
        } elif type == 115 {
            return self.read_bytes();
        } elif type == 97 {
            return self.read_ascii(False);
        } elif type == 122 {
            return self.read_ascii(True);
        } elif type == 65 {
            return self.read_ascii(False);
        } elif type == 90 {
            return self.read_ascii(True);
        } elif type == 117 {
            return self.read_utf8();
        } elif type == 116 {
            return self.read_utf8();
        } elif type == 40 {
            return self.read_tuple(False);
        } elif type == 41 {
            return self.read_tuple(True);
        } elif type == 91 {
            return self.read_list();
        } elif type == 99 {
            return self.read_code();
        } elif type == 114 {
            idx = self.r_long();
            if idx < 0 or idx >= len(self.refs) {
                self.fail(
                    "reference index "
                        + str(idx)
                        + " out of range ("
                        + str(len(self.refs))
                        + " refs recorded)"
                );
                return py_none();
            }
            return self.refs[idx];
        } elif type == 58 {
            return self.read_slice();
        } elif type == 60 {
            return self.read_set(False);
        } elif type == 62 {
            return self.read_set(True);
        } else {
            self.fail(
                "unknown type code "
                    + str(type)
                    + " at pos "
                    + str(self.pos - 1)
            );
            return py_none();
        }
    }

    # TYPE_SET ('<' == 60) / TYPE_FROZENSET ('>' == 62): r_long count then N
    # members, materialized as a native PySet under the hash-key protocol.
    def read_set(frozen: bool) -> PyObj {
        n = self.r_long();
        name = "set";
        if frozen {
            name = "frozenset";
        }
        result = PySet(t=name, items={}, frozen=frozen);
        i = 0;
        while i < n {
            result.set_add(self.r_object());
            i = i + 1;
        }
        return result;
    }

    # TYPE_SLICE (':' == 58): three marshaled objects -- start, stop, step.
    def read_slice -> PyObj {
        start = self.r_object();
        stop = self.r_object();
        step = self.r_object();
        return PySlice(t="slice", start=start, stop=stop, step=step);
    }

    # CPython 3.14 big-int: n = r_long (signed count); digit_size=2 layout ->
    # marshal_ratio 15-bit shorts per 30-bit digit, LSB-first, little-endian.
    def read_long -> PyObj {
        n = self.r_long();
        if n == 0 {
            return PyInt(t="int", val=0);
        }
        sign = 1;
        if n < 0 {
            sign = -1;
            n = -n;
        }
        ratio = 2;
        size = 1 + (n - 1) // ratio;
        shorts_in_top = 1 + ((n - 1) % ratio);
        result = 0;
        base = 1;
        i = 0;
        while i < size - 1 {
            d = 0;
            j = 0;
            while j < ratio {
                s = self.r_short() & 0x7FFF;
                d = d + (s << (15 * j));
                j = j + 1;
            }
            result = result + d * base;
            base = base * (1 << 30);
            i = i + 1;
        }
        d = 0;
        j = 0;
        while j < shorts_in_top {
            s = self.r_short() & 0x7FFF;
            d = d + (s << (15 * j));
            j = j + 1;
        }
        result = result + d * base;
        return PyInt(t="int", val=result * sign);
    }

    def read_bytes -> PyObj {
        n = self.r_long();
        bs: list[int] = [];
        k = 0;
        while k < n {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return PyBytes(t="bytes", val=bs);
    }

    def read_ascii(short: bool) -> PyObj {
        n = 0;
        if short {
            n = self.r_byte();
        } else {
            n = self.r_long();
        }
        bs: list[int] = [];
        k = 0;
        while k < n {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return PyStr(t="str", val=bytes_to_str(bs));
    }

    def read_utf8 -> PyObj {
        n = self.r_long();
        bs: list[int] = [];
        k = 0;
        while k < n {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return PyStr(t="str", val=utf8_bytes_to_str(bs));
    }

    def read_tuple(small: bool) -> PyObj {
        n = 0;
        if small {
            n = self.r_byte();
        } else {
            n = self.r_long();
        }
        items: list[PyObj] = [];
        k = 0;
        while k < n {
            items.append(self.r_object());
            k = k + 1;
        }
        return PyTuple(t="tuple", items=items);
    }

    def read_list -> PyObj {
        n = self.r_long();
        items: list[PyObj] = [];
        k = 0;
        while k < n {
            items.append(self.r_object());
            k = k + 1;
        }
        return PyList(t="list", items=items);
    }

    def read_complex -> PyObj {
        re = self.r_double();
        im = self.r_double();
        return PyComplex(t="complex", real=re, imag=im);
    }

    def read_code -> PyObj {
        argcount = self.r_long();
        posonly = self.r_long();
        kwonly = self.r_long();
        stacksize = self.r_long();
        code_flags = self.r_long();
        code = self.r_object();
        consts_t = self.r_object();
        names_t = self.r_object();
        lpnames_t = self.r_object();
        lpkinds_t = self.r_object();
        filename = self.r_object();
        name = self.r_object();
        qualname = self.r_object();
        firstlineno = self.r_long();
        linetable = self.r_object();
        exceptiontable = self.r_object();

        co_code: list[int] = bytes_value(code);
        consts: list[PyObj] = tuple_value(consts_t);
        names: list[str] = str_values(names_t);
        lpnames: list[str] = str_values(lpnames_t);
        lpkinds: list[int] = bytes_value(lpkinds_t);
        # Frozen transport contract (codeobject.jac C1.1/C5, marshal.c
        # TYPE_CODE block): co_code must be whole instructions and the
        # localsplus names/kinds arrays must agree element-for-element.
        if len(co_code) % 2 != 0 {
            self.fail(
                "code object '"
                    + str_value(name)
                    + "': co_code length "
                    + str(len(co_code))
                    + " is not a whole number of instructions"
            );
        }
        if len(lpnames) != len(lpkinds) {
            self.fail(
                "code object '"
                    + str_value(name)
                    + "': localsplus names/kinds length mismatch ("
                    + str(len(lpnames))
                    + " vs "
                    + str(len(lpkinds))
                    + ")"
            );
        }
        varnames: list[str] = [];
        cellvars: list[str] = [];
        freevars: list[str] = [];
        i = 0;
        while i < len(lpnames) {
            kind = 0;
            if i < len(lpkinds) {
                kind = lpkinds[i];
            }
            # CPython's locals-plus kinds are bit flags, not a 0/1/2 enum:
            # local=0x20, cell=0x40, free=0x80. A cell parameter carries both
            # the local and cell bits and belongs in both views.
            if (kind & 0x20) != 0 {
                varnames.append(lpnames[i]);
            }
            if (kind & 0x40) != 0 {
                cellvars.append(lpnames[i]);
            }
            if (kind & 0x80) != 0 {
                freevars.append(lpnames[i]);
            }
            i = i + 1;
        }
        fn: str = str_value(filename);
        nm: str = str_value(name);
        qn: str = str_value(qualname);
        lt: list[int] = bytes_value(linetable);
        et: list[int] = bytes_value(exceptiontable);
        return pycode_from_marshal_fields(
            argcount,
            posonly,
            kwonly,
            stacksize,
            code_flags,
            co_code,
            consts,
            names,
            varnames,
            cellvars,
            freevars,
            fn,
            nm,
            qn,
            firstlineno,
            lt,
            et,
        );
    }
}

def unmarshal(data: list[int]) -> PyObj {
    r = Reader(data=data, pos=0, refs=[]);
    o = r.r_object();
    if r.bad != "" {
        return py_error("ValueError", "marshal: " + r.bad);
    }
    return o;
}
