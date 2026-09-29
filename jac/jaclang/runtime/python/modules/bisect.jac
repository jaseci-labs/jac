"""Bisection over Python sequences, including key and comparison callbacks.

CPython supplies values and their protocol operations. Search and insertion
orchestration execute here, without converting the sequence to a Jac list.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyExc_ValueError,
    PyList_Insert,
    PyObject,
    PyObject_CallMethod,
    PyObject_CallOneArg,
    PyObject_IsTrue,
    PySequence_Size,
    Py_LeaveRecursiveCall,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    jacpy_comparison_slot,
    jacpy_is_exact_list,
    jacpy_less,
    jacpy_recursion_enter,
    jacpy_release,
    jacpy_same_type,
    jacpy_sequence_slot
}
import from jaclang.runtime.python.capi { object_error }

# The type slots bisect calls directly: sq_item (ssizeargfunc) and
# tp_richcompare (richcmpfunc).
import from c {
    obj SequenceItemSlot {
        has call: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0;
    }  obj RichCompareSlot {
        has call: Callable[[ptr[PyObject], ptr[PyObject], i32], ptr[PyObject]] = 0;
    }
}

glob:priv PY_LT: i32 = 0;

"""left < right through a type's tp_richcompare: 1, 0, -1 on error, or -2
when the slot returns NotImplemented, so the caller falls back to the full
comparison protocol."""
def:priv slot_less(
    compare: RichCompareSlot, left: ptr[PyObject], right: ptr[PyObject]
) -> i64 {
    result = compare.call(left, right, PY_LT);
    if result == 0 {
        return -1;
    }
    comparison = i64(-2);
    if result != Py_NotImplemented {
        comparison = i64(PyObject_IsTrue(result));
    }
    jacpy_release(result);
    return comparison;
}

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
    item_slot = SequenceItemSlot();
    slot = jacpy_sequence_slot(sequence);
    if slot == 0 {
        return -1;
    }
    item_slot.call = int(slot);
    context = " in _bisect.bisect_right" if right else " in _bisect.bisect_left";
    if jacpy_recursion_enter(context) != 0 {
        return -1;
    }
    compare = jacpy_comparison_slot(item);
    compare_slot = RichCompareSlot();
    compare_slot.call = int(compare);
    try {
        while low < high {
            # Unsigned addition avoids overflow for valid ssize_t bounds.
            middle = i64((u64(low) + u64(high)) // u64(2));
            value = item_slot.call(sequence, middle);
            if value == 0 {
                return -1;
            }
            if key != 0 {
                mapped = PyObject_CallOneArg(key, value);
                jacpy_release(value);
                value = mapped;
                if value == 0 {
                    return -1;
                }
            }
            left = item if right else value;
            other = value if right else item;
            comparison = i64(-2);
            if compare != 0 and jacpy_same_type(item, value) != 0 {
                comparison = slot_less(compare_slot, left, other);
                if comparison == -2 {
                    compare = ptr();
                }
            }
            if comparison == -2 {
                comparison = jacpy_less(left, other);
            }
            jacpy_release(value);
            if comparison < 0 {
                return -1;
            }
            if (comparison != 0) == right {
                high = middle;
            } else {
                low = middle + 1;
            }
        }
        return low;
    } finally {
        Py_LeaveRecursiveCall();
    }
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
