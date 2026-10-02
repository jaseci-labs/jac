"""The _struct module: s_new, the hand-written pack and pack_into, the
slots, and the clinic-generated methods over modules/struct.jac's state."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_New,
    PyExc_IndexError,
    PyExc_TypeError,
    PyLong_FromLongLong,
    PyNumber_AsSsize_t,
    PyObject,
    PyTuple_Size,
    Py_NewRef,
    Py_None,
    jacpy_buffer_new,
    jacpy_bytes_address,
    jacpy_bytes_decode,
    jacpy_error_pending,
    jacpy_release,
    jacpy_tuple_item
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception,
    jacpy_binding_state_get,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_allocate,
    jacpy_binding_basicsize
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    dispose_payload,
    clear_payload,
    traverse_payload
}

import from jaclang.runtime.python.bindings.arguments { vector_tuple }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.capi {
    repr_value,
    object_error,
    type_name,
    text_object,
    boundary_failure,
    jac_heap_size,
    jac_list_heap_size
}
import from jaclang.runtime.python.bindings.clinic.struct {
    Struct___init___init,
    Struct_methods,
    module_doc,
    module_methods,
    pack_doc,
    pack_into_doc,
    s__doc__,
    s_getsetlist_format_doc,
    s_getsetlist_size_doc,
    s_pack__doc__,
    s_pack_into__doc__,
    s_sizeof__doc__
}
import from jaclang.runtime.python.modules.struct {
    StructState,
    Struct_token,
    iterator_state,
    module_for,
    state_for,
    module_error,
    struct_module_token,
    unpack_iterator_token,
    jacpy_struct_size,
    jacpy_struct_items,
    jacpy_struct_pack,
    jacpy_struct_offset,
    jacpy_struct_remaining,
    jacpy_struct_next,
    jacpy_struct_cached,
    jacpy_struct_memory
}

def:priv create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_binding_allocate(type);
}

def:priv format_property(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return jacpy_bytes_decode(state.references[0], "utf-8", "strict");
}

def:priv size_property(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    if jacpy_binding_native_present(instance, Struct_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Struct_token.handle);
        if isinstance(state, StructState) and state.references[0] != 0 {
            return PyLong_FromLongLong(jacpy_struct_size(state.plan));
        }
    }
    return PyLong_FromLongLong(-1);
}

def:priv representation(instance: ptr[PyObject]) -> ptr[PyObject] {
    format = format_property(instance, 0);
    if format == 0 {
        return NULL;
    }
    try {
        name = type_name(instance).split(".")[-1];
        return text_object(f"{name}({repr_value(format)})");
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(format);
    }
}

def:priv memory_size(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return PyLong_FromLongLong(
        jacpy_binding_basicsize(instance)
            + jacpy_struct_memory(state.plan)
            + jac_heap_size(u64(id(state)))
            + jac_list_heap_size(u64(id(state.references)))
    );
}

def:priv pack(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    plan = state.plan;
    module = module_for(instance);
    if module == 0 {
        return NULL;
    }
    count = PyTuple_Size(args);
    expected = jacpy_struct_items(plan);
    if count != expected {
        module_error(
            module, f"pack expected {expected} items for packing (got {count})"
        );
        return NULL;
    }
    result = jacpy_buffer_new(jacpy_struct_size(plan));
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
        return NULL;
    }
    return result;
}

def:priv pack_into(instance: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    plan = state.plan;
    module = module_for(instance);
    if module == 0 {
        return NULL;
    }
    count = PyTuple_Size(args);
    expected = jacpy_struct_items(plan);
    if count < 2 {
        module_error(
            module,
            "pack_into expected offset argument"
                if count != 0
                else "pack_into expected buffer argument"
        );
        return NULL;
    }
    if count - 2 != expected {
        module_error(
            module, f"pack_into expected {expected} items for packing (got {count - 2})"
        );
        return NULL;
    }
    buffer = BufferArgument();
    source = jacpy_tuple_item(args, 0);
    acquired = buffer.acquire_writable(source);
    jacpy_release(source);
    if not acquired {
        return NULL;
    }
    offset_object = jacpy_tuple_item(args, 1);
    offset = PyNumber_AsSsize_t(offset_object, PyExc_IndexError);
    jacpy_release(offset_object);
    if jacpy_error_pending() != 0 {
        return NULL;
    }
    error = jacpy_binding_state_get(module, 0);
    offset = jacpy_struct_offset(plan, buffer.size(), offset, 1, error);
    if offset < 0 {
        return NULL;
    }
    if jacpy_struct_pack(plan, args, 2, buffer.address() + offset, error) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def:priv iterator_next(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = iterator_state(instance);
    if state is None {
        return NULL;
    }
    cursor = state.cursor;
    if cursor is None {
        return NULL;
    }
    if jacpy_struct_remaining(cursor) == 0 {
        state.clear();
        return NULL;
    }
    return jacpy_struct_next(cursor);
}

def:priv iterator_self(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def:priv iterator_hint(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = iterator_state(instance);
    if state is not None {
        cursor = state.cursor;
        if cursor is not None {
            return PyLong_FromLongLong(jacpy_struct_remaining(cursor));
        }
    }
    return PyLong_FromLongLong(0);
}

# Struct.pack(*values) and Struct.pack_into(buffer, offset, *values):
# METH_FASTCALL over the values.
def:priv pack_call(
    instance: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    values = vector_tuple(args, nargs);
    if values == 0 {
        return NULL;
    }
    result = pack(instance, values);
    jacpy_release(values);
    return result;
}

def:priv pack_into_call(
    instance: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    values = vector_tuple(args, nargs);
    if values == 0 {
        return NULL;
    }
    result = pack_into(instance, values);
    jacpy_release(values);
    return result;
}

def:priv deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, Struct_token.handle);
}

def:priv clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, Struct_token.handle);
}

def:priv traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, Struct_token.handle, visitor, context);
}

def:priv iterator_deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, unpack_iterator_token.handle);
}

def:priv iterator_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, unpack_iterator_token.handle);
}

def:priv iterator_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, unpack_iterator_token.handle, visitor, context);
}

glob:priv struct_type = TypeDefinition(
         "_struct.Struct",
         s__doc__,
         Struct_methods
             + [
                 MethodDefinition(
                     "pack", MethodCallbacks(fast=pack_call), s_pack__doc__, flags=128
                 ),
                 MethodDefinition(
                     "pack_into",
                     MethodCallbacks(fast=pack_into_call),
                     s_pack_into__doc__,
                     flags=128
                 ),
                 MethodDefinition(
                     "__sizeof__",
                     MethodCallbacks(positional=memory_size),
                     s_sizeof__doc__,
                     flags=4
                 )
             ],
         u64(TypeFlags.GC.value | TypeFlags.BASETYPE.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=create,
             initialize=Struct___init___init,
             repr=representation,
             dealloc=deallocate,
             clear=clear,
             traverse=traverse
         ),
         [
             PropertyDefinition(
                 "format",
                 PropertyCallbacks(read=format_property),
                 doc=s_getsetlist_format_doc
             ),
             PropertyDefinition(
                 "size",
                 PropertyCallbacks(read=size_property),
                 doc=s_getsetlist_size_doc
             )
         ],
         weaklist=True,
         generic_getattr=True,
         generic_setattr=True
     ),
     iterator_type = TypeDefinition(
         "_struct.unpack_iterator",
         "",
         [
             MethodDefinition(
                 "__length_hint__",
                 MethodCallbacks(positional=iterator_hint),
                 "",
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
         ),
         generic_getattr=True
     );

# cache_struct_converter's lookup, for the hand-written pack functions.
def:priv cached_struct(module: ptr[PyObject], format: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_struct_cached(
        jacpy_binding_state_get(module, 3), jacpy_binding_state_get(module, 1), format
    );
}

# pack(format, *values) and pack_into(format, buffer, offset, *values):
# METH_FASTCALL, "missing format argument" without one.
def:priv module_pack_values(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, into: bool
) -> ptr[PyObject] {
    if nargs == 0 {
        object_error(PyExc_TypeError, "missing format argument");
        return NULL;
    }
    instance = cached_struct(module, args.view(1)[0]);
    if instance == 0 {
        return NULL;
    }
    values = vector_tuple(args + 1, nargs - 1);
    result: ptr[PyObject] = NULL;
    if values != 0 {
        result = pack_into(instance, values) if into else pack(instance, values);
        jacpy_release(values);
    }
    jacpy_release(instance);
    return result;
}

def:priv module_pack(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return module_pack_values(module, args, nargs, False);
}

def:priv module_pack_into(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return module_pack_values(module, args, nargs, True);
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    Struct_token.handle = struct_type.handle;
    unpack_iterator_token.handle = iterator_type.handle;
    struct_module_token.handle = definition.handle;
    if not add_state_owned(
        module, 0, "error", jacpy_binding_exception("struct.error", NULL, "")
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
    cache = PyDict_New();
    if cache == 0 {
        return i32(-1);
    }
    jacpy_binding_state_set(module, 3, cache);
    jacpy_release(cache);
    return i32(0);
}

# module_functions[]: the clinic functions and the hand-written pack and
# pack_into with their _struct.c docs.
glob:priv definition = ModuleDefinition(
         "_struct",
         module_doc,
         module_methods
             + [
                 MethodDefinition(
                     "pack", MethodCallbacks(fast=module_pack), pack_doc, flags=128
                 ),
                 MethodDefinition(
                     "pack_into",
                     MethodCallbacks(fast=module_pack_into),
                     pack_into_doc,
                     flags=128
                 )
             ],
         ModuleHooks(execute=execute),
         4
     );

def:pub PyInit__struct -> ptr[PyObject] {
    return definition.initialize();
}
