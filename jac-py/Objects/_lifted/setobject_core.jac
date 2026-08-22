# c2jac: 9 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L270 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L271 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L340 [W4201] cast to `size_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L376 [W4201] cast to `size_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L431 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L437 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L439 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L443 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L446 [W4201] cast to `Py_hash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob ptrdiff_t = int,
     size_t = int,
     ssize_t = int,
     intptr_t = int,
     uintptr_t = int,
     int8_t = int,
     uint8_t = int,
     int16_t = int,
     uint16_t = int,
     int32_t = int,
     uint32_t = int,
     int64_t = int,
     uint64_t = int,
     intmax_t = int,
     uintmax_t = int,
     int_least8_t = int,
     uint_least8_t = int,
     int_least16_t = int,
     uint_least16_t = int,
     int_least32_t = int,
     uint_least32_t = int,
     int_least64_t = int,
     uint_least64_t = int,
     int_fast8_t = int,
     uint_fast8_t = int,
     int_fast16_t = int,
     uint_fast16_t = int,
     int_fast32_t = int,
     uint_fast32_t = int,
     int_fast64_t = int,
     uint_fast64_t = int,
     Py_ssize_t = int,
     Py_hash_t = int;

@__jac_value__
obj PyVarObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0;
}

glob digit = int,
     stwodigits = int,
     sdigit = int,
     _Pyuintptr_t = int,
     Py_uhash_t = int;


@__jac_value__
obj lenfunc {
    def call -> int {
        ;
    }
}

@__jac_value__
obj unaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj binaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj inquiry {
    def call -> int {
        ;
    }
}

@__jac_value__
obj vectorcallfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj hashfunc {
    def call -> int {
        ;
    }
}

@__jac_value__
obj richcmpfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj getiterfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj iternextfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj ssizeargfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj PySequenceMethods {
    has sq_length: lenfunc = lenfunc(),
        sq_item: ssizeargfunc = ssizeargfunc(),
        sq_contains: inquiry = inquiry();
}

@__jac_value__
obj PyNumberMethods {
    has nb_add: binaryfunc = binaryfunc(),
        nb_subtract: binaryfunc = binaryfunc(),
        nb_multiply: binaryfunc = binaryfunc(),
        nb_remainder: binaryfunc = binaryfunc(),
        nb_divmod: binaryfunc = binaryfunc(),
        nb_power: binaryfunc = binaryfunc(),
        nb_negative: binaryfunc = binaryfunc(),
        nb_positive: binaryfunc = binaryfunc(),
        nb_absolute: binaryfunc = binaryfunc(),
        nb_bool: inquiry = inquiry(),
        nb_invert: unaryfunc = unaryfunc(),
        nb_lshift: binaryfunc = binaryfunc(),
        nb_rshift: binaryfunc = binaryfunc(),
        nb_and: binaryfunc = binaryfunc(),
        nb_xor: binaryfunc = binaryfunc(),
        nb_or: binaryfunc = binaryfunc();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}

@__jac_value__
obj PyTypeObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        tp_name: str = str(),
        tp_basicsize: int = 0,
        tp_itemsize: int = 0,
        tp_dealloc: object = object(),
        tp_repr: unaryfunc = unaryfunc(),
        tp_as_number: PyNumberMethods = PyNumberMethods(),
        tp_as_sequence: PySequenceMethods = PySequenceMethods(),
        tp_hash: hashfunc = hashfunc(),
        tp_richcompare: richcmpfunc = richcmpfunc(),
        tp_iter: getiterfunc = getiterfunc(),
        tp_iternext: iternextfunc = iternextfunc(),
        tp_flags: int = 0,
        tp_doc: str = str(),
        tp_base: PyTypeObject = PyTypeObject(),
        tp_vectorcall: vectorcallfunc = vectorcallfunc();
}

@__jac_value__
obj _PyLongValue {
    has lv_tag: int = 0,
        ob_digit: list = list();
}

@__jac_value__
obj PyLongObject {
    has ob_base: PyObject = PyObject(),
        long_value: _PyLongValue = _PyLongValue();
}


glob Py_UCS1 = int;

@__jac_value__
obj setentry {
    has key: PyObj = PyObj(),
        hash: int = 0;
}

@__jac_value__
obj PySetObject {
    has ob_base: PyObject = PyObject(),
        fill: int = 0,
        used: int = 0,
        mask: int = 0,
        table: setentry = setentry(),
        hash: int = 0,
        finger: int = 0,
        smalltable: list = list(),
        weakreflist: PyObj = PyObj();
}


def PySet_GET_SIZE(so: PyObj) -> int {
    return so.used;
}

def unicode_eq(str1: PyObj, str2: PyObj) -> int {
    str1;
    str2;
    return 0;
}

glob _dummy_struct: PyObject = PyObject();


def _PyObject_HashFast(op: PyObj) -> int {
    return PyObject_Hash(op);
}

def set_lookkey(so: PySetObject, key: PyObj, hash: int) -> setentry {
    table: setentry = setentry();
    `entry: setentry = setentry();
    perturb: int = hash;
    mask: int = so.mask;
    i: int = hash & mask;
    probes: int = 0;
    cmp: int = 0;
    frozenset: int = so.ob_type == PyFrozenSet_Type;

    while 1 {
        `entry = so.table[i];
        probes = 9 if ((i + 9) <= mask) else 0;
        while True {
            if ((`entry.hash == 0) and (`entry.key == 0)) {
                return `entry;
            }
            if (`entry.hash == hash) {
                startkey: PyObj = `entry.key;
                if (startkey == key) {
                    return `entry;
                }
                if (
                    (
                        (startkey.ob_type == PyUnicode_Type)
                        and (key.ob_type == PyUnicode_Type)
                    )
                    and unicode_eq(startkey, key)
                ) {
                    return `entry;
                }
                table = so.table;
                if frozenset {
                    cmp = PyObject_RichCompareBool(startkey, key, 2);
                    if (cmp < 0) {
                        return 0;
                    }
                } else {
                    ;
                    cmp = PyObject_RichCompareBool(startkey, key, 2);
                    ;
                    if (cmp < 0) {
                        return 0;
                    }
                    if ((table != so.table) or (`entry.key != startkey)) {
                        return set_lookkey(so, key, hash);
                    }
                }

                if (cmp > 0) {
                    return `entry;
                }
                mask = so.mask;
            }

            `entry += 1;
            if not (probes := probes - 1 + 1) {
                break;
            }
        }

        perturb >>= 5;
        i = (((i * 5) + 1) + perturb) & mask;
    }
}

def set_contains_entry(so: PySetObject, key: PyObj, hash: int) -> int {
    `entry: setentry = setentry();

    `entry = set_lookkey(so, key, hash);
    if (`entry != 0) {
        return (`entry.key != 0);
    }
    return -1;
}

def set_next(so: PySetObject, pos_ptr: object, entry_ptr: setentry) -> int {
    i: int = 0;
    mask: int = 0;
    `entry: setentry = setentry();

    i = pos_ptr;
    mask = so.mask;
    `entry = so.table[i];
    while ((i <= mask) and ((`entry.key == 0) or (`entry.key == _dummy_struct))) {
        i += 1;
        `entry += 1;
    }

    pos_ptr = i + 1;
    if (i > mask) {
        return 0;
    }
    entry_ptr = `entry;
    return 1;
}

def _shuffle_bits(h: Py_uhash_t) -> Py_uhash_t {
    return (((h ^ 89869747) ^ (h << 16)) * 3644798167);
}

def frozenset_hash_impl(`self: PyObj) -> int {
    so: PySetObject = `self;
    hash: Py_uhash_t = 0;
    `entry: setentry = setentry();

    for `entry = so.table while `entry <= so.table[so.mask] with `entry += 1 {
        hash ^= _shuffle_bits(`entry.hash);
    }

    if (((so.mask + 1) - so.fill) & 1) {
        hash ^= _shuffle_bits(0);
    }

    if ((so.fill - so.used) & 1) {
        hash ^= _shuffle_bits(-1);
    }

    hash ^= (PySet_GET_SIZE(`self) + 1) * 1927868237;
    hash ^= (hash >> 11) ^ (hash >> 25);
    hash = (hash * 69069) + 907133923;

    if (hash == -1) {
        hash = 590923713;
    }

    return hash;
}

def frozenset_hash(`self: PyObj) -> int {
    so: PySetObject = `self;
    hash: int = 0;

    if (so.hash != -1) {
        return so.hash;
    }

    hash = frozenset_hash_impl(`self);
    so.hash = hash;
    return hash;
}

def set_issubset(so: PySetObject, other: PyObj) -> PyObj {
    `entry: setentry = setentry();
    pos: int = 0;
    rv: int = 0;

    if not ((other.ob_type == PySet_Type) or (other.ob_type == PyFrozenSet_Type)) {
        return Py_NotImplemented;
    }

    if (PySet_GET_SIZE(so) > PySet_GET_SIZE(other)) {
        return Py_False;
    }

    while set_next(so, pos, `entry) {
        key: PyObj = `entry.key;
        ;
        rv = set_contains_entry(other, key, `entry.hash);
        ;
        if (rv < 0) {
            return 0;
        }
        if not rv {
            return Py_False;
        }
    }

    return Py_True;
}

def set_issuperset(so: PySetObject, other: PyObj) -> PyObj {
    if ((other.ob_type == PySet_Type) or (other.ob_type == PyFrozenSet_Type)) {
        return set_issubset(other, so);
    }
    return Py_NotImplemented;
}

def set_richcompare(`self: PyObj, w: PyObj, op: int) -> PyObj {
    v: PySetObject = `self;
    r1: PyObj = PyObj();
    r2: int = 0;

    if not ((w.ob_type == PySet_Type) or (w.ob_type == PyFrozenSet_Type)) {
        return Py_NotImplemented;
    }

    if op == 2 {
        if (PySet_GET_SIZE(v) != PySet_GET_SIZE(w)) {
            return Py_False;
        }

        v_hash: int = v.hash;
        w_hash: int = w.hash;
        if (((v_hash != -1) and (w_hash != -1)) and (v_hash != w_hash)) {
            return Py_False;
        }

        return set_issubset(v, w);
    } elif op == 3 {
        r1 = set_richcompare(`self, w, 2);
        if (r1 == 0) {
            return 0;
        }
        r2 = PyObject_IsTrue(r1);
        ;
        if (r2 < 0) {
            return 0;
        }
        return PyBool_FromLong(not r2);
    } elif op == 1 {
        return set_issubset(v, w);
    } elif op == 5 {
        return set_issuperset(v, w);
    } elif op == 0 {
        if (PySet_GET_SIZE(v) >= PySet_GET_SIZE(w)) {
            return Py_False;
        }
        return set_issubset(v, w);
    } elif op == 4 {
        if (PySet_GET_SIZE(v) <= PySet_GET_SIZE(w)) {
            return Py_False;
        }
        return set_issuperset(v, w);
    }

    return Py_NotImplemented;
}
