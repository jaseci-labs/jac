"""Native deque and mapping policies for Python's collections module.

Python object lifetimes and callbacks remain explicit at the boundary. Storage
and all collection algorithms execute in Jac. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyIter_Next,
    PyLong_FromLongLong,
    PyNumber_Add,
    PyObject,
    PyObject_Call,
    PyObject_GetAttr,
    PyObject_GetIter,
    PyObject_RichCompareBool,
    PyObject_SetItem,
    PySequence_List,
    PyTuple_New,
    Py_NewRef,
    Py_ReprEnter,
    Py_ReprLeave,
    jacpy_dict_default,
    jacpy_dict_repr,
    jacpy_error_pending,
    jacpy_is_none,
    jacpy_release,
    jacpy_set_key_error,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.modules.object_ring { object_ring }
import from jaclang.runtime.python.capi {
    jac_heap_size,
    jac_list_heap_size,
    object_error,
    required,
    checked,
    boundary_failure,
    text_object,
    text_value,
    repr_value,
    type_name
}

obj deque_state {
    has items: object_ring = object_ring(),
        maxlen: i64 = -1,
        version: u64 = 0;

    def changed {
        self.version += u64(1);
    }

    def push(value: ptr[PyObject], left: bool, limit: i64) {
        self.items.push(value, left);
        self.changed();
        if limit >= 0 and i64(self.items.count) > limit {
            removed = self.items.pop(not left);
            jacpy_release(removed);
        }
    }
}

obj deque_cursor {
    has state: deque_state,
        version: u64,
        index: int,
        remaining: int,
        reverse: bool;
}

def:pub jacpy_deque_new -> deque_state {
    return deque_state();
}

def:pub jacpy_deque_size(state: deque_state) -> i64 {
    return i64(state.items.count);
}

def:pub jacpy_deque_limit(state: deque_state) -> i64 {
    return state.maxlen;
}

def:pub jacpy_deque_set_limit(state: deque_state, limit: i64) {
    state.maxlen = limit;
}

def:pub jacpy_deque_borrow(state: deque_state, index: i64) -> ptr[PyObject] {
    return state.items.borrow(int(index));
}

def:pub jacpy_deque_memory(state: deque_state) -> i64 {
    return jac_heap_size(u64(id(state)))
        + jac_heap_size(u64(id(state.items)))
        + jac_list_heap_size(u64(id(state.items.slots)));
}

def:pub jacpy_deque_clear(state: deque_state) {
    if state.items.count == 0 {
        return;
    }
    old = state.items;
    state.items = object_ring();
    state.changed();
    while old.count > 0 {
        jacpy_release(old.pop(True));
    }
}

def:pub jacpy_deque_append(state: deque_state, value: ptr[PyObject], left: i64) {
    state.push(Py_NewRef(value), left != 0, state.maxlen);
}

def:pub jacpy_deque_pop(state: deque_state, left: i64) -> ptr[PyObject] {
    if state.items.count == 0 {
        object_error("IndexError", "pop from an empty deque");
        return NULL;
    }
    result = state.items.pop(left != 0);
    state.changed();
    return result;
}

def:pub jacpy_deque_extend(
    state: deque_state, owner: ptr[PyObject], iterable: ptr[PyObject], left: i64
) -> i64 {
    source: ptr[PyObject] = NULL;
    iterator: ptr[PyObject] = NULL;
    limit = state.maxlen;
    try {
        source = required(
            PySequence_List(owner) if owner == iterable else Py_NewRef(iterable)
        );
        iterator = required(PyObject_GetIter(source));
        while True {
            item = PyIter_Next(iterator);
            if item == 0 {
                break;
            }
            if limit == 0 {
                jacpy_release(item);
            } else {
                state.push(item, left != 0, limit);
            }
        }
        if jacpy_error_pending() != 0 {
            return -1;
        }
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(iterator);
        jacpy_release(source);
    }
}

def:pub jacpy_deque_item(state: deque_state, index: i64) -> ptr[PyObject] {
    if index < 0 or index >= i64(state.items.count) {
        object_error("IndexError", "deque index out of range");
        return NULL;
    }
    return Py_NewRef(state.items.borrow(int(index)));
}

def:pub jacpy_deque_assign(
    state: deque_state, index: i64, value: ptr[PyObject]
) -> i64 {
    if index < 0 or index >= i64(state.items.count) {
        object_error("IndexError", "deque index out of range");
        return -1;
    }
    i = int(index);
    if value != 0 {
        previous = state.items.exchange(i, Py_NewRef(value));
        jacpy_release(previous);
    } else {
        previous = state.items.borrow(i);
        if i < state.items.count // 2 {
            while i > 0 {
                state.items.exchange(i, state.items.borrow(i - 1));
                i -= 1;
            }
            state.items.pop(True);
        } else {
            while i + 1 < state.items.count {
                state.items.exchange(i, state.items.borrow(i + 1));
                i += 1;
            }
            state.items.pop(False);
        }
        state.changed();
        jacpy_release(previous);
    }
    return 0;
}

def:pub jacpy_deque_rotate(state: deque_state, amount: i64) {
    count = state.items.count;
    if count <= 1 {
        return;
    }
    n = int(amount % i64(count));
    if n > count // 2 {
        n -= count;
    }
    if n < -(count // 2) {
        n += count;
    }
    state.changed();
    while n > 0 {
        state.items.push(state.items.pop(False), True);
        n -= 1;
    }
    while n < 0 {
        state.items.push(state.items.pop(True), False);
        n += 1;
    }
}

def:pub jacpy_deque_reverse(state: deque_state) {
    for i in range(state.items.count // 2) {
        j = state.items.count - i - 1;
        first = state.items.exchange(i, state.items.borrow(j));
        state.items.exchange(j, first);
    }
}

def:pub jacpy_deque_insert(
    state: deque_state, index: i64, value: ptr[PyObject]
) -> i64 {
    if state.maxlen >= 0 and i64(state.items.count) >= state.maxlen {
        object_error("IndexError", "deque already at its maximum size");
        return -1;
    }
    at = index;
    if at < 0 {
        at += i64(state.items.count);
    }
    at = max(i64(0), min(at, i64(state.items.count)));
    i = int(at);
    state.items.push(Py_NewRef(value));
    j = state.items.count - 1;
    while j > i {
        state.items.exchange(j, state.items.borrow(j - 1));
        j -= 1;
    }
    state.items.exchange(i, value);
    state.changed();
    return 0;
}

# mode: count, contains, index, remove. Mutation checks intentionally differ:
# a successful contains/index may return immediately, while remove must validate.
def:pub jacpy_deque_search(
    state: deque_state, value: ptr[PyObject], start: i64, stop: i64, mode: i64
) -> i64 {
    size = i64(state.items.count);
    first = start;
    last = stop;
    if first < 0 {
        first += size;
    }
    if last < 0 {
        last += size;
    }
    first = max(i64(0), min(first, size));
    last = max(i64(0), min(last, size));
    version = state.version;
    total: i64 = 0;
    for i in range(int(first), int(last)) {
        item = Py_NewRef(state.items.borrow(i));
        equal = PyObject_RichCompareBool(item, value, 2);
        jacpy_release(item);
        if equal < 0 {
            return -1;
        }
        if equal > 0 and (mode == 1 or mode == 2) {
            return i64(1) if mode == 1 else i64(i);
        }
        if state.version != version {
            object_error(
                "IndexError" if mode == 3 else "RuntimeError",
                "deque mutated during iteration"
            );
            return -1;
        }
        if equal > 0 {
            if mode == 3 {
                return jacpy_deque_assign(state, i64(i), NULL);
            }
            total += 1;
        }
    }
    if mode >= 2 {
        object_error(
            "ValueError",
            "deque.remove(x): x not in deque"
                if mode == 3
                else "deque.index(x): x not in deque"
        );
        return -1;
    }
    return total;
}

def:pub jacpy_deque_cursor(
    state: deque_state, reverse: i64, consumed_count: i64
) -> deque_cursor {
    consumed = int(max(i64(0), min(consumed_count, i64(state.items.count))));
    return deque_cursor(
        state=state,
        version=state.version,
        index=state.items.count - consumed - 1 if reverse != 0 else consumed,
        remaining=state.items.count - consumed,
        reverse=reverse != 0
    );
}

def:pub jacpy_deque_next(cursor: deque_cursor) -> ptr[PyObject] {
    if cursor.version != cursor.state.version {
        cursor.remaining = 0;
        object_error("RuntimeError", "deque mutated during iteration");
        return NULL;
    }
    if cursor.remaining == 0 {
        return NULL;
    }
    result = Py_NewRef(cursor.state.items.borrow(cursor.index));
    cursor.remaining -= 1;
    cursor.index += -1 if cursor.reverse else 1;
    return result;
}

def:pub jacpy_deque_remaining(cursor: deque_cursor) -> i64 {
    return i64(cursor.remaining);
}

def:pub jacpy_deque_consumed(cursor: deque_cursor) -> i64 {
    return i64(cursor.state.items.count - cursor.remaining);
}

def:pub jacpy_deque_compare(
    first: deque_state,
    second: deque_state,
    a_owner: ptr[PyObject],
    b_owner: ptr[PyObject],
    operation: i64
) -> ptr[PyObject] {
    if operation == 2 or operation == 3 {
        if a_owner == b_owner {
            return PyBool_FromLong(1 if operation == 2 else 0);
        }
        if first.items.count != second.items.count {
            return PyBool_FromLong(1 if operation == 3 else 0);
        }
    }
    left: ptr[PyObject] = NULL;
    right: ptr[PyObject] = NULL;
    try {
        left = required(PyObject_GetIter(a_owner));
        right = required(PyObject_GetIter(b_owner));
        while True {
            a = PyIter_Next(left);
            if a == 0 and jacpy_error_pending() != 0 {
                return NULL;
            }
            b = PyIter_Next(right);
            if jacpy_error_pending() != 0 {
                jacpy_release(a);
                jacpy_release(b);
                return NULL;
            }
            if a == 0 or b == 0 {
                result = False;
                if operation == 0 {
                    result = b != 0;
                } elif operation == 1 {
                    result = a == 0;
                } elif operation == 2 {
                    result = a == b;
                } elif operation == 3 {
                    result = a != b;
                } elif operation == 4 {
                    result = a != 0;
                } else {
                    result = b == 0;
                }
                jacpy_release(a);
                jacpy_release(b);
                return PyBool_FromLong(1 if result else 0);
            }
            equal = PyObject_RichCompareBool(a, b, 2);
            if equal == 0 {
                equal = PyObject_RichCompareBool(a, b, i32(operation));
                jacpy_release(a);
                jacpy_release(b);
                return NULL if equal < 0 else PyBool_FromLong(equal);
            }
            jacpy_release(a);
            jacpy_release(b);
            if equal < 0 {
                return NULL;
            }
        }
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(left);
        jacpy_release(right);
    }
    return NULL;
}

def:pub jacpy_deque_repeat(state: deque_state, repetitions: i64) -> i64 {
    size = state.items.count;
    if size == 0 or repetitions == 1 {
        return 0;
    }
    if repetitions <= 0 {
        jacpy_deque_clear(state);
        return 0;
    }
    if repetitions > i64(9223372036854775807) // i64(size) {
        object_error("MemoryError", "");
        return -1;
    }
    total = repetitions * i64(size);
    if state.maxlen >= 0 {
        total = min(total, state.maxlen);
    }
    replacement = object_ring();
    start = (repetitions * i64(size) - total) % i64(size);
    for i in range(int(total)) {
        replacement.push(
            Py_NewRef(state.items.borrow(int((start + i64(i)) % i64(size))))
        );
    }
    old = state.items;
    state.items = replacement;
    state.changed();
    while old.count > 0 {
        jacpy_release(old.pop(True));
    }
    return 0;
}

def:pub jacpy_deque_repr(state: deque_state, owner: ptr[PyObject]) -> ptr[PyObject] {
    entered = Py_ReprEnter(owner);
    if entered < 0 {
        return NULL;
    }
    if entered > 0 {
        return text_object("[...]");
    }
    values: ptr[PyObject] = NULL;
    try {
        values = required(PySequence_List(owner));
        limit = state.maxlen;
        suffix = ", maxlen=" + str(limit) if limit >= 0 else "";
        return text_object(
            type_name(owner).split(".")[-1] + "(" + repr_value(values) + suffix + ")"
        );
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(values);
        Py_ReprLeave(owner);
    }
}

def:pub jacpy_default_missing(
    mapping: ptr[PyObject], factory: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    if factory == 0 or jacpy_is_none(factory) != 0 {
        jacpy_set_key_error(key);
        return NULL;
    }
    args = PyTuple_New(0);
    if args == 0 {
        return NULL;
    }
    value = PyObject_Call(factory, args, NULL);
    jacpy_release(args);
    if value == 0 {
        return NULL;
    }
    result = jacpy_dict_default(mapping, key, value);
    jacpy_release(value);
    return result;
}

def:pub jacpy_count_elements(mapping: ptr[PyObject], iterable: ptr[PyObject]) -> i64 {
    iterator: ptr[PyObject] = NULL;
    get_method: ptr[PyObject] = NULL;
    name: ptr[PyObject] = NULL;
    one: ptr[PyObject] = NULL;
    zero: ptr[PyObject] = NULL;
    try {
        iterator = required(PyObject_GetIter(iterable));
        name = text_object("get");
        get_method = required(PyObject_GetAttr(mapping, name));
        one = required(PyLong_FromLongLong(1));
        zero = required(PyLong_FromLongLong(0));
        while True {
            key = PyIter_Next(iterator);
            if key == 0 {
                break;
            }
            args: ptr[PyObject] = NULL;
            value: ptr[PyObject] = NULL;
            increment: ptr[PyObject] = NULL;
            try {
                args = required(PyTuple_New(2));
                jacpy_tuple_set_owned(args, 0, Py_NewRef(key));
                jacpy_tuple_set_owned(args, 1, Py_NewRef(zero));
                value = required(PyObject_Call(get_method, args, NULL));
                increment = required(PyNumber_Add(value, one));
                checked(PyObject_SetItem(mapping, key, increment));
            } finally {
                jacpy_release(args);
                jacpy_release(value);
                jacpy_release(increment);
                jacpy_release(key);
            }
        }
        return -1 if jacpy_error_pending() != 0 else 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(iterator);
        jacpy_release(get_method);
        jacpy_release(name);
        jacpy_release(one);
        jacpy_release(zero);
    }
}

def:pub jacpy_default_repr(
    mapping: ptr[PyObject], factory: ptr[PyObject]
) -> ptr[PyObject] {
    base: ptr[PyObject] = NULL;
    try {
        base = required(jacpy_dict_repr(mapping));
        factory_repr = "None";
        if factory != 0 {
            entered = Py_ReprEnter(factory);
            if entered < 0 {
                return NULL;
            }
            if entered > 0 {
                factory_repr = "...";
            } else {
                try {
                    factory_repr = repr_value(factory);
                } finally {
                    Py_ReprLeave(factory);
                }
            }
        }
        return text_object(
            type_name(mapping).split(".")[-1]
                + "("
                + factory_repr
                + ", "
                + text_value(base)
                + ")"
        );
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(base);
    }
}
