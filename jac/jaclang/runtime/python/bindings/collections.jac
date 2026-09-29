"""The _collections module: deque_new, the deque slots and iterators, the
hand-written defaultdict and _tuplegetter, and the clinic-generated methods
over the state modules/collections.jac keeps."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyCallable_Check,
    PyDict_New,
    PyDict_Update,
    PyExc_AttributeError,
    PyExc_RuntimeError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyLong_FromLongLong,
    PyODict_Type,
    PyObject,
    PyObject_Call,
    PyObject_CallNoArgs,
    PyObject_GetAttrString,
    PyObject_GetIter,
    PyTuple_GetSlice,
    PyTuple_New,
    PyTuple_Size,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    Py_TYPE,
    jacpy_is_dict,
    jacpy_is_tuple,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_type_check
}
import from jaclang.runtime.python.object_model.genericalias { Py_GenericAlias }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition,
    add_state_owned,
    add_owned,
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_parent,
    jacpy_binding_matches,
    jacpy_binding_record,
    jacpy_binding_base_init,
    jacpy_binding_base_traverse,
    jacpy_binding_base_clear,
    jacpy_binding_base_dealloc
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_clear,
    jacpy_binding_untrack,
    traverse_payload,
    clear_payload,
    dispose_payload
}
import from jaclang.runtime.python.bindings.members {
    MemberField,
    MemberType,
    record_object,
    record_set_object
}
import from jaclang.runtime.python.bindings.references { ReferenceState, owned_tuple }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    PARSE_FORMAT,
    invoke,
    index_value
}
import from jaclang.runtime.python.bindings.converters { bad_argument }
import from jaclang.runtime.python.bindings.clinic.collections {
    collections_doc,
    defdict_class_getitem_doc,
    defdict_copy_doc,
    defdict_doc,
    defdict_members_default_factory_doc,
    defdict_missing_doc,
    deque_doc,
    deque_getset_maxlen_doc,
    deque_init_init,
    deque_methods,
    deque_methods___class_getitem___doc,
    length_hint_doc,
    module_methods,
    reduce_doc,
    tuplegetter_new_new
}
import from jaclang.runtime.python.modules.collections {
    DequeIteratorState,
    DequeState,
    TupleGetterState,
    _tuplegetter_token,
    allocate,
    collections_module_token,
    defdict_token,
    deque_copy_impl,
    deque_state,
    deque_token,
    deque_value,
    dequeiter_token,
    dequereviter_token,
    iterator_create,
    module_for,
    search,
    jacpy_deque_size,
    jacpy_deque_limit,
    jacpy_deque_extend,
    jacpy_deque_item,
    jacpy_deque_assign,
    jacpy_deque_next,
    jacpy_deque_remaining,
    jacpy_deque_consumed,
    jacpy_deque_compare,
    jacpy_deque_repeat,
    jacpy_deque_repr,
    jacpy_default_missing,
    jacpy_default_repr
}
import from jaclang.runtime.python.capi {
    repr_value,
    object_error,
    type_name,
    text_object,
    boundary_failure
}

def:priv reference_value(
    instance: ptr[PyObject], definition: ptr
) -> (ReferenceState | None) {
    if jacpy_binding_native_present(instance, definition) != 0 {
        state = jacpy_binding_native_get(instance, definition);
        if isinstance(state, ReferenceState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "native collection references are unavailable");
    return None;
}

# deque_new: an empty deque; deque.__init__ (clinic) fills it.
def:priv deque_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return allocate(type, deque_token.handle, DequeState(native=deque_state()));
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

def:priv deque_contains(instance: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    return i32(search(instance, value, 0, 9223372036854775807, 1));
}

def:priv deque_maxlen(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = deque_value(instance);
    if state is None {
        return NULL;
    }
    limit = jacpy_deque_limit(state.native);
    return Py_NewRef(Py_None) if limit < 0 else PyLong_FromLongLong(limit);
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
        return Py_NewRef(Py_NotImplemented);
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

def:priv deque_concat(instance: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_binding_matches(other, deque_token.handle) == 0 {
        object_error(
            PyExc_TypeError,
            f"can only concatenate deque (not \"{type_name(other)[:200]}\") to deque"
        );
        return NULL;
    }
    result = deque_copy_impl(instance);
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
    result = deque_copy_impl(instance);
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

def:priv iterator_definition(instance: ptr[PyObject]) -> ptr {
    return dequereviter_token.handle
        if jacpy_binding_matches(instance, dequereviter_token.handle) != 0
        else dequeiter_token.handle;
}

def:priv iterator_value(instance: ptr[PyObject]) -> (DequeIteratorState | None) {
    state = reference_value(instance, iterator_definition(instance));
    if isinstance(state, DequeIteratorState) {
        return state;
    }
    return None;
}

def:priv deque_iter(instance: ptr[PyObject]) -> ptr[PyObject] {
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    return iterator_create(jacpy_binding_state_get(module, 1), instance, False, 0);
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

# dequeiter_new: PyArg_ParseTuple(args, "O!|n", ...), without a function
# name; keyword arguments are ignored.
glob:priv iterator_signature = CallSignature(
         "", ["deque", "index"], 1, 2, 2, parser=PARSE_FORMAT
     );

def:priv iterator_create_bound(args: BoundArguments) -> ptr[PyObject] {
    module = module_for(args.context);
    if module == 0 {
        return NULL;
    }
    if jacpy_type_check(args.values[0], jacpy_binding_state_get(module, 0)) == 0 {
        bad_argument("", "argument 1", "collections.deque", args.values[0]);
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
    return invoke(iterator_signature, args, NULL, iterator_create_bound, type);
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
        object_error(PyExc_RuntimeError, "cleared deque iterator");
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

# defaultdict keeps default_factory in its record (defdict_members[]), so
# dict's tp_new allocates it as C's defdict does.
def:priv dictionary_base(instance: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_parent(Py_TYPE(instance), defdict_token.handle);
}

def:priv factory_record(instance: ptr[PyObject]) -> ptr {
    return jacpy_binding_record(instance, defdict_token.handle);
}

# The factory as a new reference; None when unset.
def:priv default_factory(instance: ptr[PyObject]) -> ptr[PyObject] {
    value = record_object(factory_record(instance), 0);
    return Py_NewRef(value) if value != 0 else Py_NewRef(Py_None);
}

def:priv default_release_factory(instance: ptr[PyObject]) {
    record = factory_record(instance);
    old = record_object(record, 0);
    record_set_object(record, 0, NULL);
    jacpy_release(old);
}

def:priv default_initialize(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    count = PyTuple_Size(args);
    factory = jacpy_tuple_item(args, 0) if count > 0 else NULL;
    if count > 0 and factory == 0 {
        return i32(-1);
    }
    if factory != 0 and factory != Py_None and PyCallable_Check(factory) == 0 {
        jacpy_release(factory);
        object_error(PyExc_TypeError, "first argument must be callable or None");
        return i32(-1);
    }
    record = factory_record(instance);
    old = record_object(record, 0);
    record_set_object(record, 0, factory);
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

def:priv default_missing(instance: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    factory = default_factory(instance);
    result = jacpy_default_missing(instance, factory, key);
    jacpy_release(factory);
    return result;
}

def:priv default_construct(
    instance: ptr[PyObject], mapping: ptr[PyObject]
) -> ptr[PyObject] {
    args = owned_tuple([default_factory(instance), Py_NewRef(mapping)]);
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
    factory = default_factory(instance);
    result = jacpy_default_repr(instance, factory);
    jacpy_release(factory);
    return result;
}

def:priv default_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    factory = default_factory(instance);
    args = PyTuple_New(0) if factory == Py_None else owned_tuple([Py_NewRef(factory)]);
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
            Py_NewRef(Py_None),
            Py_NewRef(Py_None),
            PyObject_GetIter(held.references[2])
        ]
    );
}

def:priv default_or(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_dict(left) == 0 or jacpy_is_dict(right) == 0 {
        return Py_NewRef(Py_NotImplemented);
    }
    owner = left if jacpy_binding_matches(left, defdict_token.handle) != 0 else right;
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
    status = traverse_payload(instance, defdict_token.handle, visitor, context);
    if status != 0 {
        return status;
    }
    status = visit_reference(
        record_object(factory_record(instance), 0), visitor, context
    );
    if status != 0 {
        return status;
    }
    base = dictionary_base(instance);
    return jacpy_binding_base_traverse(base, instance, visitor, context)
        if base != 0
        else i32(-1);
}

def:priv default_clear(instance: ptr[PyObject]) -> i32 {
    clear_payload(instance, defdict_token.handle);
    default_release_factory(instance);
    base = dictionary_base(instance);
    return jacpy_binding_base_clear(base, instance) if base != 0 else i32(-1);
}

def:priv default_dealloc(instance: ptr[PyObject]) {
    base = dictionary_base(instance);
    type = Py_TYPE(instance);
    jacpy_binding_untrack(instance);
    default_release_factory(instance);
    clear_payload(instance, defdict_token.handle);
    jacpy_binding_native_clear(instance, defdict_token.handle);
    jacpy_binding_base_dealloc(base, instance);
    jacpy_release(type);
}

# _tuplegetter: the index in its native state, __doc__ in its record.
def:priv getter_record(instance: ptr[PyObject]) -> ptr {
    return jacpy_binding_record(instance, _tuplegetter_token.handle);
}

def:priv getter_get(
    instance: ptr[PyObject], object: ptr[PyObject], owner: ptr[PyObject]
) -> ptr[PyObject] {
    if object == 0 {
        return Py_NewRef(instance);
    }
    state = reference_value(instance, _tuplegetter_token.handle);
    if not isinstance(state, TupleGetterState) {
        return NULL;
    }
    if jacpy_is_tuple(object) == 0 {
        object_error(
            PyExc_TypeError,
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
        PyExc_AttributeError,
        "can't set attribute" if value != 0 else "can't delete attribute"
    );
    return i32(-1);
}

def:priv getter_doc(instance: ptr[PyObject]) -> ptr[PyObject] {
    value = record_object(getter_record(instance), 0);
    return Py_NewRef(value) if value != 0 else Py_NewRef(Py_None);
}

def:priv getter_release_doc(instance: ptr[PyObject]) {
    record = getter_record(instance);
    old = record_object(record, 0);
    record_set_object(record, 0, NULL);
    jacpy_release(old);
}

def:priv getter_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = reference_value(instance, _tuplegetter_token.handle);
    if not isinstance(state, TupleGetterState) {
        return NULL;
    }
    doc = getter_doc(instance);
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
    state = reference_value(instance, _tuplegetter_token.handle);
    if not isinstance(state, TupleGetterState) {
        return NULL;
    }
    args = owned_tuple([PyLong_FromLongLong(state.index), getter_doc(instance)]);
    return owned_tuple([Py_NewRef(Py_TYPE(instance)), args]);
}

def:priv deque_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, deque_token.handle, visitor, context);
}

def:priv deque_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, deque_token.handle);
}

def:priv deque_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, deque_token.handle);
}

def:priv getter_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    status = traverse_payload(instance, _tuplegetter_token.handle, visitor, context);
    if status != 0 {
        return status;
    }
    return visit_reference(record_object(getter_record(instance), 0), visitor, context);
}

def:priv getter_clear(instance: ptr[PyObject]) -> i32 {
    getter_release_doc(instance);
    return clear_payload(instance, _tuplegetter_token.handle);
}

def:priv getter_dealloc(instance: ptr[PyObject]) {
    jacpy_binding_untrack(instance);
    getter_release_doc(instance);
    dispose_payload(instance, _tuplegetter_token.handle);
}

def:priv iterator_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, iterator_definition(instance), visitor, context);
}

def:priv iterator_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, iterator_definition(instance));
}

def:priv iterator_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, iterator_definition(instance));
}

glob:priv flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     # dequeiter_methods[]
     iterator_methods = [
         MethodDefinition(
             "__length_hint__",
             MethodCallbacks(positional=iterator_hint),
             length_hint_doc,
             flags=4
         ),
         MethodDefinition(
             "__reduce__",
             MethodCallbacks(positional=iterator_reduce),
             reduce_doc,
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
         "collections._deque_iterator",
         "",
         iterator_methods,
         flags,
         iterator_hooks,
         generic_getattr=True
     ),
     reverse_type = TypeDefinition(
         "collections._deque_reverse_iterator",
         "",
         iterator_methods,
         flags,
         iterator_hooks,
         generic_getattr=True
     ),
     deque_type = TypeDefinition(
         "collections.deque",
         deque_doc,
         deque_methods
             + [
                 MethodDefinition(
                     "__class_getitem__",
                     MethodCallbacks(positional=Py_GenericAlias),
                     deque_methods___class_getitem___doc,
                     flags=24
                 )
             ],
         flags | u64(TypeFlags.BASETYPE.value | TypeFlags.SEQUENCE.value),
         TypeHooks(
             create=deque_create,
             initialize=deque_init_init,
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
         [
             PropertyDefinition(
                 "maxlen",
                 PropertyCallbacks(read=deque_maxlen),
                 doc=deque_getset_maxlen_doc
             )
         ],
         unhashable=True,
         weaklist=True,
         generic_getattr=True
     ),
     # defdict_methods[] and defdict_members[].
     default_type = TypeDefinition(
         "collections.defaultdict",
         defdict_doc,
         [
             MethodDefinition(
                 "__missing__",
                 MethodCallbacks(positional=default_missing),
                 defdict_missing_doc,
                 flags=8
             ),
             MethodDefinition(
                 "copy",
                 MethodCallbacks(positional=default_copy),
                 defdict_copy_doc,
                 flags=4
             ),
             MethodDefinition(
                 "__copy__",
                 MethodCallbacks(positional=default_copy),
                 defdict_copy_doc,
                 flags=4
             ),
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=default_reduce),
                 reduce_doc,
                 flags=4
             ),
             MethodDefinition(
                 "__class_getitem__",
                 MethodCallbacks(positional=Py_GenericAlias),
                 defdict_class_getitem_doc,
                 flags=24
             )
         ],
         flags | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             initialize=default_initialize,
             traverse=default_traverse,
             clear=default_clear,
             dealloc=default_dealloc,
             repr=default_repr,
             bit_or=default_or
         ),
         members=[
             MemberField(
                 "default_factory",
                 MemberType.OBJECT.value,
                 0,
                 doc=defdict_members_default_factory_doc
             )
         ],
         record_size=8,
         generic_getattr=True
     ),
     # tuplegetter_members[]: __doc__ over the record.
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
             create=tuplegetter_new_new,
             descriptor=getter_get,
             descriptor_set=getter_set,
             traverse=getter_traverse,
             clear=getter_clear,
             dealloc=getter_dealloc,
             repr=getter_repr
         ),
         members=[MemberField("__doc__", MemberType.OBJECT.value, 0)],
         record_size=8
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    deque_token.handle = deque_type.handle;
    dequeiter_token.handle = forward_type.handle;
    dequereviter_token.handle = reverse_type.handle;
    defdict_token.handle = default_type.handle;
    _tuplegetter_token.handle = getter_type.handle;
    collections_module_token.handle = definition.handle;
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
    ordered = PyObject_CallNoArgs(addressof(PyODict_Type));
    if ordered == 0 {
        return i32(-1);
    }
    ordered_type = Py_NewRef(Py_TYPE(ordered));
    jacpy_release(ordered);
    return i32(0) if add_owned(module, "OrderedDict", ordered_type) else i32(-1);
}

glob:priv definition = ModuleDefinition(
         "_collections",
         collections_doc,
         module_methods,
         hooks=ModuleHooks(execute=execute),
         state_count=6
     );

def:pub PyInit__collections -> ptr[PyObject] {
    return definition.initialize();
}
