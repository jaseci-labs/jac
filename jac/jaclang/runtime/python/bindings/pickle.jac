"""Native pickle constructors, descriptors, and Python callback ownership."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition,
    add_owned,
    add_state_owned,
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    jacpy_binding_visit,
    jacpy_binding_exception,
    jacpy_binding_exception_with_base
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    jacpy_binding_typeof,
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_matches,
    jacpy_binding_type_matches,
    jacpy_binding_basicsize
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
    traverse_payload,
    clear_payload,
    dispose_payload
}
import from jaclang.runtime.python.bindings.references { ReferenceState, owned_tuple }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke
}
import from jaclang.runtime.python.capi {
    builtin_kind,
    jacpy_builtin_type,
    jacpy_retain,
    jacpy_release,
    jacpy_none,
    jacpy_is_none,
    jacpy_is_unicode,
    jacpy_int,
    jacpy_boolean,
    jacpy_integer_value,
    jacpy_long_as_int32,
    jacpy_truth,
    jacpy_error_pending,
    jacpy_error_is,
    jacpy_clear_error,
    jacpy_optional_attr,
    jacpy_getattr_string,
    jacpy_generic_getattr,
    jacpy_generic_setattr,
    jacpy_import_attr,
    jacpy_call,
    jacpy_call_one,
    jacpy_dict_new,
    jacpy_dict_set,
    jacpy_set_exception,
    text_value,
    text_object,
    object_error,
    required,
    boundary_failure
}
import from jaclang.runtime.python.modules.pickle_encode { pickle_state }
import from jaclang.runtime.python.modules.pickle_decode { unpickle_state }
import from jaclang.runtime.python.modules.pickle {
    jacpy_pickler_new,
    jacpy_pickler_clear,
    jacpy_unpickler_new,
    jacpy_unpickler_clear,
    jacpy_pickler_init,
    jacpy_pickler_dump,
    jacpy_pickler_field,
    jacpy_pickler_size,
    jacpy_unpickler_init,
    jacpy_unpickler_load,
    jacpy_unpickler_find,
    jacpy_unpickler_field_count,
    jacpy_unpickler_field,
    jacpy_unpickler_size,
    jacpy_pickler_memo,
    jacpy_pickler_memo_clear,
    jacpy_unpickler_memo,
    jacpy_unpickler_memo_clear,
    jacpy_pickler_memo_set,
    jacpy_unpickler_memo_set
}

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

obj CodecState(ReferenceState) {
    has initialized: bool = False,
        busy: bool = False,
        bin: i64 = 0,
        fast: i64 = 0,
        fix_imports: i64 = 1;

    override def clear {
        self.initialized = False;
        super.clear();
    }

    def enter -> bool {
        if self.busy {
            object_error("RuntimeError", "pickle object is already in use");
            return False;
        }
        self.busy = True;
        return True;
    }
}

obj PicklerState(CodecState) {
    has native: pickle_state;

    override def traverse_refs(visitor: u64, context: u64) -> i32 {
        result = super.traverse_refs(visitor, context);
        if result != 0 {
            return result;
        }
        for index in range(8) {
            result = jacpy_binding_visit(
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

    override def traverse_refs(visitor: u64, context: u64) -> i32 {
        result = super.traverse_refs(visitor, context);
        if result != 0 {
            return result;
        }
        for index in range(int(jacpy_unpickler_field_count(self.native))) {
            result = jacpy_binding_visit(
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
def:priv module_for(type: u64) -> u64 {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv type_definition(type: u64) -> u64 {
    if jacpy_binding_type_matches(type, pickler_type.handle) != 0 {
        return pickler_type.handle;
    }
    if jacpy_binding_type_matches(type, unpickler_type.handle) != 0 {
        return unpickler_type.handle;
    }
    if jacpy_binding_type_matches(type, pickler_memo_type.handle) != 0 {
        return pickler_memo_type.handle;
    }
    if jacpy_binding_type_matches(type, unpickler_memo_type.handle) != 0 {
        return unpickler_memo_type.handle;
    }
    return 0;
}

def:priv state_for(instance: u64) -> (CodecState | None) {
    handle = type_definition(jacpy_binding_typeof(instance));
    if handle != 0 and jacpy_binding_native_present(instance, handle) != 0 {
        state = jacpy_binding_native_get(instance, handle);
        if isinstance(state, CodecState) {
            return state;
        }
    }
    object_error("RuntimeError", "uninitialized native pickle object");
    return None;
}

def:priv wrap(type: u64, state: NativeState) -> u64 {
    handle = type_definition(type);
    if handle == 0 {
        return 0;
    }
    result = jacpy_binding_allocate(type);
    if result == 0 {
        return 0;
    }
    if jacpy_binding_native_set(result, handle, state) < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(
        instance, type_definition(jacpy_binding_typeof(instance)), visitor, context
    );
}

def:priv clear(instance: u64) -> i32 {
    return clear_payload(instance, type_definition(jacpy_binding_typeof(instance)));
}

def:priv dealloc(instance: u64) {
    dispose_payload(instance, type_definition(jacpy_binding_typeof(instance)));
}

def:priv create(type: u64, args: u64, kwargs: u64) -> u64 {
    if jacpy_binding_type_matches(type, unpickler_type.handle) != 0 {
        return wrap(
            type,
            UnpicklerState(references=[u64(0), u64(0)], native=jacpy_unpickler_new())
        );
    }
    return wrap(
        type, PicklerState(references=[u64(0), u64(0)], native=jacpy_pickler_new())
    );
}

def:priv get_attribute(instance: u64, name: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    attribute = "persistent_load"
        if isinstance(state, UnpicklerState)
        else "persistent_id";
    if state.references[0] != 0
        and jacpy_is_unicode(name) != 0
        and text_value(name) == attribute {
        return jacpy_retain(state.references[0]);
    }
    return jacpy_generic_getattr(instance, name);
}

def:priv set_attribute(instance: u64, name: u64, value: u64) -> i32 {
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    attribute = "persistent_load"
        if isinstance(state, UnpicklerState)
        else "persistent_id";
    if jacpy_is_unicode(name) != 0 and text_value(name) == attribute {
        previous = state.references[0];
        state.references[0] = jacpy_retain(value) if value != 0 else u64(0);
        jacpy_release(previous);
        return i32(0);
    }
    return jacpy_generic_setattr(instance, name, value);
}

def:priv fail(message: str, category: str = "TypeError") -> u64 {
    object_error(category, message);
    return 0;
}

def:priv module_error(instance: u64, slot: int, message: str) -> u64 {
    module = module_for(jacpy_binding_typeof(instance));
    if module != 0 {
        jacpy_set_exception(
            jacpy_binding_state_get(module, i64(slot)), message, i64(len(message))
        );
    }
    return 0;
}

def:priv bind(
    signature: CallSignature, args: u64, kwargs: u64, instance: u64
) -> (BoundArguments | None) {
    bound = BoundArguments([u64(0) for _ in signature.names], instance);
    if not signature.bind(bound, args, kwargs) {
        return None;
    }
    return bound;
}

def:priv flag(value: u64, default_value: i64 = 1) -> i64 {
    return jacpy_truth(value) if value != 0 else default_value;
}

def:priv text_argument(value: u64, default_value: str) -> u64 {
    if value == 0 {
        return text_object(default_value);
    }
    if jacpy_is_unicode(value) == 0 {
        return fail("argument must be str");
    }
    text = text_value(value);
    if "\0" in text {
        return fail("embedded null character", "ValueError");
    }
    return text_object(text);
}

def:priv initialize_pickler(instance: u64, args: u64, kwargs: u64) -> i32 {
    try {
        bound = bind(pickler_signature, args, kwargs, instance);
        if bound is None {
            return i32(-1);
        }
        version: i64 = 5;
        if bound.values[1] != 0 and jacpy_is_none(bound.values[1]) == 0 {
            version = jacpy_integer_value(bound.values[1]);
            if version == -1 and jacpy_error_pending() != 0 {
                return i32(-1);
            }
            if version < 0 {
                version = 5;
            }
        }
        fix = flag(bound.values[2]);
        if fix < 0 {
            return i32(-1);
        }
        if version > 5 {
            fail("pickle protocol must be <= 5", "ValueError");
            return i32(-1);
        }
        callback = bound.values[3];
        if callback != 0 and jacpy_is_none(callback) != 0 {
            callback = 0;
        }
        if callback != 0 and version < 5 {
            fail("buffer_callback needs protocol >= 5", "ValueError");
            return i32(-1);
        }
        state = state_for(instance);
        if not isinstance(state, PicklerState) or not state.enter() {
            return i32(-1);
        }
        held = ReferenceState(references=[u64(0)]);
        try {
            module = module_for(jacpy_binding_typeof(instance));
            if module == 0 {
                return i32(-1);
            }
            held.references[0] = jacpy_getattr_string(bound.values[0], "write");
            if held.references[0] == 0 {
                if jacpy_error_is("AttributeError") != 0 {
                    jacpy_clear_error();
                    fail("file must have a 'write' attribute");
                }
                return i32(-1);
            }
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
                state.bin = i64(version > 0);
                state.fast = 0;
                state.fix_imports = fix;
            }
            return i32(result);
        } finally {
            state.busy = False;
        }
    } except boundary_failure {
        return i32(-1);
    }
}

def:priv initialize_unpickler(instance: u64, args: u64, kwargs: u64) -> i32 {
    try {
        bound = bind(unpickler_signature, args, kwargs, instance);
        if bound is None {
            return i32(-1);
        }
        fix = flag(bound.values[1]);
        if fix < 0 {
            return i32(-1);
        }
        held = ReferenceState(references=[u64(0), u64(0), u64(0), u64(0)]);
        held.references[2] = required(text_argument(bound.values[2], "ASCII"));
        held.references[3] = required(text_argument(bound.values[3], "strict"));
        state = state_for(instance);
        if not isinstance(state, UnpicklerState) or not state.enter() {
            return i32(-1);
        }
        try {
            module = module_for(jacpy_binding_typeof(instance));
            if module == 0 {
                return i32(-1);
            }
            held.references[0] = jacpy_optional_attr(bound.values[0], "read");
            if jacpy_error_pending() != 0 {
                return i32(-1);
            }
            held.references[1] = jacpy_optional_attr(bound.values[0], "readline");
            if jacpy_error_pending() != 0 {
                return i32(-1);
            }
            if held.references[0] == 0 or held.references[1] == 0 {
                fail("file must have 'read' and 'readline' attributes");
                return i32(-1);
            }
            buffers = bound.values[4];
            if buffers != 0 and jacpy_is_none(buffers) != 0 {
                buffers = 0;
            }
            result = jacpy_unpickler_init(
                state.native,
                held.references[0],
                held.references[1],
                jacpy_binding_state_get(module, i64(Slot.UNPICKLING_ERROR.value)),
                buffers,
                held.references[2],
                held.references[3]
            );
            if result == 0 {
                state.initialized = True;
                state.fix_imports = fix;
            }
            return i32(result);
        } finally {
            state.busy = False;
        }
    } except boundary_failure {
        return i32(-1);
    }
}

def:priv dump(instance: u64, value: u64) -> u64 {
    state = state_for(instance);
    if not isinstance(state, PicklerState) {
        return 0;
    }
    if not state.initialized {
        return module_error(
            instance, Slot.PICKLING_ERROR.value, "Pickler.__init__() was not called"
        );
    }
    if not state.enter() {
        return 0;
    }
    held = ReferenceState(references=[u64(0), u64(0), u64(0)]);
    try {
        module = module_for(jacpy_binding_typeof(instance));
        if module == 0 {
            return 0;
        }
        held.references[0] = required(jacpy_getattr_string(instance, "persistent_id"));
        held.references[1] = jacpy_optional_attr(instance, "reducer_override");
        if jacpy_error_pending() != 0 {
            return 0;
        }
        held.references[2] = jacpy_optional_attr(instance, "dispatch_table");
        if jacpy_error_pending() != 0 {
            return 0;
        }
        if held.references[2] == 0 {
            held.references[2] = jacpy_retain(
                jacpy_binding_state_get(module, i64(Slot.DISPATCH.value))
            );
        }
        if jacpy_pickler_dump(
            state.native,
            value,
            held.references[0],
            held.references[1],
            held.references[2],
            state.fast
        )
            == 0 {
            return jacpy_none();
        }
        return 0;
    } except boundary_failure {
        return 0;
    } finally {
        state.busy = False;
    }
}

def:priv load(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if not isinstance(state, UnpicklerState) {
        return 0;
    }
    if not state.initialized {
        return module_error(
            instance, Slot.UNPICKLING_ERROR.value, "Unpickler.__init__() was not called"
        );
    }
    if not state.enter() {
        return 0;
    }
    held = ReferenceState(references=[u64(0), u64(0)]);
    try {
        held.references[0] = required(jacpy_getattr_string(instance, "find_class"));
        held.references[1] = required(
            jacpy_getattr_string(instance, "persistent_load")
        );
        return jacpy_unpickler_load(
            state.native, held.references[0], held.references[1]
        );
    } except boundary_failure {
        return 0;
    } finally {
        state.busy = False;
    }
}

def:priv persistent_id(instance: u64, value: u64) -> u64 {
    return jacpy_none();
}

def:priv persistent_load(instance: u64, value: u64) -> u64 {
    return module_error(
        instance,
        Slot.UNPICKLING_ERROR.value,
        "A load persistent id instruction was encountered, but no persistent_load function was specified."
    );
}

def:priv find_bound(args: BoundArguments) -> u64 {
    state = state_for(args.context);
    return jacpy_unpickler_find(
        state.native, args.values[0], args.values[1], state.fix_imports
    )
        if isinstance(state, UnpicklerState)
        else u64(0);
}

def:priv find_class(instance: u64, args: u64) -> u64 {
    return invoke(
        CallSignature("find_class", ["module", "name"], 2, 2, 2),
        args,
        0,
        find_bound,
        instance
    );
}

def:priv size_of(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    size: i64 = -1;
    if isinstance(state, PicklerState) {
        size = jacpy_pickler_size(state.native);
    } elif isinstance(state, UnpicklerState) {
        size = jacpy_unpickler_size(state.native);
    }
    return jacpy_int(jacpy_binding_basicsize(jacpy_binding_typeof(instance)) + size)
        if size >= 0
        else u64(0);
}

def:priv memo_owner(instance: u64) -> u64 {
    handle = type_definition(jacpy_binding_typeof(instance));
    if handle != 0 and jacpy_binding_native_present(instance, handle) != 0 {
        state = jacpy_binding_native_get(instance, handle);
        if isinstance(state, MemoState) and state.references[0] != 0 {
            return state.references[0];
        }
    }
    object_error("RuntimeError", "uninitialized pickle memo proxy");
    return 0;
}

def:priv memo_copy(instance: u64, unused: u64) -> u64 {
    owner = memo_owner(instance);
    if owner == 0 {
        return 0;
    }
    state = state_for(owner);
    if isinstance(state, PicklerState) {
        return jacpy_pickler_memo(state.native);
    }
    if isinstance(state, UnpicklerState) {
        return jacpy_unpickler_memo(state.native);
    }
    return 0;
}

def:priv memo_clear(instance: u64, unused: u64) -> u64 {
    owner = memo_owner(instance);
    if owner == 0 {
        return 0;
    }
    state = state_for(owner);
    if isinstance(state, PicklerState) {
        jacpy_pickler_memo_clear(state.native);
        return jacpy_none();
    }
    if isinstance(state, UnpicklerState) {
        jacpy_unpickler_memo_clear(state.native);
        return jacpy_none();
    }
    return 0;
}

def:priv memo_reduce(instance: u64, unused: u64) -> u64 {
    held = ReferenceState(references=[memo_copy(instance, 0), u64(0)]);
    if held.references[0] == 0 {
        return 0;
    }
    held.references[1] = owned_tuple([jacpy_retain(held.references[0])]);
    if held.references[1] == 0 {
        return 0;
    }
    return owned_tuple(
        [
            jacpy_builtin_type(i64(builtin_kind.DICT.value)),
            jacpy_retain(held.references[1])
        ]
    );
}

def:priv get_memo(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return 0;
    }
    index = Slot.UNPICKLER_MEMO.value
        if isinstance(state, UnpicklerState)
        else Slot.PICKLER_MEMO.value;
    return wrap(
        jacpy_binding_state_get(module, i64(index)),
        MemoState(references=[jacpy_retain(instance)])
    );
}

def:priv set_memo(instance: u64, value: u64, unused: u64) -> i32 {
    if value == 0 {
        fail("attribute deletion is not supported");
        return i32(-1);
    }
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    module = module_for(jacpy_binding_typeof(instance));
    if module == 0 {
        return i32(-1);
    }
    index = Slot.UNPICKLER_MEMO.value
        if isinstance(state, UnpicklerState)
        else Slot.PICKLER_MEMO.value;
    held = ReferenceState(references=[u64(0)]);
    held.references[0] = memo_copy(value, 0)
        if jacpy_binding_typeof(value) == jacpy_binding_state_get(module, i64(index))
        else jacpy_retain(value);
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

def:priv clear_memo(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if not isinstance(state, PicklerState) {
        return 0;
    }
    jacpy_pickler_memo_clear(state.native);
    return jacpy_none();
}

def:priv integer_get(instance: u64, field: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    return jacpy_int(state.bin if field == 0 else state.fast);
}

def:priv integer_set(instance: u64, value: u64, field: u64) -> i32 {
    if value == 0 {
        fail("can't delete numeric/char attribute");
        return i32(-1);
    }
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    number = jacpy_long_as_int32(value);
    if number == -1 and jacpy_error_pending() != 0 {
        return i32(-1);
    }
    if field == 0 {
        state.bin = number;
    } else {
        state.fast = number;
    }
    return i32(0);
}

def:priv dispatch_get(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if state is None {
        return 0;
    }
    if state.references[1] == 0 {
        return fail("dispatch_table", "AttributeError");
    }
    return jacpy_retain(state.references[1]);
}

def:priv dispatch_set(instance: u64, value: u64, unused: u64) -> i32 {
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    previous = state.references[1];
    if value == 0 and previous == 0 {
        fail("dispatch_table", "AttributeError");
        return i32(-1);
    }
    state.references[1] = jacpy_retain(value) if value != 0 else u64(0);
    jacpy_release(previous);
    return i32(0);
}

# These helpers borrow values; the caller's BoundArguments owns the call frame.
def:priv keywords(names: list[str], values: list[u64]) -> u64 {
    held = ReferenceState(references=[jacpy_dict_new(), u64(0)]);
    if held.references[0] == 0 {
        return 0;
    }
    for index in range(len(names)) {
        held.references[1] = text_object(names[index]);
        if held.references[1] == 0 {
            return 0;
        }
        result = jacpy_dict_set(held.references[0], held.references[1], values[index]);
        previous = held.references[1];
        held.references[1] = 0;
        jacpy_release(previous);
        if result < 0 {
            return 0;
        }
    }
    return jacpy_retain(held.references[0]);
}

def:priv write_value(
    module: u64, value: u64, file: u64, protocol: u64, fix: i64, callback: u64
) -> u64 {
    held = ReferenceState(references=[u64(0), u64(0), u64(0), jacpy_boolean(fix)]);
    held.references[0] = owned_tuple([jacpy_retain(file), jacpy_retain(protocol)]);
    if held.references[0] == 0 {
        return 0;
    }
    held.references[1] = keywords(
        ["fix_imports", "buffer_callback"], [held.references[3], callback]
    );
    if held.references[1] == 0 {
        return 0;
    }
    held.references[2] = jacpy_call(
        jacpy_binding_state_get(module, i64(Slot.PICKLER.value)),
        held.references[0],
        held.references[1]
    );
    if held.references[2] == 0 {
        return 0;
    }
    return dump(held.references[2], value);
}

def:priv dump_bound(args: BoundArguments) -> u64 {
    if args.values[2] == 0 {
        args.values[2] = jacpy_none();
    }
    if args.values[4] == 0 {
        args.values[4] = jacpy_none();
    }
    fix = flag(args.values[3]);
    if fix < 0 {
        return 0;
    }
    return write_value(
        args.context,
        args.values[0],
        args.values[1],
        args.values[2],
        fix,
        args.values[4]
    );
}

def:priv dumps_bound(args: BoundArguments) -> u64 {
    if args.values[1] == 0 {
        args.values[1] = jacpy_none();
    }
    if args.values[3] == 0 {
        args.values[3] = jacpy_none();
    }
    fix = flag(args.values[2]);
    if fix < 0 {
        return 0;
    }
    held = ReferenceState(references=[u64(0), u64(0), u64(0), u64(0)]);
    held.references[0] = owned_tuple([]);
    if held.references[0] == 0 {
        return 0;
    }
    held.references[1] = jacpy_call(
        jacpy_binding_state_get(args.context, i64(Slot.BYTESIO.value)),
        held.references[0],
        0
    );
    if held.references[1] == 0 {
        return 0;
    }
    held.references[2] = write_value(
        args.context,
        args.values[0],
        held.references[1],
        args.values[1],
        fix,
        args.values[3]
    );
    if held.references[2] == 0 {
        return 0;
    }
    held.references[3] = jacpy_getattr_string(held.references[1], "getvalue");
    if held.references[3] == 0 {
        return 0;
    }
    return jacpy_call(held.references[3], held.references[0], 0);
}

def:priv module_dump(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(dump_signature, args, kwargs, dump_bound, module);
}

def:priv module_dumps(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(dumps_signature, args, kwargs, dumps_bound, module);
}

def:priv module_load(module: u64, args: u64, kwargs: u64) -> u64 {
    held = ReferenceState(
        references=[
            jacpy_call(
                jacpy_binding_state_get(module, i64(Slot.UNPICKLER.value)), args, kwargs
            )
        ]
    );
    return load(held.references[0], 0) if held.references[0] != 0 else u64(0);
}

def:priv loads_bound(args: BoundArguments) -> u64 {
    fix = flag(args.values[1]);
    if fix < 0 {
        return 0;
    }
    held = ReferenceState(references=[u64(0) for _ in range(6)]);
    held.references[0] = required(text_argument(args.values[2], "ASCII"));
    held.references[1] = required(text_argument(args.values[3], "strict"));
    if args.values[4] == 0 {
        args.values[4] = jacpy_none();
    }
    held.references[2] = required(
        jacpy_call_one(
            jacpy_binding_state_get(args.context, i64(Slot.BYTESIO.value)),
            args.values[0]
        )
    );
    held.references[3] = required(owned_tuple([jacpy_retain(held.references[2])]));
    held.references[4] = jacpy_boolean(fix);
    held.references[5] = required(
        keywords(
            ["fix_imports", "encoding", "errors", "buffers"],
            [held.references[4], held.references[0], held.references[1], args.values[4]]
        )
    );
    return module_load(args.context, held.references[3], held.references[5]);
}

def:priv module_loads(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(loads_signature, args, kwargs, loads_bound, module);
}

glob:priv pickler_signature = CallSignature(
         "Pickler", ["file", "protocol", "fix_imports", "buffer_callback"], 1, 2
     ),
     unpickler_signature = CallSignature(
         "Unpickler", ["file", "fix_imports", "encoding", "errors", "buffers"], 1, 1
     ),
     dump_signature = CallSignature(
         "dump", ["obj", "file", "protocol", "fix_imports", "buffer_callback"], 2, 3
     ),
     dumps_signature = CallSignature(
         "dumps", ["obj", "protocol", "fix_imports", "buffer_callback"], 1, 2
     ),
     loads_signature = CallSignature(
         "loads", ["data", "fix_imports", "encoding", "errors", "buffers"], 1, 1
     ),
     flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     pickler_type = TypeDefinition(
         "_pickle.Pickler",
         "",
         [
             MethodDefinition("dump", MethodCallbacks(positional=dump), "", flags=8),
             MethodDefinition(
                 "clear_memo", MethodCallbacks(positional=clear_memo), "", flags=4
             ),
             MethodDefinition(
                 "persistent_id", MethodCallbacks(positional=persistent_id), "", flags=8
             ),
             MethodDefinition(
                 "__sizeof__", MethodCallbacks(positional=size_of), "", flags=4
             )
         ],
         flags | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=create,
             initialize=initialize_pickler,
             dealloc=dealloc,
             traverse=traverse,
             clear=clear,
             get_attribute=get_attribute,
             set_attribute=set_attribute
         ),
         [
             PropertyDefinition("memo", get_memo, write=set_memo),
             PropertyDefinition("bin", integer_get, context=0, write=integer_set),
             PropertyDefinition("fast", integer_get, context=1, write=integer_set),
             PropertyDefinition("dispatch_table", dispatch_get, write=dispatch_set)
         ]
     ),
     unpickler_type = TypeDefinition(
         "_pickle.Unpickler",
         "",
         [
             MethodDefinition("load", MethodCallbacks(positional=load), "", flags=4),
             MethodDefinition(
                 "find_class", MethodCallbacks(positional=find_class), "", flags=1
             ),
             MethodDefinition(
                 "persistent_load",
                 MethodCallbacks(positional=persistent_load),
                 "",
                 flags=8
             ),
             MethodDefinition(
                 "__sizeof__", MethodCallbacks(positional=size_of), "", flags=4
             )
         ],
         flags | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=create,
             initialize=initialize_unpickler,
             dealloc=dealloc,
             traverse=traverse,
             clear=clear,
             get_attribute=get_attribute,
             set_attribute=set_attribute
         ),
         [PropertyDefinition("memo", get_memo, write=set_memo)]
     ),
     memo_methods = [
         MethodDefinition("copy", MethodCallbacks(positional=memo_copy), "", flags=4),
         MethodDefinition("clear", MethodCallbacks(positional=memo_clear), "", flags=4),
         MethodDefinition(
             "__reduce__", MethodCallbacks(positional=memo_reduce), "", flags=4
         )
     ],
     pickler_memo_type = TypeDefinition(
         "_pickle.PicklerMemoProxy",
         "",
         memo_methods,
         flags,
         TypeHooks(dealloc=dealloc, traverse=traverse, clear=clear)
     ),
     unpickler_memo_type = TypeDefinition(
         "_pickle.UnpicklerMemoProxy",
         "",
         memo_methods,
         flags,
         TypeHooks(dealloc=dealloc, traverse=traverse, clear=clear)
     );

def:priv retain_state(module: u64, index: int, value: u64) -> bool {
    if value == 0 {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    jacpy_release(value);
    return True;
}

def:priv execute(module: u64) -> i32 {
    if not add_state_owned(
        module,
        Slot.ERROR.value,
        "PickleError",
        jacpy_binding_exception("_pickle.PickleError", "", "")
    ) {
        return i32(-1);
    }
    error = jacpy_binding_state_get(module, i64(Slot.ERROR.value));
    if not add_state_owned(
        module,
        Slot.PICKLING_ERROR.value,
        "PicklingError",
        jacpy_binding_exception_with_base("_pickle.PicklingError", error, "")
    )
        or not add_state_owned(
            module,
            Slot.UNPICKLING_ERROR.value,
            "UnpicklingError",
            jacpy_binding_exception_with_base("_pickle.UnpicklingError", error, "")
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
            module, Slot.BYTESIO.value, jacpy_import_attr("_io", "BytesIO")
        )
        or not retain_state(
            module, Slot.DISPATCH.value, jacpy_import_attr("copyreg", "dispatch_table")
        )
        or not add_owned(
            module,
            "PickleBuffer",
            jacpy_builtin_type(i64(builtin_kind.PICKLE_BUFFER.value))
        ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_pickle",
         "Native Jac pickle serialization.",
         [
             MethodDefinition("dump", MethodCallbacks(keywords=module_dump), ""),
             MethodDefinition("dumps", MethodCallbacks(keywords=module_dumps), ""),
             MethodDefinition("load", MethodCallbacks(keywords=module_load), ""),
             MethodDefinition("loads", MethodCallbacks(keywords=module_loads), "")
         ],
         hooks=ModuleHooks(execute=execute),
         state_count=9
     );

def:pub PyInit__pickle -> u64 {
    return definition.initialize();
}
