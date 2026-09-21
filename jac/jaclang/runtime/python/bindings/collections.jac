"""Native collection types, iteration, descriptors, and Python ownership."""
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
    jacpy_binding_typeof,
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_generic_alias,
    jacpy_binding_basicsize,
    jacpy_binding_parent,
    jacpy_binding_matches,
    jacpy_binding_base_new,
    jacpy_binding_base_init,
    jacpy_binding_base_traverse,
    jacpy_binding_base_clear,
    jacpy_binding_base_dealloc,
    jacpy_binding_object_state
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
    index_value,
    jacpy_ssize
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
    jacpy_retain,
    jacpy_release,
    jacpy_none,
    jacpy_is_none,
    jacpy_not_implemented,
    jacpy_tuple_new,
    jacpy_tuple_item,
    jacpy_tuple_size,
    jacpy_tuple_slice,
    jacpy_tuple_set_owned,
    jacpy_int,
    jacpy_error_pending,
    jacpy_type_check,
    jacpy_call,
    jacpy_call_one,
    jacpy_dict_new,
    jacpy_dict_update,
    jacpy_ordered_dict_new,
    jacpy_is_dict,
    jacpy_is_tuple,
    jacpy_callable,
    jacpy_iter,
    jacpy_getattr_string,
    object_error,
    type_name,
    text_object,
    repr_value,
    boundary_failure
}
import from c { def jacpy_number_ssize(value: u64, exception: str) -> i64;  }

obj DequeState(NativeState) {
    has native: deque_state;

    def clear {
        jacpy_deque_clear(self.native);
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
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

def:priv module_for(type: u64) -> u64 {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv deque_value(instance: u64) -> (DequeState | None) {
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
    instance: u64, type: TypeDefinition
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

def:priv allocate(type: u64, declaration: TypeDefinition, state: NativeState) -> u64 {
    instance = jacpy_binding_allocate(type);
    if instance != 0
        and jacpy_binding_native_set(instance, declaration.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv deque_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return allocate(type, deque_type, DequeState(native=deque_state()));
}

glob:priv deque_signature = CallSignature("deque", ["iterable", "maxlen"], 0, 2);
def:priv deque_init_bound(args: BoundArguments) -> u64 {
    limit: i64 = -1;
    if args.values[1] != 0 and jacpy_is_none(args.values[1]) == 0 {
        limit = jacpy_ssize(args.values[1]);
        if limit == -1 and jacpy_error_pending() != 0 {
            return 0;
        }
        if limit < 0 {
            object_error("ValueError", "maxlen must be non-negative");
            return 0;
        }
    }
    state = deque_value(args.context);
    if state is None {
        return 0;
    }
    jacpy_deque_set_limit(state.native, limit);
    jacpy_deque_clear(state.native);
    if args.values[0] != 0
        and jacpy_deque_extend(state.native, args.context, args.values[0], 0) < 0 {
        return 0;
    }
    return jacpy_none();
}

def:priv deque_initialize(instance: u64, args: u64, kwargs: u64) -> i32 {
    result = invoke(deque_signature, args, kwargs, deque_init_bound, instance);
    if result == 0 {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

def:priv deque_length(instance: u64) -> i64 {
    state = deque_value(instance);
    return jacpy_deque_size(state.native) if state is not None else i64(-1);
}

def:priv deque_item(instance: u64, index: i64) -> u64 {
    state = deque_value(instance);
    return jacpy_deque_item(state.native, index) if state is not None else u64(0);
}

def:priv deque_assign(instance: u64, index: i64, value: u64) -> i32 {
    state = deque_value(instance);
    return i32(jacpy_deque_assign(state.native, index, value))
        if state is not None
        else i32(-1);
}

def:priv append(instance: u64, value: u64, left: i64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    jacpy_deque_append(state.native, value, left);
    return jacpy_none();
}

def:priv deque_append(instance: u64, value: u64) -> u64 {
    return append(instance, value, 0);
}

def:priv deque_appendleft(instance: u64, value: u64) -> u64 {
    return append(instance, value, 1);
}

def:priv pop(instance: u64, left: i64) -> u64 {
    state = deque_value(instance);
    return jacpy_deque_pop(state.native, left) if state is not None else u64(0);
}

def:priv deque_pop(instance: u64, unused: u64) -> u64 {
    return pop(instance, 0);
}

def:priv deque_popleft(instance: u64, unused: u64) -> u64 {
    return pop(instance, 1);
}

def:priv extend(instance: u64, value: u64, left: i64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    return jacpy_none()
        if jacpy_deque_extend(state.native, instance, value, left) == 0
        else u64(0);
}

def:priv deque_extend(instance: u64, value: u64) -> u64 {
    return extend(instance, value, 0);
}

def:priv deque_extendleft(instance: u64, value: u64) -> u64 {
    return extend(instance, value, 1);
}

def:priv deque_clear_method(instance: u64, unused: u64) -> u64 {
    clear_payload(instance, deque_type.handle);
    return jacpy_none();
}

def:priv deque_reverse(instance: u64, unused: u64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    jacpy_deque_reverse(state.native);
    return jacpy_none();
}

glob:priv rotate_signature = CallSignature("rotate", ["n"], 0, 1, 1),
     insert_signature = CallSignature("insert", ["index", "value"], 2, 2, 2),
     index_signature = CallSignature("index", ["value", "start", "stop"], 1, 3, 3);

def:priv rotate_bound(args: BoundArguments) -> u64 {
    amount: i64 = 1;
    if args.values[0] != 0 {
        value = index_value(args.values[0]);
        if value is None {
            return 0;
        }
        amount = value;
    }
    state = deque_value(args.context);
    if state is None {
        return 0;
    }
    jacpy_deque_rotate(state.native, amount);
    return jacpy_none();
}

def:priv deque_rotate(instance: u64, args: u64) -> u64 {
    return invoke(rotate_signature, args, 0, rotate_bound, instance);
}

def:priv insert_bound(args: BoundArguments) -> u64 {
    index = index_value(args.values[0]);
    if index is None {
        return 0;
    }
    state = deque_value(args.context);
    if state is None {
        return 0;
    }
    return jacpy_none()
        if jacpy_deque_insert(state.native, index, args.values[1]) == 0
        else u64(0);
}

def:priv deque_insert(instance: u64, args: u64) -> u64 {
    return invoke(insert_signature, args, 0, insert_bound, instance);
}

def:priv search(instance: u64, value: u64, first: i64, last: i64, kind: i64) -> i64 {
    state = deque_value(instance);
    return jacpy_deque_search(state.native, value, first, last, kind)
        if state is not None
        else i64(-1);
}

def:priv deque_count(instance: u64, value: u64) -> u64 {
    count = search(instance, value, 0, 9223372036854775807, 0);
    return jacpy_int(count) if count >= 0 else u64(0);
}

def:priv deque_contains(instance: u64, value: u64) -> i32 {
    return i32(search(instance, value, 0, 9223372036854775807, 1));
}

def:priv deque_remove(instance: u64, value: u64) -> u64 {
    return jacpy_none()
        if search(instance, value, 0, 9223372036854775807, 3) >= 0
        else u64(0);
}

def:priv index_bound(args: BoundArguments) -> u64 {
    first: i64 = 0;
    last: i64 = 9223372036854775807;
    if args.values[1] != 0 {
        first = jacpy_number_ssize(args.values[1], "");
        if jacpy_error_pending() != 0 {
            return 0;
        }
    }
    if args.values[2] != 0 {
        last = jacpy_number_ssize(args.values[2], "");
        if jacpy_error_pending() != 0 {
            return 0;
        }
    }
    found = search(args.context, args.values[0], first, last, 2);
    return jacpy_int(found) if found >= 0 else u64(0);
}

def:priv deque_index(instance: u64, args: u64) -> u64 {
    return invoke(index_signature, args, 0, index_bound, instance);
}

def:priv deque_maxlen(instance: u64, unused: u64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    limit = jacpy_deque_limit(state.native);
    return jacpy_none() if limit < 0 else jacpy_int(limit);
}

def:priv deque_sizeof(instance: u64, unused: u64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    return jacpy_int(
        jacpy_binding_basicsize(instance)
            + jac_heap_size(u64(id(state)))
            + jacpy_deque_memory(state.native)
    );
}

def:priv deque_repr(instance: u64) -> u64 {
    state = deque_value(instance);
    return jacpy_deque_repr(state.native, instance) if state is not None else u64(0);
}

def:priv deque_compare(instance: u64, other: u64, operation: i32) -> u64 {
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return 0;
    }
    if jacpy_type_check(other, jacpy_binding_state_get(module, 0)) == 0 {
        return jacpy_not_implemented();
    }
    left = deque_value(instance);
    right = deque_value(other);
    if left is None or right is None {
        return 0;
    }
    return jacpy_deque_compare(
        left.native, right.native, instance, other, i64(operation)
    );
}

def:priv deque_copy(instance: u64, unused: u64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    limit = jacpy_deque_limit(state.native);
    args = owned_tuple([jacpy_retain(instance)])
        if limit < 0
        else owned_tuple([jacpy_retain(instance), jacpy_int(limit)]);
    if args == 0 {
        return 0;
    }
    result = jacpy_call(jacpy_binding_typeof(instance), args, 0);
    jacpy_release(args);
    if result != 0 and jacpy_binding_matches(result, deque_type.handle) == 0 {
        object_error(
            "TypeError",
            f"{type_name(instance)[:200]}() must return a deque, not {type_name(result)[:200]}"
        );
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv deque_concat(instance: u64, other: u64) -> u64 {
    if jacpy_binding_matches(other, deque_type.handle) == 0 {
        object_error(
            "TypeError",
            f"can only concatenate deque (not \"{type_name(other)[:200]}\") to deque"
        );
        return 0;
    }
    result = deque_copy(instance, 0);
    if result == 0 {
        return 0;
    }
    state = deque_value(result);
    if state is None or jacpy_deque_extend(state.native, result, other, 0) < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv deque_iconcat(instance: u64, other: u64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    return jacpy_retain(instance)
        if jacpy_deque_extend(state.native, instance, other, 0) == 0
        else u64(0);
}

def:priv deque_irepeat(instance: u64, count: i64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    return jacpy_retain(instance)
        if jacpy_deque_repeat(state.native, count) == 0
        else u64(0);
}

def:priv deque_repeat(instance: u64, count: i64) -> u64 {
    result = deque_copy(instance, 0);
    if result == 0 {
        return 0;
    }
    state = deque_value(result);
    if state is None or jacpy_deque_repeat(state.native, count) < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv iterator_type_for(instance: u64) -> TypeDefinition {
    return reverse_type
        if jacpy_binding_matches(instance, reverse_type.handle) != 0
        else forward_type;
}

def:priv iterator_value(instance: u64) -> (DequeIteratorState | None) {
    state = reference_value(instance, iterator_type_for(instance));
    if isinstance(state, DequeIteratorState) {
        return state;
    }
    return None;
}

def:priv iterator_create(type: u64, owner: u64, reverse: bool, advance: i64) -> u64 {
    native = deque_value(owner);
    if native is None {
        return 0;
    }
    state = DequeIteratorState(
        references=[jacpy_retain(owner)],
        cursor=jacpy_deque_cursor(native.native, i64(reverse), advance)
    );
    return allocate(type, reverse_type if reverse else forward_type, state);
}

def:priv deque_iter(instance: u64) -> u64 {
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return 0;
    }
    return iterator_create(jacpy_binding_state_get(module, 1), instance, False, 0);
}

def:priv deque_reversed(instance: u64, unused: u64) -> u64 {
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return 0;
    }
    return iterator_create(jacpy_binding_state_get(module, 2), instance, True, 0);
}

def:priv iterator_self(instance: u64) -> u64 {
    return jacpy_retain(instance);
}

def:priv iterator_next(instance: u64) -> u64 {
    state = iterator_value(instance);
    if state is None {
        return 0;
    }
    cursor = state.cursor;
    return jacpy_deque_next(cursor) if cursor is not None else u64(0);
}

def:priv iterator_hint(instance: u64, unused: u64) -> u64 {
    state = iterator_value(instance);
    if state is None {
        return 0;
    }
    cursor = state.cursor;
    return jacpy_int(jacpy_deque_remaining(cursor) if cursor is not None else i64(0));
}

glob:priv iterator_signature = CallSignature(
         "deque iterator", ["deque", "index"], 1, 2, 2
     );

def:priv iterator_create_bound(args: BoundArguments) -> u64 {
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    if jacpy_type_check(args.values[0], jacpy_binding_state_get(module, 0)) == 0 {
        object_error("TypeError", "argument must be a deque");
        return 0;
    }
    advance: i64 = 0;
    if args.values[1] != 0 {
        value = index_value(args.values[1]);
        if value is None {
            return 0;
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

def:priv iterator_new(type: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(iterator_signature, args, kwargs, iterator_create_bound, type);
}

def:priv iterator_reduce(instance: u64, unused: u64) -> u64 {
    state = iterator_value(instance);
    if state is None {
        return 0;
    }
    cursor = state.cursor;
    if cursor is None {
        object_error("RuntimeError", "cleared deque iterator");
        return 0;
    }
    args = owned_tuple(
        [jacpy_retain(state.references[0]), jacpy_int(jacpy_deque_consumed(cursor))]
    );
    return owned_tuple([jacpy_retain(jacpy_binding_typeof(instance)), args]);
}

def:priv deque_reduce(instance: u64, unused: u64) -> u64 {
    state = deque_value(instance);
    if state is None {
        return 0;
    }
    limit = jacpy_deque_limit(state.native);
    saved = jacpy_binding_object_state(instance);
    iterator = jacpy_iter(instance);
    args = jacpy_tuple_new(0)
        if limit < 0
        else owned_tuple([jacpy_tuple_new(0), jacpy_int(limit)]);
    return owned_tuple(
        [jacpy_retain(jacpy_binding_typeof(instance)), args, saved, iterator]
    );
}

def:priv dictionary_base(instance: u64) -> u64 {
    return jacpy_binding_parent(jacpy_binding_typeof(instance), default_type.handle);
}

def:priv default_create(type: u64, args: u64, kwargs: u64) -> u64 {
    module = module_for(type);
    if module == 0 {
        return 0;
    }
    instance = jacpy_binding_base_new(
        jacpy_binding_state_get(module, 5), type, args, kwargs
    );
    if instance == 0 {
        return 0;
    }
    state = ReferenceState(references=[u64(0)]);
    if jacpy_binding_native_set(instance, default_type.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv default_initialize(instance: u64, args: u64, kwargs: u64) -> i32 {
    count = jacpy_tuple_size(args);
    factory = jacpy_tuple_item(args, 0) if count > 0 else u64(0);
    if count > 0 and factory == 0 {
        return i32(-1);
    }
    if factory != 0 and jacpy_is_none(factory) == 0 and jacpy_callable(factory) == 0 {
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
    rest = jacpy_tuple_slice(args, 1 if count > 0 else 0, count);
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

def:priv default_factory(instance: u64, unused: u64) -> u64 {
    state = reference_value(instance, default_type);
    if state is None {
        return 0;
    }
    value = state.references[0];
    return jacpy_retain(value) if value != 0 else jacpy_none();
}

def:priv default_set_factory(instance: u64, value: u64, unused: u64) -> i32 {
    state = reference_value(instance, default_type);
    if state is None {
        return i32(-1);
    }
    old = state.references[0];
    state.references[0] = jacpy_retain(value) if value != 0 else u64(0);
    jacpy_release(old);
    return i32(0);
}

def:priv default_missing(instance: u64, key: u64) -> u64 {
    factory = default_factory(instance, 0);
    if factory == 0 {
        return 0;
    }
    result = jacpy_default_missing(instance, factory, key);
    jacpy_release(factory);
    return result;
}

def:priv default_construct(instance: u64, mapping: u64) -> u64 {
    args = owned_tuple([default_factory(instance, 0), jacpy_retain(mapping)]);
    if args == 0 {
        return 0;
    }
    result = jacpy_call(jacpy_binding_typeof(instance), args, 0);
    jacpy_release(args);
    return result;
}

def:priv default_copy(instance: u64, unused: u64) -> u64 {
    return default_construct(instance, instance);
}

def:priv default_repr(instance: u64) -> u64 {
    factory = default_factory(instance, 0);
    if factory == 0 {
        return 0;
    }
    result = jacpy_default_repr(instance, factory);
    jacpy_release(factory);
    return result;
}

def:priv default_reduce(instance: u64, unused: u64) -> u64 {
    factory = default_factory(instance, 0);
    if factory == 0 {
        return 0;
    }
    args = jacpy_tuple_new(0)
        if jacpy_is_none(factory) != 0
        else owned_tuple([jacpy_retain(factory)]);
    jacpy_release(factory);
    if args == 0 {
        return 0;
    }
    held = ReferenceState(
        references=[args, jacpy_getattr_string(instance, "items"), u64(0)]
    );
    if held.references[1] == 0 {
        return 0;
    }
    empty = jacpy_tuple_new(0);
    if empty == 0 {
        return 0;
    }
    held.references[2] = jacpy_call(held.references[1], empty, 0);
    jacpy_release(empty);
    if held.references[2] == 0 {
        return 0;
    }
    return owned_tuple(
        [
            jacpy_retain(jacpy_binding_typeof(instance)),
            jacpy_retain(args),
            jacpy_none(),
            jacpy_none(),
            jacpy_iter(held.references[2])
        ]
    );
}

def:priv default_or(left: u64, right: u64) -> u64 {
    if jacpy_is_dict(left) == 0 or jacpy_is_dict(right) == 0 {
        return jacpy_not_implemented();
    }
    owner = left if jacpy_binding_matches(left, default_type.handle) != 0 else right;
    result = default_construct(owner, left);
    if result == 0 {
        return 0;
    }
    if jacpy_dict_update(result, right) < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv default_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    status = traverse_payload(instance, default_type.handle, visitor, context);
    if status != 0 {
        return status;
    }
    base = dictionary_base(instance);
    return jacpy_binding_base_traverse(base, instance, visitor, context)
        if base != 0
        else i32(-1);
}

def:priv default_clear(instance: u64) -> i32 {
    clear_payload(instance, default_type.handle);
    base = dictionary_base(instance);
    return jacpy_binding_base_clear(base, instance) if base != 0 else i32(-1);
}

def:priv default_dealloc(instance: u64) {
    base = dictionary_base(instance);
    type = jacpy_binding_typeof(instance);
    jacpy_binding_untrack(instance);
    clear_payload(instance, default_type.handle);
    jacpy_binding_native_clear(instance, default_type.handle);
    jacpy_binding_base_dealloc(base, instance);
    jacpy_release(type);
}

glob:priv getter_signature = CallSignature(
         "_tuplegetter", ["index", "doc"], 2, 2, 2
     );

def:priv getter_create_bound(args: BoundArguments) -> u64 {
    index = index_value(args.values[0]);
    if index is None {
        return 0;
    }
    state = TupleGetterState(references=[jacpy_retain(args.values[1])], index=index);
    return allocate(args.context, getter_type, state);
}

def:priv getter_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(getter_signature, args, kwargs, getter_create_bound, type);
}

def:priv getter_get(instance: u64, object: u64, owner: u64) -> u64 {
    if object == 0 {
        return jacpy_retain(instance);
    }
    state = reference_value(instance, getter_type);
    if not isinstance(state, TupleGetterState) {
        return 0;
    }
    if jacpy_is_tuple(object) == 0 {
        object_error(
            "TypeError",
            f"descriptor for index '{state.index}' for tuple subclasses doesn't apply to '{type_name(
                object
            )}' object"
        );
        return 0;
    }
    return jacpy_tuple_item(object, state.index);
}

def:priv getter_set(instance: u64, object: u64, value: u64) -> i32 {
    object_error(
        "AttributeError",
        "can't set attribute" if value != 0 else "can't delete attribute"
    );
    return i32(-1);
}

def:priv getter_doc(instance: u64, unused: u64) -> u64 {
    state = reference_value(instance, getter_type);
    if state is None {
        return 0;
    }
    value = state.references[0];
    return jacpy_retain(value) if value != 0 else jacpy_none();
}

def:priv getter_set_doc(instance: u64, value: u64, unused: u64) -> i32 {
    state = reference_value(instance, getter_type);
    if state is None {
        return i32(-1);
    }
    previous = state.references[0];
    state.references[0] = jacpy_retain(value) if value != 0 else u64(0);
    jacpy_release(previous);
    return i32(0);
}

def:priv getter_repr(instance: u64) -> u64 {
    state = reference_value(instance, getter_type);
    if not isinstance(state, TupleGetterState) {
        return 0;
    }
    doc = getter_doc(instance, 0);
    if doc == 0 {
        return 0;
    }
    try {
        return text_object(
            f"{type_name(instance).split(".")[-1]}({state.index}, {repr_value(doc)})"
        );
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(doc);
    }
}

def:priv getter_reduce(instance: u64, unused: u64) -> u64 {
    state = reference_value(instance, getter_type);
    if not isinstance(state, TupleGetterState) {
        return 0;
    }
    args = owned_tuple([jacpy_int(state.index), getter_doc(instance, 0)]);
    return owned_tuple([jacpy_retain(jacpy_binding_typeof(instance)), args]);
}

glob:priv count_signature = CallSignature(
         "_count_elements", ["mapping", "iterable"], 2, 2, 2
     );

def:priv count_bound(args: BoundArguments) -> u64 {
    return jacpy_none()
        if jacpy_count_elements(args.values[0], args.values[1]) == 0
        else u64(0);
}

def:priv count_elements(module: u64, args: u64) -> u64 {
    return invoke(count_signature, args, 0, count_bound);
}

def:priv deque_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, deque_type.handle, visitor, context);
}

def:priv deque_clear(instance: u64) -> i32 {
    return clear_payload(instance, deque_type.handle);
}

def:priv deque_dealloc(instance: u64) {
    dispose_payload(instance, deque_type.handle);
}

def:priv getter_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, getter_type.handle, visitor, context);
}

def:priv getter_clear(instance: u64) -> i32 {
    return clear_payload(instance, getter_type.handle);
}

def:priv getter_dealloc(instance: u64) {
    dispose_payload(instance, getter_type.handle);
}

def:priv iterator_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(
        instance, iterator_type_for(instance).handle, visitor, context
    );
}

def:priv iterator_clear(instance: u64) -> i32 {
    return clear_payload(instance, iterator_type_for(instance).handle);
}

def:priv iterator_dealloc(instance: u64) {
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
                 MethodCallbacks(positional=jacpy_binding_generic_alias),
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
                 MethodCallbacks(positional=jacpy_binding_generic_alias),
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

def:priv execute(module: u64) -> i32 {
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
    dictionary = jacpy_dict_new();
    if dictionary == 0 {
        return i32(-1);
    }
    base = jacpy_binding_typeof(dictionary);
    jacpy_binding_state_set(module, 5, base);
    bases = owned_tuple([jacpy_retain(base)]);
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
    ordered_type = jacpy_retain(jacpy_binding_typeof(ordered));
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

def:pub PyInit__collections -> u64 {
    return definition.initialize();
}
