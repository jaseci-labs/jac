"""Native typed-array declarations, sequence protocols, and buffer ownership."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodDefinition,
    MethodCallbacks,
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
    TypeSlot,
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_typeof,
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_generic_alias,
    jacpy_binding_matches,
    jacpy_binding_slot,
    jacpy_binding_basicsize
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
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
    jacpy_ssize,
    character_value
}
import from jaclang.runtime.python.bindings.buffer {
    BufferArgument,
    BufferLayout,
    jacpy_binding_buffer_fill,
    jacpy_binding_buffer_dispose
}
import from jaclang.runtime.python.capi {
    jacpy_retain,
    jacpy_release,
    jacpy_none,
    jacpy_int,
    jacpy_uint,
    jacpy_is_unicode,
    jacpy_is_bytes,
    jacpy_is_bytearray,
    jacpy_is_list,
    jacpy_is_long,
    jacpy_is_type,
    jacpy_type_check,
    jacpy_index_check,
    jacpy_error_pending,
    jacpy_not_implemented,
    jacpy_unicode_from_ordinal,
    jacpy_optional_attr,
    jacpy_getattr_string,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_import_attr,
    jacpy_call,
    jacpy_call_one,
    jacpy_tuple_new,
    jac_heap_size,
    object_error,
    text_object,
    type_name,
    jacpy_number_ssize,
    jacpy_audit,
    jacpy_warn,
    jacpy_builtins,
    SliceBounds,
    jacpy_is_slice,
    jacpy_slice_unpack,
    jacpy_slice_adjust,
    jacpy_type_subtype,
    jacpy_long_as_int32
}
import from jaclang.runtime.python.modules.array {
    array_state,
    array_cursor,
    jacpy_array_new,
    jacpy_array_init,
    jacpy_array_clear,
    jacpy_array_field,
    jacpy_array_length,
    jacpy_array_code,
    jacpy_array_itemsize,
    jacpy_array_address,
    jacpy_array_export,
    jacpy_array_memory,
    jacpy_array_item,
    jacpy_array_assign,
    jacpy_array_insert,
    jacpy_array_empty,
    jacpy_array_extend,
    jacpy_array_tolist,
    jacpy_array_tobytes,
    jacpy_array_frombytes,
    jacpy_array_reverse,
    jacpy_array_copy,
    jacpy_array_assign_slice,
    jacpy_array_delete,
    jacpy_array_pop,
    jacpy_array_repeat,
    jacpy_array_fromlist,
    jacpy_array_search,
    jacpy_array_compare,
    jacpy_array_tounicode,
    jacpy_array_fromunicode,
    jacpy_array_repr,
    jacpy_array_cursor_new,
    jacpy_array_cursor_owner,
    jacpy_array_cursor_index,
    jacpy_array_cursor_clear,
    jacpy_array_cursor_set,
    jacpy_array_cursor_next,
    jacpy_array_fromfile,
    jacpy_array_tofile,
    jacpy_array_reduce,
    jacpy_array_cursor_reduce,
    jacpy_array_reconstruct_object
}

obj ArrayState(NativeState) {
    has native: array_state;

    def clear {
        # An exported view keeps storage valid until its release callback runs.
        if self.native.exports == 0 {
            jacpy_array_clear(self.native);
        }
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        return jacpy_binding_visit(jacpy_array_field(self.native), visitor, context);
    }

    def drop {
        self.clear();
    }
}

obj ArrayIteratorState(NativeState) {
    has native: array_cursor;

    def clear {
        jacpy_array_cursor_clear(self.native);
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        return jacpy_binding_visit(
            jacpy_array_cursor_owner(self.native), visitor, context
        );
    }

    def drop {
        self.clear();
    }
}

def:priv module_for(type: u64) -> u64 {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv state_for(instance: u64) -> (ArrayState | None) {
    if jacpy_binding_native_present(instance, array_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, array_type.handle);
        if isinstance(state, ArrayState) {
            return state;
        }
    }
    object_error("SystemError", "native array state is unavailable");
    return None;
}

def:priv iterator_state(instance: u64) -> (ArrayIteratorState | None) {
    if jacpy_binding_native_present(instance, iterator_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, iterator_type.handle);
        if isinstance(state, ArrayIteratorState) {
            return state;
        }
    }
    object_error("SystemError", "native array iterator state is unavailable");
    return None;
}

def:priv allocate(type: u64, code: i64) -> u64 {
    state = ArrayState(native=array_state());
    if jacpy_array_init(state.native, code) < 0 {
        return 0;
    }
    instance = jacpy_binding_allocate(type);
    if instance != 0
        and jacpy_binding_native_set(instance, array_type.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv done(status: i64) -> u64 {
    return jacpy_none() if status >= 0 else u64(0);
}

def:priv append_buffer(state: array_state, value: u64) -> i64 {
    buffer = BufferArgument();
    if not buffer.acquire(value) {
        return -1;
    }
    return jacpy_array_frombytes(state, buffer.address(), buffer.size());
}

glob:priv array_signature = CallSignature(
         "array", ["typecode", "initializer"], 1, 2, 2
     );

def:priv create_bound(args: BoundArguments) -> u64 {
    character = character_value(args.values[0], "array");
    if character is None {
        return 0;
    }
    code: i64 = character;
    initial = args.values[1];
    audit = owned_tuple(
        [
            jacpy_retain(args.values[0]),
            jacpy_retain(initial) if initial != 0 else jacpy_none()
        ]
    );
    if audit == 0 {
        return 0;
    }
    status = jacpy_audit("array.__new__", audit);
    jacpy_release(audit);
    if status < 0 {
        return 0;
    }
    if code == 117
        and jacpy_warn(
            "DeprecationWarning",
            "The 'u' type code is deprecated and will be removed in Python 3.16",
            1
        )
            < 0 {
        return 0;
    }
    other: (ArrayState | None) = None;
    if initial != 0 and jacpy_binding_matches(initial, array_type.handle) != 0 {
        other = state_for(initial);
        if other is None {
            return 0;
        }
    }
    if initial != 0
        and code != 117
        and code != 119
        and (
            jacpy_is_unicode(initial) != 0
            or (
                other is not None
                and (other.native.code == 117 or other.native.code == 119)
            )
        ) {
        source = "str" if jacpy_is_unicode(initial) != 0 else "unicode array";
        object_error(
            "TypeError",
            f"cannot use a {source} to initialize an array with typecode '{chr(
                int(code)
            )}'"
        );
        return 0;
    }
    instance = allocate(args.context, code);
    if instance == 0 {
        return 0;
    }
    state = state_for(instance);
    if state is None {
        jacpy_release(instance);
        return 0;
    }
    if initial != 0 {
        status = i64(0);
        if jacpy_is_bytes(initial) != 0 or jacpy_is_bytearray(initial) != 0 {
            status = append_buffer(state.native, initial);
        } elif other is not None and i64(other.native.code) == code {
            status = jacpy_array_copy(
                state.native, other.native, 0, 1, other.native.length
            );
        } else {
            status = jacpy_array_extend(state.native, initial);
        }
        if status < 0 {
            jacpy_release(instance);
            return 0;
        }
    }
    return instance;
}

def:priv create(type: u64, args: u64, kwargs: u64) -> u64 {
    module = module_for(type);
    if module == 0 {
        return 0;
    }
    base = jacpy_binding_state_get(module, 0);
    if jacpy_binding_slot(type, i64(TypeSlot.INIT.value))
        == jacpy_binding_slot(base, i64(TypeSlot.INIT.value)) {
        if kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
            object_error("TypeError", "array.array() takes no keyword arguments");
            return 0;
        }
        return invoke(array_signature, args, 0, create_bound, type);
    }
    # Subclass __init__ owns its keywords; the array constructor sees positionals.
    return invoke(array_signature, args, 0, create_bound, type);
}

def:priv length(instance: u64) -> i64 {
    state = state_for(instance);
    return state.native.length if state is not None else i64(-1);
}

def:priv item(instance: u64, index: i64) -> u64 {
    state = state_for(instance);
    return jacpy_array_item(state.native, index) if state is not None else u64(0);
}

def:priv assign_item(instance: u64, index: i64, value: u64) -> i32 {
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    if index < 0 or index >= state.native.length {
        object_error("IndexError", "array assignment index out of range");
        return i32(-1);
    }
    return i32(
        jacpy_array_assign(state.native, index, value)
            if value != 0
            else jacpy_array_delete(state.native, index, 1, 1)
    );
}

def:priv subscript(instance: u64, key: u64) -> u64 {
    if jacpy_index_check(key) != 0 {
        index = jacpy_number_ssize(key, "IndexError");
        if jacpy_error_pending() != 0 {
            return 0;
        }
        if index < 0 {
            index += length(instance);
        }
        return item(instance, index);
    }
    if jacpy_is_slice(key) != 0 {
        bounds = jacpy_slice_unpack(key);
        if bounds.valid == 0 {
            return 0;
        }
        state = state_for(instance);
        if state is None {
            return 0;
        }
        span = jacpy_slice_adjust(state.native.length, bounds);
        module = module_for(jacpy_binding_typeof(instance));
        if module == 0 {
            return 0;
        }
        result = allocate(jacpy_binding_state_get(module, 0), i64(state.native.code));
        if result == 0 {
            return 0;
        }
        target = state_for(result);
        if target is None
            or jacpy_array_copy(
                target.native, state.native, span.start, span.step, span.count
            )
                < 0 {
            jacpy_release(result);
            return 0;
        }
        return result;
    }
    object_error("TypeError", "array indices must be integers or slices");
    return 0;
}

def:priv assign_subscript(instance: u64, key: u64, value: u64) -> i32 {
    if jacpy_index_check(key) != 0 {
        index = jacpy_number_ssize(key, "IndexError");
        if jacpy_error_pending() != 0 {
            return i32(-1);
        }
        if index < 0 {
            index += length(instance);
        }
        return assign_item(instance, index, value);
    }
    if jacpy_is_slice(key) != 0 {
        bounds = jacpy_slice_unpack(key);
        if bounds.valid == 0 {
            return i32(-1);
        }
        state = state_for(instance);
        if state is None {
            return i32(-1);
        }
        span = jacpy_slice_adjust(state.native.length, bounds);
        if value == 0 {
            return i32(
                jacpy_array_delete(state.native, span.start, span.step, span.count)
            );
        }
        if jacpy_binding_matches(value, array_type.handle) == 0 {
            object_error("TypeError", "can only assign array to array slice");
            return i32(-1);
        }
        other = state_for(value);
        if other is None {
            return i32(-1);
        }
        return i32(
            jacpy_array_assign_slice(
                state.native, span.start, span.step, span.count, other.native
            )
        );
    }
    object_error("TypeError", "array indices must be integers or slices");
    return i32(-1);
}

def:priv inplace_concat(instance: u64, value: u64) -> u64 {
    if jacpy_binding_matches(value, array_type.handle) == 0 {
        object_error("TypeError", "can only extend array with array");
        return 0;
    }
    state = state_for(instance);
    other = state_for(value);
    if state is None or other is None {
        return 0;
    }
    return jacpy_retain(instance)
        if jacpy_array_assign_slice(
            state.native, state.native.length, 1, 0, other.native
        )
            == 0
        else u64(0);
}

def:priv copy(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return 0;
    }
    result = allocate(jacpy_binding_state_get(module, 0), i64(state.native.code));
    if result == 0 {
        return 0;
    }
    target = state_for(result);
    if target is None
        or jacpy_array_copy(target.native, state.native, 0, 1, state.native.length)
            < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv concat(instance: u64, other: u64) -> u64 {
    copied = copy(instance, 0);
    if copied == 0 {
        return 0;
    }
    result = inplace_concat(copied, other);
    jacpy_release(copied);
    return result;
}

def:priv inplace_repeat(instance: u64, count: i64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_retain(instance)
        if jacpy_array_repeat(state.native, count) == 0
        else u64(0);
}

def:priv repeat(instance: u64, count: i64) -> u64 {
    copied = copy(instance, 0);
    if copied == 0 {
        return 0;
    }
    result = inplace_repeat(copied, count);
    jacpy_release(copied);
    return result;
}

def:priv compare(instance: u64, other: u64, operation: i32) -> u64 {
    if jacpy_binding_matches(other, array_type.handle) == 0 {
        return jacpy_not_implemented();
    }
    left = state_for(instance);
    right = state_for(other);
    if left is None or right is None {
        return 0;
    }
    return jacpy_array_compare(left.native, right.native, i64(operation));
}

def:priv contains(instance: u64, value: u64) -> i32 {
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    return i32(jacpy_array_search(state.native, value, 0, 9223372036854775807, 3));
}

glob:priv insert_signature = CallSignature("insert", ["index", "value"], 2, 2, 2),
     pop_signature = CallSignature("pop", ["index"], 0, 1, 1),
     index_signature = CallSignature("index", ["value", "start", "stop"], 1, 3, 3),
     fromfile_signature = CallSignature("fromfile", ["file", "n"], 2, 2, 2),
     reconstruct_signature = CallSignature(
         "_array_reconstructor", ["type", "typecode", "mformat", "items"], 4, 4, 4
     );

def:priv insert_bound(args: BoundArguments) -> u64 {
    index = index_value(args.values[0]);
    if index is None {
        return 0;
    }
    state = state_for(args.context);
    if state is None {
        return 0;
    }
    return done(jacpy_array_insert(state.native, index, args.values[1]));
}

def:priv insert(instance: u64, args: u64) -> u64 {
    return invoke(insert_signature, args, 0, insert_bound, instance);
}

def:priv pop_bound(args: BoundArguments) -> u64 {
    index: i64 = -1;
    if args.values[0] != 0 {
        value = index_value(args.values[0]);
        if value is None {
            return 0;
        }
        index = value;
    }
    state = state_for(args.context);
    return jacpy_array_pop(state.native, index) if state is not None else u64(0);
}

def:priv pop(instance: u64, args: u64) -> u64 {
    return invoke(pop_signature, args, 0, pop_bound, instance);
}

def:priv index_bound(args: BoundArguments) -> u64 {
    first: i64 = 0;
    last: i64 = 9223372036854775807;
    if args.values[1] != 0 {
        value = index_value(args.values[1]);
        if value is None {
            return 0;
        }
        first = value;
    }
    if args.values[2] != 0 {
        value = index_value(args.values[2]);
        if value is None {
            return 0;
        }
        last = value;
    }
    state = state_for(args.context);
    if state is None {
        return 0;
    }
    result = jacpy_array_search(state.native, args.values[0], first, last, 1);
    return jacpy_int(result) if result >= 0 else u64(0);
}

def:priv index(instance: u64, args: u64) -> u64 {
    return invoke(index_signature, args, 0, index_bound, instance);
}

def:priv fromfile_bound(args: BoundArguments) -> u64 {
    count = index_value(args.values[1]);
    if count is None {
        return 0;
    }
    state = state_for(args.context);
    if state is None {
        return 0;
    }
    return done(jacpy_array_fromfile(state.native, args.values[0], count));
}

def:priv fromfile(instance: u64, args: u64) -> u64 {
    return invoke(fromfile_signature, args, 0, fromfile_bound, instance);
}

def:priv frombytes(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    return done(append_buffer(state.native, value)) if state is not None else u64(0);
}

def:priv fromlist(instance: u64, value: u64) -> u64 {
    if jacpy_is_list(value) == 0 {
        object_error("TypeError", "arg must be list");
        return 0;
    }
    state = state_for(instance);
    return done(jacpy_array_fromlist(state.native, value))
        if state is not None
        else u64(0);
}

def:priv fromunicode(instance: u64, value: u64) -> u64 {
    if jacpy_is_unicode(value) == 0 {
        object_error("TypeError", "fromunicode() argument must be str");
        return 0;
    }
    state = state_for(instance);
    return done(jacpy_array_fromunicode(state.native, value))
        if state is not None
        else u64(0);
}

def:priv extend(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    if jacpy_binding_matches(value, array_type.handle) != 0 {
        other = state_for(value);
        if other is None {
            return 0;
        }
        return done(
            jacpy_array_assign_slice(
                state.native, state.native.length, 1, 0, other.native
            )
        );
    }
    return done(jacpy_array_extend(state.native, value));
}

def:priv buffer_info(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    address = jacpy_array_address(state.native) if state.native.length != 0 else u64(0);
    return owned_tuple([jacpy_uint(address), jacpy_int(state.native.length)]);
}

def:priv size_of(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_int(
        jacpy_binding_basicsize(instance)
            + jac_heap_size(u64(id(state)))
            + jacpy_array_memory(state.native)
    );
}

def:priv typecode(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    return jacpy_unicode_from_ordinal(i64(state.native.code))
        if state is not None
        else u64(0);
}

def:priv itemsize(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    return jacpy_int(i64(state.native.itemsize)) if state is not None else u64(0);
}

def:priv get_buffer(instance: u64, view: u64, flags: i32) -> i32 {
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    letter = "w" if state.native.code == 117 else chr(state.native.code);
    layout = BufferLayout(
        address=jacpy_array_address(state.native),
        count=state.native.length,
        itemsize=i64(state.native.itemsize)
    );
    status = jacpy_binding_buffer_fill(view, instance, layout, letter, flags);
    if status == 0 {
        jacpy_array_export(state.native, 1);
    }
    return status;
}

def:priv release_buffer(instance: u64, view: u64) {
    state = state_for(instance);
    if state is not None {
        jacpy_array_export(state.native, -1);
    }
    jacpy_binding_buffer_dispose(view);
}

def:priv reduce(instance: u64, value: u64) -> u64 {
    if jacpy_is_long(value) == 0 {
        object_error("TypeError", "__reduce_ex__ argument should be an integer");
        return 0;
    }
    protocol = jacpy_ssize(value);
    if jacpy_error_pending() != 0 {
        return 0;
    }
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return 0;
    }
    held = ReferenceState(
        references=[jacpy_getattr_string(module, "_array_reconstructor"), u64(0)]
    );
    if held.references[0] == 0 {
        return 0;
    }
    held.references[1] = jacpy_optional_attr(instance, "__dict__");
    if held.references[1] == 0 {
        if jacpy_error_pending() != 0 {
            return 0;
        }
        held.references[1] = jacpy_none();
    }
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_array_reduce(
        state.native,
        jacpy_binding_typeof(instance),
        held.references[1],
        held.references[0],
        protocol
    );
}

def:priv reconstruct_bound(args: BoundArguments) -> u64 {
    character = character_value(args.values[1], "_array_reconstructor");
    if character is None {
        return 0;
    }
    code: i64 = character;
    format = jacpy_long_as_int32(args.values[2]);
    if jacpy_error_pending() != 0 {
        return 0;
    }
    if jacpy_is_type(args.values[0]) == 0
        or jacpy_type_subtype(args.values[0], jacpy_binding_state_get(args.context, 0))
            == 0 {
        object_error("TypeError", "first argument must be an array subtype");
        return 0;
    }
    if jacpy_is_bytes(args.values[3]) == 0 {
        object_error("TypeError", "fourth argument should be bytes");
        return 0;
    }
    return jacpy_array_reconstruct_object(args.values[0], code, format, args.values[3]);
}

def:priv reconstruct(module: u64, args: u64) -> u64 {
    return invoke(reconstruct_signature, args, 0, reconstruct_bound, module);
}

def:priv iterate(instance: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return 0;
    }
    cursor = ArrayIteratorState(native=jacpy_array_cursor_new(instance, state.native));
    result = jacpy_binding_allocate(jacpy_binding_state_get(module, 1));
    if result != 0
        and jacpy_binding_native_set(result, iterator_type.handle, cursor) < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv iterator_next(instance: u64) -> u64 {
    state = iterator_state(instance);
    return jacpy_array_cursor_next(state.native) if state is not None else u64(0);
}

def:priv iterator_self(instance: u64) -> u64 {
    return jacpy_retain(instance);
}

def:priv iterator_setstate(instance: u64, value: u64) -> u64 {
    index = jacpy_ssize(value);
    if jacpy_error_pending() != 0 {
        return 0;
    }
    state = iterator_state(instance);
    if state is None {
        return 0;
    }
    jacpy_array_cursor_set(state.native, index);
    return jacpy_none();
}

def:priv iterator_reduce(instance: u64, unused: u64) -> u64 {
    held = ReferenceState(references=[jacpy_builtins(), text_object("iter"), u64(0)]);
    if held.references[0] == 0 or held.references[1] == 0 {
        return 0;
    }
    held.references[2] = jacpy_dict_get(held.references[0], held.references[1]);
    if held.references[2] == 0 {
        object_error("RuntimeError", "missing builtin iter");
        return 0;
    }
    state = iterator_state(instance);
    if state is None {
        return 0;
    }
    return jacpy_array_cursor_reduce(state.native, held.references[2]);
}

def:priv repr(instance: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_array_repr(state.native);
}

def:priv append(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return done(jacpy_array_insert(state.native, 9223372036854775807, value));
}

def:priv count(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    result = jacpy_array_search(state.native, value, 0, 9223372036854775807, 0);
    return jacpy_int(result) if result >= 0 else u64(0);
}

def:priv remove(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return done(jacpy_array_search(state.native, value, 0, 9223372036854775807, 2));
}

def:priv clear(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return done(jacpy_array_empty(state.native));
}

def:priv tolist(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_array_tolist(state.native);
}

def:priv tobytes(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_array_tobytes(state.native);
}

def:priv tounicode(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_array_tounicode(state.native);
}

def:priv tofile(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return done(jacpy_array_tofile(state.native, value));
}

def:priv reverse(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    jacpy_array_reverse(state.native, 0);
    return jacpy_none();
}

def:priv byteswap(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    jacpy_array_reverse(state.native, 1);
    return jacpy_none();
}

def:priv array_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, array_type.handle, visitor, context);
}

def:priv array_clear(instance: u64) -> i32 {
    return clear_payload(instance, array_type.handle);
}

def:priv array_dealloc(instance: u64) {
    dispose_payload(instance, array_type.handle);
}

def:priv iterator_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, iterator_type.handle, visitor, context);
}

def:priv iterator_clear(instance: u64) -> i32 {
    return clear_payload(instance, iterator_type.handle);
}

def:priv iterator_dealloc(instance: u64) {
    dispose_payload(instance, iterator_type.handle);
}

glob:priv flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     iterator_type = TypeDefinition(
         "array.arrayiterator",
         "",
         [
             MethodDefinition(
                 "__reduce__", MethodCallbacks(positional=iterator_reduce), "", flags=4
             ),
             MethodDefinition(
                 "__setstate__",
                 MethodCallbacks(positional=iterator_setstate),
                 "",
                 flags=8
             )
         ],
         flags | u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(
             dealloc=iterator_dealloc,
             traverse=iterator_traverse,
             clear=iterator_clear,
             iter=iterator_self,
             next=iterator_next
         )
     ),
     array_type = TypeDefinition(
         "array.array",
         "",
         [
             MethodDefinition(
                 "fromfile", MethodCallbacks(positional=fromfile), "", flags=1
             ),
             MethodDefinition(
                 "tofile", MethodCallbacks(positional=tofile), "", flags=8
             ),
             MethodDefinition(
                 "__reduce_ex__", MethodCallbacks(positional=reduce), "", flags=8
             ),
             MethodDefinition(
                 "append", MethodCallbacks(positional=append), "", flags=8
             ),
             MethodDefinition(
                 "insert", MethodCallbacks(positional=insert), "", flags=1
             ),
             MethodDefinition("pop", MethodCallbacks(positional=pop), "", flags=1),
             MethodDefinition("index", MethodCallbacks(positional=index), "", flags=1),
             MethodDefinition("count", MethodCallbacks(positional=count), "", flags=8),
             MethodDefinition(
                 "remove", MethodCallbacks(positional=remove), "", flags=8
             ),
             MethodDefinition("clear", MethodCallbacks(positional=clear), "", flags=4),
             MethodDefinition(
                 "reverse", MethodCallbacks(positional=reverse), "", flags=4
             ),
             MethodDefinition(
                 "byteswap", MethodCallbacks(positional=byteswap), "", flags=4
             ),
             MethodDefinition(
                 "extend", MethodCallbacks(positional=extend), "", flags=8
             ),
             MethodDefinition(
                 "fromlist", MethodCallbacks(positional=fromlist), "", flags=8
             ),
             MethodDefinition(
                 "frombytes", MethodCallbacks(positional=frombytes), "", flags=8
             ),
             MethodDefinition(
                 "fromunicode", MethodCallbacks(positional=fromunicode), "", flags=8
             ),
             MethodDefinition(
                 "tolist", MethodCallbacks(positional=tolist), "", flags=4
             ),
             MethodDefinition(
                 "tobytes", MethodCallbacks(positional=tobytes), "", flags=4
             ),
             MethodDefinition(
                 "tounicode", MethodCallbacks(positional=tounicode), "", flags=4
             ),
             MethodDefinition(
                 "buffer_info", MethodCallbacks(positional=buffer_info), "", flags=4
             ),
             MethodDefinition(
                 "__sizeof__", MethodCallbacks(positional=size_of), "", flags=4
             ),
             MethodDefinition(
                 "__copy__", MethodCallbacks(positional=copy), "", flags=4
             ),
             MethodDefinition(
                 "__deepcopy__", MethodCallbacks(positional=copy), "", flags=8
             ),
             MethodDefinition(
                 "__class_getitem__",
                 MethodCallbacks(positional=jacpy_binding_generic_alias),
                 "",
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
             create=create,
             dealloc=array_dealloc,
             traverse=array_traverse,
             clear=array_clear,
             repr=repr,
             compare=compare,
             iter=iterate,
             length=length,
             item=item,
             assign=assign_item,
             contains=contains,
             concat=concat,
             inplace_concat=inplace_concat,
             repeat=repeat,
             inplace_repeat=inplace_repeat,
             mapping_length=length,
             subscript=subscript,
             assign_subscript=assign_subscript,
             buffer=get_buffer,
             release_buffer=release_buffer
         ),
         [
             PropertyDefinition("typecode", PropertyCallbacks(read=typecode)),
             PropertyDefinition("itemsize", PropertyCallbacks(read=itemsize))
         ],
         unhashable=True
     );

def:priv execute(module: u64) -> i32 {
    iterator = iterator_type.create(module);
    if iterator == 0 {
        return i32(-1);
    }
    jacpy_binding_state_set(module, 1, iterator);
    jacpy_release(iterator);
    if not add_state_owned(module, 0, "array", array_type.create(module))
        or not add_owned(
            module, "ArrayType", jacpy_retain(jacpy_binding_state_get(module, 0))
        )
        or not add_owned(module, "typecodes", text_object("bBuhHiIlLqQfdw")) {
        return i32(-1);
    }
    held = ReferenceState(
        references=[jacpy_import_attr("collections.abc", "MutableSequence"), u64(0)]
    );
    if held.references[0] == 0 {
        return i32(-1);
    }
    held.references[1] = jacpy_getattr_string(held.references[0], "register");
    if held.references[1] == 0 {
        return i32(-1);
    }
    result = jacpy_call_one(held.references[1], jacpy_binding_state_get(module, 0));
    if result == 0 {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "array",
         "Native Jac typed arrays.",
         [
             MethodDefinition(
                 "_array_reconstructor",
                 MethodCallbacks(positional=reconstruct),
                 "",
                 flags=1
             )
         ],
         hooks=ModuleHooks(execute=execute),
         state_count=2
     );

def:pub PyInit_array -> u64 {
    return definition.initialize();
}
