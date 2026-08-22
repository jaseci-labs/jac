glob ptrdiff_t = int;
glob size_t = int;
glob ssize_t = int;
glob intptr_t = int;
glob uintptr_t = int;

glob int8_t = int;
glob uint8_t = int;
glob int16_t = int;
glob uint16_t = int;
glob int32_t = int;
glob uint32_t = int;
glob int64_t = int;
glob uint64_t = int;

glob intmax_t = int;
glob uintmax_t = int;

glob int_least8_t = int;
glob uint_least8_t = int;
glob int_least16_t = int;
glob uint_least16_t = int;
glob int_least32_t = int;
glob uint_least32_t = int;
glob int_least64_t = int;
glob uint_least64_t = int;

glob int_fast8_t = int;
glob uint_fast8_t = int;
glob int_fast16_t = int;
glob uint_fast16_t = int;
glob int_fast32_t = int;
glob uint_fast32_t = int;
glob int_fast64_t = int;
glob uint_fast64_t = int;
glob Py_ssize_t = int;
glob Py_hash_t = int;

@__jac_value__
obj PyVarObject {
    has ob_base: PyObject = PyObject();
    has ob_size: int = 0;
}

glob digit = int;
glob stwodigits = int;
glob sdigit = int;
glob _Pyuintptr_t = int;
glob Py_uhash_t = int;


@__jac_value__
obj lenfunc {
    def call() -> int {
        ;
    }
}
@__jac_value__
obj unaryfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj binaryfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj inquiry {
    def call() -> int {
        ;
    }
}
@__jac_value__
obj vectorcallfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj hashfunc {
    def call() -> int {
        ;
    }
}
@__jac_value__
obj richcmpfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj getiterfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj iternextfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj ssizeargfunc {
    def call() -> PyObj {
        ;
    }
}

@__jac_value__
obj PySequenceMethods {
    has sq_length: lenfunc = lenfunc();
    has sq_item: ssizeargfunc = ssizeargfunc();
    has sq_contains: inquiry = inquiry();
}

@__jac_value__
obj PyNumberMethods {
    has nb_add: binaryfunc = binaryfunc();
    has nb_subtract: binaryfunc = binaryfunc();
    has nb_multiply: binaryfunc = binaryfunc();
    has nb_remainder: binaryfunc = binaryfunc();
    has nb_divmod: binaryfunc = binaryfunc();
    has nb_power: binaryfunc = binaryfunc();
    has nb_negative: binaryfunc = binaryfunc();
    has nb_positive: binaryfunc = binaryfunc();
    has nb_absolute: binaryfunc = binaryfunc();
    has nb_bool: inquiry = inquiry();
    has nb_invert: unaryfunc = unaryfunc();
    has nb_lshift: binaryfunc = binaryfunc();
    has nb_rshift: binaryfunc = binaryfunc();
    has nb_and: binaryfunc = binaryfunc();
    has nb_xor: binaryfunc = binaryfunc();
    has nb_or: binaryfunc = binaryfunc();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}

@__jac_value__
obj PyTypeObject {
    has ob_base: PyObject = PyObject();
    has ob_size: int = 0;
    has tp_name: str = str();
    has tp_basicsize: int = 0;
    has tp_itemsize: int = 0;
    has tp_dealloc: object = object();
    has tp_repr: unaryfunc = unaryfunc();
    has tp_as_number: PyNumberMethods = PyNumberMethods();
    has tp_as_sequence: PySequenceMethods = PySequenceMethods();
    has tp_hash: hashfunc = hashfunc();
    has tp_richcompare: richcmpfunc = richcmpfunc();
    has tp_iter: getiterfunc = getiterfunc();
    has tp_iternext: iternextfunc = iternextfunc();
    has tp_flags: int = 0;
    has tp_doc: str = str();
    has tp_base: PyTypeObject = PyTypeObject();
    has tp_vectorcall: vectorcallfunc = vectorcallfunc();
}

@__jac_value__
obj _PyLongValue {
    has lv_tag: int = 0;
    has ob_digit: list = list();
}

@__jac_value__
obj PyLongObject {
    has ob_base: PyObject = PyObject();
    has long_value: _PyLongValue = _PyLongValue();
}


glob Py_UCS1 = int;

def bytes_isupper_byte(c: int) -> int {
    return ((c >= 65) and (c <= 90));
}

def bytes_islower_byte(c: int) -> int {
    return ((c >= 97) and (c <= 122));
}

def bytes_isdigit_byte(c: int) -> int {
    return ((c >= 48) and (c <= 57));
}

def bytes_isspace_byte(c: int) -> int {
    return (
        (((((c == 32) or (c == 9)) or (c == 10)) or (c == 13)) or (c == 12))
        or (c == 11)
    );
}

def bytes_toupper_byte(c: int) -> int {
    if bytes_islower_byte(c) {
        return (c - (97 - 65));
    }

    return c;
}

def bytes_tolower_byte(c: int) -> int {
    if bytes_isupper_byte(c) {
        return (c + (97 - 65));
    }

    return c;
}
