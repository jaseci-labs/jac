"""Native deque and mapping policies for Python's collections module.

Python object lifetimes and callbacks remain explicit at the boundary. Storage
and all collection algorithms execute in Jac. Derived from Python 3.14.6;
see ../LICENSE.cpython.
"""

import from c {
    def _PyDict_GetItem_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64
    ) -> ptr[PyObject];  def _PyDict_SetItem_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], hash: i64
    ) -> i32;  obj deque_record {
        has items: ptr[ptr[PyObject]],
            capacity: i64,
            head: i64,
            count: i64,
            maxlen: i64,
            version: u64;
    }
}


glob DEQUE_MIN_CAPACITY: Final[i64] = 8;

obj deque_cursor {
    has record: ptr[deque_record],
        version: u64,
        index: i64,
        remaining: i64,
        reverse: bool;
}

def:priv deque_slot(d: ptr[deque_record], index: i64) -> ptr[ptr[PyObject]] {
    return d.view(1)[0].items
        + ((d.view(1)[0].head + index) & (d.view(1)[0].capacity - 1));
}

def:priv deque_resize(d: ptr[deque_record], capacity: i64, loud: bool) -> i32 {
    items = ptr[ptr[PyObject]](PyMem_Malloc(u64(capacity * 8)));
    if items.is_null() {
        if loud {
            PyErr_NoMemory();
        }
        return i32(-1);
    }
    count = d.view(1)[0].count;
    i: i64 = 0;
    while i < count {
        (items + i).view(1)[0] = deque_slot(d, i).view(1)[0];
        i += 1;
    }
    PyMem_Free(ptr(d.view(1)[0].items));
    d.view(1)[0].items = items;
    d.view(1)[0].capacity = capacity;
    d.view(1)[0].head = 0;
    return i32(0);
}

def:priv deque_take(d: ptr[deque_record], left: bool) -> ptr[PyObject] {
    capacity = d.view(1)[0].capacity;
    mask = capacity - 1;
    index: i64 = 0;
    if left {
        index = d.view(1)[0].head;
        d.view(1)[0].head = (index + 1) & mask;
    } else {
        index = (d.view(1)[0].head + d.view(1)[0].count - 1) & mask;
    }
    slot = d.view(1)[0].items + index;
    value = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    count = d.view(1)[0].count - 1;
    d.view(1)[0].count = count;
    d.view(1)[0].version += u64(1);
    return value;
}

def:priv deque_place(d: ptr[deque_record], value: ptr[PyObject], left: bool) {
    mask = d.view(1)[0].capacity - 1;
    if left {
        head = (d.view(1)[0].head - 1) & mask;
        d.view(1)[0].head = head;
        (d.view(1)[0].items + head).view(1)[0] = value;
    } else {
        (d.view(1)[0].items + ((d.view(1)[0].head + d.view(1)[0].count) & mask)).view(1)[
            0
        ] = value;
    }
    d.view(1)[0].count += 1;
    d.view(1)[0].version += u64(1);
}

def:priv deque_shrink(d: ptr[deque_record]) {
    capacity = d.view(1)[0].capacity;
    if capacity > 64 and d.view(1)[0].count < capacity // 4 {
        deque_resize(d, capacity // 2, False);
    }
}

def:pub deque_of(instance: ptr[PyObject]) -> ptr[deque_record] {
    record = ptr[deque_record](jacpy_binding_record(instance, deque_token.handle));
    if record.is_null() {
        object_error(PyExc_SystemError, "native deque state is unavailable");
    }
    return record;
}

def:pub jacpy_deque_init(d: ptr[deque_record]) {
    d.view(1)[0].items = ptr[ptr[PyObject]]();
    d.view(1)[0].capacity = 0;
    d.view(1)[0].head = 0;
    d.view(1)[0].count = 0;
    d.view(1)[0].maxlen = -1;
    d.view(1)[0].version = u64(0);
}

def:pub jacpy_deque_size(d: ptr[deque_record]) -> i64 {
    return d.view(1)[0].count;
}

def:pub jacpy_deque_limit(d: ptr[deque_record]) -> i64 {
    return d.view(1)[0].maxlen;
}

def:pub jacpy_deque_set_limit(d: ptr[deque_record], limit: i64) {
    d.view(1)[0].maxlen = limit;
}

def:pub jacpy_deque_borrow(d: ptr[deque_record], index: i64) -> ptr[PyObject] {
    return deque_slot(d, index).view(1)[0];
}

def:pub jacpy_deque_memory(d: ptr[deque_record]) -> i64 {
    return d.view(1)[0].capacity * 8;
}

def:pub jacpy_deque_clear(d: ptr[deque_record]) {
    items = d.view(1)[0].items;
    capacity = d.view(1)[0].capacity;
    head = d.view(1)[0].head;
    count = d.view(1)[0].count;
    d.view(1)[0].items = ptr[ptr[PyObject]]();
    d.view(1)[0].capacity = 0;
    d.view(1)[0].head = 0;
    d.view(1)[0].count = 0;
    d.view(1)[0].version += u64(1);
    i: i64 = 0;
    while i < count {
        jacpy_release((items + ((head + i) & (capacity - 1))).view(1)[0]);
        i += 1;
    }
    PyMem_Free(ptr(items));
}

def:pub jacpy_deque_push(
    d: ptr[deque_record], value: ptr[PyObject], left: bool
) -> i32 {
    count = d.view(1)[0].count;
    capacity = d.view(1)[0].capacity;
    if count == capacity {
        if deque_resize(d, DEQUE_MIN_CAPACITY if capacity == 0 else capacity * 2, True)
            < 0 {
            jacpy_release(value);
            return i32(-1);
        }
    }
    deque_place(d, value, left);
    maxlen = d.view(1)[0].maxlen;
    if maxlen >= 0 and d.view(1)[0].count > maxlen {
        jacpy_release(deque_take(d, not left));
    }
    return i32(0);
}

def:pub jacpy_deque_pop(d: ptr[deque_record], left: bool) -> ptr[PyObject] {
    if d.view(1)[0].count == 0 {
        object_error(PyExc_IndexError, "pop from an empty deque");
        return NULL;
    }
    value = deque_take(d, left);
    deque_shrink(d);
    return value;
}

def:pub jacpy_deque_extend(
    d: ptr[deque_record], owner: ptr[PyObject], iterable: ptr[PyObject], left: bool
) -> i64 {
    source = PySequence_List(owner) if owner == iterable else Py_NewRef(iterable);
    if source == 0 {
        return -1;
    }
    iterator = PyObject_GetIter(source);
    jacpy_release(source);
    if iterator == 0 {
        return -1;
    }
    status: i64 = 0;
    while True {
        item = PyIter_Next(iterator);
        if item == 0 {
            break;
        }
        if d.view(1)[0].maxlen == 0 {
            jacpy_release(item);
        } elif jacpy_deque_push(d, item, left) < 0 {
            status = -1;
            break;
        }
    }
    jacpy_release(iterator);
    if status == 0 and jacpy_error_pending() != 0 {
        status = -1;
    }
    return status;
}

def:pub jacpy_deque_item(d: ptr[deque_record], index: i64) -> ptr[PyObject] {
    if index < 0 or index >= d.view(1)[0].count {
        object_error(PyExc_IndexError, "deque index out of range");
        return NULL;
    }
    return Py_NewRef(deque_slot(d, index).view(1)[0]);
}

def:pub jacpy_deque_assign(
    d: ptr[deque_record], index: i64, value: ptr[PyObject]
) -> i64 {
    count = d.view(1)[0].count;
    if index < 0 or index >= count {
        object_error(PyExc_IndexError, "deque index out of range");
        return -1;
    }
    i = index;
    if value != 0 {
        slot = deque_slot(d, i);
        previous = slot.view(1)[0];
        slot.view(1)[0] = Py_NewRef(value);
        jacpy_release(previous);
        return 0;
    }
    previous = deque_slot(d, i).view(1)[0];
    if i < count // 2 {
        while i > 0 {
            deque_slot(d, i).view(1)[0] = deque_slot(d, i - 1).view(1)[0];
            i -= 1;
        }
        deque_take(d, True);
    } else {
        while i + 1 < count {
            deque_slot(d, i).view(1)[0] = deque_slot(d, i + 1).view(1)[0];
            i += 1;
        }
        deque_take(d, False);
    }
    deque_shrink(d);
    jacpy_release(previous);
    return 0;
}

def:pub jacpy_deque_rotate(d: ptr[deque_record], amount: i64) {
    count = d.view(1)[0].count;
    if count <= 1 {
        return;
    }
    half = count // 2;
    n = amount % count;
    if n > half {
        n -= count;
    }
    if n < -half {
        n += count;
    }
    d.view(1)[0].version += u64(1);
    while n > 0 {
        deque_place(d, deque_take(d, False), True);
        n -= 1;
    }
    while n < 0 {
        deque_place(d, deque_take(d, True), False);
        n += 1;
    }
}

def:pub jacpy_deque_reverse(d: ptr[deque_record]) {
    count = d.view(1)[0].count;
    i: i64 = 0;
    while i < count // 2 {
        first = deque_slot(d, i);
        second = deque_slot(d, count - i - 1);
        value = first.view(1)[0];
        first.view(1)[0] = second.view(1)[0];
        second.view(1)[0] = value;
        i += 1;
    }
}

def:pub jacpy_deque_insert(
    d: ptr[deque_record], index: i64, value: ptr[PyObject]
) -> i64 {
    maxlen = d.view(1)[0].maxlen;
    count = d.view(1)[0].count;
    if maxlen >= 0 and count >= maxlen {
        object_error(PyExc_IndexError, "deque already at its maximum size");
        return -1;
    }
    at = index;
    if at < 0 {
        at += count;
    }
    if at < 0 {
        at = 0;
    }
    if at > count {
        at = count;
    }
    if jacpy_deque_push(d, Py_NewRef(value), False) < 0 {
        return -1;
    }
    j = d.view(1)[0].count - 1;
    while j > at {
        deque_slot(d, j).view(1)[0] = deque_slot(d, j - 1).view(1)[0];
        j -= 1;
    }
    deque_slot(d, at).view(1)[0] = value;
    return 0;
}

def:pub jacpy_deque_search(
    d: ptr[deque_record], value: ptr[PyObject], start: i64, stop: i64, mode: i64
) -> i64 {
    size = d.view(1)[0].count;
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
    version = d.view(1)[0].version;
    total: i64 = 0;
    i = first;
    while i < last {
        item = Py_NewRef(deque_slot(d, i).view(1)[0]);
        equal = PyObject_RichCompareBool(item, value, 2);
        jacpy_release(item);
        if equal < 0 {
            return -1;
        }
        if equal > 0 and (mode == 1 or mode == 2) {
            return i64(1) if mode == 1 else i;
        }
        if d.view(1)[0].version != version {
            object_error(
                PyExc_IndexError if mode == 3 else PyExc_RuntimeError,
                "deque mutated during iteration"
            );
            return -1;
        }
        if equal > 0 {
            if mode == 3 {
                return jacpy_deque_assign(d, i, NULL);
            }
            total += 1;
        }
        i += 1;
    }
    if mode >= 2 {
        object_error(
            PyExc_ValueError,
            "deque.remove(x): x not in deque"
                if mode == 3
                else "deque.index(x): x not in deque"
        );
        return -1;
    }
    return total;
}

def:pub jacpy_deque_cursor(
    d: ptr[deque_record], reverse: i64, consumed_count: i64
) -> deque_cursor {
    count = d.view(1)[0].count;
    consumed = max(i64(0), min(consumed_count, count));
    return deque_cursor(
        record=d,
        version=d.view(1)[0].version,
        index=count - consumed - 1 if reverse != 0 else consumed,
        remaining=count - consumed,
        reverse=reverse != 0
    );
}

def:pub jacpy_deque_next(cursor: deque_cursor) -> ptr[PyObject] {
    d = cursor.record;
    if cursor.version != d.view(1)[0].version {
        cursor.remaining = 0;
        object_error(PyExc_RuntimeError, "deque mutated during iteration");
        return NULL;
    }
    if cursor.remaining == 0 {
        return NULL;
    }
    result = Py_NewRef(deque_slot(d, cursor.index).view(1)[0]);
    cursor.remaining -= 1;
    cursor.index += -1 if cursor.reverse else 1;
    return result;
}

def:pub jacpy_deque_remaining(cursor: deque_cursor) -> i64 {
    return cursor.remaining;
}

def:pub jacpy_deque_consumed(cursor: deque_cursor) -> i64 {
    return cursor.record.view(1)[0].count - cursor.remaining;
}

def:pub jacpy_deque_compare(
    first: ptr[deque_record],
    second: ptr[deque_record],
    a_owner: ptr[PyObject],
    b_owner: ptr[PyObject],
    operation: i64
) -> ptr[PyObject] {
    if operation == 2 or operation == 3 {
        if a_owner == b_owner {
            return PyBool_FromLong(1 if operation == 2 else 0);
        }
        if first.view(1)[0].count != second.view(1)[0].count {
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

def:pub jacpy_deque_repeat(d: ptr[deque_record], repetitions: i64) -> i64 {
    size = d.view(1)[0].count;
    if size == 0 or repetitions == 1 {
        return 0;
    }
    if repetitions <= 0 {
        jacpy_deque_clear(d);
        return 0;
    }
    if repetitions > i64(9223372036854775807) // size {
        object_error(PyExc_MemoryError, "");
        return -1;
    }
    total = repetitions * size;
    maxlen = d.view(1)[0].maxlen;
    if maxlen >= 0 and total > maxlen {
        total = maxlen;
    }
    capacity = DEQUE_MIN_CAPACITY;
    while capacity < total {
        capacity *= 2;
    }
    items = ptr[ptr[PyObject]](PyMem_Malloc(u64(capacity * 8)));
    if items.is_null() {
        PyErr_NoMemory();
        return -1;
    }
    start = (repetitions * size - total) % size;
    i: i64 = 0;
    while i < total {
        (items + i).view(1)[0] = Py_NewRef(
            deque_slot(d, (start + i) % size).view(1)[0]
        );
        i += 1;
    }
    old_items = d.view(1)[0].items;
    old_capacity = d.view(1)[0].capacity;
    old_head = d.view(1)[0].head;
    d.view(1)[0].items = items;
    d.view(1)[0].capacity = capacity;
    d.view(1)[0].head = 0;
    d.view(1)[0].count = total;
    d.view(1)[0].version += u64(1);
    i = 0;
    while i < size {
        jacpy_release((old_items + ((old_head + i) & (old_capacity - 1))).view(1)[0]);
        i += 1;
    }
    PyMem_Free(ptr(old_items));
    return 0;
}

def:pub jacpy_deque_repr(d: ptr[deque_record], owner: ptr[PyObject]) -> ptr[PyObject] {
    entered = Py_ReprEnter(owner);
    if entered < 0 {
        return NULL;
    }
    if entered > 0 {
        return PyUnicode_FromString(ptr[u8]("[...]"));
    }
    values: ptr[PyObject] = NULL;
    try {
        values = required(PySequence_List(owner));
        limit = d.view(1)[0].maxlen;
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
    if factory == 0 or factory == Py_None {
        tup = PyTuple_Pack(1, key);
        if not tup {
            return NULL;
        }
        PyErr_SetObject(PyExc_KeyError, tup);
        jacpy_release(tup);
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

def:priv count_known_dict(
    mapping: ptr[PyObject], iterator: ptr[PyObject], one: ptr[PyObject]
) -> i64 {
    while True {
        key = PyIter_Next(iterator);
        if key == 0 {
            break;
        }
        hash = PyObject_Hash(key);
        if hash == -1 {
            jacpy_release(key);
            return -1;
        }
        oldval = _PyDict_GetItem_KnownHash(mapping, key, hash);
        status: i32 = 0;
        if oldval == 0 {
            if jacpy_error_pending() != 0 {
                jacpy_release(key);
                return -1;
            }
            status = _PyDict_SetItem_KnownHash(mapping, key, one, hash);
        } else {
            newval = PyNumber_Add(oldval, one);
            if newval == 0 {
                jacpy_release(key);
                return -1;
            }
            status = _PyDict_SetItem_KnownHash(mapping, key, newval, hash);
            jacpy_release(newval);
        }
        jacpy_release(key);
        if status < 0 {
            return -1;
        }
    }
    return -1 if jacpy_error_pending() != 0 else 0;
}

def:priv count_mapping(
    mapping: ptr[PyObject], iterator: ptr[PyObject], one: ptr[PyObject]
) -> i64 {
    get_name = PyUnicode_InternFromString(ptr[u8]("get"));
    if get_name == 0 {
        return -1;
    }
    bound_get = PyObject_GetAttr(mapping, get_name);
    jacpy_release(get_name);
    if bound_get == 0 {
        return -1;
    }
    zero = PyLong_FromLongLong(0);
    if zero == 0 {
        jacpy_release(bound_get);
        return -1;
    }
    status: i64 = 0;
    while True {
        key = PyIter_Next(iterator);
        if key == 0 {
            break;
        }
        oldval = PyObject_CallFunctionObjArgs(bound_get, key, zero, NULL);
        if oldval == 0 {
            jacpy_release(key);
            status = -1;
            break;
        }
        newval: ptr[PyObject] = NULL;
        if oldval == zero {
            newval = Py_NewRef(one);
        } else {
            newval = PyNumber_Add(oldval, one);
        }
        jacpy_release(oldval);
        if newval == 0 {
            jacpy_release(key);
            status = -1;
            break;
        }
        stored = PyObject_SetItem(mapping, key, newval);
        jacpy_release(newval);
        jacpy_release(key);
        if stored < 0 {
            status = -1;
            break;
        }
    }
    jacpy_release(zero);
    jacpy_release(bound_get);
    if status == 0 and jacpy_error_pending() != 0 {
        status = -1;
    }
    return status;
}

def:pub jacpy_count_elements(mapping: ptr[PyObject], iterable: ptr[PyObject]) -> i64 {
    iterator = PyObject_GetIter(iterable);
    if iterator == 0 {
        return -1;
    }
    one = PyLong_FromLongLong(1);
    get_name = PyUnicode_InternFromString(ptr[u8]("get"));
    set_name = PyUnicode_InternFromString(ptr[u8]("__setitem__"));
    status: i64 = -1;
    if one != 0 and get_name != 0 and set_name != 0 {
        dict_type = ptr[PyObject](addressof(PyDict_Type));
        mapping_get = _PyType_LookupRef(Py_TYPE(mapping), get_name);
        dict_get = _PyType_LookupRef(dict_type, get_name);
        mapping_set = _PyType_LookupRef(Py_TYPE(mapping), set_name);
        dict_set = _PyType_LookupRef(dict_type, set_name);
        if mapping_get != 0
            and mapping_get == dict_get
            and mapping_set != 0
            and mapping_set == dict_set
            and jacpy_is_dict(mapping) != 0 {
            status = count_known_dict(mapping, iterator, one);
        } elif jacpy_error_pending() == 0 {
            status = count_mapping(mapping, iterator, one);
        }
        jacpy_release(mapping_get);
        jacpy_release(dict_get);
        jacpy_release(mapping_set);
        jacpy_release(dict_set);
    }
    jacpy_release(set_name);
    jacpy_release(get_name);
    jacpy_release(one);
    jacpy_release(iterator);
    return status;
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

# The definitions the binding creates; methods find the receiver's state and
# module by them.
glob deque_token = ClassToken(),
     dequeiter_token = ClassToken(),
     dequereviter_token = ClassToken(),
     defdict_token = ClassToken(),
     _tuplegetter_token = ClassToken(),
     collections_module_token = ClassToken();

obj DequeState(NativeState) {
    has native: ptr[deque_record];

    def clear {
        jacpy_deque_clear(self.native);
    }

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        count = jacpy_deque_size(self.native);
        i: i64 = 0;
        while i < count {
            status = visit_reference(
                jacpy_deque_borrow(self.native, i), visitor, context
            );
            if status != 0 {
                return status;
            }
            i += 1;
        }
        return i32(0);
    }

    def drop {
        self.clear();
    }
}

obj DequeIteratorState(ReferenceState) {
    has cursor: (deque_cursor | None);

    def clear {
        self.cursor = None;
        super.clear();
    }
}

obj TupleGetterState(ReferenceState) {
    has index: i64;
}

def module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, collections_module_token.handle);
}

def allocate(
    type: ptr[PyObject], definition: ptr, state: NativeState
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if instance != 0 and jacpy_binding_native_set(instance, definition, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def:pub deque_allocate(type: ptr[PyObject]) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return NULL;
    }
    record = deque_of(instance);
    if record.is_null() {
        jacpy_release(instance);
        return NULL;
    }
    jacpy_deque_init(record);
    if jacpy_binding_native_set(instance, deque_token.handle, DequeState(native=record))
        < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def search(
    instance: ptr[PyObject], value: ptr[PyObject], first: i64, last: i64, kind: i64
) -> i64 {
    d = deque_of(instance);
    if d.is_null() {
        return -1;
    }
    return jacpy_deque_search(d, value, first, last, kind);
}

def iterator_create(
    type: ptr[PyObject], owner: ptr[PyObject], reverse: bool, advance: i64
) -> ptr[PyObject] {
    d = deque_of(owner);
    if d.is_null() {
        return NULL;
    }
    state = DequeIteratorState(
        references=[Py_NewRef(owner)],
        cursor=jacpy_deque_cursor(d, i64(reverse), advance)
    );
    return allocate(
        type, dequereviter_token.handle if reverse else dequeiter_token.handle, state
    );
}

def:priv deque_push_method(
    instance: ptr[PyObject], value: ptr[PyObject], left: bool
) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() or jacpy_deque_push(d, Py_NewRef(value), left) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def:priv deque_pop_method(instance: ptr[PyObject], left: bool) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() {
        return NULL;
    }
    return jacpy_deque_pop(d, left);
}

def:priv deque_grow(
    instance: ptr[PyObject], iterable: ptr[PyObject], left: bool
) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() or jacpy_deque_extend(d, instance, iterable, left) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def deque_pop_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return deque_pop_method(instance, False);
}

def deque_popleft_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return deque_pop_method(instance, True);
}

def deque_append_impl(instance: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    return deque_push_method(instance, item, False);
}

def deque_appendleft_impl(
    instance: ptr[PyObject], item: ptr[PyObject]
) -> ptr[PyObject] {
    return deque_push_method(instance, item, True);
}

def deque_extend_impl(
    instance: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    return deque_grow(instance, iterable, False);
}

def deque_extendleft_impl(
    instance: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    return deque_grow(instance, iterable, True);
}

def:priv copy_type_error(instance: ptr[PyObject], result: ptr[PyObject]) {
    try {
        object_error(
            PyExc_TypeError,
            f"{type_name(instance)[:200]}() must return a deque, not {type_name(result)[:200]}"
        );
    } except boundary_failure {}
}

def deque_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() {
        return NULL;
    }
    limit = jacpy_deque_limit(d);
    args = owned_tuple([Py_NewRef(instance)])
        if limit < 0
        else owned_tuple([Py_NewRef(instance), PyLong_FromLongLong(limit)]);
    if args == 0 {
        return NULL;
    }
    result = PyObject_Call(Py_TYPE(instance), args, NULL);
    jacpy_release(args);
    if result != 0 and jacpy_binding_matches(result, deque_token.handle) == 0 {
        copy_type_error(instance, result);
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def deque___copy___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return deque_copy_impl(instance);
}

def deque_clearmethod_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() {
        return NULL;
    }
    jacpy_deque_clear(d);
    return Py_NewRef(Py_None);
}

def deque_rotate_impl(instance: ptr[PyObject], n: i64) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() {
        return NULL;
    }
    jacpy_deque_rotate(d, n);
    return Py_NewRef(Py_None);
}

def deque_reverse_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() {
        return NULL;
    }
    jacpy_deque_reverse(d);
    return Py_NewRef(Py_None);
}

def deque_count_impl(instance: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    count = search(instance, v, 0, 9223372036854775807, 0);
    return PyLong_FromLongLong(count) if count >= 0 else NULL;
}

def deque_index_impl(
    instance: ptr[PyObject], v: ptr[PyObject], start: i64, stop: i64
) -> ptr[PyObject] {
    found = search(instance, v, start, stop, 2);
    return PyLong_FromLongLong(found) if found >= 0 else NULL;
}

def deque_insert_impl(
    instance: ptr[PyObject], index: i64, value: ptr[PyObject]
) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() or jacpy_deque_insert(d, index, value) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def deque_remove_impl(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(Py_None)
        if search(instance, value, 0, 9223372036854775807, 3) >= 0
        else NULL;
}

def deque___reduce___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() {
        return NULL;
    }
    limit = jacpy_deque_limit(d);
    saved = _PyObject_GetState(instance);
    iterator = PyObject_GetIter(instance);
    args = PyTuple_New(0)
        if limit < 0
        else owned_tuple([PyTuple_New(0), PyLong_FromLongLong(limit)]);
    return owned_tuple([Py_NewRef(Py_TYPE(instance)), args, saved, iterator]);
}

def deque_init_impl(
    instance: ptr[PyObject], iterable: ptr[PyObject], maxlenobj: ptr[PyObject]
) -> i32 {
    limit: i64 = -1;
    if maxlenobj != 0 and maxlenobj != Py_None {
        limit = PyLong_AsSsize_t(maxlenobj);
        if limit == -1 and jacpy_error_pending() != 0 {
            return i32(-1);
        }
        if limit < 0 {
            object_error(PyExc_ValueError, "maxlen must be non-negative");
            return i32(-1);
        }
    }
    d = deque_of(instance);
    if d.is_null() {
        return i32(-1);
    }
    jacpy_deque_set_limit(d, limit);
    jacpy_deque_clear(d);
    if iterable != 0 and jacpy_deque_extend(d, instance, iterable, False) < 0 {
        return i32(-1);
    }
    return i32(0);
}

def deque___sizeof___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    d = deque_of(instance);
    if d.is_null() {
        return NULL;
    }
    return PyLong_FromLongLong(
        jacpy_binding_basicsize(instance) + jacpy_deque_memory(d)
    );
}

def deque___reversed___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    return iterator_create(jacpy_binding_state_get(module, 2), instance, True, 0);
}

def _collections__count_elements_impl(
    module: ptr[PyObject], mapping: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(Py_None) if jacpy_count_elements(mapping, iterable) == 0 else NULL;
}

# _tuplegetter's record: the __doc__ member it owns at offset 0; the index
# lives in the native state.
def tuplegetter_new_impl(
    type: ptr[PyObject], index: i64, doc: ptr[PyObject]
) -> ptr[PyObject] {
    instance = allocate(
        type, _tuplegetter_token.handle, TupleGetterState(references=[], index=index)
    );
    if instance != 0 {
        record_set_object(
            jacpy_binding_record(instance, _tuplegetter_token.handle), 0, Py_NewRef(doc)
        );
    }
    return instance;
}
