"""Struct bindings with owned format plans and exported-buffer iterators."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception,
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
    jacpy_binding_allocate
}
import from jaclang.runtime.python.bindings.payload {
    NativeState,
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
    invoke
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_retain,
    jacpy_is_unicode,
    jacpy_is_bytes,
    jacpy_unicode_encode,
    jacpy_bytes_decode,
    jacpy_bytes_from_memory,
    jacpy_bytes_address,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_tuple_slice,
    jacpy_dict_new,
    jacpy_dict_clear,
    jacpy_error_pending,
    jacpy_int,
    jacpy_none,
    jacpy_set_exception,
    object_error,
    type_name,
    text_object,
    repr_value,
    boundary_failure,
    jac_heap_size,
    jac_list_heap_size
}
import from jaclang.runtime.python.modules.struct {
    struct_plan,
    unpack_cursor,
    jacpy_struct_compile,
    jacpy_struct_size,
    jacpy_struct_items,
    jacpy_struct_pack,
    jacpy_struct_unpack,
    jacpy_struct_offset,
    jacpy_struct_cursor,
    jacpy_struct_remaining,
    jacpy_struct_next,
    jacpy_struct_cached,
    jacpy_struct_memory
}
import from c {
    def jacpy_binding_basicsize(instance: u64) -> i64;  def jacpy_number_ssize(
        value: u64, overflow: str
    ) -> i64;
}

obj StructState(ReferenceState) {
    has plan: struct_plan;
}

obj UnpackState(NativeState) {
    has cursor: (unpack_cursor | None) = None,
        buffer: (BufferArgument | None) = None,
        owner: u64 = 0;

    def clear {
        previous_owner = self.owner;
        previous_buffer = self.buffer;
        self.cursor = None;
        self.buffer = None;
        self.owner = 0;
        if previous_buffer is not None {
            previous_buffer.close();
        }
        jacpy_release(previous_owner);
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        status = jacpy_binding_visit(self.owner, visitor, context);
        if status != 0 {
            return status;
        }
        buffer = self.buffer;
        if buffer is not None {
            return jacpy_binding_visit(buffer.owner(), visitor, context);
        }
        return i32(0);
    }

    def drop {
        self.clear();
    }
}

def:priv state_for(instance: u64) -> (StructState | None) {
    if jacpy_binding_native_present(instance, struct_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, struct_type.handle);
        if isinstance(state, StructState) and state.references[0] != 0 {
            return state;
        }
    }
    object_error("RuntimeError", "Struct object is not initialized");
    return None;
}

def:priv module_for(instance: u64) -> u64 {
    return jacpy_binding_owner(jacpy_binding_typeof(instance), definition.handle);
}

def:priv struct_error(module: u64, message: str) {
    jacpy_set_exception(
        jacpy_binding_state_get(module, 0), message, i64(len(message.encode("utf-8")))
    );
}

def:priv create(type: u64, args: u64, kwargs: u64) -> u64 {
    return jacpy_binding_allocate(type);
}

glob:priv init_signature = CallSignature("Struct", ["format"], 1, 1);

def:priv initialize_bound(args: BoundArguments) -> u64 {
    source = args.values[0];
    format: u64 = 0;
    if jacpy_is_unicode(source) != 0 {
        format = jacpy_unicode_encode(source, "ascii", "strict");
    } elif jacpy_is_bytes(source) != 0 {
        format = jacpy_retain(source);
    } else {
        object_error(
            "TypeError",
            f"Struct() argument 1 must be a str or bytes object, not {type_name(source)[:200]}"
        );
        return 0;
    }
    if format == 0 {
        return 0;
    }
    state = StructState(references=[format], plan=struct_plan());
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    if jacpy_struct_compile(state.plan, format, jacpy_binding_state_get(module, 0))
        < 0 {
        return 0;
    }
    if jacpy_binding_native_set(args.context, struct_type.handle, state) < 0 {
        return 0;
    }
    return jacpy_none();
}

def:priv initialize(instance: u64, args: u64, kwargs: u64) -> i32 {
    result = invoke(init_signature, args, kwargs, initialize_bound, instance);
    if result == 0 {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

def:priv format_property(instance: u64, context: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_bytes_decode(state.references[0], "utf-8", "strict");
}

def:priv size_property(instance: u64, context: u64) -> u64 {
    if jacpy_binding_native_present(instance, struct_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, struct_type.handle);
        if isinstance(state, StructState) and state.references[0] != 0 {
            return jacpy_int(jacpy_struct_size(state.plan));
        }
    }
    return jacpy_int(-1);
}

def:priv representation(instance: u64) -> u64 {
    format = format_property(instance, 0);
    if format == 0 {
        return 0;
    }
    try {
        name = type_name(instance).split(".")[-1];
        return text_object(f"{name}({repr_value(format)})");
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(format);
    }
}

def:priv memory_size(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_int(
        jacpy_binding_basicsize(instance)
            + jacpy_struct_memory(state.plan)
            + jac_heap_size(u64(id(state)))
            + jac_list_heap_size(u64(id(state.references)))
    );
}

def:priv pack(instance: u64, args: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    plan = state.plan;
    module = module_for(instance);
    if module == 0 {
        return 0;
    }
    count = jacpy_tuple_size(args);
    expected = jacpy_struct_items(plan);
    if count != expected {
        struct_error(
            module, f"pack expected {expected} items for packing (got {count})"
        );
        return 0;
    }
    result = jacpy_bytes_from_memory(0, jacpy_struct_size(plan));
    if result != 0
        and jacpy_struct_pack(
            plan,
            args,
            0,
            jacpy_bytes_address(result),
            jacpy_binding_state_get(module, 0)
        )
            < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv pack_into(instance: u64, args: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    plan = state.plan;
    module = module_for(instance);
    if module == 0 {
        return 0;
    }
    count = jacpy_tuple_size(args);
    expected = jacpy_struct_items(plan);
    if count < 2 {
        struct_error(
            module,
            "pack_into expected offset argument"
                if count != 0
                else "pack_into expected buffer argument"
        );
        return 0;
    }
    if count - 2 != expected {
        struct_error(
            module, f"pack_into expected {expected} items for packing (got {count - 2})"
        );
        return 0;
    }
    buffer = BufferArgument();
    source = jacpy_tuple_item(args, 0);
    acquired = buffer.acquire_writable(source);
    jacpy_release(source);
    if not acquired {
        return 0;
    }
    offset_object = jacpy_tuple_item(args, 1);
    offset = jacpy_number_ssize(offset_object, "IndexError");
    jacpy_release(offset_object);
    if jacpy_error_pending() != 0 {
        return 0;
    }
    error = jacpy_binding_state_get(module, 0);
    offset = jacpy_struct_offset(plan, buffer.size(), offset, 1, error);
    if offset < 0 {
        return 0;
    }
    if jacpy_struct_pack(plan, args, 2, buffer.address() + u64(offset), error) < 0 {
        return 0;
    }
    return jacpy_none();
}

glob:priv unpack_signature = CallSignature("unpack", ["buffer"], 1, 1, 1),
     unpack_from_signature = CallSignature("unpack_from", ["buffer", "offset"], 1, 2),
     iter_unpack_signature = CallSignature("iter_unpack", ["buffer"], 1, 1, 1);

def:priv unpack_bound(args: BoundArguments) -> u64 {
    state = state_for(args.context);
    if state is None {
        return 0;
    }
    plan = state.plan;
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    buffer = BufferArgument();
    if not buffer.acquire(args.values[0]) {
        return 0;
    }
    size = jacpy_struct_size(plan);
    if buffer.size() != size {
        struct_error(module, f"unpack requires a buffer of {size} bytes");
        return 0;
    }
    return jacpy_struct_unpack(plan, buffer.address());
}

def:priv unpack(instance: u64, args: u64, kwargs: u64) -> u64 {
    if state_for(instance) is None {
        return 0;
    }
    return invoke(unpack_signature, args, kwargs, unpack_bound, instance);
}

def:priv unpack_from_bound(args: BoundArguments) -> u64 {
    state = state_for(args.context);
    if state is None {
        return 0;
    }
    plan = state.plan;
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    buffer = BufferArgument();
    if not buffer.acquire(args.values[0]) {
        return 0;
    }
    offset = jacpy_number_ssize(args.values[1], "IndexError")
        if args.values[1] != 0
        else i64(0);
    if jacpy_error_pending() != 0 {
        return 0;
    }
    offset = jacpy_struct_offset(
        plan, buffer.size(), offset, 0, jacpy_binding_state_get(module, 0)
    );
    if offset < 0 {
        return 0;
    }
    return jacpy_struct_unpack(plan, buffer.address() + u64(offset));
}

def:priv unpack_from(instance: u64, args: u64, kwargs: u64) -> u64 {
    if state_for(instance) is None {
        return 0;
    }
    return invoke(unpack_from_signature, args, kwargs, unpack_from_bound, instance);
}

def:priv iterator_state(instance: u64) -> (UnpackState | None) {
    if jacpy_binding_native_present(instance, iterator_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, iterator_type.handle);
        if isinstance(state, UnpackState) {
            return state;
        }
    }
    return None;
}

def:priv iterator_next(instance: u64) -> u64 {
    state = iterator_state(instance);
    if state is None {
        return 0;
    }
    cursor = state.cursor;
    if cursor is None {
        return 0;
    }
    if jacpy_struct_remaining(cursor) == 0 {
        state.clear();
        return 0;
    }
    return jacpy_struct_next(cursor);
}

def:priv iterator_self(instance: u64) -> u64 {
    return jacpy_retain(instance);
}

def:priv iterator_hint(instance: u64, unused: u64) -> u64 {
    state = iterator_state(instance);
    if state is not None {
        cursor = state.cursor;
        if cursor is not None {
            return jacpy_int(jacpy_struct_remaining(cursor));
        }
    }
    return jacpy_int(0);
}

def:priv iter_unpack_bound(args: BoundArguments) -> u64 {
    state = state_for(args.context);
    if state is None {
        return 0;
    }
    plan = state.plan;
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    size = jacpy_struct_size(plan);
    if size == 0 {
        struct_error(module, "cannot iteratively unpack with a struct of length 0");
        return 0;
    }
    iterator = jacpy_binding_allocate(jacpy_binding_state_get(module, 2));
    if iterator == 0 {
        return 0;
    }
    buffer = BufferArgument();
    iterator_data = UnpackState(buffer=buffer);
    if jacpy_binding_native_set(iterator, iterator_type.handle, iterator_data) < 0 {
        jacpy_release(iterator);
        return 0;
    }
    if not buffer.acquire(args.values[0]) {
        jacpy_release(iterator);
        return 0;
    }
    if buffer.size() % size != 0 {
        struct_error(
            module,
            f"iterative unpacking requires a buffer of a multiple of {size} bytes"
        );
        jacpy_release(iterator);
        return 0;
    }
    iterator_data.owner = jacpy_retain(args.context);
    iterator_data.cursor = jacpy_struct_cursor(plan, buffer.address(), buffer.size());
    return iterator;
}

def:priv iter_unpack(instance: u64, args: u64, kwargs: u64) -> u64 {
    if state_for(instance) is None {
        return 0;
    }
    return invoke(iter_unpack_signature, args, kwargs, iter_unpack_bound, instance);
}

def:priv deallocate(instance: u64) {
    dispose_payload(instance, struct_type.handle);
}

def:priv clear(instance: u64) -> i32 {
    return clear_payload(instance, struct_type.handle);
}

def:priv traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, struct_type.handle, visitor, context);
}

def:priv iterator_deallocate(instance: u64) {
    dispose_payload(instance, iterator_type.handle);
}

def:priv iterator_clear(instance: u64) -> i32 {
    return clear_payload(instance, iterator_type.handle);
}

def:priv iterator_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, iterator_type.handle, visitor, context);
}

glob:priv struct_type = TypeDefinition(
         "_struct.Struct",
         "Compiled binary layout.",
         [
             MethodDefinition(
                 "pack", MethodCallbacks(positional=pack), "Pack values.", flags=1
             ),
             MethodDefinition(
                 "pack_into",
                 MethodCallbacks(positional=pack_into),
                 "Pack into a writable buffer.",
                 flags=1
             ),
             MethodDefinition(
                 "unpack", MethodCallbacks(keywords=unpack), "Unpack a buffer."
             ),
             MethodDefinition(
                 "unpack_from",
                 MethodCallbacks(keywords=unpack_from),
                 "Unpack from a buffer offset."
             ),
             MethodDefinition(
                 "iter_unpack",
                 MethodCallbacks(keywords=iter_unpack),
                 "Iterate over packed records."
             ),
             MethodDefinition(
                 "__sizeof__",
                 MethodCallbacks(positional=memory_size),
                 "Memory consumed by this format.",
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value
                 | TypeFlags.BASETYPE.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.MANAGED_WEAKREF.value
         ),
         TypeHooks(
             create=create,
             initialize=initialize,
             repr=representation,
             dealloc=deallocate,
             clear=clear,
             traverse=traverse
         ),
         [
             PropertyDefinition(
                 "format", PropertyCallbacks(read=format_property), doc="Format string"
             ),
             PropertyDefinition(
                 "size", PropertyCallbacks(read=size_property), doc="Record size"
             )
         ]
     ),
     iterator_type = TypeDefinition(
         "_struct.unpack_iterator",
         "Packed record iterator.",
         [
             MethodDefinition(
                 "__length_hint__",
                 MethodCallbacks(positional=iterator_hint),
                 "Remaining records.",
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
         ),
         TypeHooks(
             dealloc=iterator_deallocate,
             clear=iterator_clear,
             traverse=iterator_traverse,
             iter=iterator_self,
             next=iterator_next
         )
     );

def:priv module_call(module: u64, args: u64, kwargs: u64, operation: int) -> u64 {
    if jacpy_tuple_size(args) == 0 {
        object_error("TypeError", "missing format argument");
        return 0;
    }
    format = jacpy_tuple_item(args, 0);
    instance = jacpy_struct_cached(
        jacpy_binding_state_get(module, 3), jacpy_binding_state_get(module, 1), format
    );
    jacpy_release(format);
    if instance == 0 {
        return 0;
    }
    rest = jacpy_tuple_slice(args, 1, jacpy_tuple_size(args));
    result: u64 = 0;
    if rest != 0 {
        if operation == 0 {
            result = pack(instance, rest);
        } elif operation == 1 {
            result = pack_into(instance, rest);
        } elif operation == 2 {
            result = unpack(instance, rest, 0);
        } elif operation == 3 {
            result = unpack_from(instance, rest, kwargs);
        } else {
            result = iter_unpack(instance, rest, 0);
        }
        jacpy_release(rest);
    }
    jacpy_release(instance);
    return result;
}

def:priv module_pack(module: u64, args: u64) -> u64 {
    return module_call(module, args, 0, 0);
}

def:priv module_pack_into(module: u64, args: u64) -> u64 {
    return module_call(module, args, 0, 1);
}

def:priv module_unpack(module: u64, args: u64) -> u64 {
    return module_call(module, args, 0, 2);
}

def:priv module_unpack_from(module: u64, args: u64, kwargs: u64) -> u64 {
    return module_call(module, args, kwargs, 3);
}

def:priv module_iter_unpack(module: u64, args: u64) -> u64 {
    return module_call(module, args, 0, 4);
}

def:priv module_calcsize(module: u64, format: u64) -> u64 {
    instance = jacpy_struct_cached(
        jacpy_binding_state_get(module, 3), jacpy_binding_state_get(module, 1), format
    );
    if instance == 0 {
        return 0;
    }
    result = size_property(instance, 0);
    jacpy_release(instance);
    return result;
}

def:priv module_clearcache(module: u64, unused: u64) -> u64 {
    jacpy_dict_clear(jacpy_binding_state_get(module, 3));
    return jacpy_none();
}

def:priv execute(module: u64) -> i32 {
    if not add_state_owned(
        module, 0, "error", jacpy_binding_exception("struct.error", "", "")
    ) {
        return i32(-1);
    }
    if not add_state_owned(module, 1, "Struct", struct_type.create(module)) {
        return i32(-1);
    }
    iterator = iterator_type.create(module);
    if iterator == 0 {
        return i32(-1);
    }
    jacpy_binding_state_set(module, 2, iterator);
    jacpy_release(iterator);
    cache = jacpy_dict_new();
    if cache == 0 {
        return i32(-1);
    }
    jacpy_binding_state_set(module, 3, cache);
    jacpy_release(cache);
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_struct",
         "Native Jac binary layouts.",
         [
             MethodDefinition(
                 "calcsize",
                 MethodCallbacks(positional=module_calcsize),
                 "Calculate record size.",
                 flags=8
             ),
             MethodDefinition(
                 "_clearcache",
                 MethodCallbacks(positional=module_clearcache),
                 "Clear cached formats.",
                 flags=4
             ),
             MethodDefinition(
                 "pack",
                 MethodCallbacks(positional=module_pack),
                 "Pack values.",
                 flags=1
             ),
             MethodDefinition(
                 "pack_into",
                 MethodCallbacks(positional=module_pack_into),
                 "Pack into a buffer.",
                 flags=1
             ),
             MethodDefinition(
                 "unpack",
                 MethodCallbacks(positional=module_unpack),
                 "Unpack a buffer.",
                 flags=1
             ),
             MethodDefinition(
                 "unpack_from",
                 MethodCallbacks(keywords=module_unpack_from),
                 "Unpack from an offset."
             ),
             MethodDefinition(
                 "iter_unpack",
                 MethodCallbacks(positional=module_iter_unpack),
                 "Iterate packed records.",
                 flags=1
             )
         ],
         ModuleHooks(execute=execute),
         4
     );

def:pub PyInit__struct -> u64 {
    return definition.initialize();
}
