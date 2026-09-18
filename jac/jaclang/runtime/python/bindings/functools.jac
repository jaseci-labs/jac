"""Native callable types, descriptors, and ownership for functools."""
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
    jacpy_binding_typeof,
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_dict_present,
    jacpy_binding_dict_get,
    jacpy_binding_dict_set,
    jacpy_binding_dict_peek,
    jacpy_binding_dict_replace,
    jacpy_binding_method_bind,
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
import from jaclang.runtime.python.capi {
    jacpy_recursion_enter,
    jacpy_recursion_leave,
    jacpy_release,
    jacpy_retain,
    jacpy_none,
    jacpy_is_none,
    jacpy_not_implemented,
    jacpy_callable,
    jacpy_type_check,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_tuple_slice,
    jacpy_tuple_new,
    jacpy_tuple_set_owned,
    jacpy_dict_size,
    jacpy_truth,
    jacpy_index_check,
    jacpy_getattr_string,
    jacpy_compare,
    jacpy_error_pending,
    text_object,
    object_error,
    boundary_failure
}
import from c { def jacpy_binding_generic_alias(type: u64, item: u64) -> u64;  }

obj PartialState(NativeState) {
    has native: partial_state;

    def clear {
        jacpy_partial_clear(self.native);
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
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

    def traverse_refs(visitor: u64, context: u64) -> i32 {
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

def:priv module_for(type: u64) -> u64 {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv partial_value(instance: u64) -> (PartialState | None) {
    if jacpy_binding_native_present(instance, partial_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, partial_type.handle);
        if isinstance(state, PartialState) {
            return state;
        }
    }
    object_error("SystemError", "native partial state is unavailable");
    return None;
}

def:priv lru_value(instance: u64) -> (LruState | None) {
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
    instance: u64, type: TypeDefinition
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

def:priv allocate(type: u64, declaration: TypeDefinition, state: NativeState) -> u64 {
    instance = jacpy_binding_allocate(type);
    if instance != 0
        and jacpy_binding_native_set(instance, declaration.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv bind(instance: u64, object: u64, type: u64) -> u64 {
    if object == 0 or jacpy_is_none(object) != 0 {
        return jacpy_retain(instance);
    }
    return jacpy_binding_method_bind(instance, object);
}

def:priv partial_create(type: u64, args: u64, kwargs: u64) -> u64 {
    count = jacpy_tuple_size(args);
    if count < 1 {
        object_error("TypeError", "type 'partial' takes at least one argument");
        return 0;
    }
    # Own every input before allocation or another user callback can collect it.
    held = ReferenceState(
        references=[jacpy_tuple_item(args, 0), u64(0), u64(0), u64(0)]
    );
    function = held.references[0];
    if function == 0 {
        return 0;
    }
    if jacpy_callable(function) == 0 {
        object_error("TypeError", "the first argument must be callable");
        return 0;
    }
    module = module_for(type);
    if module == 0 {
        return 0;
    }
    if jacpy_type_check(function, jacpy_binding_state_get(module, 0)) != 0
        and jacpy_binding_dict_present(function) == 0 {
        old = partial_value(function);
        if old is None {
            return 0;
        }
        held.references[1] = jacpy_retain(old.native.args);
        held.references[2] = jacpy_retain(old.native.keywords);
        fn = jacpy_retain(old.native.function);
        held.references[0] = fn;
        jacpy_release(function);
        function = fn;
    }
    held.references[3] = jacpy_tuple_slice(args, 1, count);
    if held.references[3] == 0 {
        return 0;
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
        return 0;
    }
    return allocate(type, partial_type, state);
}

def:priv partial_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    state = partial_value(instance);
    if state is None {
        return 0;
    }
    if jacpy_recursion_enter(" while calling a Python object") != 0 {
        return 0;
    }
    try {
        return jacpy_partial_call(state.native, args, kwargs);
    } finally {
        jacpy_recursion_leave();
    }
}

def:priv partial_repr(instance: u64) -> u64 {
    state = partial_value(instance);
    if state is None {
        return 0;
    }
    return jacpy_partial_repr(state.native, instance);
}

def:priv partial_field(instance: u64, context: u64) -> u64 {
    state = partial_value(instance);
    if state is None {
        return 0;
    }
    field = jacpy_partial_field(state.native, i64(context));
    return jacpy_retain(field) if field != 0 else jacpy_none();
}

def:priv partial_reduce(instance: u64, unused: u64) -> u64 {
    state = partial_value(instance);
    if state is None {
        return 0;
    }
    held = ReferenceState(
        references=[jacpy_tuple_new(3), jacpy_tuple_new(1), jacpy_tuple_new(4)]
    );
    if 0 in held.references {
        return 0;
    }
    saved = held.references[2];
    for i in range(3) {
        field = jacpy_partial_field(state.native, i64(i));
        jacpy_tuple_set_owned(
            saved, i64(i), jacpy_retain(field) if field != 0 else jacpy_none()
        );
    }
    dictionary = jacpy_binding_dict_peek(instance);
    jacpy_tuple_set_owned(saved, 3, dictionary if dictionary != 0 else jacpy_none());
    jacpy_tuple_set_owned(held.references[1], 0, jacpy_retain(state.native.function));
    jacpy_tuple_set_owned(
        held.references[0], 0, jacpy_retain(jacpy_binding_typeof(instance))
    );
    jacpy_tuple_set_owned(held.references[0], 1, jacpy_retain(held.references[1]));
    jacpy_tuple_set_owned(held.references[0], 2, jacpy_retain(saved));
    return jacpy_retain(held.references[0]);
}

def:priv partial_setstate(instance: u64, saved: u64) -> u64 {
    state = partial_value(instance);
    if state is None {
        return 0;
    }
    dictionary = jacpy_partial_restore(state.native, saved);
    if dictionary == 0 {
        return 0;
    }
    status = jacpy_binding_dict_replace(
        instance, u64(0) if jacpy_is_none(dictionary) != 0 else dictionary
    );
    jacpy_release(dictionary);
    return jacpy_none() if status == 0 else u64(0);
}

glob:priv key_signature = CallSignature("K", ["obj"], 1, 1);
def:priv key_create(type: u64, compare: u64, value: u64) -> u64 {
    state = ReferenceState(
        references=[
            jacpy_retain(compare),
            jacpy_retain(value) if value != 0 else u64(0)
        ]
    );
    return allocate(type, key_type, state);
}

def:priv key_call_bound(args: BoundArguments) -> u64 {
    state = reference_value(args.context, key_type);
    if state is None {
        return 0;
    }
    return key_create(
        jacpy_binding_typeof(args.context), state.references[0], args.values[0]
    );
}

def:priv key_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(key_signature, args, kwargs, key_call_bound, instance);
}

def:priv key_compare(instance: u64, other: u64, operation: i32) -> u64 {
    if jacpy_binding_typeof(instance) != jacpy_binding_typeof(other) {
        object_error("TypeError", "other argument must be K instance");
        return 0;
    }
    left = reference_value(instance, key_type);
    right = reference_value(other, key_type);
    if left is None or right is None {
        return 0;
    }
    if left.references[1] == 0 or right.references[1] == 0 {
        object_error("AttributeError", "object");
        return 0;
    }
    return jacpy_cmp_key(
        left.references[0], left.references[1], right.references[1], i64(operation)
    );
}

def:priv key_object(instance: u64, unused: u64) -> u64 {
    state = reference_value(instance, key_type);
    if state is None {
        return 0;
    }
    value = state.references[1];
    return jacpy_retain(value) if value != 0 else jacpy_none();
}

def:priv key_set_object(instance: u64, value: u64, unused: u64) -> i32 {
    state = reference_value(instance, key_type);
    if state is None {
        return i32(-1);
    }
    old = state.references[1];
    state.references[1] = jacpy_retain(value) if value != 0 else u64(0);
    jacpy_release(old);
    return i32(0);
}

def:priv key_text_signature(instance: u64, unused: u64) -> u64 {
    return text_object("(obj)");
}

def:priv make_cache_key(type_handle: u64, key: u64, hash: i64) -> u64 {
    state = CacheKeyState(references=[jacpy_retain(key)], hash=hash);
    return allocate(type_handle, hashed_type, state);
}

def:priv hashed_hash(instance: u64) -> i64 {
    state = reference_value(instance, hashed_type);
    if isinstance(state, CacheKeyState) {
        return state.hash;
    }
    return -1;
}

def:priv hashed_compare(instance: u64, other: u64, operation: i32) -> u64 {
    if jacpy_binding_typeof(instance) != jacpy_binding_typeof(other) {
        return jacpy_not_implemented();
    }
    left = reference_value(instance, hashed_type);
    right = reference_value(other, hashed_type);
    if left is None or right is None {
        return 0;
    }
    return jacpy_compare(left.references[0], right.references[0], i64(operation));
}

glob:priv lru_signature = CallSignature(
         "lru_cache", ["user_function", "maxsize", "typed", "cache_info_type"], 4, 4
     );

def:priv lru_create_bound(args: BoundArguments) -> u64 {
    if jacpy_callable(args.values[0]) == 0 {
        object_error("TypeError", "the first argument must be callable");
        return 0;
    }
    maximum: i64 = -1;
    if jacpy_is_none(args.values[1]) == 0 {
        if jacpy_index_check(args.values[1]) == 0 {
            object_error("TypeError", "maxsize should be integer or None");
            return 0;
        }
        value = index_value(args.values[1]);
        if value is None {
            return 0;
        }
        maximum = value if value > 0 else i64(0);
    }
    typed = jacpy_truth(args.values[2]);
    if typed < 0 {
        return 0;
    }
    module = module_for(args.context);
    if module == 0 {
        return 0;
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
        return 0;
    }
    return allocate(args.context, lru_type, state);
}

def:priv lru_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(lru_signature, args, kwargs, lru_create_bound, type);
}

def:priv lru_call(instance: u64, args: u64, kwargs: u64) -> u64 {
    state = lru_value(instance);
    if state is None {
        return 0;
    }
    if jacpy_recursion_enter(" while calling a Python object") != 0 {
        return 0;
    }
    try {
        return jacpy_lru_call(state.native, args, kwargs);
    } finally {
        jacpy_recursion_leave();
    }
}

def:priv lru_cache_clear(instance: u64, unused: u64) -> u64 {
    state = lru_value(instance);
    if state is None {
        return 0;
    }
    return jacpy_none() if jacpy_lru_clear(state.native) == 0 else u64(0);
}

def:priv lru_cache_info(instance: u64, unused: u64) -> u64 {
    state = lru_value(instance);
    if state is None {
        return 0;
    }
    return jacpy_lru_info(state.native);
}

def:priv lru_reduce(instance: u64, unused: u64) -> u64 {
    return jacpy_getattr_string(instance, "__qualname__");
}

def:priv lru_copy(instance: u64, unused: u64) -> u64 {
    return jacpy_retain(instance);
}

def:priv placeholder_create(type: u64, args: u64, kwargs: u64) -> u64 {
    if jacpy_tuple_size(args) != 0 or (kwargs != 0 and jacpy_dict_size(kwargs) != 0) {
        object_error("TypeError", "Placeholder takes no arguments");
        return 0;
    }
    module = module_for(type);
    if module == 0 {
        return 0;
    }
    return jacpy_retain(jacpy_binding_state_get(module, 5));
}

def:priv placeholder_repr(instance: u64) -> u64 {
    return text_object("Placeholder");
}

def:priv placeholder_reduce(instance: u64, unused: u64) -> u64 {
    return text_object("Placeholder");
}

glob:priv reduce_signature = CallSignature(
         "reduce", ["function", "iterable", "initial"], 2, 3, 2
     ),
     cmp_signature = CallSignature("cmp_to_key", ["mycmp"], 1, 1);

def:priv reduce_bound(args: BoundArguments) -> u64 {
    return jacpy_reduce(args.values[0], args.values[1], args.values[2]);
}

def:priv reduce(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(reduce_signature, args, kwargs, reduce_bound);
}

def:priv cmp_bound(args: BoundArguments) -> u64 {
    return key_create(jacpy_binding_state_get(args.context, 1), args.values[0], 0);
}

def:priv cmp_to_key(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(cmp_signature, args, kwargs, cmp_bound, module);
}

def:priv partial_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, partial_type.handle, visitor, context);
}

def:priv partial_clear(instance: u64) -> i32 {
    return clear_payload(instance, partial_type.handle);
}

def:priv partial_dealloc(instance: u64) {
    dispose_payload(instance, partial_type.handle);
}

def:priv key_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, key_type.handle, visitor, context);
}

def:priv key_clear(instance: u64) -> i32 {
    return clear_payload(instance, key_type.handle);
}

def:priv key_dealloc(instance: u64) {
    dispose_payload(instance, key_type.handle);
}

def:priv hashed_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, hashed_type.handle, visitor, context);
}

def:priv hashed_clear(instance: u64) -> i32 {
    return clear_payload(instance, hashed_type.handle);
}

def:priv hashed_dealloc(instance: u64) {
    dispose_payload(instance, hashed_type.handle);
}

def:priv lru_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, lru_type.handle, visitor, context);
}

def:priv lru_clear(instance: u64) -> i32 {
    return clear_payload(instance, lru_type.handle);
}

def:priv lru_dealloc(instance: u64) {
    dispose_payload(instance, lru_type.handle);
}

def:priv placeholder_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, placeholder_type.handle, visitor, context);
}

def:priv placeholder_clear(instance: u64) -> i32 {
    return clear_payload(instance, placeholder_type.handle);
}

def:priv placeholder_dealloc(instance: u64) {
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
                 MethodCallbacks(positional=jacpy_binding_generic_alias),
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
                 PropertyCallbacks(
                     read=jacpy_binding_dict_get, write=jacpy_binding_dict_set
                 )
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
                 PropertyCallbacks(
                     read=jacpy_binding_dict_get, write=jacpy_binding_dict_set
                 )
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

def:priv execute(module: u64) -> i32 {
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
    if not add_owned(
        module, "partial", jacpy_retain(jacpy_binding_state_get(module, 0))
    )
        or not add_owned(
            module,
            "_lru_cache_wrapper",
            jacpy_retain(jacpy_binding_state_get(module, 2))
        )
        or not add_owned(
            module, "Placeholder", jacpy_retain(jacpy_binding_state_get(module, 5))
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

def:pub PyInit__functools -> u64 {
    return definition.initialize();
}
