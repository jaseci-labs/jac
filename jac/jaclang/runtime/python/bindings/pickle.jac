def:priv traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32;

def:priv release_dispatch(instance: ptr[PyObject]);

def:priv clear(instance: ptr[PyObject]) -> i32;

def:priv dealloc(instance: ptr[PyObject]);

def:priv create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def:priv get_attribute(instance: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def:priv set_attribute(
    instance: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def:priv persistent_id(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def:priv get_memo(instance: ptr[PyObject], unused: u64) -> ptr[PyObject];

def:priv set_memo(instance: ptr[PyObject], value: ptr[PyObject], unused: u64) -> i32;

glob:priv flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     pickler_type = TypeDefinition(
         "_pickle.Pickler",
         Pickler_doc,
         Pickler_methods
             + [
                 MethodDefinition(
                     "persistent_id",
                     MethodCallbacks(positional=persistent_id),
                     Pickler_methods_persistent_id_doc,
                     flags=8
                 )
             ],
         flags | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=create,
             initialize=_pickle_Pickler___init___init,
             dealloc=dealloc,
             traverse=traverse,
             clear=clear,
             get_attribute=get_attribute,
             set_attribute=set_attribute
         ),
         [PropertyDefinition("memo", PropertyCallbacks(read=get_memo, write=set_memo))],
         members=[
             MemberField("bin", MemberType.INT.value, 0),
             MemberField("fast", MemberType.INT.value, 4),
             MemberField("dispatch_table", MemberType.OBJECT_EX.value, PICKLER_DISPATCH)
         ],
         record_size=PICKLER_RECORD
     ),
     unpickler_type = TypeDefinition(
         "_pickle.Unpickler",
         Unpickler_doc,
         Unpickler_methods,
         flags | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=create,
             initialize=_pickle_Unpickler___init___init,
             dealloc=dealloc,
             traverse=traverse,
             clear=clear,
             get_attribute=get_attribute,
             set_attribute=set_attribute
         ),
         [PropertyDefinition("memo", PropertyCallbacks(read=get_memo, write=set_memo))]
     ),
     pickler_memo_type = TypeDefinition(
         "_pickle.PicklerMemoProxy",
         "",
         PicklerMemoProxy_methods,
         flags,
         TypeHooks(dealloc=dealloc, traverse=traverse, clear=clear)
     ),
     unpickler_memo_type = TypeDefinition(
         "_pickle.UnpicklerMemoProxy",
         "",
         UnpicklerMemoProxy_methods,
         flags,
         TypeHooks(dealloc=dealloc, traverse=traverse, clear=clear)
     );

def:priv retain_state(module: ptr[PyObject], index: int, value: ptr[PyObject]) -> bool;

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_pickle",
         pickle_module_doc,
         module_methods,
         hooks=ModuleHooks(execute=execute),
         state_count=18
     );

def:pub PyInit__pickle -> ptr[PyObject];

impl traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    handle = type_definition(Py_TYPE(instance));
    status = traverse_payload(instance, handle, visitor, context);
    if status != 0 or handle != Pickler_token.handle {
        return status;
    }
    return visit_reference(
        record_object(pickler_record(instance), PICKLER_DISPATCH), visitor, context
    );
}

impl release_dispatch(instance: ptr[PyObject]) {
    if type_definition(Py_TYPE(instance)) != Pickler_token.handle {
        return;
    }
    record = pickler_record(instance);
    old = record_object(record, PICKLER_DISPATCH);
    record_set_object(record, PICKLER_DISPATCH, NULL);
    jacpy_release(old);
}

impl clear(instance: ptr[PyObject]) -> i32 {
    release_dispatch(instance);
    return clear_payload(instance, type_definition(Py_TYPE(instance)));
}

impl dealloc(instance: ptr[PyObject]) {
    jacpy_binding_untrack(instance);
    release_dispatch(instance);
    dispose_payload(instance, type_definition(Py_TYPE(instance)));
}

impl create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if type_definition(type) == Unpickler_token.handle {
        return wrap(
            type, UnpicklerState(references=[NULL, NULL], native=jacpy_unpickler_new())
        );
    }
    return wrap(
        type, PicklerState(references=[NULL, NULL], native=jacpy_pickler_new())
    );
}

impl get_attribute(instance: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    attribute = "persistent_load"
        if isinstance(state, UnpicklerState)
        else "persistent_id";
    if state.references[0] != 0
        and jacpy_is_unicode(name) != 0
        and text_value(name) == attribute {
        return Py_NewRef(state.references[0]);
    }
    return PyObject_GenericGetAttr(instance, name);
}

impl set_attribute(
    instance: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    attribute = "persistent_load"
        if isinstance(state, UnpicklerState)
        else "persistent_id";
    if jacpy_is_unicode(name) != 0 and text_value(name) == attribute {
        previous = state.references[0];
        state.references[0] = Py_NewRef(value) if value != 0 else NULL;
        jacpy_release(previous);
        return i32(0);
    }
    return PyObject_GenericSetAttr(instance, name, value);
}

impl persistent_id(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

impl get_memo(instance: ptr[PyObject], unused: u64) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    index = Slot.UNPICKLER_MEMO.value
        if isinstance(state, UnpicklerState)
        else Slot.PICKLER_MEMO.value;
    return wrap(
        jacpy_binding_state_get(module, i64(index)),
        MemoState(references=[Py_NewRef(instance)])
    );
}

impl set_memo(instance: ptr[PyObject], value: ptr[PyObject], unused: u64) -> i32 {
    if value == 0 {
        object_error(PyExc_TypeError, "attribute deletion is not supported");
        return i32(-1);
    }
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return i32(-1);
    }
    index = Slot.UNPICKLER_MEMO.value
        if isinstance(state, UnpicklerState)
        else Slot.PICKLER_MEMO.value;
    held = ReferenceState(references=[NULL]);
    held.references[0] = memo_proxy_copy(value)
        if Py_TYPE(value) == jacpy_binding_state_get(module, i64(index))
        else Py_NewRef(value);
    if held.references[0] == 0 {
        return i32(-1);
    }
    if isinstance(state, PicklerState) {
        return i32(jacpy_pickler_memo_set(state.native, held.references[0]));
    }
    if isinstance(state, UnpicklerState) {
        return i32(jacpy_unpickler_memo_set(state.native, held.references[0]));
    }
    return i32(-1);
}

impl retain_state(module: ptr[PyObject], index: int, value: ptr[PyObject]) -> bool {
    if value == 0 {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    jacpy_release(value);
    return True;
}

impl execute(module: ptr[PyObject]) -> i32 {
    Pickler_token.handle = pickler_type.handle;
    Unpickler_token.handle = unpickler_type.handle;
    PicklerMemoProxy_token.handle = pickler_memo_type.handle;
    UnpicklerMemoProxy_token.handle = unpickler_memo_type.handle;
    pickle_module_token.handle = definition.handle;
    if not add_state_owned(
        module,
        Slot.ERROR.value,
        "PickleError",
        jacpy_binding_exception("_pickle.PickleError", NULL, "")
    ) {
        return i32(-1);
    }
    error = jacpy_binding_state_get(module, i64(Slot.ERROR.value));
    if not add_state_owned(
        module,
        Slot.PICKLING_ERROR.value,
        "PicklingError",
        jacpy_binding_exception("_pickle.PicklingError", error, "")
    )
        or not add_state_owned(
            module,
            Slot.UNPICKLING_ERROR.value,
            "UnpicklingError",
            jacpy_binding_exception("_pickle.UnpicklingError", error, "")
        )
        or not add_state_owned(
            module, Slot.PICKLER.value, "Pickler", pickler_type.create(module)
        )
        or not add_state_owned(
            module, Slot.UNPICKLER.value, "Unpickler", unpickler_type.create(module)
        )
        or not retain_state(
            module, Slot.PICKLER_MEMO.value, pickler_memo_type.create(module)
        )
        or not retain_state(
            module, Slot.UNPICKLER_MEMO.value, unpickler_memo_type.create(module)
        )
        or not retain_state(
            module,
            Slot.DISPATCH.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("copyreg"), ptr[u8]("dispatch_table")
            )
        )
        or not retain_state(
            module,
            Slot.EXTENSION_REGISTRY.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("copyreg"), ptr[u8]("_extension_registry")
            )
        )
        or not retain_state(
            module,
            Slot.EXTENSION_CACHE.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("copyreg"), ptr[u8]("_extension_cache")
            )
        )
        or not retain_state(
            module,
            Slot.INVERTED_REGISTRY.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("copyreg"), ptr[u8]("_inverted_registry")
            )
        )
        or not retain_state(
            module,
            Slot.NAME_MAPPING_2TO3.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("_compat_pickle"), ptr[u8]("NAME_MAPPING")
            )
        )
        or not retain_state(
            module,
            Slot.IMPORT_MAPPING_2TO3.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("_compat_pickle"), ptr[u8]("IMPORT_MAPPING")
            )
        )
        or not retain_state(
            module,
            Slot.NAME_MAPPING_3TO2.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("_compat_pickle"), ptr[u8]("REVERSE_NAME_MAPPING")
            )
        )
        or not retain_state(
            module,
            Slot.IMPORT_MAPPING_3TO2.value,
            PyImport_ImportModuleAttrString(
                ptr[u8]("_compat_pickle"), ptr[u8]("REVERSE_IMPORT_MAPPING")
            )
        )
        or not retain_state(
            module,
            Slot.CODECS_ENCODE.value,
            PyImport_ImportModuleAttrString(ptr[u8]("codecs"), ptr[u8]("encode"))
        )
        or not retain_state(
            module,
            Slot.GETATTR.value,
            PyImport_ImportModuleAttrString(ptr[u8]("builtins"), ptr[u8]("getattr"))
        )
        or not retain_state(
            module,
            Slot.PARTIAL.value,
            PyImport_ImportModuleAttrString(ptr[u8]("functools"), ptr[u8]("partial"))
        )
        or not add_owned(
            module, "PickleBuffer", builtin_type(builtin_kind.PICKLE_BUFFER)
        ) {
        return i32(-1);
    }
    return i32(0);
}

impl PyInit__pickle -> ptr[PyObject] {
    return definition.initialize();
}
