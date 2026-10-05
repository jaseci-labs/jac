"""Native typed-array declarations, sequence protocols, and buffer ownership."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyImport_ImportModuleAttrString,
    PyIndex_Check,
    PyLong_AsInt,
    PyLong_AsSsize_t,
    PyLong_FromLongLong,
    PyLong_FromUnsignedLongLong,
    PyLong_FromVoidPtr,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PySys_AuditTuple,
    PyTuple_New,
    PyType_GetSlot,
    PyType_IsSubtype,
    PyUnicode_FromOrdinal,
    Py_GenericAlias,
    Py_NewRef,
    Py_TYPE,
    Py_buffer,
    SliceBounds,
    jacpy_builtins,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_is_bytearray,
    jacpy_is_bytes,
    jacpy_is_list,
    jacpy_is_long,
    jacpy_is_slice,
    jacpy_is_type,
    jacpy_is_unicode,
    jacpy_none,
    jacpy_not_implemented,
    jacpy_number_ssize,
    jacpy_optional_attr,
    jacpy_release,
    jacpy_slice_adjust,
    jacpy_slice_unpack,
    jacpy_type_check,
    jacpy_warn
}
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
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_matches,
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
    character_value
}
import from jaclang.runtime.python.bindings.buffer {
    BufferArgument,
    BufferLayout,
    jacpy_binding_buffer_fill,
    jacpy_binding_buffer_dispose
}
import from jaclang.runtime.python.capi {
    jac_heap_size,
    object_error,
    text_object,
    type_name
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

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
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

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        return jacpy_binding_visit(
            jacpy_array_cursor_owner(self.native), visitor, context
        );
    }

    def drop {
        self.clear();
    }
}

def:priv module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv state_for(instance: ptr[PyObject]) -> (ArrayState | None) {
    if jacpy_binding_native_present(instance, array_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, array_type.handle);
        if isinstance(state, ArrayState) {
            return state;
        }
    }
    object_error("SystemError", "native array state is unavailable");
    return None;
}

def:priv iterator_state(instance: ptr[PyObject]) -> (ArrayIteratorState | None) {
    if jacpy_binding_native_present(instance, iterator_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, iterator_type.handle);
        if isinstance(state, ArrayIteratorState) {
            return state;
        }
    }
    object_error("SystemError", "native array iterator state is unavailable");
    return None;
}

def:priv allocate(type: ptr[PyObject], code: i64) -> ptr[PyObject] {
    state = ArrayState(native=array_state());
    if jacpy_array_init(state.native, code) < 0 {
        return NULL;
    }
    instance = jacpy_binding_allocate(type);
    if instance != 0
        and jacpy_binding_native_set(instance, array_type.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def:priv done(status: i64) -> ptr[PyObject] {
    return jacpy_none() if status >= 0 else NULL;
}

def:priv append_buffer(state: array_state, value: ptr[PyObject]) -> i64 {
    buffer = BufferArgument();
    if not buffer.acquire(value) {
        return -1;
    }
    return jacpy_array_frombytes(state, buffer.address(), buffer.size());
}

glob:priv array_signature = CallSignature(
         "array", ["typecode", "initializer"], 1, 2, 2
     );

def:priv create_bound(args: BoundArguments) -> ptr[PyObject] {
    character = character_value(args.values[0], "array");
    if character is None {
        return NULL;
    }
    code: i64 = character;
    initial = args.values[1];
    audit = owned_tuple(
        [
            Py_NewRef(args.values[0]),
            Py_NewRef(initial) if initial != 0 else jacpy_none()
        ]
    );
    if audit == 0 {
        return NULL;
    }
    status = PySys_AuditTuple("array.__new__", audit);
    jacpy_release(audit);
    if status < 0 {
        return NULL;
    }
    if code == 117
        and jacpy_warn(
            "DeprecationWarning",
            "The 'u' type code is deprecated and will be removed in Python 3.16",
            1
        )
            < 0 {
        return NULL;
    }
    other: (ArrayState | None) = None;
    if initial != 0 and jacpy_binding_matches(initial, array_type.handle) != 0 {
        other = state_for(initial);
        if other is None {
            return NULL;
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
        return NULL;
    }
    instance = allocate(args.context, code);
    if instance == 0 {
        return NULL;
    }
    state = state_for(instance);
    if state is None {
        jacpy_release(instance);
        return NULL;
    }
    if initial != 0 {
        filled = i64(0);
        if jacpy_is_bytes(initial) != 0 or jacpy_is_bytearray(initial) != 0 {
            filled = append_buffer(state.native, initial);
        } elif other is not None and i64(other.native.code) == code {
            filled = jacpy_array_copy(
                state.native, other.native, 0, 1, other.native.length
            );
        } else {
            filled = jacpy_array_extend(state.native, initial);
        }
        if filled < 0 {
            jacpy_release(instance);
            return NULL;
        }
    }
    return instance;
}

def:priv create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_for(type);
    if module == 0 {
        return NULL;
    }
    base = jacpy_binding_state_get(module, 0);
    if PyType_GetSlot(type, i32(TypeSlot.INIT.value))
        == PyType_GetSlot(base, i32(TypeSlot.INIT.value)) {
        if kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
            object_error("TypeError", "array.array() takes no keyword arguments");
            return NULL;
        }
        return invoke(array_signature, args, NULL, create_bound, type);
    }
    # Subclass __init__ owns its keywords; the array constructor sees positionals.
    return invoke(array_signature, args, NULL, create_bound, type);
}

def:priv length(instance: ptr[PyObject]) -> i64 {
    state = state_for(instance);
    return state.native.length if state is not None else i64(-1);
}

def:priv item(instance: ptr[PyObject], index: i64) -> ptr[PyObject] {
    state = state_for(instance);
    return jacpy_array_item(state.native, index) if state is not None else NULL;
}

def:priv assign_item(instance: ptr[PyObject], index: i64, value: ptr[PyObject]) -> i32 {
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

def:priv subscript(instance: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(key) != 0 {
        index = jacpy_number_ssize(key, "IndexError");
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        if index < 0 {
            index += length(instance);
        }
        return item(instance, index);
    }
    if jacpy_is_slice(key) != 0 {
        bounds = jacpy_slice_unpack(key);
        if bounds.valid == 0 {
            return NULL;
        }
        state = state_for(instance);
        if state is None {
            return NULL;
        }
        span = jacpy_slice_adjust(state.native.length, bounds);
        module = module_for(Py_TYPE(instance));
        if module == 0 {
            return NULL;
        }
        result = allocate(jacpy_binding_state_get(module, 0), i64(state.native.code));
        if result == 0 {
            return NULL;
        }
        target = state_for(result);
        if target is None
            or jacpy_array_copy(
                target.native, state.native, span.start, span.step, span.count
            )
                < 0 {
            jacpy_release(result);
            return NULL;
        }
        return result;
    }
    object_error("TypeError", "array indices must be integers or slices");
    return NULL;
}

def:priv assign_subscript(
    instance: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if PyIndex_Check(key) != 0 {
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

def:priv inplace_concat(
    instance: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_binding_matches(value, array_type.handle) == 0 {
        object_error("TypeError", "can only extend array with array");
        return NULL;
    }
    state = state_for(instance);
    other = state_for(value);
    if state is None or other is None {
        return NULL;
    }
    return Py_NewRef(instance)
        if jacpy_array_assign_slice(
            state.native, state.native.length, 1, 0, other.native
        )
            == 0
        else NULL;
}

def:priv copy(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    result = allocate(jacpy_binding_state_get(module, 0), i64(state.native.code));
    if result == 0 {
        return NULL;
    }
    target = state_for(result);
    if target is None
        or jacpy_array_copy(target.native, state.native, 0, 1, state.native.length)
            < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:priv concat(instance: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    copied = copy(instance, NULL);
    if copied == 0 {
        return NULL;
    }
    result = inplace_concat(copied, other);
    jacpy_release(copied);
    return result;
}

def:priv inplace_repeat(instance: ptr[PyObject], count: i64) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(instance)
        if jacpy_array_repeat(state.native, count) == 0
        else NULL;
}

def:priv repeat(instance: ptr[PyObject], count: i64) -> ptr[PyObject] {
    copied = copy(instance, NULL);
    if copied == 0 {
        return NULL;
    }
    result = inplace_repeat(copied, count);
    jacpy_release(copied);
    return result;
}

def:priv compare(
    instance: ptr[PyObject], other: ptr[PyObject], operation: i32
) -> ptr[PyObject] {
    if jacpy_binding_matches(other, array_type.handle) == 0 {
        return jacpy_not_implemented();
    }
    left = state_for(instance);
    right = state_for(other);
    if left is None or right is None {
        return NULL;
    }
    return jacpy_array_compare(left.native, right.native, i64(operation));
}

def:priv contains(instance: ptr[PyObject], value: ptr[PyObject]) -> i32 {
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

def:priv insert_bound(args: BoundArguments) -> ptr[PyObject] {
    index = index_value(args.values[0]);
    if index is None {
        return NULL;
    }
    state = state_for(args.context);
    if state is None {
        return NULL;
    }
    return done(jacpy_array_insert(state.native, index, args.values[1]));
}

def:priv insert(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(insert_signature, args, NULL, insert_bound, instance);
}

def:priv pop_bound(args: BoundArguments) -> ptr[PyObject] {
    index: i64 = -1;
    if args.values[0] != 0 {
        value = index_value(args.values[0]);
        if value is None {
            return NULL;
        }
        index = value;
    }
    state = state_for(args.context);
    return jacpy_array_pop(state.native, index) if state is not None else NULL;
}

def:priv pop(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(pop_signature, args, NULL, pop_bound, instance);
}

def:priv index_bound(args: BoundArguments) -> ptr[PyObject] {
    first: i64 = 0;
    last: i64 = 9223372036854775807;
    if args.values[1] != 0 {
        value = index_value(args.values[1]);
        if value is None {
            return NULL;
        }
        first = value;
    }
    if args.values[2] != 0 {
        value = index_value(args.values[2]);
        if value is None {
            return NULL;
        }
        last = value;
    }
    state = state_for(args.context);
    if state is None {
        return NULL;
    }
    result = jacpy_array_search(state.native, args.values[0], first, last, 1);
    return PyLong_FromLongLong(result) if result >= 0 else NULL;
}

def:priv index(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(index_signature, args, NULL, index_bound, instance);
}

def:priv fromfile_bound(args: BoundArguments) -> ptr[PyObject] {
    count = index_value(args.values[1]);
    if count is None {
        return NULL;
    }
    state = state_for(args.context);
    if state is None {
        return NULL;
    }
    return done(jacpy_array_fromfile(state.native, args.values[0], count));
}

def:priv fromfile(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(fromfile_signature, args, NULL, fromfile_bound, instance);
}

def:priv frombytes(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    return done(append_buffer(state.native, value)) if state is not None else NULL;
}

def:priv fromlist(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_list(value) == 0 {
        object_error("TypeError", "arg must be list");
        return NULL;
    }
    state = state_for(instance);
    return done(jacpy_array_fromlist(state.native, value))
        if state is not None
        else NULL;
}

def:priv fromunicode(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_unicode(value) == 0 {
        object_error("TypeError", "fromunicode() argument must be str");
        return NULL;
    }
    state = state_for(instance);
    return done(jacpy_array_fromunicode(state.native, value))
        if state is not None
        else NULL;
}

def:priv extend(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    if jacpy_binding_matches(value, array_type.handle) != 0 {
        other = state_for(value);
        if other is None {
            return NULL;
        }
        return done(
            jacpy_array_assign_slice(
                state.native, state.native.length, 1, 0, other.native
            )
        );
    }
    return done(jacpy_array_extend(state.native, value));
}

def:priv buffer_info(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    address = jacpy_array_address(state.native) if state.native.length != 0 else ptr();
    return owned_tuple(
        [PyLong_FromVoidPtr(address), PyLong_FromLongLong(state.native.length)]
    );
}

def:priv size_of(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLongLong(
        jacpy_binding_basicsize(instance)
            + jac_heap_size(u64(id(state)))
            + jacpy_array_memory(state.native)
    );
}

def:priv typecode(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = state_for(instance);
    return PyUnicode_FromOrdinal(i32(state.native.code)) if state is not None else NULL;
}

def:priv itemsize(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = state_for(instance);
    return PyLong_FromLongLong(i64(state.native.itemsize))
        if state is not None
        else NULL;
}

def:priv get_buffer(instance: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32 {
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

def:priv release_buffer(instance: ptr[PyObject], view: ptr[Py_buffer]) {
    state = state_for(instance);
    if state is not None {
        jacpy_array_export(state.native, -1);
    }
    jacpy_binding_buffer_dispose(view);
}

def:priv reduce(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_long(value) == 0 {
        object_error("TypeError", "__reduce_ex__ argument should be an integer");
        return NULL;
    }
    protocol = PyLong_AsSsize_t(value);
    if jacpy_error_pending() != 0 {
        return NULL;
    }
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    held = ReferenceState(
        references=[PyObject_GetAttrString(module, "_array_reconstructor"), NULL]
    );
    if held.references[0] == 0 {
        return NULL;
    }
    held.references[1] = jacpy_optional_attr(instance, "__dict__");
    if held.references[1] == 0 {
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        held.references[1] = jacpy_none();
    }
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return jacpy_array_reduce(
        state.native,
        Py_TYPE(instance),
        held.references[1],
        held.references[0],
        protocol
    );
}

def:priv reconstruct_bound(args: BoundArguments) -> ptr[PyObject] {
    character = character_value(args.values[1], "_array_reconstructor");
    if character is None {
        return NULL;
    }
    code: i64 = character;
    format = PyLong_AsInt(args.values[2]);
    if jacpy_error_pending() != 0 {
        return NULL;
    }
    if jacpy_is_type(args.values[0]) == 0
        or PyType_IsSubtype(args.values[0], jacpy_binding_state_get(args.context, 0))
            == 0 {
        object_error("TypeError", "first argument must be an array subtype");
        return NULL;
    }
    if jacpy_is_bytes(args.values[3]) == 0 {
        object_error("TypeError", "fourth argument should be bytes");
        return NULL;
    }
    return jacpy_array_reconstruct_object(args.values[0], code, format, args.values[3]);
}

def:priv reconstruct(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(reconstruct_signature, args, NULL, reconstruct_bound, module);
}

def:priv iterate(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    cursor = ArrayIteratorState(native=jacpy_array_cursor_new(instance, state.native));
    result = jacpy_binding_allocate(jacpy_binding_state_get(module, 1));
    if result != 0
        and jacpy_binding_native_set(result, iterator_type.handle, cursor) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:priv iterator_next(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = iterator_state(instance);
    return jacpy_array_cursor_next(state.native) if state is not None else NULL;
}

def:priv iterator_self(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def:priv iterator_setstate(
    instance: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    index = PyLong_AsSsize_t(value);
    if jacpy_error_pending() != 0 {
        return NULL;
    }
    state = iterator_state(instance);
    if state is None {
        return NULL;
    }
    jacpy_array_cursor_set(state.native, index);
    return jacpy_none();
}

def:priv iterator_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    held = ReferenceState(references=[jacpy_builtins(), text_object("iter"), NULL]);
    if held.references[0] == 0 or held.references[1] == 0 {
        return NULL;
    }
    held.references[2] = jacpy_dict_get(held.references[0], held.references[1]);
    if held.references[2] == 0 {
        object_error("RuntimeError", "missing builtin iter");
        return NULL;
    }
    state = iterator_state(instance);
    if state is None {
        return NULL;
    }
    return jacpy_array_cursor_reduce(state.native, held.references[2]);
}

def:priv repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return jacpy_array_repr(state.native);
}

def:priv append(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return done(jacpy_array_insert(state.native, 9223372036854775807, value));
}

def:priv count(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    result = jacpy_array_search(state.native, value, 0, 9223372036854775807, 0);
    return PyLong_FromLongLong(result) if result >= 0 else NULL;
}

def:priv remove(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return done(jacpy_array_search(state.native, value, 0, 9223372036854775807, 2));
}

def:priv clear(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return done(jacpy_array_empty(state.native));
}

def:priv tolist(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return jacpy_array_tolist(state.native);
}

def:priv tobytes(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return jacpy_array_tobytes(state.native);
}

def:priv tounicode(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return jacpy_array_tounicode(state.native);
}

def:priv tofile(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return done(jacpy_array_tofile(state.native, value));
}

def:priv reverse(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    jacpy_array_reverse(state.native, 0);
    return jacpy_none();
}

def:priv byteswap(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    jacpy_array_reverse(state.native, 1);
    return jacpy_none();
}

def:priv array_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, array_type.handle, visitor, context);
}

def:priv array_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, array_type.handle);
}

def:priv array_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, array_type.handle);
}

def:priv iterator_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, iterator_type.handle, visitor, context);
}

def:priv iterator_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, iterator_type.handle);
}

def:priv iterator_dealloc(instance: ptr[PyObject]) {
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
                 MethodCallbacks(positional=Py_GenericAlias),
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

def:priv execute(module: ptr[PyObject]) -> i32 {
    iterator = iterator_type.create(module);
    if iterator == 0 {
        return i32(-1);
    }
    jacpy_binding_state_set(module, 1, iterator);
    jacpy_release(iterator);
    if not add_state_owned(module, 0, "array", array_type.create(module))
        or not add_owned(
            module, "ArrayType", Py_NewRef(jacpy_binding_state_get(module, 0))
        )
        or not add_owned(module, "typecodes", text_object("bBuhHiIlLqQfdw")) {
        return i32(-1);
    }
    held = ReferenceState(
        references=[
            PyImport_ImportModuleAttrString("collections.abc", "MutableSequence"),
            NULL
        ]
    );
    if held.references[0] == 0 {
        return i32(-1);
    }
    held.references[1] = PyObject_GetAttrString(held.references[0], "register");
    if held.references[1] == 0 {
        return i32(-1);
    }
    result = PyObject_CallOneArg(
        held.references[1], jacpy_binding_state_get(module, 0)
    );
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

def:pub PyInit_array -> ptr[PyObject] {
    return definition.initialize();
}
