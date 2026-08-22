# c2jac: hand-staged from ``jac-py/tools/p3_object_core/corpus/sliceobject.c``
# (``PySlice_AdjustIndices`` core; runtime truth in ``objects.jac``).

glob Py_ssize_t = int;


def adjust_index(i: int, length: int, neg: bool) -> int {
    if i < 0 {
        i = i + length;
        if i < 0 {
            if neg {
                return -1;
            }
            return 0;
        }
    } elif i >= length {
        if neg {
            return length - 1;
        }
        return length;
    }
    return i;
}

def PySlice_AdjustIndices(length: int, start: int, stop: int, step: int) -> int {
    neg = step < 0;
    if start == -9223372036854775808 {
        if neg {
            start = length - 1;
        } else {
            start = 0;
        }
    } else {
        start = adjust_index(start, length, neg);
    }
    if stop == -9223372036854775808 {
        if neg {
            stop = -1;
        } else {
            stop = length;
        }
    } else {
        stop = adjust_index(stop, length, neg);
    }
    if (step < 0 and stop < start) or (step > 0 and start < stop) {
        return 1;
    }
    return 0;
}
