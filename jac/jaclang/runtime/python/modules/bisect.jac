"""Bisection over Python sequences, including key and comparison callbacks.

CPython supplies values and their protocol operations. Search and insertion
orchestration execute here, without converting the sequence to a Jac list.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyExc_ValueError,
    PyLong_FromLongLong,
    PyObject,
    PyObject_CallOneArg,
    PyObject_IsTrue,
    PySequence_Size,
    Py_LeaveRecursiveCall,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    jacpy_comparison_slot,
    jacpy_insert,
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

def:pub jacpy_bisect(
    sequence: ptr[PyObject],
    item: ptr[PyObject],
    low: i64,
    high: i64,
    key: ptr[PyObject],
    right: i64,
    insert: i64
) -> ptr[PyObject] {
    search = item;
    if insert != 0 and key != 0 {
        search = PyObject_CallOneArg(key, item);
        if search == 0 {
            return NULL;
        }
    }
    index = bisect_index(sequence, search, low, high, key, right != 0);
    if insert != 0 and key != 0 {
        jacpy_release(search);
    }
    if index < 0 {
        return NULL;
    }
    if insert == 0 {
        return PyLong_FromLongLong(index);
    }
    if jacpy_insert(sequence, index, item) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}
