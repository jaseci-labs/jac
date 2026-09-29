"""The _operator module: its clinic-generated functions, the hand-written
call(), and the itemgetter, attrgetter and methodcaller types."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyExc_SystemError,
    PyExc_TypeError,
    PyObject,
    PyTuple_Size,
    PyVectorcall_NARGS,
    Py_NewRef,
    Py_TYPE,
    jacpy_dict_size,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_allocate
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
    dispose_payload,
    clear_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.references { ReferenceState }
import from jaclang.runtime.python.bindings.arguments { check_positional }

import from jaclang.runtime.python.capi { object_error, text_object, boundary_failure }
import from jaclang.runtime.python.bindings.clinic.operator {
    _operator_call__doc__,
    attrgetter_doc,
    itemgetter_doc,
    methodcaller_doc,
    module_methods,
    operator_doc,
    reduce_doc
}
import from jaclang.runtime.python.modules.operator {
    jacpy_operator_call,
    jacpy_operator_prepare,
    jacpy_operator_apply,
    jacpy_operator_repr,
    jacpy_operator_reduce
}

def:priv call_call(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if PyTuple_Size(args) == 0 {
        object_error(PyExc_TypeError, "call expected at least 1 argument, got 0");
        return NULL;
    }
    return jacpy_operator_call(args, kwargs);
}

obj AccessorState(ReferenceState) {
    has kind: i64;
}

def:priv accessor_state(
    instance: ptr[PyObject], definition: ptr
) -> (AccessorState | None) {
    if jacpy_binding_native_present(instance, definition) != 0 {
        state = jacpy_binding_native_get(instance, definition);
        if isinstance(state, AccessorState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "native accessor state is unavailable");
    return None;
}

# The names _operator.c's constructors and calls report, by accessor kind.
glob:priv ACCESSOR_NAMES: list[str] = ["itemgetter", "attrgetter", "methodcaller"];

def:priv accessor_create(
    type: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    definition: ptr,
    kind: i64
) -> ptr[PyObject] {
    name = ACCESSOR_NAMES[int(kind)];
    count = int(PyTuple_Size(args));
    if kind == 2 {
        if count < 1 {
            object_error(
                PyExc_TypeError,
                "methodcaller needs at least one argument, the method name"
            );
            return NULL;
        }
    } else {
        # _PyArg_NoKeywords(), then PyArg_UnpackTuple(args, name, 1, 1).
        if kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
            object_error(PyExc_TypeError, f"{name}() takes no keyword arguments");
            return NULL;
        }
        if count < 1 and not check_positional(name, count, 1, 1) {
            return NULL;
        }
    }
    prepared = jacpy_operator_prepare(kind, args);
    if prepared == 0 {
        return NULL;
    }
    state = AccessorState(
        references=[prepared, Py_NewRef(kwargs) if kwargs != 0 else NULL], kind=kind
    );
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return NULL;
    }
    if jacpy_binding_native_set(instance, definition, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

# The vectorcall of an accessor: _PyArg_NoKwnames() and
# _PyArg_CheckPositional(name, nargs, 1, 1).
def:priv accessor_vector(
    instance: ptr[PyObject],
    args: ptr,
    count: u64,
    names: ptr[PyObject],
    definition: ptr
) -> ptr[PyObject] {
    state = accessor_state(instance, definition);
    if state is None {
        return NULL;
    }
    name = ACCESSOR_NAMES[int(state.kind)];
    if names != 0 and PyTuple_Size(names) != 0 {
        object_error(PyExc_TypeError, f"{name}() takes no keyword arguments");
        return NULL;
    }
    size = PyVectorcall_NARGS(count);
    if not check_positional(name, int(size), 1, 1) {
        return NULL;
    }
    return jacpy_operator_apply(
        state.kind,
        ptr[ptr[PyObject]](int(args)).view(1)[0],
        state.references[0],
        state.references[1]
    );
}

def:priv accessor_repr(instance: ptr[PyObject], definition: ptr) -> ptr[PyObject] {
    state = accessor_state(instance, definition);
    if state is None {
        return NULL;
    }
    return jacpy_operator_repr(
        state.kind, instance, state.references[0], state.references[1]
    );
}

def:priv accessor_reduce(instance: ptr[PyObject], definition: ptr) -> ptr[PyObject] {
    state = accessor_state(instance, definition);
    if state is None {
        return NULL;
    }
    return jacpy_operator_reduce(
        state.kind, Py_TYPE(instance), state.references[0], state.references[1]
    );
}

def:priv accessor_signature(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    try {
        return text_object("(obj, /)");
    } except boundary_failure {
        return NULL;
    }
}

def:priv itemgetter_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_create(type, args, kwargs, itemgetter_type.handle, i64(0));
}

def:priv itemgetter_vector(
    instance: ptr[PyObject], args: ptr, count: u64, names: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_vector(instance, args, count, names, itemgetter_type.handle);
}

def:priv itemgetter_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return accessor_repr(instance, itemgetter_type.handle);
}

def:priv itemgetter_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_reduce(instance, itemgetter_type.handle);
}

def:priv itemgetter_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, itemgetter_type.handle);
}

def:priv itemgetter_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, itemgetter_type.handle, visitor, context);
}

def:priv itemgetter_deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, itemgetter_type.handle);
}

glob:priv itemgetter_type = TypeDefinition(
         "operator.itemgetter",
         itemgetter_doc,
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=itemgetter_reduce),
                 reduce_doc,
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value | TypeFlags.IMMUTABLE.value | TypeFlags.VECTORCALL.value
         ),
         TypeHooks(
             create=itemgetter_create,
             vectorcall=itemgetter_vector,
             repr=itemgetter_repr,
             clear=itemgetter_clear,
             traverse=itemgetter_traverse,
             dealloc=itemgetter_deallocate
         ),
         [
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=accessor_signature)
             )
         ],
         generic_getattr=True
     );

def:priv attrgetter_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_create(type, args, kwargs, attrgetter_type.handle, i64(1));
}

def:priv attrgetter_vector(
    instance: ptr[PyObject], args: ptr, count: u64, names: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_vector(instance, args, count, names, attrgetter_type.handle);
}

def:priv attrgetter_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return accessor_repr(instance, attrgetter_type.handle);
}

def:priv attrgetter_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_reduce(instance, attrgetter_type.handle);
}

def:priv attrgetter_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, attrgetter_type.handle);
}

def:priv attrgetter_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, attrgetter_type.handle, visitor, context);
}

def:priv attrgetter_deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, attrgetter_type.handle);
}

glob:priv attrgetter_type = TypeDefinition(
         "operator.attrgetter",
         attrgetter_doc,
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=attrgetter_reduce),
                 reduce_doc,
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value | TypeFlags.IMMUTABLE.value | TypeFlags.VECTORCALL.value
         ),
         TypeHooks(
             create=attrgetter_create,
             vectorcall=attrgetter_vector,
             repr=attrgetter_repr,
             clear=attrgetter_clear,
             traverse=attrgetter_traverse,
             dealloc=attrgetter_deallocate
         ),
         [
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=accessor_signature)
             )
         ],
         generic_getattr=True
     );

def:priv methodcaller_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_create(type, args, kwargs, methodcaller_type.handle, i64(2));
}

def:priv methodcaller_vector(
    instance: ptr[PyObject], args: ptr, count: u64, names: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_vector(instance, args, count, names, methodcaller_type.handle);
}

def:priv methodcaller_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return accessor_repr(instance, methodcaller_type.handle);
}

def:priv methodcaller_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_reduce(instance, methodcaller_type.handle);
}

def:priv methodcaller_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, methodcaller_type.handle);
}

def:priv methodcaller_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, methodcaller_type.handle, visitor, context);
}

def:priv methodcaller_deallocate(instance: ptr[PyObject]) {
    dispose_payload(instance, methodcaller_type.handle);
}

glob:priv methodcaller_type = TypeDefinition(
         "operator.methodcaller",
         methodcaller_doc,
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=methodcaller_reduce),
                 reduce_doc,
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value | TypeFlags.IMMUTABLE.value | TypeFlags.VECTORCALL.value
         ),
         TypeHooks(
             create=methodcaller_create,
             vectorcall=methodcaller_vector,
             repr=methodcaller_repr,
             clear=methodcaller_clear,
             traverse=methodcaller_traverse,
             dealloc=methodcaller_deallocate
         ),
         [
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=accessor_signature)
             )
         ],
         generic_getattr=True
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    if not add_owned(module, "itemgetter", itemgetter_type.create(module)) {
        return i32(-1);
    }
    if not add_owned(module, "attrgetter", attrgetter_type.create(module)) {
        return i32(-1);
    }
    if not add_owned(module, "methodcaller", methodcaller_type.create(module)) {
        return i32(-1);
    }
    return i32(0);
}

# operator_methods[]: the clinic-generated functions and the hand-written
# call(), with its _operator.c doc.
glob:priv definition = ModuleDefinition(
         "_operator",
         operator_doc,
         module_methods
             + [
                 MethodDefinition(
                     "call", MethodCallbacks(keywords=call_call), _operator_call__doc__
                 )
             ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__operator -> ptr[PyObject] {
    return definition.initialize();
}
