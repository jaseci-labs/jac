"""Native collection types, iteration, descriptors, and Python ownership."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyCallable_Check,
    PyDict_New,
    PyDict_Update,
    PyLong_AsSsize_t,
    PyLong_FromLongLong,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_GetIter,
    PyTuple_GetSlice,
    PyTuple_New,
    PyTuple_Size,
    Py_GenericAlias,
    Py_NewRef,
    Py_TYPE,
    _PyObject_GetState,
    jacpy_error_pending,
    jacpy_is_dict,
    jacpy_is_none,
    jacpy_is_tuple,
    jacpy_none,
    jacpy_not_implemented,
    jacpy_number_ssize,
    jacpy_ordered_dict_new,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_type_check
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition,
    add_state_owned,
    add_owned,
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    jacpy_binding_visit
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_basicsize,
    jacpy_binding_parent,
    jacpy_binding_matches,
    jacpy_binding_base_new,
    jacpy_binding_base_init,
    jacpy_binding_base_traverse,
    jacpy_binding_base_clear,
    jacpy_binding_base_dealloc
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
    jacpy_binding_native_clear,
    jacpy_binding_untrack,
    traverse_payload,
    clear_payload,
    dispose_payload
}
import from jaclang.runtime.python.bindings.references { ReferenceState, owned_tuple }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke,
    index_value
}
import from jaclang.runtime.python.modules.collections {
    deque_state,
    deque_cursor,
    jacpy_deque_size,
    jacpy_deque_limit,
    jacpy_deque_memory,
    jacpy_deque_set_limit,
    jacpy_deque_clear,
    jacpy_deque_borrow,
    jacpy_deque_pop,
    jacpy_deque_append,
    jacpy_deque_extend,
    jacpy_deque_item,
    jacpy_deque_assign,
    jacpy_deque_insert,
    jacpy_deque_rotate,
    jacpy_deque_reverse,
    jacpy_deque_search,
    jacpy_deque_cursor,
    jacpy_deque_next,
    jacpy_deque_remaining,
    jacpy_deque_consumed,
    jacpy_deque_compare,
    jacpy_deque_repeat,
    jacpy_deque_repr,
    jacpy_default_missing,
    jacpy_count_elements,
    jacpy_default_repr
}
import from jaclang.runtime.python.capi {
    jac_heap_size,
    object_error,
    type_name,
    text_object,
    repr_value,
    boundary_failure
}

obj DequeState(NativeState) {
    has native: deque_state;

    def clear {
        jacpy_deque_clear(self.native);
    }

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for i in range(int(jacpy_deque_size(self.native))) {
            status = jacpy_binding_visit(
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

def:priv module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv deque_value(instance: ptr[PyObject]) -> (DequeState | None) {
    if jacpy_binding_native_present(instance, deque_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, deque_type.handle);
        if isinstance(state, DequeState) {
            return state;
        }
    }
    object_error("SystemError", "native deque state is unavailable");
    return None;
}

def:priv reference_value(
    instance: ptr[PyObject], type: TypeDefinition
) -> (ReferenceState | None) {
    if jacpy_binding_native_present(instance, type.handle) != 0 {
        state = jacpy_binding_native_get(instance, type.handle);
        if isinstance(state, ReferenceState) {
            return state;
        }
    }
    object_error("SystemError", "native collection references are unavailable");
    return None;
}

def:priv allocate(
    type: ptr[PyObject], declaration: TypeDefinition, state: NativeState
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if instance != 0
        and jacpy_binding_native_set(instance, declaration.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def:priv deque_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return allocate(type, deque_type, DequeState(native=deque_state()));
}

glob:priv deque_signature = CallSignature("deque", ["iterable", "maxlen"], 0, 2);
def:priv deque_init_bound(args: BoundArguments) -> ptr[PyObject] {
    limit: i64 = -1;
    if args.values[1] != 0 and jacpy_is_none(args.values[1]) == 0 {
        limit = PyLong_AsSsize_t(args.values[1]);
        if limit == -1 and jacpy_error_pending() != 0 {
            return NULL;
        }
        if limit < 0 {
            object_error("ValueError", "maxlen must be non-negative");
            return NULL;
        }
    }
    state = deque_value(args.context);
    if state is None {
        return NULL;
    }
    jacpy_deque_set_limit(state.native, limit);
    jacpy_deque_clear(state.native);
    if args.values[0] != 0
        and jacpy_deque_extend(state.native, args.context, args.values[0], 0) < 0 {
        return NULL;
    }
    return jacpy_none();
}

def:priv deque_initialize(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result = invoke(deque_signature, args, kwargs, deque_init_bound, instance);
    if result == 0 {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

def:priv deque_length(instance: ptr[PyObject]) -> i64 {
    state = deque_value(instance);
    return jacpy_deque_size(state.native) if state is not None else i64(-1);
}

def:priv deque_item(instance: ptr[PyObject], index: i64) -> ptr[PyObject] {
    state = deque_value(instance);
    return jacpy_deque_item(state.native, index) if state is not None else NULL;
}

def:priv deque_assign(
    instance: ptr[PyObject], index: i64, value: ptr[PyObject]
) -> i32 {
    state = deque_value(instance);
    return i32(jacpy_deque_assign(state.native, index, value))
        if state is not None
        else i32(-1);
}

def:priv append(
    instance: ptr[PyObject], value: ptr[PyObject], left: i64
) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    jacpy_deque_append(state.native, value, left);
    return jacpy_none();
}

def:priv deque_append(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return append(instance, value, 0);
}

def:priv deque_appendleft(
    instance: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    return append(instance, value, 1);
}

def:priv pop(instance: ptr[PyObject], left: i64) -> ptr[PyObject] {
    state = deque_value(instance);
    return jacpy_deque_pop(state.native, left) if state is not None else NULL;
}

def:priv deque_pop(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return pop(instance, 0);
}

def:priv deque_popleft(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return pop(instance, 1);
}

def:priv extend(
    instance: ptr[PyObject], value: ptr[PyObject], left: i64
) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    return jacpy_none()
        if jacpy_deque_extend(state.native, instance, value, left) == 0
        else NULL;
}

def:priv deque_extend(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return extend(instance, value, 0);
}

def:priv deque_extendleft(
    instance: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    return extend(instance, value, 1);
}

def:priv deque_clear_method(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    clear_payload(instance, deque_type.handle);
    return jacpy_none();
}

def:priv deque_reverse(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    jacpy_deque_reverse(state.native);
    return jacpy_none();
}

glob:priv rotate_signature = CallSignature("rotate", ["n"], 0, 1, 1),
     insert_signature = CallSignature("insert", ["index", "value"], 2, 2, 2),
     index_signature = CallSignature("index", ["value", "start", "stop"], 1, 3, 3);

def:priv rotate_bound(args: BoundArguments) -> ptr[PyObject] {
    amount: i64 = 1;
    if args.values[0] != 0 {
        value = index_value(args.values[0]);
        if value is None {
            return NULL;
        }
        amount = value;
    }
    state = deque_value(args.context);
    if state is None {
        return NULL;
    }
    jacpy_deque_rotate(state.native, amount);
    return jacpy_none();
}

def:priv deque_rotate(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(rotate_signature, args, NULL, rotate_bound, instance);
}

def:priv insert_bound(args: BoundArguments) -> ptr[PyObject] {
    index = index_value(args.values[0]);
    if index is None {
        return NULL;
    }
    state = deque_value(args.context);
    if state is None {
        return NULL;
    }
    return jacpy_none()
        if jacpy_deque_insert(state.native, index, args.values[1]) == 0
        else NULL;
}

def:priv deque_insert(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(insert_signature, args, NULL, insert_bound, instance);
}

def:priv search(
    instance: ptr[PyObject], value: ptr[PyObject], first: i64, last: i64, kind: i64
) -> i64 {
    state = deque_value(instance);
    return jacpy_deque_search(state.native, value, first, last, kind)
        if state is not None
        else i64(-1);
}

def:priv deque_count(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    count = search(instance, value, 0, 9223372036854775807, 0);
    return PyLong_FromLongLong(count) if count >= 0 else NULL;
}

def:priv deque_contains(instance: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    return i32(search(instance, value, 0, 9223372036854775807, 1));
}

def:priv deque_remove(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_none()
        if search(instance, value, 0, 9223372036854775807, 3) >= 0
        else NULL;
}

def:priv index_bound(args: BoundArguments) -> ptr[PyObject] {
    first: i64 = 0;
    last: i64 = 9223372036854775807;
    if args.values[1] != 0 {
        first = jacpy_number_ssize(args.values[1], "");
        if jacpy_error_pending() != 0 {
            return NULL;
        }
    }
    if args.values[2] != 0 {
        last = jacpy_number_ssize(args.values[2], "");
        if jacpy_error_pending() != 0 {
            return NULL;
        }
    }
    found = search(args.context, args.values[0], first, last, 2);
    return PyLong_FromLongLong(found) if found >= 0 else NULL;
}

def:priv deque_index(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(index_signature, args, NULL, index_bound, instance);
}

def:priv deque_maxlen(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    limit = jacpy_deque_limit(state.native);
    return jacpy_none() if limit < 0 else PyLong_FromLongLong(limit);
}

def:priv deque_sizeof(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
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

def:priv deque_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = deque_value(instance);
    return jacpy_deque_repr(state.native, instance) if state is not None else NULL;
}

def:priv deque_compare(
    instance: ptr[PyObject], other: ptr[PyObject], operation: i32
) -> ptr[PyObject] {
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    if jacpy_type_check(other, jacpy_binding_state_get(module, 0)) == 0 {
        return jacpy_not_implemented();
    }
    left = deque_value(instance);
    right = deque_value(other);
    if left is None or right is None {
        return NULL;
    }
    return jacpy_deque_compare(
        left.native, right.native, instance, other, i64(operation)
    );
}

def:priv deque_copy(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
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
    if result != 0 and jacpy_binding_matches(result, deque_type.handle) == 0 {
        object_error(
            "TypeError",
            f"{type_name(instance)[:200]}() must return a deque, not {type_name(result)[:200]}"
        );
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:priv deque_concat(instance: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_binding_matches(other, deque_type.handle) == 0 {
        object_error(
            "TypeError",
            f"can only concatenate deque (not \"{type_name(other)[:200]}\") to deque"
        );
        return NULL;
    }
    result = deque_copy(instance, NULL);
    if result == 0 {
        return NULL;
    }
    state = deque_value(result);
    if state is None or jacpy_deque_extend(state.native, result, other, 0) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:priv deque_iconcat(instance: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(instance)
        if jacpy_deque_extend(state.native, instance, other, 0) == 0
        else NULL;
}

def:priv deque_irepeat(instance: ptr[PyObject], count: i64) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(instance)
        if jacpy_deque_repeat(state.native, count) == 0
        else NULL;
}

def:priv deque_repeat(instance: ptr[PyObject], count: i64) -> ptr[PyObject] {
    result = deque_copy(instance, NULL);
    if result == 0 {
        return NULL;
    }
    state = deque_value(result);
    if state is None or jacpy_deque_repeat(state.native, count) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:priv iterator_type_for(instance: ptr[PyObject]) -> TypeDefinition {
    return reverse_type
        if jacpy_binding_matches(instance, reverse_type.handle) != 0
        else forward_type;
}

def:priv iterator_value(instance: ptr[PyObject]) -> (DequeIteratorState | None) {
    state = reference_value(instance, iterator_type_for(instance));
    if isinstance(state, DequeIteratorState) {
        return state;
    }
    return None;
}

def:priv iterator_create(
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
    return allocate(type, reverse_type if reverse else forward_type, state);
}

def:priv deque_iter(instance: ptr[PyObject]) -> ptr[PyObject] {
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    return iterator_create(jacpy_binding_state_get(module, 1), instance, False, 0);
}

def:priv deque_reversed(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    return iterator_create(jacpy_binding_state_get(module, 2), instance, True, 0);
}

def:priv iterator_self(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def:priv iterator_next(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = iterator_value(instance);
    if state is None {
        return NULL;
    }
    cursor = state.cursor;
    return jacpy_deque_next(cursor) if cursor is not None else NULL;
}

def:priv iterator_hint(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = iterator_value(instance);
    if state is None {
        return NULL;
    }
    cursor = state.cursor;
    return PyLong_FromLongLong(
        jacpy_deque_remaining(cursor) if cursor is not None else i64(0)
    );
}

glob:priv iterator_signature = CallSignature(
         "deque iterator", ["deque", "index"], 1, 2, 2
     );

def:priv iterator_create_bound(args: BoundArguments) -> ptr[PyObject] {
    module = module_for(args.context);
    if module == 0 {
        return NULL;
    }
    if jacpy_type_check(args.values[0], jacpy_binding_state_get(module, 0)) == 0 {
        object_error("TypeError", "argument must be a deque");
        return NULL;
    }
    advance: i64 = 0;
    if args.values[1] != 0 {
        value = index_value(args.values[1]);
        if value is None {
            return NULL;
        }
        advance = value;
    }
    return iterator_create(
        args.context,
        args.values[0],
        args.context == jacpy_binding_state_get(module, 2),
        advance
    );
}

def:priv iterator_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(iterator_signature, args, kwargs, iterator_create_bound, type);
}

def:priv iterator_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = iterator_value(instance);
    if state is None {
        return NULL;
    }
    cursor = state.cursor;
    if cursor is None {
        object_error("RuntimeError", "cleared deque iterator");
        return NULL;
    }
    args = owned_tuple(
        [
            Py_NewRef(state.references[0]),
            PyLong_FromLongLong(jacpy_deque_consumed(cursor))
        ]
    );
    return owned_tuple([Py_NewRef(Py_TYPE(instance)), args]);
}

def:priv deque_reduce(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
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

def:priv dictionary_base(instance: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_parent(Py_TYPE(instance), default_type.handle);
}

def:priv default_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_for(type);
    if module == 0 {
        return NULL;
    }
    instance = jacpy_binding_base_new(
        jacpy_binding_state_get(module, 5), type, args, kwargs
    );
    if instance == 0 {
        return NULL;
    }
    state = ReferenceState(references=[NULL]);
    if jacpy_binding_native_set(instance, default_type.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def:priv default_initialize(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    count = PyTuple_Size(args);
    factory = jacpy_tuple_item(args, 0) if count > 0 else NULL;
    if count > 0 and factory == 0 {
        return i32(-1);
    }
    if factory != 0
        and jacpy_is_none(factory) == 0
        and PyCallable_Check(factory) == 0 {
        jacpy_release(factory);
        object_error("TypeError", "first argument must be callable or None");
        return i32(-1);
    }
    state = reference_value(instance, default_type);
    if state is None {
        jacpy_release(factory);
        return i32(-1);
    }
    old = state.references[0];
    state.references[0] = factory;
    jacpy_release(old);
    rest = PyTuple_GetSlice(args, 1 if count > 0 else 0, count);
    if rest == 0 {
        return i32(-1);
    }
    base = dictionary_base(instance);
    status = jacpy_binding_base_init(base, instance, rest, kwargs)
        if base != 0
        else i32(-1);
    jacpy_release(rest);
    return status;
}

def:priv default_factory(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = reference_value(instance, default_type);
    if state is None {
        return NULL;
    }
    value = state.references[0];
    return Py_NewRef(value) if value != 0 else jacpy_none();
}

def:priv default_set_factory(
    instance: ptr[PyObject], value: ptr[PyObject], unused: u64
) -> i32 {
    state = reference_value(instance, default_type);
    if state is None {
        return i32(-1);
    }
    old = state.references[0];
    state.references[0] = Py_NewRef(value) if value != 0 else NULL;
    jacpy_release(old);
    return i32(0);
}

def:priv default_missing(instance: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    factory = default_factory(instance, 0);
    if factory == 0 {
        return NULL;
    }
    result = jacpy_default_missing(instance, factory, key);
    jacpy_release(factory);
    return result;
}

def:priv default_construct(
    instance: ptr[PyObject], mapping: ptr[PyObject]
) -> ptr[PyObject] {
    args = owned_tuple([default_factory(instance, 0), Py_NewRef(mapping)]);
    if args == 0 {
        return NULL;
    }
    result = PyObject_Call(Py_TYPE(instance), args, NULL);
    jacpy_release(args);
    return result;
}

def:priv default_copy(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return default_construct(instance, instance);
}

def:priv default_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    factory = default_factory(instance, 0);
    if factory == 0 {
        return NULL;
    }
    result = jacpy_default_repr(instance, factory);
    jacpy_release(factory);
    return result;
}

def:priv default_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    factory = default_factory(instance, 0);
    if factory == 0 {
        return NULL;
    }
    args = PyTuple_New(0)
        if jacpy_is_none(factory) != 0
        else owned_tuple([Py_NewRef(factory)]);
    jacpy_release(factory);
    if args == 0 {
        return NULL;
    }
    held = ReferenceState(
        references=[args, PyObject_GetAttrString(instance, "items"), NULL]
    );
    if held.references[1] == 0 {
        return NULL;
    }
    empty = PyTuple_New(0);
    if empty == 0 {
        return NULL;
    }
    held.references[2] = PyObject_Call(held.references[1], empty, NULL);
    jacpy_release(empty);
    if held.references[2] == 0 {
        return NULL;
    }
    return owned_tuple(
        [
            Py_NewRef(Py_TYPE(instance)),
            Py_NewRef(args),
            jacpy_none(),
            jacpy_none(),
            PyObject_GetIter(held.references[2])
        ]
    );
}

def:priv default_or(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_dict(left) == 0 or jacpy_is_dict(right) == 0 {
        return jacpy_not_implemented();
    }
    owner = left if jacpy_binding_matches(left, default_type.handle) != 0 else right;
    result = default_construct(owner, left);
    if result == 0 {
        return NULL;
    }
    if PyDict_Update(result, right) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:priv default_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    status = traverse_payload(instance, default_type.handle, visitor, context);
    if status != 0 {
        return status;
    }
    base = dictionary_base(instance);
    return jacpy_binding_base_traverse(base, instance, visitor, context)
        if base != 0
        else i32(-1);
}

def:priv default_clear(instance: ptr[PyObject]) -> i32 {
    clear_payload(instance, default_type.handle);
    base = dictionary_base(instance);
    return jacpy_binding_base_clear(base, instance) if base != 0 else i32(-1);
}

def:priv default_dealloc(instance: ptr[PyObject]) {
    base = dictionary_base(instance);
    type = Py_TYPE(instance);
    jacpy_binding_untrack(instance);
    clear_payload(instance, default_type.handle);
    jacpy_binding_native_clear(instance, default_type.handle);
    jacpy_binding_base_dealloc(base, instance);
    jacpy_release(type);
}

glob:priv getter_signature = CallSignature(
         "_tuplegetter", ["index", "doc"], 2, 2, 2
     );

def:priv getter_create_bound(args: BoundArguments) -> ptr[PyObject] {
    index = index_value(args.values[0]);
    if index is None {
        return NULL;
    }
    state = TupleGetterState(references=[Py_NewRef(args.values[1])], index=index);
    return allocate(args.context, getter_type, state);
}

def:priv getter_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(getter_signature, args, kwargs, getter_create_bound, type);
}

def:priv getter_get(
    instance: ptr[PyObject], object: ptr[PyObject], owner: ptr[PyObject]
) -> ptr[PyObject] {
    if object == 0 {
        return Py_NewRef(instance);
    }
    state = reference_value(instance, getter_type);
    if not isinstance(state, TupleGetterState) {
        return NULL;
    }
    if jacpy_is_tuple(object) == 0 {
        object_error(
            "TypeError",
            f"descriptor for index '{state.index}' for tuple subclasses doesn't apply to '{type_name(
                object
            )}' object"
        );
        return NULL;
    }
    return jacpy_tuple_item(object, state.index);
}

def:priv getter_set(
    instance: ptr[PyObject], object: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    object_error(
        "AttributeError",
        "can't set attribute" if value != 0 else "can't delete attribute"
    );
    return i32(-1);
}

def:priv getter_doc(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = reference_value(instance, getter_type);
    if state is None {
        return NULL;
    }
    value = state.references[0];
    return Py_NewRef(value) if value != 0 else jacpy_none();
}

def:priv getter_set_doc(
    instance: ptr[PyObject], value: ptr[PyObject], unused: u64
) -> i32 {
    state = reference_value(instance, getter_type);
    if state is None {
        return i32(-1);
    }
    previous = state.references[0];
    state.references[0] = Py_NewRef(value) if value != 0 else NULL;
    jacpy_release(previous);
    return i32(0);
}

def:priv getter_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = reference_value(instance, getter_type);
    if not isinstance(state, TupleGetterState) {
        return NULL;
    }
    doc = getter_doc(instance, 0);
    if doc == 0 {
        return NULL;
    }
    try {
        return text_object(
            f"{type_name(instance).split(".")[-1]}({state.index}, {repr_value(doc)})"
        );
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(doc);
    }
}

def:priv getter_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = reference_value(instance, getter_type);
    if not isinstance(state, TupleGetterState) {
        return NULL;
    }
    args = owned_tuple([PyLong_FromLongLong(state.index), getter_doc(instance, 0)]);
    return owned_tuple([Py_NewRef(Py_TYPE(instance)), args]);
}

glob:priv count_signature = CallSignature(
         "_count_elements", ["mapping", "iterable"], 2, 2, 2
     );

def:priv count_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_none()
        if jacpy_count_elements(args.values[0], args.values[1]) == 0
        else NULL;
}

def:priv count_elements(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(count_signature, args, NULL, count_bound);
}

def:priv deque_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, deque_type.handle, visitor, context);
}

def:priv deque_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, deque_type.handle);
}

def:priv deque_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, deque_type.handle);
}

def:priv getter_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, getter_type.handle, visitor, context);
}

def:priv getter_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, getter_type.handle);
}

def:priv getter_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, getter_type.handle);
}

def:priv iterator_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(
        instance, iterator_type_for(instance).handle, visitor, context
    );
}

def:priv iterator_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, iterator_type_for(instance).handle);
}

def:priv iterator_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, iterator_type_for(instance).handle);
}

glob:priv flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     iterator_methods = [
         MethodDefinition(
             "__length_hint__",
             MethodCallbacks(positional=iterator_hint),
             "Private method returning an estimate of len(list(it)).",
             flags=4
         ),
         MethodDefinition(
             "__reduce__",
             MethodCallbacks(positional=iterator_reduce),
             "Return state information for pickling.",
             flags=4
         )
     ],
     iterator_hooks = TypeHooks(
         create=iterator_new,
         dealloc=iterator_dealloc,
         traverse=iterator_traverse,
         clear=iterator_clear,
         iter=iterator_self,
         next=iterator_next
     ),
     forward_type = TypeDefinition(
         "_collections._deque_iterator", "", iterator_methods, flags, iterator_hooks
     ),
     reverse_type = TypeDefinition(
         "_collections._deque_reverse_iterator",
         "",
         iterator_methods,
         flags,
         iterator_hooks
     ),
     deque_type = TypeDefinition(
         "collections.deque",
         "A list-like sequence optimized for data accesses near its endpoints.",
         [
             MethodDefinition(
                 "append",
                 MethodCallbacks(positional=deque_append),
                 "Add an element to the right side of the deque.",
                 flags=8
             ),
             MethodDefinition(
                 "appendleft",
                 MethodCallbacks(positional=deque_appendleft),
                 "Add an element to the left side of the deque.",
                 flags=8
             ),
             MethodDefinition(
                 "pop",
                 MethodCallbacks(positional=deque_pop),
                 "Remove and return the rightmost element.",
                 flags=4
             ),
             MethodDefinition(
                 "popleft",
                 MethodCallbacks(positional=deque_popleft),
                 "Remove and return the leftmost element.",
                 flags=4
             ),
             MethodDefinition(
                 "extend",
                 MethodCallbacks(positional=deque_extend),
                 "Extend the right side of the deque with elements from the iterable.",
                 flags=8
             ),
             MethodDefinition(
                 "extendleft",
                 MethodCallbacks(positional=deque_extendleft),
                 "Extend the left side of the deque with elements from the iterable.",
                 flags=8
             ),
             MethodDefinition(
                 "clear",
                 MethodCallbacks(positional=deque_clear_method),
                 "Remove all elements from the deque.",
                 flags=4
             ),
             MethodDefinition(
                 "reverse",
                 MethodCallbacks(positional=deque_reverse),
                 "Reverse *IN PLACE*.",
                 flags=4
             ),
             MethodDefinition(
                 "rotate",
                 MethodCallbacks(positional=deque_rotate),
                 "Rotate the deque n steps to the right. If n is negative, rotates left.",
                 flags=1
             ),
             MethodDefinition(
                 "insert",
                 MethodCallbacks(positional=deque_insert),
                 "Insert value before index.",
                 flags=1
             ),
             MethodDefinition(
                 "count",
                 MethodCallbacks(positional=deque_count),
                 "Return number of occurrences of value.",
                 flags=8
             ),
             MethodDefinition(
                 "index",
                 MethodCallbacks(positional=deque_index),
                 "Return first index of value.",
                 flags=1
             ),
             MethodDefinition(
                 "remove",
                 MethodCallbacks(positional=deque_remove),
                 "Remove first occurrence of value.",
                 flags=8
             ),
             MethodDefinition(
                 "copy",
                 MethodCallbacks(positional=deque_copy),
                 "Return a shallow copy of a deque.",
                 flags=4
             ),
             MethodDefinition(
                 "__copy__",
                 MethodCallbacks(positional=deque_copy),
                 "Return a shallow copy of a deque.",
                 flags=4
             ),
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=deque_reduce),
                 "Return state information for pickling.",
                 flags=4
             ),
             MethodDefinition(
                 "__reversed__",
                 MethodCallbacks(positional=deque_reversed),
                 "Return a reverse iterator over the deque.",
                 flags=4
             ),
             MethodDefinition(
                 "__sizeof__",
                 MethodCallbacks(positional=deque_sizeof),
                 "Return the size of the deque in memory, in bytes.",
                 flags=4
             ),
             MethodDefinition(
                 "__class_getitem__",
                 MethodCallbacks(positional=Py_GenericAlias),
                 "deques are generic over the type of their contents",
                 flags=24
             )
         ],
         flags
             | u64(
                 TypeFlags.BASETYPE.value
                     | TypeFlags.SEQUENCE.value
                     | TypeFlags.MANAGED_WEAKREF.value
             ),
         TypeHooks(
             create=deque_create,
             initialize=deque_initialize,
             dealloc=deque_dealloc,
             traverse=deque_traverse,
             clear=deque_clear,
             iter=deque_iter,
             repr=deque_repr,
             compare=deque_compare,
             length=deque_length,
             item=deque_item,
             assign=deque_assign,
             contains=deque_contains,
             concat=deque_concat,
             inplace_concat=deque_iconcat,
             repeat=deque_repeat,
             inplace_repeat=deque_irepeat
         ),
         [PropertyDefinition("maxlen", PropertyCallbacks(read=deque_maxlen))],
         unhashable=True
     ),
     default_type = TypeDefinition(
         "collections.defaultdict",
         "defaultdict(default_factory=None, /, [...]) --> dict with default factory\n\nThe default factory is called without arguments to produce\na new value when a key is not present, in __getitem__ only.\nA defaultdict compares equal to a dict with the same items.\nAll remaining arguments are treated the same as if they were\npassed to the dict constructor, including keyword arguments.\n",
         [
             MethodDefinition(
                 "__missing__",
                 MethodCallbacks(positional=default_missing),
                 "Called by __getitem__ for missing keys.",
                 flags=8
             ),
             MethodDefinition(
                 "copy",
                 MethodCallbacks(positional=default_copy),
                 "D.copy() -> a shallow copy of D.",
                 flags=4
             ),
             MethodDefinition(
                 "__copy__",
                 MethodCallbacks(positional=default_copy),
                 "D.copy() -> a shallow copy of D.",
                 flags=4
             ),
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=default_reduce),
                 "Return state information for pickling.",
                 flags=4
             ),
             MethodDefinition(
                 "__class_getitem__",
                 MethodCallbacks(positional=Py_GenericAlias),
                 "defaultdicts are generic over keys and values",
                 flags=24
             )
         ],
         flags | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=default_create,
             initialize=default_initialize,
             traverse=default_traverse,
             clear=default_clear,
             dealloc=default_dealloc,
             repr=default_repr,
             bit_or=default_or
         ),
         [
             PropertyDefinition(
                 "default_factory",
                 PropertyCallbacks(read=default_factory, write=default_set_factory)
             )
         ]
     ),
     getter_type = TypeDefinition(
         "collections._tuplegetter",
         "",
         [
             MethodDefinition(
                 "__reduce__", MethodCallbacks(positional=getter_reduce), "", flags=4
             )
         ],
         flags,
         TypeHooks(
             create=getter_create,
             descriptor=getter_get,
             descriptor_set=getter_set,
             traverse=getter_traverse,
             clear=getter_clear,
             dealloc=getter_dealloc,
             repr=getter_repr
         ),
         [
             PropertyDefinition(
                 "__doc__", PropertyCallbacks(read=getter_doc, write=getter_set_doc)
             )
         ]
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    if not add_state_owned(module, 0, "deque", deque_type.create(module))
        or not add_state_owned(
            module, 1, "_deque_iterator", forward_type.create(module)
        )
        or not add_state_owned(
            module, 2, "_deque_reverse_iterator", reverse_type.create(module)
        )
        or not add_state_owned(module, 4, "_tuplegetter", getter_type.create(module)) {
        return i32(-1);
    }
    dictionary = PyDict_New();
    if dictionary == 0 {
        return i32(-1);
    }
    base = Py_TYPE(dictionary);
    jacpy_binding_state_set(module, 5, base);
    bases = owned_tuple([Py_NewRef(base)]);
    jacpy_release(dictionary);
    if bases == 0 {
        return i32(-1);
    }
    defaults = default_type.create(module, bases);
    jacpy_release(bases);
    if not add_state_owned(module, 3, "defaultdict", defaults) {
        return i32(-1);
    }
    ordered = jacpy_ordered_dict_new();
    if ordered == 0 {
        return i32(-1);
    }
    ordered_type = Py_NewRef(Py_TYPE(ordered));
    jacpy_release(ordered);
    return i32(0) if add_owned(module, "OrderedDict", ordered_type) else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "_collections",
         "Native Jac collections.",
         [
             MethodDefinition(
                 "_count_elements",
                 MethodCallbacks(positional=count_elements),
                 "",
                 flags=1
             )
         ],
         hooks=ModuleHooks(execute=execute),
         state_count=6
     );

def:pub PyInit__collections -> ptr[PyObject] {
    return definition.initialize();
}
