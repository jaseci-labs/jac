"""Native callable types, descriptors, and ownership for functools."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyCallable_Check,
    PyIndex_Check,
    PyMethod_New,
    PyObject,
    PyObject_GenericGetDict,
    PyObject_GenericSetDict,
    PyObject_GetAttrString,
    PyObject_IsTrue,
    PyObject_RichCompare,
    PyTuple_GetSlice,
    PyTuple_New,
    PyTuple_Size,
    Py_GenericAlias,
    Py_LeaveRecursiveCall,
    Py_NewRef,
    Py_TYPE,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_is_none,
    jacpy_none,
    jacpy_not_implemented,
    jacpy_recursion_enter,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_type_check
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodDefinition,
    MethodCallbacks,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    add_owned,
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
    jacpy_binding_dict_present,
    jacpy_binding_dict_peek,
    jacpy_binding_dict_replace,
    jacpy_binding_marker
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
    dispose_payload,
    clear_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.references { ReferenceState }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke,
    index_value
}
import from jaclang.runtime.python.modules.functools {
    partial_state,
    lru_state,
    jacpy_partial_field,
    jacpy_partial_clear,
    jacpy_partial_init,
    jacpy_partial_call,
    jacpy_partial_restore,
    jacpy_partial_repr,
    jacpy_lru_field,
    jacpy_lru_destroy,
    jacpy_lru_init,
    jacpy_lru_call,
    jacpy_lru_clear,
    jacpy_lru_info,
    jacpy_reduce,
    jacpy_cmp_key
}
import from jaclang.runtime.python.capi { text_object, object_error, boundary_failure }
obj PartialState(NativeState) {
    has native: partial_state;

    def clear {
        jacpy_partial_clear(self.native);
    }

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for i in range(4) {
            status = jacpy_binding_visit(
                jacpy_partial_field(self.native, i64(i)), visitor, context
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

obj LruState(NativeState) {
    has native: lru_state;

    def clear {
        jacpy_lru_destroy(self.native);
    }

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for i in range(7) {
            status = jacpy_binding_visit(
                jacpy_lru_field(self.native, i64(i)), visitor, context
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

obj CacheKeyState(ReferenceState) {
    has hash: i64;
}

def:priv module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv partial_value(instance: ptr[PyObject]) -> (PartialState | None) {
    if jacpy_binding_native_present(instance, partial_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, partial_type.handle);
        if isinstance(state, PartialState) {
            return state;
        }
    }
    object_error("SystemError", "native partial state is unavailable");
    return None;
}

def:priv lru_value(instance: ptr[PyObject]) -> (LruState | None) {
    if jacpy_binding_native_present(instance, lru_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, lru_type.handle);
        if isinstance(state, LruState) {
            return state;
        }
    }
    object_error("SystemError", "native cache state is unavailable");
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
    object_error("SystemError", "native callable references are unavailable");
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

def:priv bind(
    instance: ptr[PyObject], object: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if object == 0 or jacpy_is_none(object) != 0 {
        return Py_NewRef(instance);
    }
    return PyMethod_New(instance, object);
}

def:priv partial_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    count = PyTuple_Size(args);
    if count < 1 {
        object_error("TypeError", "type 'partial' takes at least one argument");
        return NULL;
    }
    # Own every input before allocation or another user callback can collect it.
    held = ReferenceState(references=[jacpy_tuple_item(args, 0), NULL, NULL, NULL]);
    function = held.references[0];
    if function == 0 {
        return NULL;
    }
    if PyCallable_Check(function) == 0 {
        object_error("TypeError", "the first argument must be callable");
        return NULL;
    }
    module = module_for(type);
    if module == 0 {
        return NULL;
    }
    if jacpy_type_check(function, jacpy_binding_state_get(module, 0)) != 0
        and jacpy_binding_dict_present(function) == 0 {
        old = partial_value(function);
        if old is None {
            return NULL;
        }
        held.references[1] = Py_NewRef(old.native.args);
        held.references[2] = Py_NewRef(old.native.keywords);
        fn = Py_NewRef(old.native.function);
        held.references[0] = fn;
        jacpy_release(function);
        function = fn;
    }
    held.references[3] = PyTuple_GetSlice(args, 1, count);
    if held.references[3] == 0 {
        return NULL;
    }
    state = PartialState(native=partial_state());
    if jacpy_partial_init(
        state.native,
        function,
        held.references[3],
        kwargs,
        held.references[1],
        held.references[2],
        jacpy_binding_state_get(module, 5)
    )
        < 0 {
        return NULL;
    }
    return allocate(type, partial_type, state);
}

def:priv partial_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    state = partial_value(instance);
    if state is None {
        return NULL;
    }
    if jacpy_recursion_enter(" while calling a Python object") != 0 {
        return NULL;
    }
    try {
        return jacpy_partial_call(state.native, args, kwargs);
    } finally {
        Py_LeaveRecursiveCall();
    }
}

def:priv partial_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = partial_value(instance);
    if state is None {
        return NULL;
    }
    return jacpy_partial_repr(state.native, instance);
}

def:priv partial_field(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = partial_value(instance);
    if state is None {
        return NULL;
    }
    field = jacpy_partial_field(state.native, i64(context));
    return Py_NewRef(field) if field != 0 else jacpy_none();
}

def:priv partial_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = partial_value(instance);
    if state is None {
        return NULL;
    }
    held = ReferenceState(references=[PyTuple_New(3), PyTuple_New(1), PyTuple_New(4)]);
    if 0 in held.references {
        return NULL;
    }
    saved = held.references[2];
    for i in range(3) {
        field = jacpy_partial_field(state.native, i64(i));
        jacpy_tuple_set_owned(
            saved, i64(i), Py_NewRef(field) if field != 0 else jacpy_none()
        );
    }
    dictionary = jacpy_binding_dict_peek(instance);
    jacpy_tuple_set_owned(saved, 3, dictionary if dictionary != 0 else jacpy_none());
    jacpy_tuple_set_owned(held.references[1], 0, Py_NewRef(state.native.function));
    jacpy_tuple_set_owned(held.references[0], 0, Py_NewRef(Py_TYPE(instance)));
    jacpy_tuple_set_owned(held.references[0], 1, Py_NewRef(held.references[1]));
    jacpy_tuple_set_owned(held.references[0], 2, Py_NewRef(saved));
    return Py_NewRef(held.references[0]);
}

def:priv partial_setstate(
    instance: ptr[PyObject], saved: ptr[PyObject]
) -> ptr[PyObject] {
    state = partial_value(instance);
    if state is None {
        return NULL;
    }
    dictionary = jacpy_partial_restore(state.native, saved);
    if dictionary == 0 {
        return NULL;
    }
    status = jacpy_binding_dict_replace(
        instance, NULL if jacpy_is_none(dictionary) != 0 else dictionary
    );
    jacpy_release(dictionary);
    return jacpy_none() if status == 0 else NULL;
}

# __dict__ accessors for the property table, whose closure is an integer tag.
def:priv generic_get_dict(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    return PyObject_GenericGetDict(instance, ptr());
}

def:priv generic_set_dict(
    instance: ptr[PyObject], value: ptr[PyObject], unused: u64
) -> i32 {
    return PyObject_GenericSetDict(instance, value, ptr());
}

glob:priv key_signature = CallSignature("K", ["obj"], 1, 1);
def:priv key_create(
    type: ptr[PyObject], compare: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    state = ReferenceState(
        references=[Py_NewRef(compare), Py_NewRef(value) if value != 0 else NULL]
    );
    return allocate(type, key_type, state);
}

def:priv key_call_bound(args: BoundArguments) -> ptr[PyObject] {
    state = reference_value(args.context, key_type);
    if state is None {
        return NULL;
    }
    return key_create(Py_TYPE(args.context), state.references[0], args.values[0]);
}

def:priv key_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(key_signature, args, kwargs, key_call_bound, instance);
}

def:priv key_compare(
    instance: ptr[PyObject], other: ptr[PyObject], operation: i32
) -> ptr[PyObject] {
    if Py_TYPE(instance) != Py_TYPE(other) {
        object_error("TypeError", "other argument must be K instance");
        return NULL;
    }
    left = reference_value(instance, key_type);
    right = reference_value(other, key_type);
    if left is None or right is None {
        return NULL;
    }
    if left.references[1] == 0 or right.references[1] == 0 {
        object_error("AttributeError", "object");
        return NULL;
    }
    return jacpy_cmp_key(
        left.references[0], left.references[1], right.references[1], i64(operation)
    );
}

def:priv key_object(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = reference_value(instance, key_type);
    if state is None {
        return NULL;
    }
    value = state.references[1];
    return Py_NewRef(value) if value != 0 else jacpy_none();
}

def:priv key_set_object(
    instance: ptr[PyObject], value: ptr[PyObject], unused: u64
) -> i32 {
    state = reference_value(instance, key_type);
    if state is None {
        return i32(-1);
    }
    old = state.references[1];
    state.references[1] = Py_NewRef(value) if value != 0 else NULL;
    jacpy_release(old);
    return i32(0);
}

def:priv key_text_signature(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    return text_object("(obj)");
}

def:priv make_cache_key(
    type_handle: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> ptr[PyObject] {
    state = CacheKeyState(references=[Py_NewRef(key)], hash=hash);
    return allocate(type_handle, hashed_type, state);
}

def:priv hashed_hash(instance: ptr[PyObject]) -> i64 {
    state = reference_value(instance, hashed_type);
    if isinstance(state, CacheKeyState) {
        return state.hash;
    }
    return -1;
}

def:priv hashed_compare(
    instance: ptr[PyObject], other: ptr[PyObject], operation: i32
) -> ptr[PyObject] {
    if Py_TYPE(instance) != Py_TYPE(other) {
        return jacpy_not_implemented();
    }
    left = reference_value(instance, hashed_type);
    right = reference_value(other, hashed_type);
    if left is None or right is None {
        return NULL;
    }
    return PyObject_RichCompare(
        left.references[0], right.references[0], i32(operation)
    );
}

glob:priv lru_signature = CallSignature(
         "lru_cache", ["user_function", "maxsize", "typed", "cache_info_type"], 4, 4
     );

def:priv lru_create_bound(args: BoundArguments) -> ptr[PyObject] {
    if PyCallable_Check(args.values[0]) == 0 {
        object_error("TypeError", "the first argument must be callable");
        return NULL;
    }
    maximum: i64 = -1;
    if jacpy_is_none(args.values[1]) == 0 {
        if PyIndex_Check(args.values[1]) == 0 {
            object_error("TypeError", "maxsize should be integer or None");
            return NULL;
        }
        value = index_value(args.values[1]);
        if value is None {
            return NULL;
        }
        maximum = value if value > 0 else i64(0);
    }
    typed = PyObject_IsTrue(args.values[2]);
    if typed < 0 {
        return NULL;
    }
    module = module_for(args.context);
    if module == 0 {
        return NULL;
    }
    state = LruState(native=lru_state(key_factory=make_cache_key));
    if jacpy_lru_init(
        state.native,
        args.values[0],
        maximum,
        typed,
        args.values[3],
        jacpy_binding_state_get(module, 3),
        jacpy_binding_state_get(module, 6)
    )
        < 0 {
        return NULL;
    }
    return allocate(args.context, lru_type, state);
}

def:priv lru_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(lru_signature, args, kwargs, lru_create_bound, type);
}

def:priv lru_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    state = lru_value(instance);
    if state is None {
        return NULL;
    }
    if jacpy_recursion_enter(" while calling a Python object") != 0 {
        return NULL;
    }
    try {
        return jacpy_lru_call(state.native, args, kwargs);
    } finally {
        Py_LeaveRecursiveCall();
    }
}

def:priv lru_cache_clear(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = lru_value(instance);
    if state is None {
        return NULL;
    }
    return jacpy_none() if jacpy_lru_clear(state.native) == 0 else NULL;
}

def:priv lru_cache_info(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = lru_value(instance);
    if state is None {
        return NULL;
    }
    return jacpy_lru_info(state.native);
}

def:priv lru_reduce(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_GetAttrString(instance, "__qualname__");
}

def:priv lru_copy(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def:priv placeholder_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if PyTuple_Size(args) != 0 or (kwargs != 0 and jacpy_dict_size(kwargs) != 0) {
        object_error("TypeError", "Placeholder takes no arguments");
        return NULL;
    }
    module = module_for(type);
    if module == 0 {
        return NULL;
    }
    return Py_NewRef(jacpy_binding_state_get(module, 5));
}

def:priv placeholder_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return text_object("Placeholder");
}

def:priv placeholder_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return text_object("Placeholder");
}

glob:priv reduce_signature = CallSignature(
         "reduce", ["function", "iterable", "initial"], 2, 3, 2
     ),
     cmp_signature = CallSignature("cmp_to_key", ["mycmp"], 1, 1);

def:priv reduce_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_reduce(args.values[0], args.values[1], args.values[2]);
}

def:priv reduce(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(reduce_signature, args, kwargs, reduce_bound);
}

def:priv cmp_bound(args: BoundArguments) -> ptr[PyObject] {
    return key_create(jacpy_binding_state_get(args.context, 1), args.values[0], NULL);
}

def:priv cmp_to_key(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(cmp_signature, args, kwargs, cmp_bound, module);
}

def:priv partial_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, partial_type.handle, visitor, context);
}

def:priv partial_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, partial_type.handle);
}

def:priv partial_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, partial_type.handle);
}

def:priv key_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, key_type.handle, visitor, context);
}

def:priv key_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, key_type.handle);
}

def:priv key_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, key_type.handle);
}

def:priv hashed_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, hashed_type.handle, visitor, context);
}

def:priv hashed_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, hashed_type.handle);
}

def:priv hashed_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, hashed_type.handle);
}

def:priv lru_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, lru_type.handle, visitor, context);
}

def:priv lru_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, lru_type.handle);
}

def:priv lru_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, lru_type.handle);
}

def:priv placeholder_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, placeholder_type.handle, visitor, context);
}

def:priv placeholder_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, placeholder_type.handle);
}

def:priv placeholder_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, placeholder_type.handle);
}

glob:priv callable_flags = u64(
         TypeFlags.GC.value
             | TypeFlags.IMMUTABLE.value
             | TypeFlags.BASETYPE.value
             | TypeFlags.MANAGED_WEAKREF.value
     ),
     sealed_flags = u64(
         TypeFlags.GC.value
             | TypeFlags.IMMUTABLE.value
             | TypeFlags.DISALLOW_INSTANTIATION.value
     ),
     partial_type = TypeDefinition(
         "functools.partial",
         "partial(func, /, *args, **keywords)\n--\n\nCreate a new function with partial application of the given arguments\nand keywords.",
         [
             MethodDefinition(
                 "__reduce__", MethodCallbacks(positional=partial_reduce), "", flags=4
             ),
             MethodDefinition(
                 "__setstate__",
                 MethodCallbacks(positional=partial_setstate),
                 "",
                 flags=8
             ),
             MethodDefinition(
                 "__class_getitem__",
                 MethodCallbacks(positional=Py_GenericAlias),
                 "partial is generic over the wrapped function's return type",
                 flags=24
             )
         ],
         callable_flags,
         TypeHooks(
             create=partial_create,
             dealloc=partial_dealloc,
             traverse=partial_traverse,
             clear=partial_clear,
             call=partial_call,
             repr=partial_repr,
             descriptor=bind
         ),
         [
             PropertyDefinition(
                 "func",
                 PropertyCallbacks(read=partial_field),
                 context=0,
                 doc="function object to use in future partial calls"
             ),
             PropertyDefinition(
                 "args",
                 PropertyCallbacks(read=partial_field),
                 context=1,
                 doc="tuple of arguments to future partial calls"
             ),
             PropertyDefinition(
                 "keywords",
                 PropertyCallbacks(read=partial_field),
                 context=2,
                 doc="dictionary of keyword arguments to future partial calls"
             ),
             PropertyDefinition(
                 "__dict__",
                 PropertyCallbacks(read=generic_get_dict, write=generic_set_dict)
             )
         ],
         instance_dict=True
     ),
     key_type = TypeDefinition(
         "functools.KeyWrapper",
         "",
         [],
         sealed_flags,
         TypeHooks(
             dealloc=key_dealloc,
             traverse=key_traverse,
             clear=key_clear,
             call=key_call,
             compare=key_compare,
         ),
         [
             PropertyDefinition(
                 "obj",
                 PropertyCallbacks(read=key_object, write=key_set_object),
                 doc="Value wrapped by a key function."
             ),
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=key_text_signature)
             )
         ],
         unhashable=True
     ),
     hashed_type = TypeDefinition(
         "functools._CacheKey",
         "",
         [],
         sealed_flags,
         TypeHooks(
             dealloc=hashed_dealloc,
             traverse=hashed_traverse,
             clear=hashed_clear,
             hash=hashed_hash,
             compare=hashed_compare
         )
     ),
     lru_type = TypeDefinition(
         "functools._lru_cache_wrapper",
         "Create a cached callable that wraps another function.",
         [
             MethodDefinition(
                 "cache_clear",
                 MethodCallbacks(positional=lru_cache_clear),
                 "cache_clear($self, /)\n--\n\nClear the cache and cache statistics",
                 flags=4
             ),
             MethodDefinition(
                 "cache_info",
                 MethodCallbacks(positional=lru_cache_info),
                 "cache_info($self, /)\n--\n\nReport cache statistics",
                 flags=4
             ),
             MethodDefinition(
                 "__reduce__", MethodCallbacks(positional=lru_reduce), "", flags=4
             ),
             MethodDefinition(
                 "__copy__", MethodCallbacks(positional=lru_copy), "", flags=1
             ),
             MethodDefinition(
                 "__deepcopy__", MethodCallbacks(positional=lru_copy), "", flags=1
             )
         ],
         callable_flags,
         TypeHooks(
             create=lru_create,
             dealloc=lru_dealloc,
             traverse=lru_traverse,
             clear=lru_clear,
             call=lru_call,
             descriptor=bind
         ),
         [
             PropertyDefinition(
                 "__dict__",
                 PropertyCallbacks(read=generic_get_dict, write=generic_set_dict)
             )
         ],
         instance_dict=True
     ),
     placeholder_type = TypeDefinition(
         "functools._PlaceholderType",
         "",
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=placeholder_reduce),
                 "",
                 flags=4
             )
         ],
         u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=placeholder_create,
             repr=placeholder_repr,
             traverse=placeholder_traverse,
             dealloc=placeholder_dealloc
         )
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    declarations = [partial_type, key_type, lru_type, hashed_type, placeholder_type];
    for i in range(len(declarations)) {
        type = declarations[i].create(module);
        if type == 0 {
            return i32(-1);
        }
        jacpy_binding_state_set(module, i64(i), type);
        jacpy_release(type);
    }
    placeholder = jacpy_binding_allocate(jacpy_binding_state_get(module, 4));
    if placeholder == 0 {
        return i32(-1);
    }
    jacpy_binding_state_set(module, 5, placeholder);
    jacpy_release(placeholder);
    marker = jacpy_binding_marker();
    if marker == 0 {
        return i32(-1);
    }
    jacpy_binding_state_set(module, 6, marker);
    jacpy_release(marker);
    if not add_owned(module, "partial", Py_NewRef(jacpy_binding_state_get(module, 0)))
        or not add_owned(
            module, "_lru_cache_wrapper", Py_NewRef(jacpy_binding_state_get(module, 2))
        )
        or not add_owned(
            module, "Placeholder", Py_NewRef(jacpy_binding_state_get(module, 5))
        ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_functools",
         "Native Jac callable policies.",
         [
             MethodDefinition(
                 "reduce",
                 MethodCallbacks(keywords=reduce),
                 "reduce($module, function, iterable, /, initial=<unrepresentable>)\n--\n\nApply a function of two arguments cumulatively to the items of an iterable."
             ),
             MethodDefinition(
                 "cmp_to_key",
                 MethodCallbacks(keywords=cmp_to_key),
                 "cmp_to_key($module, /, mycmp)\n--\n\nConvert a cmp= function into a key= function."
             )
         ],
         hooks=ModuleHooks(execute=execute),
         state_count=7
     );

def:pub PyInit__functools -> ptr[PyObject] {
    return definition.initialize();
}
