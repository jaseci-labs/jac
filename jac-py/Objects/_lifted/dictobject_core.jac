# c2jac: 15 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L332 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L333 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L340 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L341 [W4201] cast to `int32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L350 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L366 [W4201] cast to `int64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L371 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L373 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L389 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L416 [W4201] cast to `int64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L422 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L452 [W4201] cast to `int64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L454 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L458 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L460 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

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


glob Py_UCS1 = int,
     DictKeysKind = int;

@__jac_value__
obj PyDictKeyEntry {
    has me_hash: int = 0,
        me_key: PyObj = PyObj(),
        me_value: PyObj = PyObj();
}

@__jac_value__
obj PyDictUnicodeEntry {
    has me_key: PyObj = PyObj(),
        me_value: PyObj = PyObj();
}

@__jac_value__
obj PyDictKeysObject {
    has dk_refcnt: int = 0,
        dk_log2_size: int = 0,
        dk_log2_index_bytes: int = 0,
        dk_kind: int = 0,
        dk_version: int = 0,
        dk_usable: int = 0,
        dk_nentries: int = 0,
        dk_indices: list = list();
}

@__jac_value__
obj PyDictValues {
    has capacity: int = 0,
        size: int = 0,
        embedded: int = 0,
        valid: int = 0,
        values: list = list();
}

@__jac_value__
obj PyDictObject {
    has ob_base: PyObject = PyObject(),
        ma_used: int = 0,
        ma_keys: PyDictKeysObject = PyDictKeysObject(),
        ma_values: PyDictValues = PyDictValues();
}


def _DK_ENTRIES(dk: PyDictKeysObject) -> object {
    indices: object = dk.dk_indices;
    index: int = 1 << dk.dk_log2_index_bytes;
    return indices[index];
}

def DK_ENTRIES(dk: PyDictKeysObject) -> PyDictKeyEntry {
    return _DK_ENTRIES(dk);
}

def DK_UNICODE_ENTRIES(dk: PyDictKeysObject) -> PyDictUnicodeEntry {
    return _DK_ENTRIES(dk);
}

def is_unusable_slot(ix: int) -> int {
    return (ix >= 0);
}

def dictkeys_get_index(keys: PyDictKeysObject, i: int) -> int {
    indices: object = keys.dk_indices;
    keys;
    return indices[i];
}

def dictkeys_set_index(keys: PyDictKeysObject, i: int, ix: int) {
    indices: object = keys.dk_indices;
    keys;
    indices[i] = ix;
}

def calculate_log2_keysize(minsize: int) -> int {
    log2_size: int = 0;
    minsize = 8 if (minsize < 8) else minsize;
    for log2_size = 3 while (1 << log2_size) < minsize with log2_size += 1 {
        ;
    }
    return log2_size;
}

def estimate_log2_keysize(n: int) -> int {
    return calculate_log2_keysize((((n * 3) + 1) / 2));
}


def lookdict_index(k: PyDictKeysObject, hash: int, index: int) -> int {
    mask: int = (1 << k.dk_log2_size) - 1;
    perturb: int = hash;
    i: int = hash & mask;

    while True {
        ix: int = dictkeys_get_index(k, i);
        if (ix == index) {
            return i;
        }

        if (ix == -1) {
            return -1;
        }

        perturb >>= 5;
        i = mask & (((i * 5) + perturb) + 1);
    }

    Py_UNREACHABLE();
}

def compare_generic(
    mp: PyDictObject, dk: PyDictKeysObject, ep0: object, ix: int, key: PyObj, hash: int
) -> int {
    ep: PyDictKeyEntry = ep0[ix];
    mp;
    `assert((ep.me_key != 0));
    if (ep.me_key == key) {
        return 1;
    }

    if (ep.me_hash == hash) {
        startkey: PyObj = ep.me_key;
        ;
        cmp: int = PyObject_RichCompareBool(startkey, key, 2);
        ;
        if (cmp < 0) {
            return -3;
        }

        if ((dk == mp.ma_keys) and (ep.me_key == startkey)) {
            return cmp;
        }

        return -4;
    }

    return 0;
}

def do_lookup(
    mp: PyDictObject, dk: PyDictKeysObject, key: PyObj, hash: int, check_lookup: object
) -> int {
    ep0: object = _DK_ENTRIES(dk);
    mask: int = (1 << dk.dk_log2_size) - 1;
    perturb: int = hash;
    i: int = hash & mask;
    ix: int = 0;

    while True {
        ix = dictkeys_get_index(dk, i);
        if (ix >= 0) {
            cmp: int = check_lookup(mp, dk, ep0, ix, key, hash);
            if (cmp < 0) {
                return cmp;
            }

            if cmp {
                return ix;
            }
        } elif (ix == -1) {
            return -1;
        }

        perturb >>= 5;
        i = mask & (((i * 5) + perturb) + 1);
    }

    Py_UNREACHABLE();
}

def dictkeys_generic_lookup(
    mp: PyDictObject, dk: PyDictKeysObject, key: PyObj, hash: int
) -> int {
    return do_lookup(mp, dk, key, hash, compare_generic);
}


def find_empty_slot(keys: PyDictKeysObject, hash: int) -> int {
    mask: int = (1 << keys.dk_log2_size) - 1;
    i: int = hash & mask;
    ix: int = dictkeys_get_index(keys, i);
    perturb: int = hash;
    while is_unusable_slot(ix) {
        perturb >>= 5;
        i = (((i * 5) + perturb) + 1) & mask;
        ix = dictkeys_get_index(keys, i);
    }

    return i;
}

def dict_equal_entries(a: PyDictObject, b: PyDictObject) -> int {
    i: int = 0;

    if (a.ma_used != b.ma_used) {
        return 0;
    }

    for i = 0 while i < a.ma_keys.dk_nentries with i += 1 {
        key: PyObj = PyObj();
        aval: PyObj = PyObj();
        hash: int = 0;
        ep: PyDictKeyEntry = DK_ENTRIES(a.ma_keys)[i];
        key = ep.me_key;
        aval = ep.me_value;
        hash = ep.me_hash;
        if ((key == 0) or (aval == 0)) {
            continue;
        }

        bval: PyObj = 0;
        ix: int = dictkeys_generic_lookup(b, b.ma_keys, key, hash);
        if (ix == -1) {
            return 0;
        }

        if (ix < 0) {
            return -1;
        }

        bval = DK_ENTRIES(b.ma_keys)[ix].me_value;
        if (bval == 0) {
            return 0;
        }

        cmp: int = PyObject_RichCompareBool(aval, bval, 2);
        if (cmp <= 0) {
            return cmp;
        }
    }

    return 1;
}

def dict_richcompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    cmp: int = 0;

    if (not (v.ob_type == PyDict_Type) or not (w.ob_type == PyDict_Type)) {
        return Py_NotImplemented;
    }

    if ((op != 2) and (op != 3)) {
        return Py_NotImplemented;
    }

    cmp = dict_equal_entries(v, w);
    if (cmp < 0) {
        return 0;
    }

    while True {
        if op == 2 {
            if (cmp == (op == 2)) {
                return Py_True;
            }
            return Py_False;
        } elif op == 3 {
            if (cmp != (op == 2)) {
                return Py_True;
            }
            return Py_False;
        } else {
            return Py_NotImplemented;
        }
        if not 0 {
            break;
        }
    }
}
