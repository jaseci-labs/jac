"""Native deque and mapping policies for Python's collections module.

Python object lifetimes and callbacks remain explicit at the boundary. Storage
and all collection algorithms execute in Jac. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_dict_default,
    jacpy_dict_repr,
    jacpy_error_pending,
    jacpy_release,
    jacpy_tuple_set_owned,
    NULL,
    Py_NewRef,
    Py_None,
    Py_ReprEnter,
    Py_ReprLeave,
    PyErr_SetObject,
    PyExc_IndexError,
    PyExc_KeyError,
    PyExc_MemoryError,
    PyExc_RuntimeError,
    PyExc_ValueError,
    PyIter_Next,
    PyLong_FromLongLong,
    PyNumber_Add,
    PyObject,
    _PyObject_GetState,
    Py_TYPE,
    PyLong_AsSsize_t,
    PyExc_TypeError,
    PyExc_SystemError,
    PyObject_Call,
    PyObject_GetAttr,
    PyObject_GetIter,
    PyObject_RichCompareBool,
    PyObject_SetItem,
    PySequence_List,
    PyTuple_New,
    PyTuple_Pack
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
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

import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.references { ReferenceState, owned_tuple }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_basicsize,
    jacpy_binding_matches,
    jacpy_binding_owner,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    clear_payload,
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.members { record_set_object }
import from jaclang.runtime.python.bindings.converters { ClassToken }

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
        object_error(PyExc_IndexError, "pop from an empty deque");
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
        object_error(PyExc_IndexError, "deque index out of range");
        return NULL;
    }
    return Py_NewRef(state.items.borrow(int(index)));
}

def:pub jacpy_deque_assign(
    state: deque_state, index: i64, value: ptr[PyObject]
) -> i64 {
    if index < 0 or index >= i64(state.items.count) {
        object_error(PyExc_IndexError, "deque index out of range");
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
        object_error(PyExc_IndexError, "deque already at its maximum size");
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
                PyExc_IndexError if mode == 3 else PyExc_RuntimeError,
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
        object_error(PyExc_RuntimeError, "deque mutated during iteration");
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
        object_error(PyExc_MemoryError, "");
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

# The definitions the binding creates; methods find the receiver's state and
# module by them.
glob deque_token = ClassToken(),
     dequeiter_token = ClassToken(),
     dequereviter_token = ClassToken(),
     defdict_token = ClassToken(),
     _tuplegetter_token = ClassToken(),
     collections_module_token = ClassToken();

obj DequeState(NativeState) {
    has native: deque_state;

    def clear {
        jacpy_deque_clear(self.native);
    }

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for i in range(int(jacpy_deque_size(self.native))) {
            status = visit_reference(
                jacpy_deque_borrow(self.native, i64(i)), visitor, context
            );
            if status != 0 {
                return status;
            }
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

def deque_value(instance: ptr[PyObject]) -> (DequeState | None) {
    if jacpy_binding_native_present(instance, deque_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, deque_token.handle);
        if isinstance(state, DequeState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "native deque state is unavailable");
    return None;
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

def search(
    instance: ptr[PyObject], value: ptr[PyObject], first: i64, last: i64, kind: i64
) -> i64 {
    state = deque_value(instance);
    return jacpy_deque_search(state.native, value, first, last, kind)
        if state is not None
        else i64(-1);
}

def iterator_create(
    type: ptr[PyObject], owner: ptr[PyObject], reverse: bool, advance: i64
) -> ptr[PyObject] {
    native = deque_value(owner);
    if native is None {
        return NULL;
    }
    state = DequeIteratorState(
        references=[Py_NewRef(owner)],
        cursor=jacpy_deque_cursor(native.native, i64(reverse), advance)
    );
    return allocate(
        type, dequereviter_token.handle if reverse else dequeiter_token.handle, state
    );
}

def:priv deque_push(
    instance: ptr[PyObject], value: ptr[PyObject], left: i64
) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    jacpy_deque_append(state.native, value, left);
    return Py_NewRef(Py_None);
}

def:priv deque_take(instance: ptr[PyObject], left: i64) -> ptr[PyObject] {
    state = deque_value(instance);
    return jacpy_deque_pop(state.native, left) if state is not None else NULL;
}

def:priv deque_grow(
    instance: ptr[PyObject], iterable: ptr[PyObject], left: i64
) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(Py_None)
        if jacpy_deque_extend(state.native, instance, iterable, left) == 0
        else NULL;
}

# The Argument Clinic _impl functions.
def deque_pop_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return deque_take(instance, 0);
}

def deque_popleft_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return deque_take(instance, 1);
}

def deque_append_impl(instance: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    return deque_push(instance, item, 0);
}

def deque_appendleft_impl(
    instance: ptr[PyObject], item: ptr[PyObject]
) -> ptr[PyObject] {
    return deque_push(instance, item, 1);
}

def deque_extend_impl(
    instance: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    return deque_grow(instance, iterable, 0);
}

def deque_extendleft_impl(
    instance: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    return deque_grow(instance, iterable, 1);
}

def deque_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    limit = jacpy_deque_limit(state.native);
    args = owned_tuple([Py_NewRef(instance)])
        if limit < 0
        else owned_tuple([Py_NewRef(instance), PyLong_FromLongLong(limit)]);
    if args == 0 {
        return NULL;
    }
    result = PyObject_Call(Py_TYPE(instance), args, NULL);
    jacpy_release(args);
    if result != 0 and jacpy_binding_matches(result, deque_token.handle) == 0 {
        object_error(
            PyExc_TypeError,
            f"{type_name(instance)[:200]}() must return a deque, not {type_name(result)[:200]}"
        );
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def deque___copy___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return deque_copy_impl(instance);
}

def deque_clearmethod_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    clear_payload(instance, deque_token.handle);
    return Py_NewRef(Py_None);
}

def deque_rotate_impl(instance: ptr[PyObject], n: i64) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    jacpy_deque_rotate(state.native, n);
    return Py_NewRef(Py_None);
}

def deque_reverse_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    jacpy_deque_reverse(state.native);
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
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(Py_None)
        if jacpy_deque_insert(state.native, index, value) == 0
        else NULL;
}

def deque_remove_impl(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(Py_None)
        if search(instance, value, 0, 9223372036854775807, 3) >= 0
        else NULL;
}

def deque___reduce___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    limit = jacpy_deque_limit(state.native);
    saved = _PyObject_GetState(instance);
    iterator = PyObject_GetIter(instance);
    args = PyTuple_New(0)
        if limit < 0
        else owned_tuple([PyTuple_New(0), PyLong_FromLongLong(limit)]);
    return owned_tuple([Py_NewRef(Py_TYPE(instance)), args, saved, iterator]);
}

# deque.__init__ returns clinic's int: -1 with the exception set.
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
    state = deque_value(instance);
    if state is None {
        return i32(-1);
    }
    jacpy_deque_set_limit(state.native, limit);
    jacpy_deque_clear(state.native);
    if iterable != 0 and jacpy_deque_extend(state.native, instance, iterable, 0) < 0 {
        return i32(-1);
    }
    return i32(0);
}

def deque___sizeof___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLongLong(
        jacpy_binding_basicsize(instance)
            + jac_heap_size(u64(id(state)))
            + jacpy_deque_memory(state.native)
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
