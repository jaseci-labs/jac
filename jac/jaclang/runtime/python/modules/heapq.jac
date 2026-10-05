"""Native min/max heaps over retained Python lists.

Keep compared objects alive across arbitrary user callbacks, then recheck the
list length before accessing slots. Swaps use the current slots, including
changes made by comparisons. Derived from CPython; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyList_Append,
    PyList_GetItemRef,
    PyObject,
    Py_NewRef,
    jacpy_less,
    jacpy_list_delete,
    jacpy_list_exchange,
    jacpy_list_size,
    jacpy_list_swap,
    jacpy_none,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error }

def heap_size_unchanged(heap: ptr[PyObject], size: i64) -> bool {
    if jacpy_list_size(heap) != size {
        object_error("RuntimeError", "list changed size during iteration");
        return False;
    }
    return True;
}

def heap_compare(heap: ptr[PyObject], left: i64, right: i64, maximum: bool) -> i64 {
    a = PyList_GetItemRef(heap, left);
    if a == 0 {
        return -1;
    }
    b = PyList_GetItemRef(heap, right);
    if b == 0 {
        jacpy_release(a);
        return -1;
    }
    result = jacpy_less(b, a) if maximum else jacpy_less(a, b);
    jacpy_release(a);
    jacpy_release(b);
    return result;
}

def heap_siftdown(
    heap: ptr[PyObject], start: i64, position: i64, maximum: bool
) -> i64 {
    size = jacpy_list_size(heap);
    if position >= size {
        object_error("IndexError", "index out of range");
        return -1;
    }
    while position > start {
        parent = (position - 1) >> 1;
        comparison = heap_compare(heap, position, parent, maximum);
        if comparison < 0 {
            return -1;
        }
        if not heap_size_unchanged(heap, size) {
            return -1;
        }
        if comparison == 0 {
            break;
        }
        jacpy_list_swap(heap, position, parent);
        position = parent;
    }
    return 0;
}

def heap_siftup(heap: ptr[PyObject], position: i64, maximum: bool) -> i64 {
    end = jacpy_list_size(heap);
    start = position;
    if position >= end {
        object_error("IndexError", "index out of range");
        return -1;
    }
    while position < (end >> 1) {
        child = 2 * position + 1;
        if child + 1 < end {
            comparison = heap_compare(heap, child, child + 1, maximum);
            if comparison < 0 {
                return -1;
            }
            if comparison == 0 {
                child += 1;
            }
            if not heap_size_unchanged(heap, end) {
                return -1;
            }
        }
        jacpy_list_swap(heap, child, position);
        position = child;
    }
    return heap_siftdown(heap, start, position, maximum);
}

def:pub jacpy_heap_push(
    heap: ptr[PyObject], item: ptr[PyObject], maximum: i64
) -> ptr[PyObject] {
    if PyList_Append(heap, item) < 0 {
        return NULL;
    }
    if heap_siftdown(heap, 0, jacpy_list_size(heap) - 1, maximum != 0) < 0 {
        return NULL;
    }
    return jacpy_none();
}

def:pub jacpy_heap_pop(heap: ptr[PyObject], maximum: i64) -> ptr[PyObject] {
    size = jacpy_list_size(heap);
    if size == 0 {
        object_error("IndexError", "index out of range");
        return NULL;
    }
    last = PyList_GetItemRef(heap, size - 1);
    if last == 0 {
        return NULL;
    }
    if jacpy_list_delete(heap, size - 1, size) < 0 {
        jacpy_release(last);
        return NULL;
    }
    if size == 1 {
        return last;
    }
    result = jacpy_list_exchange(heap, 0, last);
    jacpy_release(last);
    if result == 0 {
        return NULL;
    }
    if heap_siftup(heap, 0, maximum != 0) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:pub jacpy_heap_replace(
    heap: ptr[PyObject], item: ptr[PyObject], maximum: i64
) -> ptr[PyObject] {
    if jacpy_list_size(heap) == 0 {
        object_error("IndexError", "index out of range");
        return NULL;
    }
    result = jacpy_list_exchange(heap, 0, item);
    if result == 0 {
        return NULL;
    }
    if heap_siftup(heap, 0, maximum != 0) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:pub jacpy_heap_pushpop(
    heap: ptr[PyObject], item: ptr[PyObject], maximum: i64
) -> ptr[PyObject] {
    if jacpy_list_size(heap) == 0 {
        return Py_NewRef(item);
    }
    top = PyList_GetItemRef(heap, 0);
    if top == 0 {
        return NULL;
    }
    comparison = jacpy_less(item, top) if maximum != 0 else jacpy_less(top, item);
    jacpy_release(top);
    if comparison < 0 {
        return NULL;
    }
    if comparison == 0 {
        return Py_NewRef(item);
    }
    return jacpy_heap_replace(heap, item, maximum);
}

def heapify_branch(heap: ptr[PyObject], position: i64, maximum: bool) -> i64 {
    while True {
        if heap_siftup(heap, position, maximum) < 0 {
            return -1;
        }
        if (position & 1) == 0 {
            return 0;
        }
        position >>= 1;
    }
}

def:pub jacpy_heapify(heap: ptr[PyObject], maximum: i64) -> ptr[PyObject] {
    size = jacpy_list_size(heap);
    count = size >> 1;
    if size > 2500 {
        # Visit sibling subheaps together to keep their parent in cache.
        top = i64(1);
        value = count + 1;
        while value > 1 {
            value >>= 1;
            top <<= 1;
        }
        leftmost = top - 1;
        position = leftmost - 1;
        while position >= (count >> 1) {
            if heapify_branch(heap, position, maximum != 0) < 0 {
                return NULL;
            }
            position -= 1;
        }
        position = count - 1;
        while position >= leftmost {
            if heapify_branch(heap, position, maximum != 0) < 0 {
                return NULL;
            }
            position -= 1;
        }
    } else {
        position = count - 1;
        while position >= 0 {
            if heap_siftup(heap, position, maximum != 0) < 0 {
                return NULL;
            }
            position -= 1;
        }
    }
    return jacpy_none();
}
