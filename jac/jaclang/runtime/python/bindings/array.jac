"""The array module: array_new, the sequence, mapping and buffer slots, and
the clinic-generated methods over the state modules/array.jac keeps."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_WarnEx,
    PyExc_DeprecationWarning,
    PyExc_IndexError,
    PyExc_TypeError,
    PyImport_ImportModuleAttrString,
    PyIndex_Check,
    PyLong_FromLongLong,
    PyNumber_AsSsize_t,
    PyObject,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PySys_AuditTuple,
    PyType_GetSlot,
    PyUnicode_FromOrdinal,
    Py_GenericAlias,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    Py_TYPE,
    Py_buffer,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_is_bytearray,
    jacpy_is_bytes,
    jacpy_is_slice,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_slice_adjust,
    jacpy_slice_unpack
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodDefinition,
    MethodCallbacks,
    add_state_owned,
    add_owned,
    jacpy_binding_state_get,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    TypeSlot,
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_allocate,
    jacpy_binding_matches
}

import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_set,
    traverse_payload,
    clear_payload,
    dispose_payload
}
import from jaclang.runtime.python.bindings.references { ReferenceState, owned_tuple }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke,
    PARSE_FORMAT
}
import from jaclang.runtime.python.bindings.converters { convert_unicode_char }
import from jaclang.runtime.python.bindings.buffer {
    BufferLayout,
    jacpy_binding_buffer_fill,
    jacpy_binding_buffer_dispose
}
import from jaclang.runtime.python.capi { object_error, text_object }
import from jaclang.runtime.python.bindings.clinic.array {
    array_getsets_itemsize_doc,
    array_getsets_typecode_doc,
    array_methods,
    array_methods___class_getitem___doc,
    arrayiterator_methods,
    arraytype_doc,
    module_doc,
    module_methods
}
import from jaclang.runtime.python.modules.array {
    ArrayIteratorState,
    ArrayState,
    allocate,
    append_buffer,
    array_array___copy___impl,
    array_module_token,
    array_token,
    arrayiterator_token,
    iterator_state,
    module_for,
    state_for,
    jacpy_array_address,
    jacpy_array_export,
    jacpy_array_item,
    jacpy_array_assign,
    jacpy_array_extend,
    jacpy_array_copy,
    jacpy_array_assign_slice,
    jacpy_array_delete,
    jacpy_array_repeat,
    jacpy_array_search,
    jacpy_array_compare,
    jacpy_array_repr,
    jacpy_array_cursor_new,
    jacpy_array_cursor_next
}

# array_new: PyArg_ParseTuple(args, "C|O:array", ...).
glob:priv array_signature = CallSignature(
         "array", ["typecode", "initializer"], 1, 2, 2, parser=PARSE_FORMAT
     );

def:priv create_bound(args: BoundArguments) -> ptr[PyObject] {
    code = i64(convert_unicode_char(args.values[0], "array", "argument 1", False));
    initial = args.values[1];
    audit = owned_tuple(
        [
            Py_NewRef(args.values[0]),
            Py_NewRef(initial) if initial != 0 else Py_NewRef(Py_None)
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
        and PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "The 'u' type code is deprecated and will be removed in Python 3.16",
            1
        )
            < 0 {
        return NULL;
    }
    other: (ArrayState | None) = None;
    if initial != 0 and jacpy_binding_matches(initial, array_token.handle) != 0 {
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
            PyExc_TypeError,
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
            object_error(PyExc_TypeError, "array.array() takes no keyword arguments");
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
        object_error(PyExc_IndexError, "array assignment index out of range");
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
        index = PyNumber_AsSsize_t(key, PyExc_IndexError);
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
    object_error(PyExc_TypeError, "array indices must be integers or slices");
    return NULL;
}

def:priv assign_subscript(
    instance: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if PyIndex_Check(key) != 0 {
        index = PyNumber_AsSsize_t(key, PyExc_IndexError);
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
        if jacpy_binding_matches(value, array_token.handle) == 0 {
            object_error(PyExc_TypeError, "can only assign array to array slice");
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
    object_error(PyExc_TypeError, "array indices must be integers or slices");
    return i32(-1);
}

def:priv inplace_concat(
    instance: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_binding_matches(value, array_token.handle) == 0 {
        object_error(PyExc_TypeError, "can only extend array with array");
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

def:priv concat(instance: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    copied = array_array___copy___impl(instance);
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
    copied = array_array___copy___impl(instance);
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
    if jacpy_binding_matches(other, array_token.handle) == 0 {
        return Py_NewRef(Py_NotImplemented);
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
        and jacpy_binding_native_set(result, arrayiterator_token.handle, cursor) < 0 {
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

def:priv repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    return jacpy_array_repr(state.native);
}

def:priv array_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, array_token.handle, visitor, context);
}

def:priv array_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, array_token.handle);
}

def:priv array_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, array_token.handle);
}

def:priv iterator_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, arrayiterator_token.handle, visitor, context);
}

def:priv iterator_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, arrayiterator_token.handle);
}

def:priv iterator_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, arrayiterator_token.handle);
}

glob:priv flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     iterator_type = TypeDefinition(
         "array.arrayiterator",
         "",
         arrayiterator_methods,
         flags | u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(
             dealloc=iterator_dealloc,
             traverse=iterator_traverse,
             clear=iterator_clear,
             iter=iterator_self,
             next=iterator_next
         ),
         generic_getattr=True
     ),
     array_type = TypeDefinition(
         "array.array",
         arraytype_doc,
         array_methods
             + [
                 MethodDefinition(
                     "__class_getitem__",
                     MethodCallbacks(positional=Py_GenericAlias),
                     array_methods___class_getitem___doc,
                     flags=24
                 )
             ],
         flags | u64(TypeFlags.BASETYPE.value | TypeFlags.SEQUENCE.value),
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
             PropertyDefinition(
                 "typecode",
                 PropertyCallbacks(read=typecode),
                 doc=array_getsets_typecode_doc
             ),
             PropertyDefinition(
                 "itemsize",
                 PropertyCallbacks(read=itemsize),
                 doc=array_getsets_itemsize_doc
             )
         ],
         unhashable=True,
         weaklist=True,
         generic_getattr=True
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    array_token.handle = array_type.handle;
    arrayiterator_token.handle = iterator_type.handle;
    array_module_token.handle = definition.handle;
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
        or not add_owned(module, "typecodes", text_object("bBuwhHiIlLqQfd")) {
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
         module_doc,
         module_methods,
         hooks=ModuleHooks(execute=execute),
         state_count=2
     );

def:pub PyInit_array -> ptr[PyObject] {
    return definition.initialize();
}
