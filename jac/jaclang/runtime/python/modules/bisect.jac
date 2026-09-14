"""Bisection over Python sequences, including key and comparison callbacks.

CPython supplies values and their protocol operations. Search and insertion
orchestration execute here, without converting the sequence to a Jac list.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_none,
    jacpy_int,
    jacpy_object_size,
    jacpy_sequence_slot,
    jacpy_slot_item,
    jacpy_call_one,
    jacpy_less,
    jacpy_insert,
    jacpy_recursion_enter,
    jacpy_recursion_leave,
    object_error,
    jacpy_comparison_slot,
    jacpy_same_type,
    jacpy_slot_less
}

def bisect_index(
    sequence: u64, item: u64, low: i64, high: i64, key: u64, right: bool
) -> i64 {
    if low < 0 {
        object_error("ValueError", "lo must be non-negative");
        return -1;
    }
    if high == -1 {
        high = jacpy_object_size(sequence);
        if high < 0 {
            return -1;
        }
    }
    slot = jacpy_sequence_slot(sequence);
    if slot == 0 {
        return -1;
    }
    context = " in _bisect.bisect_right" if right else " in _bisect.bisect_left";
    if jacpy_recursion_enter(context) != 0 {
        return -1;
    }
    compare = jacpy_comparison_slot(item);
    try {
        while low < high {
            # Unsigned addition avoids overflow for valid ssize_t bounds.
            middle = i64((u64(low) + u64(high)) // u64(2));
            value = jacpy_slot_item(slot, sequence, middle);
            if value == 0 {
                return -1;
            }
            if key != 0 {
                mapped = jacpy_call_one(key, value);
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
                comparison = jacpy_slot_less(compare, left, other);
                if comparison == -2 {
                    compare = 0;
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
        jacpy_recursion_leave();
    }
}

def:pub jacpy_bisect(
    sequence: u64, item: u64, low: i64, high: i64, key: u64, right: i64, insert: i64
) -> u64 {
    search = item;
    if insert != 0 and key != 0 {
        search = jacpy_call_one(key, item);
        if search == 0 {
            return 0;
        }
    }
    index = bisect_index(sequence, search, low, high, key, right != 0);
    if insert != 0 and key != 0 {
        jacpy_release(search);
    }
    if index < 0 {
        return 0;
    }
    if insert == 0 {
        return jacpy_int(index);
    }
    if jacpy_insert(sequence, index, item) < 0 {
        return 0;
    }
    return jacpy_none();
}
