"""Public native ABI for pickle state and Python object adapters."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_Clear,
    PyDict_Copy,
    PyDict_New,
    PyDict_SetItem,
    PyExc_TypeError,
    PyExc_ValueError,
    PyList_GetItemRef,
    PyLong_AsLongLong,
    PyLong_FromLongLong,
    PyLong_FromVoidPtr,
    PyMapping_Items,
    PyObject,
    jacpy_set_exception,
    jacpy_optional_attr,
    Py_TYPE,
    Py_None,
    PyObject_GetAttrString,
    PyObject_CallOneArg,
    PyObject_Call,
    PyExc_RuntimeError,
    PyExc_AttributeError,
    PyErr_ExceptionMatches,
    PyErr_Clear,
    PyObject_GetIter,
    PyTuple_Size,
    Py_NewRef,
    _PyDict_SizeOf,
    jacpy_bytearray_memory,
    jacpy_error_pending,
    jacpy_is_dict,
    jacpy_is_tuple,
    jacpy_list_size,
    jacpy_release,
    jacpy_tuple_item
}
import from jaclang.runtime.python.modules.pickle_encode { pickle_state }
import from jaclang.runtime.python.modules.pickle_decode { unpickle_state }
import from jaclang.runtime.python.modules.pickle_objects { find_global }
import from jaclang.runtime.python.modules.pickle_stream { builtin_stream_error }
import from jaclang.runtime.python.capi {
    text_value,
    required,
    checked,
    boundary_failure,
    jac_heap_size,
    jac_list_heap_size
}

import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.references { ReferenceState, owned_tuple }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_basicsize,
    jacpy_binding_owner,
    jacpy_binding_record,
    jacpy_binding_type_matches
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.members { record_int, record_set_int }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.capi {
    builtin_kind,
    builtin_type,
    object_error,
    text_object
}

def retain_optional(value: ptr[PyObject]) -> ptr[PyObject] {
    if value != 0 {
        return Py_NewRef(value);
    }
    return NULL;
}

def:pub jacpy_pickler_new -> pickle_state {
    return pickle_state();
}

def:pub jacpy_pickler_clear(state: pickle_state) {
    state.clear();
}

def:pub jacpy_unpickler_new -> unpickle_state {
    return unpickle_state();
}

def:pub jacpy_unpickler_clear(state: unpickle_state) {
    state.clear();
}

def:pub jacpy_pickler_init(
    state: pickle_state,
    write: ptr[PyObject],
    protocol: i64,
    fix_imports: i64,
    callback: ptr[PyObject],
    error: ptr[PyObject]
) -> i64 {
    try {
        state.clear();
        state.error = Py_NewRef(error);
        state.protocol = int(protocol);
        state.fix_imports = fix_imports != 0;
        state.memo = required(PyDict_New());
        state.buffer_callback = retain_optional(callback);
        state.stream.initialize(write, False);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_pickler_dump(
    state: pickle_state,
    value: ptr[PyObject],
    persistent: ptr[PyObject],
    reducer: ptr[PyObject],
    dispatch: ptr[PyObject],
    fast: i64
) -> i64 {
    try {
        state.persistent_id = retain_optional(persistent);
        state.reducer_override = retain_optional(reducer);
        state.dispatch = Py_NewRef(dispatch);
        state.fast = fast != 0;
        state.dump(value);
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        old_pid = state.persistent_id;
        old_reducer = state.reducer_override;
        old_dispatch = state.dispatch;
        state.persistent_id = NULL;
        state.reducer_override = NULL;
        state.dispatch = NULL;
        jacpy_release(old_pid);
        jacpy_release(old_reducer);
        jacpy_release(old_dispatch);
    }
}

def:pub jacpy_pickler_field(state: pickle_state, index: i64) -> ptr[PyObject] {
    return [
        state.stream.buffer,
        state.stream.write,
        state.memo,
        state.persistent_id,
        state.reducer_override,
        state.dispatch,
        state.buffer_callback,
        state.error
    ][int(index)];
}

def:pub jacpy_pickler_size(state: pickle_state) -> i64 {
    result = jac_heap_size(u64(id(state))) + jac_heap_size(u64(id(state.stream)));
    if state.stream.buffer != 0 {
        result += jacpy_bytearray_memory(state.stream.buffer);
    }
    if state.memo != 0 {
        result += _PyDict_SizeOf(state.memo);
    }
    return result;
}

def:pub jacpy_unpickler_init(
    state: unpickle_state,
    read: ptr[PyObject],
    readline: ptr[PyObject],
    error: ptr[PyObject],
    buffers: ptr[PyObject],
    encoding: ptr[PyObject],
    errors: ptr[PyObject]
) -> i64 {
    try {
        state.clear();
        state.error = Py_NewRef(error);
        state.encoding = text_value(encoding);
        state.errors = text_value(errors);
        state.memo = required(PyDict_New());
        state.stream.initialize(read, readline, error);
        if buffers != 0 {
            state.buffers = required(PyObject_GetIter(buffers));
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_unpickler_load(
    state: unpickle_state, find: ptr[PyObject], persistent: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        state.find_class = Py_NewRef(find);
        state.persistent_load = retain_optional(persistent);
        return state.load();
    } except boundary_failure {
        return NULL;
    } finally {
        state.reset_stack();
        old_find = state.find_class;
        old_persistent = state.persistent_load;
        state.find_class = NULL;
        state.persistent_load = NULL;
        jacpy_release(old_find);
        jacpy_release(old_persistent);
    }
}

def:pub jacpy_unpickler_find(
    state: unpickle_state, module: ptr[PyObject], name: ptr[PyObject], fix_imports: i64
) -> ptr[PyObject] {
    try {
        return find_global(module, name, state.protocol, fix_imports != 0);
    } except boundary_failure {
        return NULL;
    }
}

def:pub jacpy_unpickler_field_count(state: unpickle_state) -> i64 {
    return 9 + i64(len(state.stack));
}

def:pub jacpy_unpickler_field(state: unpickle_state, index: i64) -> ptr[PyObject] {
    if index >= 9 {
        return state.stack[int(index - 9)];
    }
    return [
        state.stream.read,
        state.stream.readline,
        state.stream.frame,
        state.stream.error,
        state.memo,
        state.find_class,
        state.persistent_load,
        state.buffers,
        state.error
    ][int(index)];
}

def:pub jacpy_unpickler_size(state: unpickle_state) -> i64 {
    result = jac_heap_size(u64(id(state)))
        + jac_heap_size(u64(id(state.stream)))
        + jac_list_heap_size(u64(id(state.stack)))
        + jac_list_heap_size(u64(id(state.marks)));
    if state.memo != 0 {
        result += _PyDict_SizeOf(state.memo);
    }
    return result;
}

def:pub jacpy_pickler_memo(state: pickle_state) -> ptr[PyObject] {
    return PyDict_Copy(state.memo) if state.memo != 0 else PyDict_New();
}

def:pub jacpy_pickler_memo_clear(state: pickle_state) {
    if state.memo != 0 {
        PyDict_Clear(state.memo);
    }
}

def:pub jacpy_unpickler_memo(state: unpickle_state) -> ptr[PyObject] {
    return PyDict_Copy(state.memo) if state.memo != 0 else PyDict_New();
}

def:pub jacpy_unpickler_memo_clear(state: unpickle_state) {
    if state.memo != 0 {
        PyDict_Clear(state.memo);
    }
}

def memo_copy(value: ptr[PyObject], pickler: bool) -> ptr[PyObject] {
    if jacpy_is_dict(value) == 0 {
        builtin_stream_error(
            PyExc_TypeError, "'memo' attribute must be a memo proxy or dict"
        );
    }
    result = required(PyDict_New());
    items: ptr[PyObject] = NULL;
    try {
        items = required(PyMapping_Items(value));
        for i in range(int(jacpy_list_size(items))) {
            pair = required(PyList_GetItemRef(items, i64(i)));
            key: ptr[PyObject] = NULL;
            val: ptr[PyObject] = NULL;
            index: ptr[PyObject] = NULL;
            stored: ptr[PyObject] = NULL;
            identity: ptr[PyObject] = NULL;
            try {
                key = required(jacpy_tuple_item(pair, 0));
                val = required(jacpy_tuple_item(pair, 1));
                if pickler {
                    if jacpy_is_tuple(val) == 0 or PyTuple_Size(val) != 2 {
                        builtin_stream_error(
                            PyExc_TypeError, "'memo' values must be 2-item tuples"
                        );
                    }
                    index = required(jacpy_tuple_item(val, 0));
                    stored = required(jacpy_tuple_item(val, 1));
                    number = PyLong_AsLongLong(index);
                    if jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    identity = required(PyLong_FromVoidPtr(stored));
                    checked(PyDict_SetItem(result, identity, val));
                } else {
                    number = PyLong_AsLongLong(key);
                    if jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    if number < 0 {
                        builtin_stream_error(
                            PyExc_ValueError, "memo key must be positive integers."
                        );
                    }
                    index = required(PyLong_FromLongLong(number));
                    checked(PyDict_SetItem(result, index, val));
                }
            } finally {
                jacpy_release(pair);
                jacpy_release(key);
                jacpy_release(val);
                jacpy_release(index);
                jacpy_release(stored);
                jacpy_release(identity);
            }
        }
        return Py_NewRef(result);
    } finally {
        jacpy_release(result);
        jacpy_release(items);
    }
}

def:pub jacpy_pickler_memo_set(state: pickle_state, value: ptr[PyObject]) -> i64 {
    try {
        updated = memo_copy(value, True);
        old = state.memo;
        state.memo = updated;
        jacpy_release(old);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_unpickler_memo_set(state: unpickle_state, value: ptr[PyObject]) -> i64 {
    try {
        updated = memo_copy(value, False);
        old = state.memo;
        state.memo = updated;
        jacpy_release(old);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

# Module state slots.
enum Slot {
    PICKLER = 0,
    UNPICKLER = 1,
    PICKLER_MEMO = 2,
    UNPICKLER_MEMO = 3,
    ERROR = 4,
    PICKLING_ERROR = 5,
    UNPICKLING_ERROR = 6,
    BYTESIO = 7,
    DISPATCH = 8
}

# The definitions the binding creates; methods find the receiver's state and
# module by them.
glob Pickler_token = ClassToken(),
     Unpickler_token = ClassToken(),
     PicklerMemoProxy_token = ClassToken(),
     UnpicklerMemoProxy_token = ClassToken(),
     pickle_module_token = ClassToken();

# Pickler's record (Pickler_members[]): bin and fast as C ints, then the
# dispatch_table it owns.
glob PICKLER_BIN: int = 0,
     PICKLER_FAST: int = 4,
     PICKLER_DISPATCH: int = 8,
     PICKLER_RECORD: int = 16;

obj CodecState(ReferenceState) {
    has initialized: bool = False,
        busy: bool = False,
        fix_imports: i64 = 1;

    override def clear {
        self.initialized = False;
        super.clear();
    }

    def enter -> bool {
        if self.busy {
            object_error(PyExc_RuntimeError, "pickle object is already in use");
            return False;
        }
        self.busy = True;
        return True;
    }
}

obj PicklerState(CodecState) {
    has native: pickle_state;

    override def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        result = super.traverse_refs(visitor, context);
        if result != 0 {
            return result;
        }
        for index in range(8) {
            result = visit_reference(
                jacpy_pickler_field(self.native, i64(index)), visitor, context
            );
            if result != 0 {
                return result;
            }
        }
        return i32(0);
    }

    override def clear {
        super.clear();
        jacpy_pickler_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj UnpicklerState(CodecState) {
    has native: unpickle_state;

    override def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        result = super.traverse_refs(visitor, context);
        if result != 0 {
            return result;
        }
        for index in range(int(jacpy_unpickler_field_count(self.native))) {
            result = visit_reference(
                jacpy_unpickler_field(self.native, i64(index)), visitor, context
            );
            if result != 0 {
                return result;
            }
        }
        return i32(0);
    }

    override def clear {
        super.clear();
        jacpy_unpickler_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj MemoState(ReferenceState) {}

def module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, pickle_module_token.handle);
}

def type_definition(type: ptr[PyObject]) -> ptr {
    for token in [
        Pickler_token,
        Unpickler_token,
        PicklerMemoProxy_token,
        UnpicklerMemoProxy_token
    ] {
        if jacpy_binding_type_matches(type, token.handle) != 0 {
            return token.handle;
        }
    }
    return ptr();
}

def state_for(instance: ptr[PyObject]) -> (CodecState | None) {
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

def wrap(type: ptr[PyObject], state: NativeState) -> ptr[PyObject] {
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

def pickler_record(instance: ptr[PyObject]) -> ptr {
    return jacpy_binding_record(instance, Pickler_token.handle);
}

def:priv fail(
    message: str, category: ptr[PyObject] = PyExc_TypeError
) -> ptr[PyObject] {
    object_error(category, message);
    return NULL;
}

def module_error(instance: ptr[PyObject], slot: int, message: str) -> ptr[PyObject] {
    module = module_for(Py_TYPE(instance));
    if module != 0 {
        jacpy_set_exception(
            jacpy_binding_state_get(module, i64(slot)), message, i64(len(message))
        );
    }
    return NULL;
}

def:priv memo_owner(instance: ptr[PyObject]) -> ptr[PyObject] {
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

# A memo proxy's owner's memo as a new dict.
def memo_proxy_copy(instance: ptr[PyObject]) -> ptr[PyObject] {
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

def:priv memo_proxy_clear(instance: ptr[PyObject]) -> ptr[PyObject] {
    owner = memo_owner(instance);
    if owner == 0 {
        return NULL;
    }
    state = state_for(owner);
    if isinstance(state, PicklerState) {
        jacpy_pickler_memo_clear(state.native);
        return Py_NewRef(Py_None);
    }
    if isinstance(state, UnpicklerState) {
        jacpy_unpickler_memo_clear(state.native);
        return Py_NewRef(Py_None);
    }
    return NULL;
}

def:priv memo_proxy_reduce(instance: ptr[PyObject]) -> ptr[PyObject] {
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

# These helpers borrow values; the caller keeps them alive.
def:priv keywords(names: list[str], values: list[ptr[PyObject]]) -> ptr[PyObject] {
    held = ReferenceState(references=[PyDict_New(), NULL]);
    if held.references[0] == 0 {
        return NULL;
    }
    for index in range(len(names)) {
        held.references[1] = text_object(names[index]);
        if held.references[1] == 0 {
            return NULL;
        }
        result = PyDict_SetItem(held.references[0], held.references[1], values[index]);
        previous = held.references[1];
        held.references[1] = NULL;
        jacpy_release(previous);
        if result < 0 {
            return NULL;
        }
    }
    return Py_NewRef(held.references[0]);
}

def:priv write_value(
    module: ptr[PyObject],
    value: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix: bool,
    callback: ptr[PyObject]
) -> ptr[PyObject] {
    held = ReferenceState(references=[NULL, NULL, NULL, PyBool_FromLong(i64(fix))]);
    held.references[0] = owned_tuple([Py_NewRef(file), Py_NewRef(protocol)]);
    if held.references[0] == 0 {
        return NULL;
    }
    held.references[1] = keywords(
        ["fix_imports", "buffer_callback"], [held.references[3], callback]
    );
    if held.references[1] == 0 {
        return NULL;
    }
    held.references[2] = PyObject_Call(
        jacpy_binding_state_get(module, i64(Slot.PICKLER.value)),
        held.references[0],
        held.references[1]
    );
    if held.references[2] == 0 {
        return NULL;
    }
    return pickler_dump(held.references[2], value);
}

def:priv pickler_dump(instance: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, PicklerState) {
        return NULL;
    }
    if not state.initialized {
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
        held.references[0] = required(
            PyObject_GetAttrString(instance, "persistent_id")
        );
        held.references[1] = jacpy_optional_attr(instance, "reducer_override");
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        held.references[2] = jacpy_optional_attr(instance, "dispatch_table");
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        if held.references[2] == 0 {
            held.references[2] = Py_NewRef(
                jacpy_binding_state_get(module, i64(Slot.DISPATCH.value))
            );
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
    } except boundary_failure {
        return NULL;
    } finally {
        state.busy = False;
    }
}

def:priv unpickler_load(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, UnpicklerState) {
        return NULL;
    }
    if not state.initialized {
        return module_error(
            instance, Slot.UNPICKLING_ERROR.value, "Unpickler.__init__() was not called"
        );
    }
    if not state.enter() {
        return NULL;
    }
    held = ReferenceState(references=[NULL, NULL]);
    try {
        held.references[0] = required(PyObject_GetAttrString(instance, "find_class"));
        held.references[1] = required(
            PyObject_GetAttrString(instance, "persistent_load")
        );
        return jacpy_unpickler_load(
            state.native, held.references[0], held.references[1]
        );
    } except boundary_failure {
        return NULL;
    } finally {
        state.busy = False;
    }
}

def:priv unpickle(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    held = ReferenceState(
        references=[
            PyObject_Call(
                jacpy_binding_state_get(module, i64(Slot.UNPICKLER.value)), args, kwargs
            )
        ]
    );
    return unpickler_load(held.references[0]) if held.references[0] else NULL;
}

# The Argument Clinic _impl functions.
# Pickler.__init__ returns clinic's int: -1 with the exception set.
def _pickle_Pickler___init___impl(
    instance: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> i32 {
    version: i64 = 5;
    if protocol != Py_None {
        version = PyLong_AsLongLong(protocol);
        if version == -1 and jacpy_error_pending() != 0 {
            return i32(-1);
        }
        if version < 0 {
            version = 5;
        }
    }
    if version > 5 {
        fail("pickle protocol must be <= 5", PyExc_ValueError);
        return i32(-1);
    }
    callback = buffer_callback if buffer_callback != Py_None else NULL;
    if callback != 0 and version < 5 {
        fail("buffer_callback needs protocol >= 5", PyExc_ValueError);
        return i32(-1);
    }
    state = state_for(instance);
    if not isinstance(state, PicklerState) or not state.enter() {
        return i32(-1);
    }
    held = ReferenceState(references=[NULL]);
    try {
        module = module_for(Py_TYPE(instance));
        if module == 0 {
            return i32(-1);
        }
        held.references[0] = PyObject_GetAttrString(file, "write");
        if held.references[0] == 0 {
            if PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
                PyErr_Clear();
                fail("file must have a 'write' attribute");
            }
            return i32(-1);
        }
        fix = i64(1 if fix_imports else 0);
        result = jacpy_pickler_init(
            state.native,
            held.references[0],
            version,
            fix,
            callback,
            jacpy_binding_state_get(module, i64(Slot.PICKLING_ERROR.value))
        );
        if result == 0 {
            state.initialized = True;
            record = pickler_record(instance);
            record_set_int(record, PICKLER_BIN, 1 if version > 0 else 0);
            record_set_int(record, PICKLER_FAST, 0);
            state.fix_imports = fix;
        }
        return i32(result);
    } finally {
        state.busy = False;
    }
}

def _pickle_Pickler_clear_memo_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, PicklerState) {
        return NULL;
    }
    jacpy_pickler_memo_clear(state.native);
    return Py_NewRef(Py_None);
}

def _pickle_Pickler_dump_impl(
    instance: ptr[PyObject], cls: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    return pickler_dump(instance, obj_);
}

# __sizeof__ returns clinic's size_t.
def:priv codec_size(instance: ptr[PyObject]) -> u64 {
    state = state_for(instance);
    size: i64 = -1;
    if isinstance(state, PicklerState) {
        size = jacpy_pickler_size(state.native);
    } elif isinstance(state, UnpicklerState) {
        size = jacpy_unpickler_size(state.native);
    }
    if size < 0 {
        return u64(0xFFFFFFFFFFFFFFFF);
    }
    return u64(jacpy_binding_basicsize(Py_TYPE(instance)) + size);
}

def _pickle_Pickler___sizeof___impl(instance: ptr[PyObject]) -> u64 {
    return codec_size(instance);
}

def _pickle_Unpickler___sizeof___impl(instance: ptr[PyObject]) -> u64 {
    return codec_size(instance);
}

def _pickle_PicklerMemoProxy_clear_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_clear(instance);
}

def _pickle_PicklerMemoProxy_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_copy(instance);
}

def _pickle_PicklerMemoProxy___reduce___impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_reduce(instance);
}

def _pickle_UnpicklerMemoProxy_clear_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_clear(instance);
}

def _pickle_UnpicklerMemoProxy_copy_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    return memo_proxy_copy(instance);
}

def _pickle_UnpicklerMemoProxy___reduce___impl(
    instance: ptr[PyObject]
) -> ptr[PyObject] {
    return memo_proxy_reduce(instance);
}

def _pickle_Unpickler_persistent_load_impl(
    instance: ptr[PyObject], cls: ptr[PyObject], pid: ptr[PyObject]
) -> ptr[PyObject] {
    return module_error(
        instance,
        Slot.UNPICKLING_ERROR.value,
        "A load persistent id instruction was encountered, but no persistent_load function was specified."
    );
}

def _pickle_Unpickler_load_impl(
    instance: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return unpickler_load(instance);
}

def _pickle_Unpickler_find_class_impl(
    instance: ptr[PyObject],
    cls: ptr[PyObject],
    module_name: ptr[PyObject],
    global_name: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_for(instance);
    return jacpy_unpickler_find(
        state.native, module_name, global_name, state.fix_imports
    )
        if isinstance(state, UnpicklerState)
        else NULL;
}

# Unpickler.__init__ returns clinic's int: -1 with the exception set.
def _pickle_Unpickler___init___impl(
    instance: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> i32 {
    held = ReferenceState(references=[NULL, NULL, NULL, NULL]);
    try {
        held.references[2] = required(text_object(encoding));
        held.references[3] = required(text_object(errors));
    } except boundary_failure {
        return i32(-1);
    }
    state = state_for(instance);
    if not isinstance(state, UnpicklerState) or not state.enter() {
        return i32(-1);
    }
    try {
        module = module_for(Py_TYPE(instance));
        if module == 0 {
            return i32(-1);
        }
        held.references[0] = jacpy_optional_attr(file, "read");
        if jacpy_error_pending() != 0 {
            return i32(-1);
        }
        held.references[1] = jacpy_optional_attr(file, "readline");
        if jacpy_error_pending() != 0 {
            return i32(-1);
        }
        if held.references[0] == 0 or held.references[1] == 0 {
            fail("file must have 'read' and 'readline' attributes");
            return i32(-1);
        }
        given = buffers if buffers != Py_None else NULL;
        result = jacpy_unpickler_init(
            state.native,
            held.references[0],
            held.references[1],
            jacpy_binding_state_get(module, i64(Slot.UNPICKLING_ERROR.value)),
            given,
            held.references[2],
            held.references[3]
        );
        if result == 0 {
            state.initialized = True;
            state.fix_imports = i64(1 if fix_imports else 0);
        }
        return i32(result);
    } finally {
        state.busy = False;
    }
}

def _pickle_dump_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    file: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject] {
    return write_value(module, obj_, file, protocol, fix_imports, buffer_callback);
}

def _pickle_dumps_impl(
    module: ptr[PyObject],
    obj_: ptr[PyObject],
    protocol: ptr[PyObject],
    fix_imports: bool,
    buffer_callback: ptr[PyObject]
) -> ptr[PyObject] {
    held = ReferenceState(references=[NULL, NULL, NULL, NULL]);
    held.references[0] = owned_tuple([]);
    if held.references[0] == 0 {
        return NULL;
    }
    held.references[1] = PyObject_Call(
        jacpy_binding_state_get(module, i64(Slot.BYTESIO.value)),
        held.references[0],
        NULL
    );
    if held.references[1] == 0 {
        return NULL;
    }
    held.references[2] = write_value(
        module, obj_, held.references[1], protocol, fix_imports, buffer_callback
    );
    if held.references[2] == 0 {
        return NULL;
    }
    held.references[3] = PyObject_GetAttrString(held.references[1], "getvalue");
    if held.references[3] == 0 {
        return NULL;
    }
    return PyObject_Call(held.references[3], held.references[0], NULL);
}

# load(file, *, fix_imports=True, encoding="ASCII", errors="strict",
# buffers=()): an Unpickler over `file`.
def _pickle_load_impl(
    module: ptr[PyObject],
    file: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> ptr[PyObject] {
    held = ReferenceState(references=[NULL for _ in range(5)]);
    try {
        held.references[0] = required(owned_tuple([Py_NewRef(file)]));
        held.references[1] = PyBool_FromLong(i64(1 if fix_imports else 0));
        held.references[2] = required(text_object(encoding));
        held.references[3] = required(text_object(errors));
        names = ["fix_imports", "encoding", "errors"];
        values = [held.references[1], held.references[2], held.references[3]];
        if buffers != 0 {
            names.append("buffers");
            values.append(buffers);
        }
        held.references[4] = required(keywords(names, values));
        return unpickle(module, held.references[0], held.references[4]);
    } except boundary_failure {
        return NULL;
    }
}

def _pickle_loads_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    fix_imports: bool,
    encoding: str,
    errors: str,
    buffers: ptr[PyObject]
) -> ptr[PyObject] {
    # _Unpickler_SetStringInput(): the data must export a buffer.
    view = BufferArgument();
    if not view.acquire(data) {
        return NULL;
    }
    held = ReferenceState(references=[NULL for _ in range(6)]);
    try {
        held.references[0] = required(text_object(encoding));
        held.references[1] = required(text_object(errors));
        held.references[2] = required(
            PyObject_CallOneArg(
                jacpy_binding_state_get(module, i64(Slot.BYTESIO.value)), data
            )
        );
        held.references[3] = required(owned_tuple([Py_NewRef(held.references[2])]));
        held.references[4] = PyBool_FromLong(i64(1 if fix_imports else 0));
        names = ["fix_imports", "encoding", "errors"];
        values = [held.references[4], held.references[0], held.references[1]];
        if buffers != 0 {
            names.append("buffers");
            values.append(buffers);
        }
        held.references[5] = required(keywords(names, values));
        return unpickle(module, held.references[3], held.references[5]);
    } except boundary_failure {
        return NULL;
    }
}
