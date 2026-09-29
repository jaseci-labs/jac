"""Iterator construction and ownership for the itertools module.

The states, the constructors itertoolsmodule.c writes by hand, and the
Argument Clinic _impl functions; the algorithms run in iterators,
combinatorics, grouping and tee. Derived from CPython 3.14.6; see
../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Clear,
    PyExc_OverflowError,
    PyExc_RuntimeError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyLong_AsSsize_t,
    PyLong_FromLongLong,
    PyNumber_AsSsize_t,
    PyNumber_Check,
    PyObject,
    PyType_GetSlot,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_list_size,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    TypeSlot,
    jacpy_binding_owner,
    jacpy_binding_allocate,
    jacpy_binding_type_matches,
    jacpy_binding_basicsize,
    jacpy_binding_matches
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
    PARSE_FORMAT_KEYWORDS,
    index_value,
    keywords_of_dict
}
import from jaclang.runtime.python.bindings.converters { ClassToken, bad_argument }
import from jaclang.runtime.python.capi {
    text_object,
    object_error,
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
            status = visit_reference(
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
            status = visit_reference(
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
            status = visit_reference(
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
            status = visit_reference(
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
        return visit_reference(jacpy_tee_cursor_field(self.native), visitor, context);
    }

    override def clear {
        jacpy_tee_cursor_clear(self.native);
    }

    def drop {
        self.clear();
    }
}

obj GrouperState(ReferenceState) {}

def module_for(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, itertools_module_token.handle);
}

def kind_for(type: ptr[PyObject]) -> int {
    for index in range(len(kind_tokens)) {
        if jacpy_binding_type_matches(type, kind_tokens[index].handle) != 0 {
            return index;
        }
    }
    object_error(PyExc_SystemError, "unknown native iterator type");
    return -1;
}

def state_for(instance: ptr[PyObject]) -> (NativeState | None) {
    kind = kind_for(Py_TYPE(instance));
    if kind < 0 {
        return None;
    }
    handle = kind_tokens[kind].handle;
    if jacpy_binding_native_present(instance, handle) == 0 {
        object_error(PyExc_RuntimeError, "uninitialized native iterator");
        return None;
    }
    return jacpy_binding_native_get(instance, handle);
}

def wrap(type: ptr[PyObject], state: NativeState) -> ptr[PyObject] {
    kind = kind_for(type);
    if kind < 0 {
        return NULL;
    }
    result = jacpy_binding_allocate(type);
    if result == 0 {
        return NULL;
    }
    if jacpy_binding_native_set(result, kind_tokens[kind].handle, state) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def no_keywords(type: ptr[PyObject], kind: int, kwargs: ptr[PyObject]) -> bool {
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
    object_error(PyExc_TypeError, f"{clinic_name(kind)}() takes no keyword arguments");
    return False;
}

def iterator_self(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

def iterator_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    kind = kind_for(Py_TYPE(instance));
    return traverse_payload(instance, kind_tokens[kind].handle, visitor, context)
        if kind >= 0
        else i32(-1);
}

def iterator_clear(instance: ptr[PyObject]) -> i32 {
    kind = kind_for(Py_TYPE(instance));
    return clear_payload(instance, kind_tokens[kind].handle) if kind >= 0 else i32(-1);
}

def iterator_dealloc(instance: ptr[PyObject]) {
    kind = kind_for(Py_TYPE(instance));
    if kind >= 0 {
        dispose_payload(instance, kind_tokens[kind].handle);
    }
}

def data_dealloc(instance: ptr[PyObject]) {
    jacpy_binding_dealloc_guard(instance, data_dealloc, iterator_dealloc);
}

def iterator_next(instance: ptr[PyObject]) -> ptr[PyObject] {
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

def iterator_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    return jacpy_pipeline_repr(state.native, instance)
        if isinstance(state, PipelineState)
        else NULL;
}

def repeat_length(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
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

def combination_size(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    state = state_for(instance);
    return PyLong_FromLongLong(
        jacpy_binding_basicsize(Py_TYPE(instance))
            + jacpy_combinatorial_memory(state.native)
    )
        if isinstance(state, CombinationState)
        else NULL;
}

def pipeline_create(
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

def chain_from(type: ptr[PyObject], source: ptr[PyObject]) -> ptr[PyObject] {
    return pipeline_create(type, Kind.CHAIN.value, source);
}

def fail(message: str, category: ptr[PyObject] = PyExc_TypeError) -> ptr[PyObject] {
    object_error(category, message);
    return NULL;
}

# The name itertoolsmodule.c's argument errors use for a type: its clinic
# name, which is teedataobject for _tee_dataobject.
def clinic_name(kind: int) -> str {
    return "teedataobject" if kind == Kind.TEE_DATA.value else names[kind];
}

glob PRODUCT_KEYWORDS = CallSignature(
         "product", ["repeat"], 0, 1, 0, parser=PARSE_FORMAT_KEYWORDS
     );

def bind(
    signature: CallSignature, args: ptr[PyObject], kwargs: ptr[PyObject]
) -> (BoundArguments | None) {
    bound = BoundArguments([NULL for _ in signature.names]);
    if not signature.bind(bound, args, kwargs) {
        return None;
    }
    return bound;
}

def keyword(kwargs: ptr[PyObject], name: str) -> ptr[PyObject] {
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

def iterator_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return create_iterator(type, args, kwargs);
    } except boundary_failure {
        return NULL;
    }
}

# The constructors itertoolsmodule.c writes by hand: product, repeat,
# chain, zip_longest and islice.
def create_iterator(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    kind = kind_for(type);
    if kind < 0 {
        return NULL;
    }
    if kind == Kind.PRODUCT.value {
        width: i64 = 1;
        if kwargs != 0 and jacpy_dict_size(kwargs) != 0 {
            # PyArg_ParseTupleAndKeywords((), kwds, "|n:product", {"repeat"}).
            repeat = BoundArguments([NULL]);
            try {
                if not PRODUCT_KEYWORDS.bind_values(
                    repeat, [], keywords_of_dict(kwargs)
                ) {
                    return NULL;
                }
                repeat.reach(0);
                if repeat.values[0] != 0 {
                    converted = index_value(repeat.values[0]);
                    if converted is None {
                        return NULL;
                    }
                    width = converted;
                }
                repeat.reach(1);
            } except boundary_failure {
                return NULL;
            }
        }
        if width < 0 {
            return fail("repeat argument cannot be negative", PyExc_ValueError);
        }
        return combination_create(type, kind, args, width);
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
    if kind == Kind.REPEAT.value {
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
        held.references[0] = Py_NewRef(Py_None);
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
        if a != 0 and a != Py_None {
            first = PyNumber_AsSsize_t(a, PyExc_OverflowError);
        }
        if first == -1 and jacpy_error_pending() != 0 {
            PyErr_Clear();
        }
        if b != Py_None {
            stop = PyNumber_AsSsize_t(b, PyExc_OverflowError);
            if stop == -1 {
                PyErr_Clear();
                return fail(
                    "Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize.",
                    PyExc_ValueError
                );
            }
        }
        if first < 0 or stop < -1 {
            return fail(
                "Indices for islice() must be None or an integer: 0 <= x <= sys.maxsize.",
                PyExc_ValueError
            );
        }
        if c != 0 and c != Py_None {
            step = PyNumber_AsSsize_t(c, PyExc_OverflowError);
        }
        if step < 1 {
            PyErr_Clear();
            return fail(
                "Step for islice() must be a positive integer or None.",
                PyExc_ValueError
            );
        }
    } else {
        return fail("unknown native iterator kind", PyExc_SystemError);
    }
    return pipeline_create(
        type, kind, source, second, function, initial, first, stop, step, flag
    );
}

def make_group(parent: ptr[PyObject], target: ptr[PyObject]) -> ptr[PyObject] {
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

glob tee_bindings = IteratorBindings();
def tee_copy(instance: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
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

# The type names, by Kind.
glob names = [
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
     ];

# The definitions the binding creates, by Kind, and the module's.
glob kind_tokens: list[ClassToken] = [ClassToken() for _ in range(22)],
     itertools_module_token = ClassToken(),
     _grouper_token = kind_tokens[19],
     _tee_token = kind_tokens[20],
     teedataobject_token = kind_tokens[21],
     cycle_token = kind_tokens[5],
     dropwhile_token = kind_tokens[6],
     filterfalse_token = kind_tokens[7],
     pairwise_token = kind_tokens[9],
     starmap_token = kind_tokens[11],
     takewhile_token = kind_tokens[12];

# _grouper's parent: object(subclass_of='clinic_state_by_cls()->groupby_type').
def subclass_clinic_state_by_cls_groupby_type(
    value: ptr[PyObject], fname: str, label: str
) {
    if jacpy_binding_matches(value, kind_tokens[18].handle) == 0 {
        bad_argument(fname, label, "itertools.groupby", value);
    }
}

def combination_create(
    type: ptr[PyObject], kind: int, iterable: ptr[PyObject], width: i64
) -> ptr[PyObject] {
    combination = CombinationState(jacpy_combinatorial_new());
    if jacpy_combinatorial_init(combination.native, i64(kind), iterable, width) < 0 {
        return NULL;
    }
    return wrap(type, combination);
}

# The Argument Clinic _impl functions.
def itertools_groupby_impl(
    type: ptr[PyObject], it: ptr[PyObject], keyfunc: ptr[PyObject]
) -> ptr[PyObject] {
    state = GroupState(group_state(make_group=make_group));
    if jacpy_group_init(state.native, it, keyfunc) < 0 {
        return NULL;
    }
    return wrap(type, state);
}

def itertools__grouper_impl(
    type: ptr[PyObject], parent: ptr[PyObject], tgtkey: ptr[PyObject]
) -> ptr[PyObject] {
    return make_group(parent, tgtkey);
}

def itertools_teedataobject_impl(
    type: ptr[PyObject], it: ptr[PyObject], values: ptr[PyObject], next: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_for(type);
    if module == 0 {
        return NULL;
    }
    successor = next;
    if successor != Py_None {
        if jacpy_list_size(values) != 57
            or Py_TYPE(successor)
                != jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)) {
            return fail("Invalid arguments", PyExc_ValueError);
        }
    } else {
        successor = NULL;
    }
    state = BlockState(tee_block());
    if jacpy_tee_block_init(state.native, it, values, successor) < 0 {
        return NULL;
    }
    return wrap(type, state);
}

def itertools__tee_impl(type: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
    module = module_for(type);
    if module == 0 {
        return NULL;
    }
    try {
        return jacpy_tee_construct(
            tee_bindings,
            type,
            jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)),
            iterable
        );
    } except boundary_failure {
        return NULL;
    }
}

def itertools_tee_impl(
    module: ptr[PyObject], iterable: ptr[PyObject], n: i64
) -> ptr[PyObject] {
    if n < 0 {
        return fail("n must be >= 0", PyExc_ValueError);
    }
    try {
        return jacpy_tee_split(
            tee_bindings,
            jacpy_binding_state_get(module, i64(Kind.TEE.value)),
            jacpy_binding_state_get(module, i64(Kind.TEE_DATA.value)),
            iterable,
            n
        );
    } except boundary_failure {
        return NULL;
    }
}

def batched_new_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], n: i64, strict: bool
) -> ptr[PyObject] {
    if n < 1 {
        return fail("n must be at least one", PyExc_ValueError);
    }
    return pipeline_create(
        type, Kind.BATCHED.value, iterable, step=n, flag=i64(1 if strict else 0)
    );
}

def itertools_cycle_impl(
    type: ptr[PyObject], iterable: ptr[PyObject]
) -> ptr[PyObject] {
    return pipeline_create(type, Kind.CYCLE.value, iterable);
}

def pairwise_new_impl(type: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
    return pipeline_create(type, Kind.PAIRWISE.value, iterable);
}

def itertools_dropwhile_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    return pipeline_create(type, Kind.DROPWHILE.value, seq, function=func);
}

def itertools_takewhile_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    return pipeline_create(type, Kind.TAKEWHILE.value, seq, function=func);
}

def itertools_starmap_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    return pipeline_create(type, Kind.STARMAP.value, seq, function=func);
}

def itertools_filterfalse_impl(
    type: ptr[PyObject], func: ptr[PyObject], seq: ptr[PyObject]
) -> ptr[PyObject] {
    return pipeline_create(type, Kind.FILTERFALSE.value, seq, function=func);
}

def itertools_chain_from_iterable_impl(
    type: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    return chain_from(type, arg);
}

def itertools_combinations_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], r: i64
) -> ptr[PyObject] {
    if r < 0 {
        return fail("r must be non-negative", PyExc_ValueError);
    }
    return combination_create(type, Kind.COMBINATIONS.value, iterable, r);
}

def itertools_combinations_with_replacement_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], r: i64
) -> ptr[PyObject] {
    if r < 0 {
        return fail("r must be non-negative", PyExc_ValueError);
    }
    return combination_create(type, Kind.CWR.value, iterable, r);
}

def itertools_permutations_impl(
    type: ptr[PyObject], iterable: ptr[PyObject], robj: ptr[PyObject]
) -> ptr[PyObject] {
    width: i64 = -1;
    if robj != 0 and robj != Py_None {
        width = PyLong_AsSsize_t(robj);
        if width == -1 and jacpy_error_pending() != 0 {
            return NULL;
        }
        if width < 0 {
            return fail("r must be non-negative", PyExc_ValueError);
        }
    }
    return combination_create(type, Kind.PERMUTATIONS.value, iterable, width);
}

def itertools_accumulate_impl(
    type: ptr[PyObject],
    iterable: ptr[PyObject],
    binop: ptr[PyObject],
    initial: ptr[PyObject]
) -> ptr[PyObject] {
    return pipeline_create(
        type, Kind.ACCUMULATE.value, iterable, function=binop, initial=initial
    );
}

def itertools_compress_impl(
    type: ptr[PyObject], seq1: ptr[PyObject], seq2: ptr[PyObject]
) -> ptr[PyObject] {
    return pipeline_create(type, Kind.COMPRESS.value, seq1, second=seq2);
}

def itertools_count_impl(
    type: ptr[PyObject], long_cnt: ptr[PyObject], long_step: ptr[PyObject]
) -> ptr[PyObject] {
    if (long_cnt != 0 and PyNumber_Check(long_cnt) == 0)
        or (long_step != 0 and PyNumber_Check(long_step) == 0) {
        return fail("a number is required");
    }
    held = ReferenceState(references=[NULL, NULL]);
    try {
        held.references[0] = Py_NewRef(long_cnt)
            if long_cnt != 0
            else required(PyLong_FromLongLong(0));
        held.references[1] = Py_NewRef(long_step)
            if long_step != 0
            else required(PyLong_FromLongLong(1));
    } except boundary_failure {
        return NULL;
    }
    return pipeline_create(
        type, Kind.COUNT.value, held.references[0], second=held.references[1]
    );
}
