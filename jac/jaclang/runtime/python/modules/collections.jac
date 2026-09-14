"""Native deque and mapping policies for Python's collections module.

Python object lifetimes and callbacks remain explicit at the boundary. Storage
and all collection algorithms execute in Jac. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.modules.object_ring { object_ring }
import from jaclang.runtime.python.capi {
    jacpy_retain,
    jacpy_release,
    jacpy_error_pending,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_sequence_list,
    jacpy_compare_bool,
    jacpy_int,
    jacpy_boolean,
    jacpy_getattr,
    jacpy_call,
    jacpy_tuple_new,
    jacpy_tuple_set_owned,
    jacpy_setitem,
    jacpy_add,
    jacpy_dict_repr,
    jacpy_dict_default,
    jacpy_is_none,
    jacpy_set_key_error,
    jacpy_repr_enter,
    jacpy_repr_leave,
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

    def push(value: u64, left: bool, limit: i64) {
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

def:pub jacpy_deque_borrow(state: deque_state, index: i64) -> u64 {
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

def:pub jacpy_deque_append(state: deque_state, value: u64, left: i64) {
    state.push(jacpy_retain(value), left != 0, state.maxlen);
}

def:pub jacpy_deque_pop(state: deque_state, left: i64) -> u64 {
    if state.items.count == 0 {
        object_error("IndexError", "pop from an empty deque");
        return 0;
    }
    result = state.items.pop(left != 0);
    state.changed();
    return result;
}

def:pub jacpy_deque_extend(
    state: deque_state, owner: u64, iterable: u64, left: i64
) -> i64 {
    source: u64 = 0;
    iterator: u64 = 0;
    limit = state.maxlen;
    try {
        source = required(
            jacpy_sequence_list(owner) if owner == iterable else jacpy_retain(iterable)
        );
        iterator = required(jacpy_iter(source));
        while True {
            item = jacpy_iter_next(iterator);
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

def:pub jacpy_deque_item(state: deque_state, index: i64) -> u64 {
    if index < 0 or index >= i64(state.items.count) {
        object_error("IndexError", "deque index out of range");
        return 0;
    }
    return jacpy_retain(state.items.borrow(int(index)));
}

def:pub jacpy_deque_assign(state: deque_state, index: i64, value: u64) -> i64 {
    if index < 0 or index >= i64(state.items.count) {
        object_error("IndexError", "deque index out of range");
        return -1;
    }
    i = int(index);
    if value != 0 {
        previous = state.items.exchange(i, jacpy_retain(value));
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

def:pub jacpy_deque_insert(state: deque_state, index: i64, value: u64) -> i64 {
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
    state.items.push(jacpy_retain(value));
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
    state: deque_state, value: u64, start: i64, stop: i64, mode: i64
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
        item = jacpy_retain(state.items.borrow(i));
        equal = jacpy_compare_bool(item, value, 2);
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
                return jacpy_deque_assign(state, i64(i), 0);
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

def:pub jacpy_deque_next(cursor: deque_cursor) -> u64 {
    if cursor.version != cursor.state.version {
        cursor.remaining = 0;
        object_error("RuntimeError", "deque mutated during iteration");
        return 0;
    }
    if cursor.remaining == 0 {
        return 0;
    }
    result = jacpy_retain(cursor.state.items.borrow(cursor.index));
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
    first: deque_state, second: deque_state, a_owner: u64, b_owner: u64, operation: i64
) -> u64 {
    if operation == 2 or operation == 3 {
        if a_owner == b_owner {
            return jacpy_boolean(1 if operation == 2 else 0);
        }
        if first.items.count != second.items.count {
            return jacpy_boolean(1 if operation == 3 else 0);
        }
    }
    left: u64 = 0;
    right: u64 = 0;
    try {
        left = required(jacpy_iter(a_owner));
        right = required(jacpy_iter(b_owner));
        while True {
            a = jacpy_iter_next(left);
            if a == 0 and jacpy_error_pending() != 0 {
                return 0;
            }
            b = jacpy_iter_next(right);
            if jacpy_error_pending() != 0 {
                jacpy_release(a);
                jacpy_release(b);
                return 0;
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
                return jacpy_boolean(1 if result else 0);
            }
            equal = jacpy_compare_bool(a, b, 2);
            if equal == 0 {
                equal = jacpy_compare_bool(a, b, operation);
                jacpy_release(a);
                jacpy_release(b);
                return u64(0) if equal < 0 else jacpy_boolean(equal);
            }
            jacpy_release(a);
            jacpy_release(b);
            if equal < 0 {
                return 0;
            }
        }
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(left);
        jacpy_release(right);
    }
    return 0;
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
            jacpy_retain(state.items.borrow(int((start + i64(i)) % i64(size))))
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

def:pub jacpy_deque_repr(state: deque_state, owner: u64) -> u64 {
    entered = jacpy_repr_enter(owner);
    if entered < 0 {
        return 0;
    }
    if entered > 0 {
        return text_object("[...]");
    }
    values: u64 = 0;
    try {
        values = required(jacpy_sequence_list(owner));
        limit = state.maxlen;
        suffix = ", maxlen=" + str(limit) if limit >= 0 else "";
        return text_object(
            type_name(owner).split(".")[-1] + "(" + repr_value(values) + suffix + ")"
        );
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(values);
        jacpy_repr_leave(owner);
    }
}

def:pub jacpy_default_missing(mapping: u64, factory: u64, key: u64) -> u64 {
    if factory == 0 or jacpy_is_none(factory) != 0 {
        jacpy_set_key_error(key);
        return 0;
    }
    args = jacpy_tuple_new(0);
    if args == 0 {
        return 0;
    }
    value = jacpy_call(factory, args, 0);
    jacpy_release(args);
    if value == 0 {
        return 0;
    }
    result = jacpy_dict_default(mapping, key, value);
    jacpy_release(value);
    return result;
}

def:pub jacpy_count_elements(mapping: u64, iterable: u64) -> i64 {
    iterator: u64 = 0;
    get_method: u64 = 0;
    name: u64 = 0;
    one: u64 = 0;
    zero: u64 = 0;
    try {
        iterator = required(jacpy_iter(iterable));
        name = text_object("get");
        get_method = required(jacpy_getattr(mapping, name));
        one = required(jacpy_int(1));
        zero = required(jacpy_int(0));
        while True {
            key = jacpy_iter_next(iterator);
            if key == 0 {
                break;
            }
            args: u64 = 0;
            value: u64 = 0;
            increment: u64 = 0;
            try {
                args = required(jacpy_tuple_new(2));
                jacpy_tuple_set_owned(args, 0, jacpy_retain(key));
                jacpy_tuple_set_owned(args, 1, jacpy_retain(zero));
                value = required(jacpy_call(get_method, args, 0));
                increment = required(jacpy_add(value, one));
                checked(jacpy_setitem(mapping, key, increment));
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

def:pub jacpy_default_repr(mapping: u64, factory: u64) -> u64 {
    base: u64 = 0;
    try {
        base = required(jacpy_dict_repr(mapping));
        factory_repr = "None";
        if factory != 0 {
            entered = jacpy_repr_enter(factory);
            if entered < 0 {
                return 0;
            }
            if entered > 0 {
                factory_repr = "...";
            } else {
                try {
                    factory_repr = repr_value(factory);
                } finally {
                    jacpy_repr_leave(factory);
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
        return 0;
    } finally {
        jacpy_release(base);
    }
}
