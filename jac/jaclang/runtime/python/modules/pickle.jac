import from c {
    def _PyType_Lookup(type: ptr[PyTypeObject], name: ptr[PyObject]) -> ptr[PyObject];
}

def:pub jacpy_pickler_new -> pickle_state;

def:pub jacpy_pickler_clear(state: pickle_state);

def:pub jacpy_unpickler_new -> unpickle_state;

def:pub jacpy_unpickler_clear(state: unpickle_state);

def:pub jacpy_pickler_dump(
    state: pickle_state,
    value: ptr[PyObject],
    persistent: ptr[PyObject],
    reducer: ptr[PyObject],
    dispatch: ptr[PyObject],
    fast: i64
) -> i64;

def:pub jacpy_unpickler_load(
    state: unpickle_state, find: ptr[PyObject], persistent: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_pickler_memo(state: pickle_state) -> ptr[PyObject];

def:pub jacpy_pickler_memo_clear(state: pickle_state) -> i64;

def:pub jacpy_unpickler_memo(state: unpickle_state) -> ptr[PyObject];

def:pub jacpy_unpickler_memo_clear(state: unpickle_state) -> i64;

def:pub jacpy_pickler_memo_set(state: pickle_state, value: ptr[PyObject]) -> i64;

def:pub jacpy_unpickler_memo_set(state: unpickle_state, value: ptr[PyObject]) -> i64;

enum Slot {
    PICKLER = 0,
    UNPICKLER = 1,
    PICKLER_MEMO = 2,
    UNPICKLER_MEMO = 3,
    ERROR = 4,
    PICKLING_ERROR = 5,
    UNPICKLING_ERROR = 6,
    DISPATCH = 7,
    EXTENSION_REGISTRY = 8,
    EXTENSION_CACHE = 9,
    INVERTED_REGISTRY = 10,
    NAME_MAPPING_2TO3 = 11,
    IMPORT_MAPPING_2TO3 = 12,
    NAME_MAPPING_3TO2 = 13,
    IMPORT_MAPPING_3TO2 = 14,
    CODECS_ENCODE = 15,
    GETATTR = 16,
    PARTIAL = 17
}

glob Pickler_token = ClassToken(),
     Unpickler_token = ClassToken(),
     PicklerMemoProxy_token = ClassToken(),
     UnpicklerMemoProxy_token = ClassToken(),
     pickle_module_token = ClassToken();

glob PICKLER_BIN: int = 0,
     PICKLER_FAST: int = 4,
     PICKLER_DISPATCH: int = 8,
     PICKLER_RECORD: int = 16;

obj CodecState(ReferenceState) {
    has initialized: bool = False,
        busy: bool = False,
        fix_imports: i64 = 1;

    override def clear;
    def enter -> bool;
}

obj PicklerState(CodecState) {
    has native: pickle_state;

    override def traverse_refs(visitor: ptr, context: ptr) -> i32;
    override def clear;
    def drop;
}

obj UnpicklerState(CodecState) {
    has native: unpickle_state;

    override def traverse_refs(visitor: ptr, context: ptr) -> i32;
    override def clear;
    def drop;
}

obj MemoState(ReferenceState) {}

def module_for(type: ptr[PyObject]) -> ptr[PyObject];

def type_definition(type: ptr[PyObject]) -> ptr;

def state_for(instance: ptr[PyObject]) -> (CodecState | None);

def wrap(type: ptr[PyObject], state: NativeState) -> ptr[PyObject];

def pickler_record(instance: ptr[PyObject]) -> ptr;

def:priv fail(
    message: str, category: ptr[PyObject] = PyExc_TypeError
) -> ptr[PyObject];

def module_error(instance: ptr[PyObject], slot: int, message: str) -> ptr[PyObject];

def:priv memo_owner(instance: ptr[PyObject]) -> ptr[PyObject];

def memo_proxy_copy(instance: ptr[PyObject]) -> ptr[PyObject];

def:priv memo_proxy_clear(instance: ptr[PyObject]) -> ptr[PyObject];

def:priv memo_proxy_reduce(instance: ptr[PyObject]) -> ptr[PyObject];

def:priv overridden_method(
    instance: ptr[PyObject], base: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def:priv codec_name(text: str, dflt: str) -> ptr[PyObject];

def:priv pickler_dump(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def:priv unpickler_load(instance: ptr[PyObject]) -> ptr[PyObject];

def _pickle_Pickler___init___impl(
    instance: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> i32;

def _pickle_Pickler_clear_memo_impl(instance: ptr[PyObject]) -> ptr[PyObject];

def _pickle_Pickler_dump_impl(
    instance: ptr[PyObject], cls: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject];

def:priv codec_size(instance: ptr[PyObject]) -> u64;

def _pickle_Pickler___sizeof___impl(instance: ptr[PyObject]) -> u64;

def _pickle_Unpickler___sizeof___impl(instance: ptr[PyObject]) -> u64;

def _pickle_PicklerMemoProxy_clear_impl(instance: ptr[PyObject]) -> ptr[PyObject];

def _pickle_PicklerMemoProxy_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject];

def _pickle_PicklerMemoProxy___reduce___impl(instance: ptr[PyObject]) -> ptr[PyObject];

def _pickle_UnpicklerMemoProxy_clear_impl(instance: ptr[PyObject]) -> ptr[PyObject];

def _pickle_UnpicklerMemoProxy_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject];

def _pickle_UnpicklerMemoProxy___reduce___impl(
    instance: ptr[PyObject]
) -> ptr[PyObject];

def _pickle_Unpickler_persistent_load_impl(
    instance: ptr[PyObject], cls: ptr[PyObject], pid: ptr[PyObject]
) -> ptr[PyObject];

def _pickle_Unpickler_load_impl(
    instance: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def _pickle_Unpickler_find_class_impl(
    instance: ptr[PyObject],
    cls: ptr[PyObject],
    module_name: ptr[PyObject],
    global_name: ptr[PyObject]
) -> ptr[PyObject];

def _pickle_Unpickler___init___impl(
    instance: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> i32;

def _pickle_dump_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject];

def _pickle_dumps_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject];

def _pickle_load_impl(
    module: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> ptr[PyObject];

def _pickle_loads_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> ptr[PyObject];

impl jacpy_pickler_new -> pickle_state {
    return pickle_state(rec=pickler_new());
}

impl jacpy_pickler_clear(state: pickle_state) {
    rec = state.rec;
    state.rec = ptr[PicklerRec]();
    if rec {
        pickler_free(rec);
    }
}

impl jacpy_unpickler_new -> unpickle_state {
    return unpickle_state(rec=unpickler_new());
}

impl jacpy_unpickler_clear(state: unpickle_state) {
    rec = state.rec;
    state.rec = ptr[UnpicklerRec]();
    if rec {
        unpickler_free(rec);
    }
}

impl jacpy_pickler_dump(
    state: pickle_state,
    value: ptr[PyObject],
    persistent: ptr[PyObject],
    reducer: ptr[PyObject],
    dispatch: ptr[PyObject],
    fast: i64
) -> i64 {
    return i64(
        pickler_dump_file(state.rec, value, persistent, reducer, dispatch, i32(fast))
    );
}

impl jacpy_unpickler_load(
    state: unpickle_state, find: ptr[PyObject], persistent: ptr[PyObject]
) -> ptr[PyObject] {
    return unpickler_run(state.rec, find, persistent);
}

impl jacpy_pickler_memo(state: pickle_state) -> ptr[PyObject] {
    if not state.rec {
        return PyDict_New();
    }
    return pickler_memo_copy(state.rec);
}

impl jacpy_pickler_memo_clear(state: pickle_state) -> i64 {
    if not state.rec {
        return 0;
    }
    return i64(pickler_memo_clear(state.rec));
}

impl jacpy_unpickler_memo(state: unpickle_state) -> ptr[PyObject] {
    if not state.rec {
        return PyDict_New();
    }
    return unpickler_memo_copy(state.rec);
}

impl jacpy_unpickler_memo_clear(state: unpickle_state) -> i64 {
    if not state.rec {
        return 0;
    }
    return i64(unpickler_memo_clear(state.rec));
}

impl jacpy_pickler_memo_set(state: pickle_state, value: ptr[PyObject]) -> i64 {
    if not state.rec {
        state.rec = pickler_new();
        if not state.rec {
            return -1;
        }
    }
    return i64(pickler_memo_set(state.rec, value));
}

impl jacpy_unpickler_memo_set(state: unpickle_state, value: ptr[PyObject]) -> i64 {
    if not state.rec {
        state.rec = unpickler_new();
        if not state.rec {
            return -1;
        }
    }
    return i64(unpickler_memo_set(state.rec, value));
}

impl CodecState.clear {
    self.initialized = False;
    super.clear();
}

impl CodecState.enter -> bool {
    if self.busy {
        object_error(PyExc_RuntimeError, "pickle object is already in use");
        return False;
    }
    self.busy = True;
    return True;
}

impl PicklerState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    result = super.traverse_refs(visitor, context);
    if result != 0 or not self.native.rec {
        return result;
    }
    return pickler_traverse(self.native.rec, ptr(visitor), ptr(context));
}

impl PicklerState.clear {
    super.clear();
    jacpy_pickler_clear(self.native);
}

impl PicklerState.drop {
    self.clear();
}

impl UnpicklerState.traverse_refs(
    visitor: ptr, context: ptr
) -> i32 {
    result = super.traverse_refs(visitor, context);
    if result != 0 or not self.native.rec {
        return result;
    }
    return unpickler_traverse(self.native.rec, ptr(visitor), ptr(context));
}

impl UnpicklerState.clear {
    super.clear();
    jacpy_unpickler_clear(self.native);
}

impl UnpicklerState.drop {
    self.clear();
}

impl module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, pickle_module_token.handle);
}

impl type_definition(type: ptr[PyObject]) -> ptr {
    found = jacpy_binding_token(type);
    if found == Pickler_token.handle
        or found == Unpickler_token.handle
        or found == PicklerMemoProxy_token.handle
        or found == UnpicklerMemoProxy_token.handle {
        return found;
    }
    return ptr();
}

impl state_for(instance: ptr[PyObject]) -> (CodecState | None) {
    handle = type_definition(Py_TYPE(instance));
    if handle != 0 and jacpy_binding_native_present(instance, handle) != 0 {
        state = jacpy_binding_native_get(instance, handle);
        if isinstance(state, CodecState) {
            return state;
        }
    }
    object_error(PyExc_RuntimeError, "uninitialized native pickle object");
    return None;
}

impl wrap(type: ptr[PyObject], state: NativeState) -> ptr[PyObject] {
    handle = type_definition(type);
    if handle == 0 {
        return NULL;
    }
    result = jacpy_binding_allocate(type);
    if result == 0 {
        return NULL;
    }
    if jacpy_binding_native_set(result, handle, state) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

impl pickler_record(instance: ptr[PyObject]) -> ptr {
    return jacpy_binding_record(instance, Pickler_token.handle);
}

impl fail(message: str, category: ptr[PyObject] = PyExc_TypeError) -> ptr[PyObject] {
    object_error(category, message);
    return NULL;
}

impl module_error(instance: ptr[PyObject], slot: int, message: str) -> ptr[PyObject] {
    module = module_for(Py_TYPE(instance));
    if module != 0 {
        jacpy_set_exception(
            jacpy_binding_state_get(module, i64(slot)), message, i64(len(message))
        );
    }
    return NULL;
}

impl memo_owner(instance: ptr[PyObject]) -> ptr[PyObject] {
    handle = type_definition(Py_TYPE(instance));
    if handle != 0 and jacpy_binding_native_present(instance, handle) != 0 {
        state = jacpy_binding_native_get(instance, handle);
        if isinstance(state, MemoState) and state.references[0] != 0 {
            return state.references[0];
        }
    }
    object_error(PyExc_RuntimeError, "uninitialized pickle memo proxy");
    return NULL;
}

impl memo_proxy_copy(instance: ptr[PyObject]) -> ptr[PyObject] {
    owner = memo_owner(instance);
    if owner == 0 {
        return NULL;
    }
    state = state_for(owner);
    if isinstance(state, PicklerState) {
        return jacpy_pickler_memo(state.native);
    }
    if isinstance(state, UnpicklerState) {
        return jacpy_unpickler_memo(state.native);
    }
    return NULL;
}

impl memo_proxy_clear(instance: ptr[PyObject]) -> ptr[PyObject] {
    owner = memo_owner(instance);
    if owner == 0 {
        return NULL;
    }
    state = state_for(owner);
    status: i64 = -1;
    if isinstance(state, PicklerState) {
        status = jacpy_pickler_memo_clear(state.native);
    } elif isinstance(state, UnpicklerState) {
        status = jacpy_unpickler_memo_clear(state.native);
    }
    if status < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl memo_proxy_reduce(instance: ptr[PyObject]) -> ptr[PyObject] {
    held = ReferenceState(references=[memo_proxy_copy(instance), NULL]);
    if held.references[0] == 0 {
        return NULL;
    }
    held.references[1] = owned_tuple([Py_NewRef(held.references[0])]);
    if held.references[1] == 0 {
        return NULL;
    }
    return owned_tuple(
        [builtin_type(builtin_kind.DICT), Py_NewRef(held.references[1])]
    );
}

impl overridden_method(
    instance: ptr[PyObject], base: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    if not name {
        return NULL;
    }
    descr = _PyType_Lookup(object_type(instance), name);
    if descr and descr == _PyType_Lookup(ptr[PyTypeObject](base), name) {
        return NULL;
    }
    return PyObject_GetAttr(instance, name);
}

impl codec_name(text: str, dflt: str) -> ptr[PyObject] {
    if text == dflt {
        return NULL;
    }
    return text_object(text);
}

impl pickler_dump(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, PicklerState) {
        return NULL;
    }
    if not state.initialized or not state.native.rec {
        return module_error(
            instance, Slot.PICKLING_ERROR.value, "Pickler.__init__() was not called"
        );
    }
    if not state.enter() {
        return NULL;
    }
    held = ReferenceState(references=[NULL, NULL, NULL]);
    try {
        module = module_for(Py_TYPE(instance));
        if module == 0 {
            return NULL;
        }
        if state.references[0] != 0 {
            held.references[0] = Py_NewRef(state.references[0]);
        } else {
            name = PyUnicode_InternFromString(ptr[u8]("persistent_id"));
            held.references[0] = overridden_method(
                instance, jacpy_binding_state_get(module, i64(Slot.PICKLER.value)), name
            );
            jacpy_release(name);
            if jacpy_error_pending() != 0 {
                return NULL;
            }
        }
        held.references[1] = jacpy_optional_attr(instance, "reducer_override");
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        held.references[2] = jacpy_optional_attr(instance, "dispatch_table");
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        if jacpy_pickler_dump(
            state.native,
            value,
            held.references[0],
            held.references[1],
            held.references[2],
            i64(record_int(pickler_record(instance), PICKLER_FAST))
        )
            == 0 {
            return Py_NewRef(Py_None);
        }
        return NULL;
    } finally {
        state.busy = False;
    }
}

impl unpickler_load(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, UnpicklerState) {
        return NULL;
    }
    if not state.initialized or not state.native.rec {
        return module_error(
            instance, Slot.UNPICKLING_ERROR.value, "Unpickler.__init__() was not called"
        );
    }
    if not state.enter() {
        return NULL;
    }
    held = ReferenceState(references=[NULL, NULL]);
    try {
        module = module_for(Py_TYPE(instance));
        if module == 0 {
            return NULL;
        }
        base = jacpy_binding_state_get(module, i64(Slot.UNPICKLER.value));
        if Py_TYPE(instance) != base {
            held.references[0] = PyObject_GetAttrString(
                instance, ptr[u8]("find_class")
            );
            if held.references[0] == 0 {
                return NULL;
            }
        }
        if state.references[0] != 0 {
            held.references[1] = Py_NewRef(state.references[0]);
        } else {
            name = PyUnicode_InternFromString(ptr[u8]("persistent_load"));
            held.references[1] = overridden_method(instance, base, name);
            jacpy_release(name);
            if jacpy_error_pending() != 0 {
                return NULL;
            }
        }
        return jacpy_unpickler_load(
            state.native, held.references[0], held.references[1]
        );
    } finally {
        state.busy = False;
    }
}

impl _pickle_Pickler___init___impl(
    instance: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> i32 {
    state = state_for(instance);
    if not isinstance(state, PicklerState) or not state.enter() {
        return i32(-1);
    }
    try {
        module = module_for(Py_TYPE(instance));
        if module == 0 {
            return i32(-1);
        }
        if not state.native.rec {
            state.native.rec = pickler_new();
            if not state.native.rec {
                return i32(-1);
            }
        }
        rec = state.native.rec;
        if pickler_init(rec, module, file, protocol, fix_imports, buffer_callback)
            < 0 {
            return i32(-1);
        }
        state.initialized = True;
        record = pickler_record(instance);
        record_set_int(record, PICKLER_BIN, int(rec.view(1)[0].bin));
        record_set_int(record, PICKLER_FAST, 0);
        state.fix_imports = i64(1 if fix_imports else 0);
        return i32(0);
    } finally {
        state.busy = False;
    }
}

impl _pickle_Pickler_clear_memo_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, PicklerState) {
        return NULL;
    }
    if jacpy_pickler_memo_clear(state.native) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl _pickle_Pickler_dump_impl(
    instance: ptr[PyObject], cls: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    return pickler_dump(instance, obj_);
}

impl codec_size(instance: ptr[PyObject]) -> u64 {
    state = state_for(instance);
    size: i64 = -1;
    if isinstance(state, PicklerState) {
        size = 0;
        if state.native.rec {
            size = pickler_sizeof(state.native.rec);
        }
    } elif isinstance(state, UnpicklerState) {
        size = 0;
        if state.native.rec {
            size = unpickler_sizeof(state.native.rec);
        }
    }
    if size < 0 {
        return u64(0xFFFFFFFFFFFFFFFF);
    }
    return u64(jacpy_binding_basicsize(Py_TYPE(instance)) + size);
}

impl _pickle_Pickler___sizeof___impl(instance: ptr[PyObject]) -> u64 {
    return codec_size(instance);
}

impl _pickle_Unpickler___sizeof___impl(instance: ptr[PyObject]) -> u64 {
    return codec_size(instance);
}

impl _pickle_PicklerMemoProxy_clear_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_clear(instance);
}

impl _pickle_PicklerMemoProxy_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_copy(instance);
}

impl _pickle_PicklerMemoProxy___reduce___impl(
    instance: ptr[PyObject]
) -> ptr[PyObject] {
    return memo_proxy_reduce(instance);
}

impl _pickle_UnpicklerMemoProxy_clear_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_clear(instance);
}

impl _pickle_UnpicklerMemoProxy_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_copy(instance);
}

impl _pickle_UnpicklerMemoProxy___reduce___impl(
    instance: ptr[PyObject]
) -> ptr[PyObject] {
    return memo_proxy_reduce(instance);
}

impl _pickle_Unpickler_persistent_load_impl(
    instance: ptr[PyObject], cls: ptr[PyObject], pid: ptr[PyObject]
) -> ptr[PyObject] {
    return module_error(
        instance,
        Slot.UNPICKLING_ERROR.value,
        "A load persistent id instruction was encountered, but no persistent_load function was specified."
    );
}

impl _pickle_Unpickler_load_impl(
    instance: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return unpickler_load(instance);
}

impl _pickle_Unpickler_find_class_impl(
    instance: ptr[PyObject],
    cls: ptr[PyObject],
    module_name: ptr[PyObject],
    global_name: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, UnpicklerState) {
        return NULL;
    }
    module = module_for(Py_TYPE(instance));
    if module == 0 {
        return NULL;
    }
    if not state.native.rec {
        state.native.rec = unpickler_new();
        if not state.native.rec {
            return NULL;
        }
    }
    rec = state.native.rec;
    rec.view(1)[0].module = module;
    return find_class_object(rec, module_name, global_name);
}

impl _pickle_Unpickler___init___impl(
    instance: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> i32 {
    state = state_for(instance);
    if not isinstance(state, UnpicklerState) or not state.enter() {
        return i32(-1);
    }
    try {
        module = module_for(Py_TYPE(instance));
        if module == 0 {
            return i32(-1);
        }
        if not state.native.rec {
            state.native.rec = unpickler_new();
            if not state.native.rec {
                return i32(-1);
            }
        }
        encoding_name = codec_name(encoding, "ASCII");
        errors_name = codec_name(errors, "strict");
        if (encoding_name == 0 or errors_name == 0) and jacpy_error_pending() != 0 {
            jacpy_release(encoding_name);
            jacpy_release(errors_name);
            return i32(-1);
        }
        result = unpickler_init(
            state.native.rec,
            module,
            file,
            fix_imports,
            encoding_name,
            errors_name,
            buffers
        );
        jacpy_release(encoding_name);
        jacpy_release(errors_name);
        if result < 0 {
            return i32(-1);
        }
        state.initialized = True;
        state.fix_imports = i64(1 if fix_imports else 0);
        return i32(0);
    } finally {
        state.busy = False;
    }
}

impl _pickle_dump_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject] {
    return pickle_dump(module, obj_, file, protocol, fix_imports, buffer_callback);
}

impl _pickle_dumps_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject] {
    return pickle_dumps(module, obj_, protocol, fix_imports, buffer_callback);
}

impl _pickle_load_impl(
    module: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> ptr[PyObject] {
    encoding_name = codec_name(encoding, "ASCII");
    errors_name = codec_name(errors, "strict");
    if (encoding_name == 0 or errors_name == 0) and jacpy_error_pending() != 0 {
        jacpy_release(encoding_name);
        jacpy_release(errors_name);
        return NULL;
    }
    result = pickle_load(
        module, file, fix_imports, encoding_name, errors_name, buffers
    );
    jacpy_release(encoding_name);
    jacpy_release(errors_name);
    return result;
}

impl _pickle_loads_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> ptr[PyObject] {
    encoding_name = codec_name(encoding, "ASCII");
    errors_name = codec_name(errors, "strict");
    if (encoding_name == 0 or errors_name == 0) and jacpy_error_pending() != 0 {
        jacpy_release(encoding_name);
        jacpy_release(errors_name);
        return NULL;
    }
    result = pickle_loads(
        module, data, fix_imports, encoding_name, errors_name, buffers
    );
    jacpy_release(encoding_name);
    jacpy_release(errors_name);
    return result;
}
