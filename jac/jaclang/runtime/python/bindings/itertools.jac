"""Native iterator type declarations and ownership at the Python ABI boundary."""
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
    jacpy_binding_typeof,
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_type_matches,
    jacpy_binding_slot,
    jacpy_binding_basicsize,
    jacpy_binding_generic_alias
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
    index_value,
    jacpy_ssize
}
import from jaclang.runtime.python.capi {
    jacpy_retain,
    jacpy_release,
    jacpy_none,
    jacpy_is_none,
    jacpy_int,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_dict_size,
    jacpy_dict_get,
    text_object,
    jacpy_type_check,
    jacpy_number_check,
    jacpy_number_ssize,
    jacpy_truth,
    jacpy_error_pending,
    jacpy_clear_error,
    jacpy_is_list,
    jacpy_list_size,
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

    override def traverse_refs(visitor: u64, context: u64) -> i32 {
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

    override def traverse_refs(visitor: u64, context: u64) -> i32 {
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

    override def traverse_refs(visitor: u64, context: u64) -> i32 {
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

    override def traverse_refs(visitor: u64, context: u64) -> i32 {
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

    override def traverse_refs(visitor: u64, context: u64) -> i32 {
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

def:priv module_for(type: u64) -> u64 {
    return jacpy_binding_owner(type, definition.handle);
}

def:priv kind_for(type: u64) -> int {
    for index in range(len(types)) {
        if jacpy_binding_type_matches(type, types[index].handle) != 0 {
            return index;
        }
    }
    object_error("SystemError", "unknown native iterator type");
    return -1;
}

def:priv state_for(instance: u64) -> (NativeState | None) {
    kind = kind_for(jacpy_binding_typeof(instance));
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

def:priv wrap(type: u64, state: NativeState) -> u64 {
    kind = kind_for(type);
    if kind < 0 {
        return 0;
    }
    result = jacpy_binding_allocate(type);
    if result == 0 {
        return 0;
    }
    if jacpy_binding_native_set(result, types[kind].handle, state) < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:priv no_keywords(type: u64, kind: int, kwargs: u64) -> bool {
    if kwargs == 0 or jacpy_dict_size(kwargs) == 0 {
        return True;
    }
    module = module_for(type);
    if module == 0 {
        return False;
    }
    base = jacpy_binding_state_get(module, i64(kind));
    if type != base
        and jacpy_binding_slot(type, i64(TypeSlot.INIT.value))
            != jacpy_binding_slot(base, i64(TypeSlot.INIT.value)) {
        return True;
    }
    object_error("TypeError", f"{type_name(type)}() takes no keyword arguments");
    return False;
}

def:priv iterator_self(instance: u64) -> u64 {
    return jacpy_retain(instance);
}

def:priv iterator_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    kind = kind_for(jacpy_binding_typeof(instance));
    return traverse_payload(instance, types[kind].handle, visitor, context)
        if kind >= 0
        else i32(-1);
}

def:priv iterator_clear(instance: u64) -> i32 {
    kind = kind_for(jacpy_binding_typeof(instance));
    return clear_payload(instance, types[kind].handle) if kind >= 0 else i32(-1);
}

def:priv iterator_dealloc(instance: u64) {
    kind = kind_for(jacpy_binding_typeof(instance));
    if kind >= 0 {
        dispose_payload(instance, types[kind].handle);
    }
}

def:priv data_dealloc(instance: u64) {
    jacpy_binding_dealloc_guard(instance, data_dealloc, iterator_dealloc);
}

def:priv iterator_next(instance: u64) -> u64 {
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
            return 0;
        }
        parent = state_for(state.references[0]);
        if isinstance(parent, GroupState) {
            return jacpy_grouper_next(parent.native, instance, state.references[1]);
        }
    }
    return 0;
}

def:priv iterator_repr(instance: u64) -> u64 {
    state = state_for(instance);
    return jacpy_pipeline_repr(state.native, instance)
        if isinstance(state, PipelineState)
        else u64(0);
}

def:priv repeat_length(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    if not isinstance(state, PipelineState) {
        return 0;
    }
    length = jacpy_pipeline_length(state.native);
    if length < 0 {
        return fail("len() of unsized object");
    }
    return jacpy_int(length);
}

def:priv combination_size(instance: u64, unused: u64) -> u64 {
    state = state_for(instance);
    return jacpy_int(
        jacpy_binding_basicsize(jacpy_binding_typeof(instance))
            + jacpy_combinatorial_memory(state.native)
    )
        if isinstance(state, CombinationState)
        else u64(0);
}

def:priv pipeline_create(
    type: u64,
    kind: int,
    source: u64,
    second: u64 = 0,
    function: u64 = 0,
    initial: u64 = 0,
    first: i64 = 0,
    stop: i64 = -1,
    step: i64 = 1,
    flag: i64 = 0
) -> u64 {
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
        return 0;
    }
    return wrap(type, state);
}

def:priv chain_from(type: u64, source: u64) -> u64 {
    return pipeline_create(type, Kind.CHAIN.value, source);
}

def:priv fail(message: str, category: str = "TypeError") -> u64 {
    object_error(category, message);
    return 0;
}

def:priv bind(
    signature: CallSignature, args: u64, kwargs: u64
) -> (BoundArguments | None) {
    bound = BoundArguments([u64(0) for _ in signature.names]);
    if not signature.bind(bound, args, kwargs) {
        return None;
    }
    return bound;
}

def:priv keyword(kwargs: u64, name: str) -> u64 {
    if kwargs == 0 {
        return 0;
    }
    key = text_object(name);
    if key == 0 {
        return 0;
    }
    try {
        return jacpy_dict_get(kwargs, key);
    } finally {
        jacpy_release(key);
    }
}

def:priv iterator_new(type: u64, args: u64, kwargs: u64) -> u64 {
    try {
        return create_iterator(type, args, kwargs);
    } except boundary_failure {
        return 0;
    }
}

def:priv create_iterator(type: u64, args: u64, kwargs: u64) -> u64 {
    kind = kind_for(type);
    if kind < 0 {
        return 0;
    }
    if kind == Kind.GROUPBY.value {
        bound = bind(CallSignature("groupby", ["iterable", "key"], 1, 2), args, kwargs);
        if bound is None {
            return 0;
        }
        if bound.values[1] == 0 {
            bound.values[1] = jacpy_none();
        }
        state = GroupState(group_state(make_group=make_group));
        if jacpy_group_init(state.native, bound.values[0], bound.values[1]) < 0 {
            return 0;
        }
        return wrap(type, state);
    }
    if kind >= Kind.PRODUCT.value {
        held = ReferenceState(references=[u64(0), u64(0)]);
        width: i64 = 1;
        if kind == Kind.PRODUCT.value {
            held.references[0] = jacpy_retain(args);
            if kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
                held.references[1] = keyword(kwargs, "repeat");
                if held.references[1] == 0 or jacpy_dict_size(kwargs) != 1 {
                    return fail("product() takes at most 1 keyword argument");
                }
                width = jacpy_ssize(held.references[1]);
                if width == -1 and jacpy_error_pending() != 0 {
                    return 0;
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
                return 0;
            }
            held.references[0] = jacpy_retain(bound.values[0]);
            r = bound.values[1];
            if kind == Kind.PERMUTATIONS.value {
                width = -1;
                if r != 0 and jacpy_is_none(r) == 0 {
                    width = jacpy_ssize(r);
                    if width == -1 and jacpy_error_pending() != 0 {
                        return 0;
                    }
                    if width < 0 {
                        return fail("r must be non-negative", "ValueError");
                    }
                }
            } else {
                converted = index_value(r);
                if converted is None {
                    return 0;
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
            return 0;
        }
        return wrap(type, combination);
    }
    source: u64 = 0;
    second: u64 = 0;
    function: u64 = 0;
    initial: u64 = 0;
    first: i64 = 0;
    stop: i64 = -1;
    step: i64 = 1;
    flag: i64 = 0;
    bound: BoundArguments | None = None;
    held = ReferenceState(references=[u64(0), u64(0)]);
    if kind == Kind.ACCUMULATE.value {
        bound = bind(
            CallSignature("accumulate", ["iterable", "func", "initial"], 1, 2),
            args,
            kwargs
        );
        if bound is None {
            return 0;
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
            return 0;
        }
        converted = index_value(bound.values[1]);
        if converted is None {
            return 0;
        }
        step = converted;
        if step < 1 {
            return fail("n must be at least one", "ValueError");
        }
        source = bound.values[0];
        if bound.values[2] != 0 {
            flag = jacpy_truth(bound.values[2]);
            if flag < 0 {
                return 0;
            }
        }
    } elif kind == Kind.COUNT.value {
        bound = bind(CallSignature("count", ["start", "step"], 0, 2), args, kwargs);
        if bound is None {
            return 0;
        }
        if (bound.values[0] != 0 and jacpy_number_check(bound.values[0]) == 0)
            or (bound.values[1] != 0 and jacpy_number_check(bound.values[1]) == 0) {
            return fail("a number is required");
        }
        if bound.values[0] == 0 {
            bound.values[0] = required(jacpy_int(0));
        }
        if bound.values[1] == 0 {
            bound.values[1] = required(jacpy_int(1));
        }
        source = bound.values[0];
        second = bound.values[1];
    } elif kind == Kind.REPEAT.value {
        bound = bind(CallSignature("repeat", ["object", "times"], 1, 2), args, kwargs);
        if bound is None {
            return 0;
        }
        source = bound.values[0];
        if bound.values[1] != 0 {
            converted = index_value(bound.values[1]);
            if converted is None {
                return 0;
            }
            stop = max(i64(0), converted);
        }
    } elif kind == Kind.CHAIN.value {
        if not no_keywords(type, kind, kwargs) {
            return 0;
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
            return 0;
        }
        bound = bind(
            CallSignature("islice", ["iterable", "start", "stop", "step"], 2, 4, 4),
            args,
            0
        );
        if bound is None {
            return 0;
        }
        source = bound.values[0];
        a = bound.values[1];
        b = bound.values[2];
        c = bound.values[3];
        if b == 0 {
            b = a;
            a = 0;
        }
        if a != 0 and jacpy_is_none(a) == 0 {
            first = jacpy_number_ssize(a, "OverflowError");
        }
        if first == -1 and jacpy_error_pending() != 0 {
            jacpy_clear_error();
        }
        if jacpy_is_none(b) == 0 {
            stop = jacpy_number_ssize(b, "OverflowError");
            if stop == -1 {
                jacpy_clear_error();
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
            jacpy_clear_error();
            return fail(
                "Step for islice() must be a positive integer or None.", "ValueError"
            );
        }
    } elif kind == Kind.COMPRESS.value {
        bound = bind(
            CallSignature("compress", ["data", "selectors"], 2, 2), args, kwargs
        );
        if bound is None {
            return 0;
        }
        source = bound.values[0];
        second = bound.values[1];
    } elif kind == Kind.CYCLE.value or kind == Kind.PAIRWISE.value {
        if not no_keywords(type, kind, kwargs) {
            return 0;
        }
        bound = bind(CallSignature(names[kind], ["iterable"], 1, 1, 1), args, 0);
        if bound is None {
            return 0;
        }
        source = bound.values[0];
    } else {
        if not no_keywords(type, kind, kwargs) {
            return 0;
        }
        bound = bind(
            CallSignature(names[kind], ["function", "iterable"], 2, 2, 2), args, 0
        );
        if bound is None {
            return 0;
        }
        function = bound.values[0];
        source = bound.values[1];
    }
    return pipeline_create(
        type, kind, source, second, function, initial, first, stop, step, flag
    );
}

def:priv make_group(parent: u64, target: u64) -> u64 {
    module = module_for(jacpy_binding_typeof(parent));
    if module == 0 {
        return 0;
    }
    state = GrouperState(references=[jacpy_retain(parent), jacpy_retain(target)]);
    result = wrap(jacpy_binding_state_get(module, i64(Kind.GROUPER.value)), state);
    if result != 0 {
        source = state_for(parent);
        if isinstance(source, GroupState) {
            jacpy_group_activate(source.native, result);
        } else {
            jacpy_release(result);
            return 0;
        }
    }
    return result;
}

def:priv grouper_bound(args: BoundArguments) -> u64 {
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    if jacpy_type_check(
        args.values[0], jacpy_binding_state_get(module, i64(Kind.GROUPBY.value))
    )
        == 0 {
        return fail("_grouper() argument 1 must be itertools.groupby");
    }
    return make_group(args.values[0], args.values[1]);
}

def:priv grouper_new(type: u64, args: u64, kwargs: u64) -> u64 {
    if not no_keywords(type, Kind.GROUPER.value, kwargs) {
        return 0;
    }
    return invoke(
        CallSignature("_grouper", ["parent", "target"], 2, 2, 2),
        args,
        0,
        grouper_bound,
        type
    );
}

obj IteratorBindings(TeeBindings) {
    override def wrap_block(type_handle: u64, state: tee_block) -> u64 {
        return wrap(type_handle, BlockState(state));
    }

    override def wrap_cursor(type_handle: u64, state: tee_cursor) -> u64 {
        return wrap(type_handle, CursorState(state));
    }

    override def block_state(handle: u64) -> tee_block {
        state = state_for(handle);
        if isinstance(state, BlockState) {
            return state.native;
        }
        raise boundary_failure();
    }

    override def cursor_state(handle: u64) -> tee_cursor {
        state = state_for(handle);
        if isinstance(state, CursorState) {
            return state.native;
        }
        raise boundary_failure();
    }
}

glob:priv tee_bindings = IteratorBindings();
def:priv tee_bound(args: BoundArguments) -> u64 {
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    return jacpy_tee_construct(
        tee_bindings,
        args.context,
        jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)),
        args.values[0]
    );
}

def:priv tee_new(type: u64, args: u64, kwargs: u64) -> u64 {
    if not no_keywords(type, Kind.TEE.value, kwargs) {
        return 0;
    }
    return invoke(
        CallSignature("_tee", ["iterable"], 1, 1, 1), args, 0, tee_bound, type
    );
}

def:priv data_bound(args: BoundArguments) -> u64 {
    module = module_for(args.context);
    if module == 0 {
        return 0;
    }
    values = args.values[1];
    next = args.values[2];
    if jacpy_is_list(values) == 0 {
        return fail("_tee_dataobject() argument 2 must be list");
    }
    if jacpy_is_none(next) == 0 {
        if jacpy_list_size(values) != 57
            or jacpy_binding_typeof(next)
                != jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)) {
            return fail("Invalid arguments", "ValueError");
        }
    } else {
        next = 0;
    }
    state = BlockState(tee_block());
    if jacpy_tee_block_init(state.native, args.values[0], values, next) < 0 {
        return 0;
    }
    return wrap(args.context, state);
}

def:priv data_new(type: u64, args: u64, kwargs: u64) -> u64 {
    if not no_keywords(type, Kind.TEE_DATA.value, kwargs) {
        return 0;
    }
    return invoke(
        CallSignature("_tee_dataobject", ["iterable", "values", "next"], 3, 3, 3),
        args,
        0,
        data_bound,
        type
    );
}

def:priv tee_copy(instance: u64, unused: u64) -> u64 {
    type = jacpy_binding_typeof(instance);
    module = module_for(type);
    if module == 0 {
        return 0;
    }
    try {
        return jacpy_tee_construct(
            tee_bindings,
            type,
            jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)),
            instance
        );
    } except boundary_failure {
        return 0;
    }
}

def:priv tee_call_bound(args: BoundArguments) -> u64 {
    count: i64 = 2;
    if args.values[1] != 0 {
        converted = index_value(args.values[1]);
        if converted is None {
            return 0;
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

def:priv tee_call(module: u64, args: u64) -> u64 {
    return invoke(
        CallSignature("tee", ["iterable", "n"], 1, 2, 2),
        args,
        0,
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
                    MethodCallbacks(positional=jacpy_binding_generic_alias),
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
def:priv execute(module: u64) -> i32 {
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

def:pub PyInit_itertools -> u64 {
    return definition.initialize();
}
