"""Native iterator type declarations and ownership at the Python ABI boundary."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Clear,
    PyLong_AsSsize_t,
    PyLong_FromLongLong,
    PyNumber_Check,
    PyObject,
    PyObject_IsTrue,
    PyTuple_Size,
    PyType_GetSlot,
    Py_GenericAlias,
    Py_NewRef,
    Py_TYPE,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_is_list,
    jacpy_is_none,
    jacpy_list_size,
    jacpy_none,
    jacpy_number_ssize,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_type_check
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition,
    add_state_owned,
    jacpy_binding_state_get,
    jacpy_binding_visit
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    TypeSlot,
    jacpy_binding_owner,
    jacpy_binding_allocate,
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
    dispose_payload,
    jacpy_binding_dealloc_guard
}
import from jaclang.runtime.python.bindings.references { ReferenceState }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke,
    index_value
}
import from jaclang.runtime.python.capi {
    text_object,
    object_error,
    type_name,
    boundary_failure,
    required
}
import from jaclang.runtime.python.modules.iterators {
    pipeline_state,
    jacpy_pipeline_new,
    jacpy_pipeline_init,
    jacpy_pipeline_field,
    jacpy_pipeline_clear,
    jacpy_pipeline_next,
    jacpy_pipeline_repr,
    jacpy_pipeline_length
}
import from jaclang.runtime.python.modules.combinatorics {
    combinatorial_state,
    jacpy_combinatorial_new,
    jacpy_combinatorial_init,
    jacpy_combinatorial_field,
    jacpy_combinatorial_clear,
    jacpy_combinatorial_next,
    jacpy_combinatorial_memory
}
import from jaclang.runtime.python.modules.grouping {
    group_state,
    jacpy_group_init,
    jacpy_group_field,
    jacpy_group_clear,
    jacpy_group_next,
    jacpy_group_activate,
    jacpy_grouper_next
}
import from jaclang.runtime.python.modules.tee {
    TeeBindings,
    tee_block,
    tee_cursor,
    jacpy_tee_block_init,
    jacpy_tee_block_count,
    jacpy_tee_block_field,
    jacpy_tee_block_clear,
    jacpy_tee_cursor_field,
    jacpy_tee_cursor_clear,
    jacpy_tee_construct,
    jacpy_tee_split,
    jacpy_tee_next
}

enum Kind {
    ACCUMULATE = 0,
    BATCHED = 1,
    CHAIN = 2,
    COMPRESS = 3,
    COUNT = 4,
    CYCLE = 5,
    DROPWHILE = 6,
    FILTERFALSE = 7,
    ISLICE = 8,
    PAIRWISE = 9,
    REPEAT = 10,
    STARMAP = 11,
    TAKEWHILE = 12,
    ZIP_LONGEST = 13,
    PRODUCT = 14,
    COMBINATIONS = 15,
    CWR = 16,
    PERMUTATIONS = 17,
    GROUPBY = 18,
    GROUPER = 19,
    TEE = 20,
    TEE_DATA = 21
}

obj PipelineState(NativeState) {
    has native: pipeline_state;

    override def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for index in range(7) {
            status = jacpy_binding_visit(
                jacpy_pipeline_field(self.native, i64(index)), visitor, context
            );
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    override def clear {
        jacpy_pipeline_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj CombinationState(NativeState) {
    has native: combinatorial_state;

    override def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for index in range(2) {
            status = jacpy_binding_visit(
                jacpy_combinatorial_field(self.native, i64(index)), visitor, context
            );
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    override def clear {
        jacpy_combinatorial_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj GroupState(NativeState) {
    has native: group_state;

    override def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for index in range(5) {
            status = jacpy_binding_visit(
                jacpy_group_field(self.native, i64(index)), visitor, context
            );
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    override def clear {
        jacpy_group_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj BlockState(NativeState) {
    has native: tee_block;

    override def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for index in range(int(jacpy_tee_block_count(self.native))) {
            status = jacpy_binding_visit(
                jacpy_tee_block_field(self.native, i64(index)), visitor, context
            );
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    override def clear {
        jacpy_tee_block_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj CursorState(NativeState) {
    has native: tee_cursor;

    override def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        return jacpy_binding_visit(
            jacpy_tee_cursor_field(self.native), visitor, context
        );
    }

    override def clear {
        jacpy_tee_cursor_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj GrouperState(ReferenceState) {}

def:priv module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv kind_for(type: ptr[PyObject]) -> int {
    for index in range(len(types)) {
        if jacpy_binding_type_matches(type, types[index].handle) != 0 {
            return index;
        }
    }
    object_error("SystemError", "unknown native iterator type");
    return -1;
}

def:priv state_for(instance: ptr[PyObject]) -> (NativeState | None) {
    kind = kind_for(Py_TYPE(instance));
    if kind < 0 {
        return None;
    }
    handle = types[kind].handle;
    if jacpy_binding_native_present(instance, handle) == 0 {
        object_error("RuntimeError", "uninitialized native iterator");
        return None;
    }
    return jacpy_binding_native_get(instance, handle);
}

def:priv wrap(type: ptr[PyObject], state: NativeState) -> ptr[PyObject] {
    kind = kind_for(type);
    if kind < 0 {
        return NULL;
    }
    result = jacpy_binding_allocate(type);
    if result == 0 {
        return NULL;
    }
    if jacpy_binding_native_set(result, types[kind].handle, state) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:priv no_keywords(type: ptr[PyObject], kind: int, kwargs: ptr[PyObject]) -> bool {
    if kwargs == 0 or jacpy_dict_size(kwargs) == 0 {
        return True;
    }
    module = module_for(type);
    if module == 0 {
        return False;
    }
    base = jacpy_binding_state_get(module, i64(kind));
    if type != base
        and PyType_GetSlot(type, i32(TypeSlot.INIT.value))
            != PyType_GetSlot(base, i32(TypeSlot.INIT.value)) {
        return True;
    }
    object_error("TypeError", f"{type_name(type)}() takes no keyword arguments");
    return False;
}

def:priv iterator_self(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def:priv iterator_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    kind = kind_for(Py_TYPE(instance));
    return traverse_payload(instance, types[kind].handle, visitor, context)
        if kind >= 0
        else i32(-1);
}

def:priv iterator_clear(instance: ptr[PyObject]) -> i32 {
    kind = kind_for(Py_TYPE(instance));
    return clear_payload(instance, types[kind].handle) if kind >= 0 else i32(-1);
}

def:priv iterator_dealloc(instance: ptr[PyObject]) {
    kind = kind_for(Py_TYPE(instance));
    if kind >= 0 {
        dispose_payload(instance, types[kind].handle);
    }
}

def:priv data_dealloc(instance: ptr[PyObject]) {
    jacpy_binding_dealloc_guard(instance, data_dealloc, iterator_dealloc);
}

def:priv iterator_next(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    if isinstance(state, PipelineState) {
        return jacpy_pipeline_next(state.native);
    }
    if isinstance(state, CombinationState) {
        return jacpy_combinatorial_next(state.native);
    }
    if isinstance(state, GroupState) {
        return jacpy_group_next(state.native, instance);
    }
    if isinstance(state, CursorState) {
        return jacpy_tee_next(state.native);
    }
    if isinstance(state, GrouperState) {
        if state.references[0] == 0 {
            return NULL;
        }
        parent = state_for(state.references[0]);
        if isinstance(parent, GroupState) {
            return jacpy_grouper_next(parent.native, instance, state.references[1]);
        }
    }
    return NULL;
}

def:priv iterator_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    return jacpy_pipeline_repr(state.native, instance)
        if isinstance(state, PipelineState)
        else NULL;
}

def:priv repeat_length(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_for(instance);
    if not isinstance(state, PipelineState) {
        return NULL;
    }
    length = jacpy_pipeline_length(state.native);
    if length < 0 {
        return fail("len() of unsized object");
    }
    return PyLong_FromLongLong(length);
}

def:priv combination_size(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_for(instance);
    return PyLong_FromLongLong(
        jacpy_binding_basicsize(Py_TYPE(instance))
            + jacpy_combinatorial_memory(state.native)
    )
        if isinstance(state, CombinationState)
        else NULL;
}

def:priv pipeline_create(
    type: ptr[PyObject],
    kind: int,
    source: ptr[PyObject],
    second: ptr[PyObject] = 0,
    function: ptr[PyObject] = 0,
    initial: ptr[PyObject] = 0,
    first: i64 = 0,
    stop: i64 = -1,
    step: i64 = 1,
    flag: i64 = 0
) -> ptr[PyObject] {
    state = PipelineState(jacpy_pipeline_new());
    if jacpy_pipeline_init(
        state.native,
        i64(kind),
        source,
        second,
        function,
        initial,
        first,
        stop,
        step,
        flag
    )
        < 0 {
        return NULL;
    }
    return wrap(type, state);
}

def:priv chain_from(type: ptr[PyObject], source: ptr[PyObject]) -> ptr[PyObject] {
    return pipeline_create(type, Kind.CHAIN.value, source);
}

def:priv fail(message: str, category: str = "TypeError") -> ptr[PyObject] {
    object_error(category, message);
    return NULL;
}

def:priv bind(
    signature: CallSignature, args: ptr[PyObject], kwargs: ptr[PyObject]
) -> (BoundArguments | None) {
    bound = BoundArguments([NULL for _ in signature.names]);
    if not signature.bind(bound, args, kwargs) {
        return None;
    }
    return bound;
}

def:priv keyword(kwargs: ptr[PyObject], name: str) -> ptr[PyObject] {
    if kwargs == 0 {
        return NULL;
    }
    key = text_object(name);
    if key == 0 {
        return NULL;
    }
    try {
        return jacpy_dict_get(kwargs, key);
    } finally {
        jacpy_release(key);
    }
}

def:priv iterator_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return create_iterator(type, args, kwargs);
    } except boundary_failure {
        return NULL;
    }
}

def:priv create_iterator(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    kind = kind_for(type);
    if kind < 0 {
        return NULL;
    }
    if kind == Kind.GROUPBY.value {
        bound = bind(CallSignature("groupby", ["iterable", "key"], 1, 2), args, kwargs);
        if bound is None {
            return NULL;
        }
        if bound.values[1] == 0 {
            bound.values[1] = jacpy_none();
        }
        state = GroupState(group_state(make_group=make_group));
        if jacpy_group_init(state.native, bound.values[0], bound.values[1]) < 0 {
            return NULL;
        }
        return wrap(type, state);
    }
    if kind >= Kind.PRODUCT.value {
        held = ReferenceState(references=[NULL, NULL]);
        width: i64 = 1;
        if kind == Kind.PRODUCT.value {
            held.references[0] = Py_NewRef(args);
            if kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
                held.references[1] = keyword(kwargs, "repeat");
                if held.references[1] == 0 or jacpy_dict_size(kwargs) != 1 {
                    return fail("product() takes at most 1 keyword argument");
                }
                width = PyLong_AsSsize_t(held.references[1]);
                if width == -1 and jacpy_error_pending() != 0 {
                    return NULL;
                }
            }
            if width < 0 {
                return fail("repeat argument cannot be negative", "ValueError");
            }
        } else {
            bound = bind(
                CallSignature(
                    names[kind],
                    ["iterable", "r"],
                    1 if kind == Kind.PERMUTATIONS.value else 2,
                    2
                ),
                args,
                kwargs
            );
            if bound is None {
                return NULL;
            }
            held.references[0] = Py_NewRef(bound.values[0]);
            r = bound.values[1];
            if kind == Kind.PERMUTATIONS.value {
                width = -1;
                if r != 0 and jacpy_is_none(r) == 0 {
                    width = PyLong_AsSsize_t(r);
                    if width == -1 and jacpy_error_pending() != 0 {
                        return NULL;
                    }
                    if width < 0 {
                        return fail("r must be non-negative", "ValueError");
                    }
                }
            } else {
                converted = index_value(r);
                if converted is None {
                    return NULL;
                }
                width = converted;
                if width < 0 {
                    return fail("r must be non-negative", "ValueError");
                }
            }
        }
        combination = CombinationState(jacpy_combinatorial_new());
        if jacpy_combinatorial_init(
            combination.native, i64(kind), held.references[0], width
        )
            < 0 {
            return NULL;
        }
        return wrap(type, combination);
    }
    source: ptr[PyObject] = NULL;
    second: ptr[PyObject] = NULL;
    function: ptr[PyObject] = NULL;
    initial: ptr[PyObject] = NULL;
    first: i64 = 0;
    stop: i64 = -1;
    step: i64 = 1;
    flag: i64 = 0;
    bound: BoundArguments | None = None;
    held = ReferenceState(references=[NULL, NULL]);
    if kind == Kind.ACCUMULATE.value {
        bound = bind(
            CallSignature("accumulate", ["iterable", "func", "initial"], 1, 2),
            args,
            kwargs
        );
        if bound is None {
            return NULL;
        }
        if bound.values[1] == 0 {
            bound.values[1] = jacpy_none();
        }
        if bound.values[2] == 0 {
            bound.values[2] = jacpy_none();
        }
        source = bound.values[0];
        function = bound.values[1];
        initial = bound.values[2];
    } elif kind == Kind.BATCHED.value {
        bound = bind(
            CallSignature("batched", ["iterable", "n", "strict"], 2, 2), args, kwargs
        );
        if bound is None {
            return NULL;
        }
        converted = index_value(bound.values[1]);
        if converted is None {
            return NULL;
        }
        step = converted;
        if step < 1 {
            return fail("n must be at least one", "ValueError");
        }
        source = bound.values[0];
        if bound.values[2] != 0 {
            flag = PyObject_IsTrue(bound.values[2]);
            if flag < 0 {
                return NULL;
            }
        }
    } elif kind == Kind.COUNT.value {
        bound = bind(CallSignature("count", ["start", "step"], 0, 2), args, kwargs);
        if bound is None {
            return NULL;
        }
        if (bound.values[0] != 0 and PyNumber_Check(bound.values[0]) == 0)
            or (bound.values[1] != 0 and PyNumber_Check(bound.values[1]) == 0) {
            return fail("a number is required");
        }
        if bound.values[0] == 0 {
            bound.values[0] = required(PyLong_FromLongLong(0));
        }
        if bound.values[1] == 0 {
            bound.values[1] = required(PyLong_FromLongLong(1));
        }
        source = bound.values[0];
        second = bound.values[1];
    } elif kind == Kind.REPEAT.value {
        bound = bind(CallSignature("repeat", ["object", "times"], 1, 2), args, kwargs);
        if bound is None {
            return NULL;
        }
        source = bound.values[0];
        if bound.values[1] != 0 {
            converted = index_value(bound.values[1]);
            if converted is None {
                return NULL;
            }
            stop = max(i64(0), converted);
        }
    } elif kind == Kind.CHAIN.value {
        if not no_keywords(type, kind, kwargs) {
            return NULL;
        }
        source = args;
    } elif kind == Kind.ZIP_LONGEST.value {
        source = args;
        held.references[0] = jacpy_none();
        function = held.references[0];
        if kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
            held.references[1] = keyword(kwargs, "fillvalue");
            if held.references[1] == 0 or jacpy_dict_size(kwargs) != 1 {
                return fail("zip_longest() got an unexpected keyword argument");
            }
            function = held.references[1];
        }
    } elif kind == Kind.ISLICE.value {
        if not no_keywords(type, kind, kwargs) {
            return NULL;
        }
        bound = bind(
            CallSignature("islice", ["iterable", "start", "stop", "step"], 2, 4, 4),
            args,
            NULL
        );
        if bound is None {
            return NULL;
        }
        source = bound.values[0];
        a = bound.values[1];
        b = bound.values[2];
        c = bound.values[3];
        if b == 0 {
            b = a;
            a = NULL;
        }
        if a != 0 and jacpy_is_none(a) == 0 {
            first = jacpy_number_ssize(a, "OverflowError");
        }
        if first == -1 and jacpy_error_pending() != 0 {
            PyErr_Clear();
        }
        if jacpy_is_none(b) == 0 {
            stop = jacpy_number_ssize(b, "OverflowError");
            if stop == -1 {
                PyErr_Clear();
                return fail(
                    "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize.",
                    "ValueError"
                );
            }
        }
        if first < 0 or stop < -1 {
            return fail(
                "Indices for islice() must be None or an integer: 0 <= x <= sys.maxsize.",
                "ValueError"
            );
        }
        if c != 0 and jacpy_is_none(c) == 0 {
            step = jacpy_number_ssize(c, "OverflowError");
        }
        if step < 1 {
            PyErr_Clear();
            return fail(
                "Step for islice() must be a positive integer or None.", "ValueError"
            );
        }
    } elif kind == Kind.COMPRESS.value {
        bound = bind(
            CallSignature("compress", ["data", "selectors"], 2, 2), args, kwargs
        );
        if bound is None {
            return NULL;
        }
        source = bound.values[0];
        second = bound.values[1];
    } elif kind == Kind.CYCLE.value or kind == Kind.PAIRWISE.value {
        if not no_keywords(type, kind, kwargs) {
            return NULL;
        }
        bound = bind(CallSignature(names[kind], ["iterable"], 1, 1, 1), args, NULL);
        if bound is None {
            return NULL;
        }
        source = bound.values[0];
    } else {
        if not no_keywords(type, kind, kwargs) {
            return NULL;
        }
        bound = bind(
            CallSignature(names[kind], ["function", "iterable"], 2, 2, 2), args, NULL
        );
        if bound is None {
            return NULL;
        }
        function = bound.values[0];
        source = bound.values[1];
    }
    return pipeline_create(
        type, kind, source, second, function, initial, first, stop, step, flag
    );
}

def:priv make_group(parent: ptr[PyObject], target: ptr[PyObject]) -> ptr[PyObject] {
    module = module_for(Py_TYPE(parent));
    if module == 0 {
        return NULL;
    }
    state = GrouperState(references=[Py_NewRef(parent), Py_NewRef(target)]);
    result = wrap(jacpy_binding_state_get(module, i64(Kind.GROUPER.value)), state);
    if result != 0 {
        source = state_for(parent);
        if isinstance(source, GroupState) {
            jacpy_group_activate(source.native, result);
        } else {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

def:priv grouper_bound(args: BoundArguments) -> ptr[PyObject] {
    module = module_for(args.context);
    if module == 0 {
        return NULL;
    }
    if jacpy_type_check(
        args.values[0], jacpy_binding_state_get(module, i64(Kind.GROUPBY.value))
    )
        == 0 {
        return fail("_grouper() argument 1 must be itertools.groupby");
    }
    return make_group(args.values[0], args.values[1]);
}

def:priv grouper_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not no_keywords(type, Kind.GROUPER.value, kwargs) {
        return NULL;
    }
    return invoke(
        CallSignature("_grouper", ["parent", "target"], 2, 2, 2),
        args,
        NULL,
        grouper_bound,
        type
    );
}

obj IteratorBindings(TeeBindings) {
    override def wrap_block(
        type_handle: ptr[PyObject], state: tee_block
    ) -> ptr[PyObject] {
        return wrap(type_handle, BlockState(state));
    }

    override def wrap_cursor(
        type_handle: ptr[PyObject], state: tee_cursor
    ) -> ptr[PyObject] {
        return wrap(type_handle, CursorState(state));
    }

    override def block_state(handle: ptr[PyObject]) -> tee_block {
        state = state_for(handle);
        if isinstance(state, BlockState) {
            return state.native;
        }
        raise boundary_failure();
    }

    override def cursor_state(handle: ptr[PyObject]) -> tee_cursor {
        state = state_for(handle);
        if isinstance(state, CursorState) {
            return state.native;
        }
        raise boundary_failure();
    }
}

glob:priv tee_bindings = IteratorBindings();
def:priv tee_bound(args: BoundArguments) -> ptr[PyObject] {
    module = module_for(args.context);
    if module == 0 {
        return NULL;
    }
    return jacpy_tee_construct(
        tee_bindings,
        args.context,
        jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)),
        args.values[0]
    );
}

def:priv tee_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not no_keywords(type, Kind.TEE.value, kwargs) {
        return NULL;
    }
    return invoke(
        CallSignature("_tee", ["iterable"], 1, 1, 1), args, NULL, tee_bound, type
    );
}

def:priv data_bound(args: BoundArguments) -> ptr[PyObject] {
    module = module_for(args.context);
    if module == 0 {
        return NULL;
    }
    values = args.values[1];
    next = args.values[2];
    if jacpy_is_list(values) == 0 {
        return fail("_tee_dataobject() argument 2 must be list");
    }
    if jacpy_is_none(next) == 0 {
        if jacpy_list_size(values) != 57
            or Py_TYPE(next)
                != jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)) {
            return fail("Invalid arguments", "ValueError");
        }
    } else {
        next = NULL;
    }
    state = BlockState(tee_block());
    if jacpy_tee_block_init(state.native, args.values[0], values, next) < 0 {
        return NULL;
    }
    return wrap(args.context, state);
}

def:priv data_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not no_keywords(type, Kind.TEE_DATA.value, kwargs) {
        return NULL;
    }
    return invoke(
        CallSignature("_tee_dataobject", ["iterable", "values", "next"], 3, 3, 3),
        args,
        NULL,
        data_bound,
        type
    );
}

def:priv tee_copy(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    type = Py_TYPE(instance);
    module = module_for(type);
    if module == 0 {
        return NULL;
    }
    try {
        return jacpy_tee_construct(
            tee_bindings,
            type,
            jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)),
            instance
        );
    } except boundary_failure {
        return NULL;
    }
}

def:priv tee_call_bound(args: BoundArguments) -> ptr[PyObject] {
    count: i64 = 2;
    if args.values[1] != 0 {
        converted = index_value(args.values[1]);
        if converted is None {
            return NULL;
        }
        count = converted;
    }
    if count < 0 {
        return fail("n must be >= 0", "ValueError");
    }
    return jacpy_tee_split(
        tee_bindings,
        jacpy_binding_state_get(args.context, i64(Kind.TEE.value)),
        jacpy_binding_state_get(args.context, i64(Kind.TEE_DATA.value)),
        args.values[0],
        count
    );
}

def:priv tee_call(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return invoke(
        CallSignature("tee", ["iterable", "n"], 1, 2, 2),
        args,
        NULL,
        tee_call_bound,
        module
    );
}

glob:priv names = [
         "accumulate",
         "batched",
         "chain",
         "compress",
         "count",
         "cycle",
         "dropwhile",
         "filterfalse",
         "islice",
         "pairwise",
         "repeat",
         "starmap",
         "takewhile",
         "zip_longest",
         "product",
         "combinations",
         "combinations_with_replacement",
         "permutations",
         "groupby",
         "_grouper",
         "_tee",
         "_tee_dataobject"
     ],
     docs = [
         "accumulate(iterable, func=None, *, initial=None)\n--\n\nReturn series of accumulated sums.",
         "batched(iterable, n, *, strict=False)\n--\n\nBatch data into tuples of length n.",
         "chain(*iterables)\n--\n\nReturn elements from successive iterables.",
         "compress(data, selectors)\n--\n\nReturn data whose corresponding selector is true.",
         "count(start=0, step=1)\n--\n\nReturn evenly spaced values starting with start.",
         "cycle(iterable, /)\n--\n\nReturn elements from the iterable, repeating indefinitely.",
         "dropwhile(predicate, iterable, /)\n--\n\nDrop elements while the predicate is true.",
         "filterfalse(function, iterable, /)\n--\n\nReturn items for which the predicate is false.",
         "islice(iterable, stop)\n--\n\nReturn selected elements from an iterable.",
         "pairwise(iterable, /)\n--\n\nReturn overlapping pairs from the input iterator.",
         "repeat(object, times=None)\n--\n\nReturn object repeatedly.",
         "starmap(function, iterable, /)\n--\n\nCall a function with arguments from each iterable element.",
         "takewhile(predicate, iterable, /)\n--\n\nReturn elements while the predicate is true.",
         "zip_longest(*iterables, fillvalue=None)\n--\n\nZip iterables, filling missing values.",
         "product(*iterables, repeat=1)\n--\n\nCartesian product of input iterables.",
         "combinations(iterable, r)\n--\n\nReturn length r subsequences of elements.",
         "combinations_with_replacement(iterable, r)\n--\n\nReturn length r subsequences, allowing repeated elements.",
         "permutations(iterable, r=None)\n--\n\nReturn successive length r permutations.",
         "groupby(iterable, key=None)\n--\n\nReturn consecutive keys and groups from the iterable.",
         "",
         "",
         ""
     ];

def:priv make_types -> list[TypeDefinition] {
    result: list[TypeDefinition] = [];
    for kind in range(len(names)) {
        methods: list[MethodDefinition] = [];
        flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value);
        hooks = TypeHooks(
            create=iterator_new,
            dealloc=iterator_dealloc,
            traverse=iterator_traverse,
            clear=iterator_clear,
            iter=iterator_self,
            next=iterator_next
        );
        if kind <= Kind.GROUPBY.value {
            flags = flags | u64(TypeFlags.BASETYPE.value);
        }
        if kind == Kind.COUNT.value or kind == Kind.REPEAT.value {
            hooks.repr = iterator_repr;
        }
        if kind >= Kind.PRODUCT.value and kind <= Kind.PERMUTATIONS.value {
            methods.append(
                MethodDefinition(
                    "__sizeof__",
                    MethodCallbacks(positional=combination_size),
                    "Returns size in memory, in bytes.",
                    flags=4
                )
            );
        }
        if kind == Kind.REPEAT.value {
            methods.append(
                MethodDefinition(
                    "__length_hint__",
                    MethodCallbacks(positional=repeat_length),
                    "Private method returning an estimate of len(list(it)).",
                    flags=4
                )
            );
        }
        if kind == Kind.CHAIN.value {
            methods.append(
                MethodDefinition(
                    "from_iterable",
                    MethodCallbacks(positional=chain_from),
                    "from_iterable($type, iterable, /)\n--\n\nAlternative chain constructor taking a single iterable argument.",
                    flags=24
                )
            );
            methods.append(
                MethodDefinition(
                    "__class_getitem__",
                    MethodCallbacks(positional=Py_GenericAlias),
                    "See PEP 585",
                    flags=24
                )
            );
        }
        if kind == Kind.GROUPER.value {
            hooks.create = grouper_new;
        }
        if kind == Kind.TEE.value {
            flags = flags | u64(TypeFlags.MANAGED_WEAKREF.value);
            hooks.create = tee_new;
            methods.append(
                MethodDefinition(
                    "__copy__",
                    MethodCallbacks(positional=tee_copy),
                    "Returns an independent iterator.",
                    flags=4
                )
            );
        }
        if kind == Kind.TEE_DATA.value {
            hooks = TypeHooks(
                create=data_new,
                dealloc=data_dealloc,
                traverse=iterator_traverse,
                clear=iterator_clear
            );
        }
        result.append(
            TypeDefinition(
                "itertools." + names[kind], docs[kind], methods, flags, hooks
            )
        );
    }
    return result;
}

glob:priv types = make_types();
def:priv execute(module: ptr[PyObject]) -> i32 {
    for index in range(len(types)) {
        if not add_state_owned(
            module, index, names[index], types[index].create(module)
        ) {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "itertools",
         "Native Jac iterator policies.",
         [
             MethodDefinition(
                 "tee",
                 MethodCallbacks(positional=tee_call),
                 "tee($module, iterable, n=2, /)\n--\n\nReturn n independent iterators.",
                 flags=1
             )
         ],
         hooks=ModuleHooks(execute=execute),
         state_count=22
     );

def:pub PyInit_itertools -> ptr[PyObject] {
    return definition.initialize();
}
