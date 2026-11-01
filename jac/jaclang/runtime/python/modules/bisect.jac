"""Bisection over Python sequences, including key and comparison callbacks.

CPython supplies values and their protocol operations. Search and insertion
orchestration execute here, without converting the sequence to a Jac list.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from c { def Py_EnterRecursiveCall(where: ptr[u8]) -> i32;  }

glob:priv PY_LT: i32 = 0;

def bisect_index(
    sequence: ptr[PyObject],
    item: ptr[PyObject],
    low: i64,
    high: i64,
    key: ptr[PyObject],
    right: bool
) -> i64 {
    if low < 0 {
        object_error(PyExc_ValueError, "lo must be non-negative");
        return -1;
    }
    if high == -1 {
        high = PySequence_Size(sequence);
        if high < 0 {
            return -1;
        }
    }
    if jacpy_sequence_slot(sequence) == NULL {
        return -1;
    }
    sequence_type = object_type(sequence);
    if right {
        if Py_EnterRecursiveCall(ptr[u8](" in _bisect.bisect_right")) != 0 {
            return -1;
        }
    } elif Py_EnterRecursiveCall(ptr[u8](" in _bisect.bisect_left")) != 0 {
        return -1;
    }
    item_type = object_type(item);
    fast = int(item_type.view(1)[0].tp_richcompare) != 0;
    while low < high {
        middle = i64((u64(low) + u64(high)) >> u64(1));
        value = sequence_type.view(1)[0].tp_as_sequence.view(1)[0].sq_item(
            sequence, middle
        );
        if value == NULL {
            Py_LeaveRecursiveCall();
            return -1;
        }
        if key != NULL {
            mapped = PyObject_CallOneArg(key, value);
            object_decref(value);
            if mapped == NULL {
                Py_LeaveRecursiveCall();
                return -1;
            }
            value = mapped;
        }
        comparison: i64 = 0;
        if fast and object_type(value) == item_type {
            outcome = item_type.view(1)[0].tp_richcompare(
                item if right else value, value if right else item, PY_LT
            );
            if outcome == ptr[PyObject](addressof(_Py_TrueStruct)) {
                object_decref(outcome);
                object_decref(value);
                if right {
                    high = middle;
                } else {
                    low = middle + 1;
                }
                continue;
            }
            if outcome == ptr[PyObject](addressof(_Py_FalseStruct)) {
                object_decref(outcome);
                object_decref(value);
                if right {
                    low = middle + 1;
                } else {
                    high = middle;
                }
                continue;
            }
            if outcome == NULL {
                object_decref(value);
                Py_LeaveRecursiveCall();
                return -1;
            }
            if outcome == Py_NotImplemented {
                object_decref(outcome);
                fast = False;
                comparison = i64(
                    PyObject_RichCompareBool(
                        item if right else value, value if right else item, PY_LT
                    )
                );
            } else {
                comparison = i64(PyObject_IsTrue(outcome));
                object_decref(outcome);
            }
        } else {
            comparison = i64(
                PyObject_RichCompareBool(
                    item if right else value, value if right else item, PY_LT
                )
            );
        }
        object_decref(value);
        if comparison < 0 {
            Py_LeaveRecursiveCall();
            return -1;
        }
        if (comparison != 0) == right {
            high = middle;
        } else {
            low = middle + 1;
        }
    }
    Py_LeaveRecursiveCall();
    return low;
}

# internal_bisect_right/left through the key: the index, or -1 with the
# exception set.
def:pub jacpy_bisect(
    sequence: ptr[PyObject],
    item: ptr[PyObject],
    low: i64,
    high: i64,
    key: ptr[PyObject],
    right: bool
) -> i64 {
    return bisect_index(
        sequence, item, low, high, NULL if key == Py_None else key, right
    );
}

# insort_right/left: insert `item` at its bisection point, searching by
# key(item) when a key is given.
def:priv insort(
    sequence: ptr[PyObject],
    item: ptr[PyObject],
    low: i64,
    high: i64,
    key: ptr[PyObject],
    right: bool
) -> ptr[PyObject] {
    search = item;
    if key != Py_None {
        search = PyObject_CallOneArg(key, item);
        if search == 0 {
            return NULL;
        }
    }
    index = jacpy_bisect(sequence, search, low, high, key, right);
    if key != Py_None {
        jacpy_release(search);
    }
    if index < 0 {
        return NULL;
    }
    if jacpy_is_exact_list(sequence) != 0 {
        if PyList_Insert(sequence, index, item) < 0 {
            return NULL;
        }
    } else {
        result = PyObject_CallMethod(sequence, "insert", "nO", index, item);
        if not result {
            return NULL;
        }
        jacpy_release(result);
    }
    return Py_NewRef(Py_None);
}

def _bisect_bisect_right_impl(
    module: ptr[PyObject],
    a: ptr[PyObject],
    x: ptr[PyObject],
    lo: i64,
    hi: i64,
    key: ptr[PyObject]
) -> i64 {
    return jacpy_bisect(a, x, lo, hi, key, True);
}

def _bisect_bisect_left_impl(
    module: ptr[PyObject],
    a: ptr[PyObject],
    x: ptr[PyObject],
    lo: i64,
    hi: i64,
    key: ptr[PyObject]
) -> i64 {
    return jacpy_bisect(a, x, lo, hi, key, False);
}

def _bisect_insort_right_impl(
    module: ptr[PyObject],
    a: ptr[PyObject],
    x: ptr[PyObject],
    lo: i64,
    hi: i64,
    key: ptr[PyObject]
) -> ptr[PyObject] {
    return insort(a, x, lo, hi, key, True);
}

def _bisect_insort_left_impl(
    module: ptr[PyObject],
    a: ptr[PyObject],
    x: ptr[PyObject],
    lo: i64,
    hi: i64,
    key: ptr[PyObject]
) -> ptr[PyObject] {
    return insort(a, x, lo, hi, key, False);
}
