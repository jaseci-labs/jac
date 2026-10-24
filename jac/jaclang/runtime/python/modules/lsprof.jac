obj RotatingNode {
    has key: int = 0,
        left: RotatingNode | None = None,
        right: RotatingNode | None = None;
}

obj RotatingTree {
    has top: RotatingNode | None = None,
        random_value: int = 1,
        random_stream: int = 0;

    def randombits(bits: int) -> int;
    def add(item: RotatingNode);
    def relink(parent: RotatingNode | None, on_left: bool, child: RotatingNode);
    def get(key: int) -> RotatingNode | None;
    def nodes -> list[RotatingNode];
    def clear;
}

def:priv collect(top: RotatingNode | None, result: list[RotatingNode]);

glob Profiler_token = ClassToken();

glob:priv POF_ENABLED: int = 0x001,
     POF_SUBCALLS: int = 0x002,
     POF_BUILTINS: int = 0x004,
     POF_EXT_TIMER: int = 0x008,
     POF_NOMEMORY: int = 0x100,
     PY_MONITORING_PROFILER_ID: int = 2,
     PY_TIME_ROUND_FLOOR: i32 = 0,
     CALLBACK_TABLE: list[tuple[int, str]] = [
         (0, "_pystart_callback"),
         (1, "_pystart_callback"),
         (14, "_pythrow_callback"),
         (2, "_pyreturn_callback"),
         (3, "_pyreturn_callback"),
         (13, "_pyreturn_callback"),
         (4, "_ccall_callback"),
         (16, "_creturn_callback"),
         (17, "_creturn_callback")
     ];

obj ProfilerEntry(RotatingNode) {
    has user_obj: ptr[PyObject] = NULL,
        tt: int = 0,
        it: int = 0,
        callcount: int = 0,
        recursivecallcount: int = 0,
        recursion_level: int = 0,
        calls: RotatingTree = RotatingTree();
}

obj ProfilerSubEntry(RotatingNode) {
    has callee: ProfilerEntry | None = None,
        tt: int = 0,
        it: int = 0,
        callcount: int = 0,
        recursivecallcount: int = 0,
        recursion_level: int = 0;
}

obj ProfilerContext {
    has t0: int = 0,
        subt: int = 0,
        previous: ProfilerContext | None = None,
        ctx_entry: ProfilerEntry | None = None;
}

obj ProfilerState(NativeState) {
    has entries: RotatingTree = RotatingTree(),
        current: ProfilerContext | None = None,
        free_contexts: list[ProfilerContext] = [],
        flags: int = 0,
        external_timer: ptr[PyObject] = NULL,
        external_timer_unit: f64 = 0.0,
        tool_id: int = 0,
        missing: ptr[PyObject] = NULL;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def profiler_of(instance: ptr[PyObject]) -> ProfilerState | None;

def profiler_finalize(instance: ptr[PyObject]);

def:priv call_external_timer(state: ProfilerState) -> int;

def:priv call_timer(state: ProfilerState) -> int;

def:priv is_cfunction(value: ptr[PyObject]) -> bool;

def:priv method_name(function: ptr[PyObject]) -> ptr[PyObject];

def:priv normalize_user_obj(value: ptr[PyObject]) -> ptr[PyObject];

def:priv describe_cfunction(
    function: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def:priv get_entry(state: ProfilerState, key: int) -> ProfilerEntry | None;

def:priv new_entry(
    state: ProfilerState, key: int, user_obj: ptr[PyObject]
) -> ProfilerEntry | None;

def:priv get_sub_entry(
    caller: ProfilerEntry, record: ProfilerEntry
) -> ProfilerSubEntry | None;

def:priv new_sub_entry(
    caller: ProfilerEntry, record: ProfilerEntry
) -> ProfilerSubEntry;

def:priv clear_entries(state: ProfilerState);

def:priv init_context(
    state: ProfilerState, context: ProfilerContext, record: ProfilerEntry
);

def:priv stop(state: ProfilerState, context: ProfilerContext, record: ProfilerEntry);

def:priv ptrace_enter_call(state: ProfilerState, key: int, user_obj: ptr[PyObject]);

def:priv ptrace_leave_call(state: ProfilerState, key: int);

def:priv pending_exception(state: ProfilerState) -> bool;

def:priv flush_unmatched(state: ProfilerState);

def:priv stats_row(type: ptr[PyObject], items: list[ptr[PyObject]]) -> ptr[PyObject];

def:priv stats_for_entry(
    record: ProfilerEntry, module: ptr[PyObject], factor: f64, result: ptr[PyObject]
) -> bool;

def _lsprof_Profiler_getstats_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def:priv set_subcalls(state: ProfilerState, value: bool);

def:priv set_builtins(state: ProfilerState, value: bool);

def _lsprof_Profiler__pystart_callback_impl(
    receiver: ptr[PyObject], code: ptr[PyObject], instruction_offset: ptr[PyObject]
) -> ptr[PyObject];

def _lsprof_Profiler__pythrow_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    exception: ptr[PyObject]
) -> ptr[PyObject];

def _lsprof_Profiler__pyreturn_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    retval: ptr[PyObject]
) -> ptr[PyObject];

def:priv get_cfunc_from_callable(
    callable: ptr[PyObject], self_arg: ptr[PyObject], missing: ptr[PyObject]
) -> ptr[PyObject];

def _lsprof_Profiler__ccall_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    callable_: ptr[PyObject],
    self_arg: ptr[PyObject]
) -> ptr[PyObject];

def _lsprof_Profiler__creturn_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    callable_: ptr[PyObject],
    self_arg: ptr[PyObject]
) -> ptr[PyObject];

def:priv register_callbacks(
    receiver: ptr[PyObject], state: ProfilerState, monitoring: ptr[PyObject]
) -> bool;

def _lsprof_Profiler_enable_impl(
    receiver: ptr[PyObject], subcalls: bool, builtins: bool
) -> ptr[PyObject];

def:priv unregister_callbacks(state: ProfilerState, monitoring: ptr[PyObject]) -> bool;

def _lsprof_Profiler_disable_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _lsprof_Profiler_clear_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def profiler_init_impl(
    receiver: ptr[PyObject],
    timer: ptr[PyObject],
    timeunit: f64,
    subcalls: bool,
    builtins: bool
) -> i32;

impl RotatingTree.randombits(bits: int) -> int {
    if self.random_stream < (1 << bits) {
        self.random_value = (self.random_value * 1082527) & 0xFFFFFFFF;
        self.random_stream = self.random_value;
    }
    result = self.random_stream & ((1 << bits) - 1);
    self.random_stream = self.random_stream >> bits;
    return result;
}

impl RotatingTree.add(item: RotatingNode) {
    item.left = None;
    item.right = None;
    start = self.top;
    if start is None {
        self.top = item;
        return;
    }
    at: RotatingNode = start;
    while True {
        if item.key < at.key {
            below = at.left;
            if below is None {
                at.left = item;
                return;
            }
            at = below;
        } else {
            below = at.right;
            if below is None {
                at.right = item;
                return;
            }
            at = below;
        }
    }
}

impl RotatingTree.relink(
    parent: RotatingNode | None, on_left: bool, child: RotatingNode
) {
    if parent is None {
        self.top = child;
    } elif on_left {
        parent.left = child;
    } else {
        parent.right = child;
    }
}

impl RotatingTree.get(key: int) -> RotatingNode | None {
    if self.randombits(3) != 4 {
        found = self.top;
        while found is not None {
            if found.key == key {
                return found;
            }
            found = found.left if key < found.key else found.right;
        }
        return None;
    }
    start = self.top;
    if start is None {
        return None;
    }
    at: RotatingNode = start;
    parent: RotatingNode | None = None;
    on_left = False;
    while True {
        if at.key == key {
            return at;
        }
        rotate = self.randombits(1) == 0;
        if key < at.key {
            following = at.left;
            if following is None {
                return None;
            }
            if rotate {
                at.left = following.right;
                following.right = at;
                self.relink(parent, on_left, following);
            } else {
                parent = at;
                on_left = True;
            }
            at = following;
        } else {
            following = at.right;
            if following is None {
                return None;
            }
            if rotate {
                at.right = following.left;
                following.left = at;
                self.relink(parent, on_left, following);
            } else {
                parent = at;
                on_left = False;
            }
            at = following;
        }
    }
}

impl RotatingTree.nodes -> list[RotatingNode] {
    result: list[RotatingNode] = [];
    collect(self.top, result);
    return result;
}

impl RotatingTree.clear {
    pending: list[RotatingNode] = [];
    if self.top is not None {
        pending.append(self.top);
    }
    self.top = None;
    while pending {
        item = pending.pop();
        if item.left is not None {
            pending.append(item.left);
        }
        if item.right is not None {
            pending.append(item.right);
        }
        item.left = None;
        item.right = None;
    }
}

impl collect(top: RotatingNode | None, result: list[RotatingNode]) {
    item = top;
    while item is not None {
        collect(item.left, result);
        result.append(item);
        item = item.right;
    }
}

impl ProfilerState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return visit_reference(self.external_timer, visitor, context);
}

impl ProfilerState.clear {
    clear_entries(self);
    timer = self.external_timer;
    self.external_timer = NULL;
    jacpy_release(timer);
    missing = self.missing;
    self.missing = NULL;
    jacpy_release(missing);
}

impl ProfilerState.drop {
    self.clear();
}

impl profiler_of(instance: ptr[PyObject]) -> ProfilerState | None {
    if jacpy_binding_native_present(instance, Profiler_token.handle) == 0 {
        fresh = ProfilerState(entries=RotatingTree(), free_contexts=[]);
        if jacpy_binding_native_set(instance, Profiler_token.handle, fresh) < 0 {
            return None;
        }
    }
    state = jacpy_binding_native_get(instance, Profiler_token.handle);
    if isinstance(state, ProfilerState) {
        return state;
    }
    object_error(PyExc_SystemError, "Profiler state is unavailable");
    return None;
}

impl profiler_finalize(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, Profiler_token.handle) == 0 {
        return;
    }
    state = jacpy_binding_native_get(instance, Profiler_token.handle);
    if not isinstance(state, ProfilerState) {
        return;
    }
    if state.flags & POF_ENABLED {
        if _PyEval_SetProfile(PyThreadState_Get(), ptr(), NULL) < 0 {
            PyErr_FormatUnraisable(
                "Exception ignored while destroying _lsprof profiler"
            );
        }
    }
    flush_unmatched(state);
    clear_entries(state);
}

impl call_external_timer(state: ProfilerState) -> int {
    state.flags |= POF_EXT_TIMER;
    value = PyObject_CallNoArgs(state.external_timer);
    state.flags &= ~POF_EXT_TIMER;
    if not value {
        PyErr_FormatUnraisable(
            "Exception ignored while calling _lsprof timer %R", state.external_timer
        );
        return 0;
    }
    result: i64 = 0;
    status: i32 = 0;
    if state.external_timer_unit > 0.0 {
        status = _PyTime_FromLong(&mut result, value);
    } else {
        status = _PyTime_FromSecondsObject(&mut result, value, PY_TIME_ROUND_FLOOR);
    }
    jacpy_release(value);
    if status < 0 {
        PyErr_FormatUnraisable(
            "Exception ignored while calling _lsprof timer %R", state.external_timer
        );
        return 0;
    }
    return int(result);
}

impl call_timer(state: ProfilerState) -> int {
    if state.external_timer {
        return call_external_timer(state);
    }
    ticks: i64 = 0;
    PyTime_PerfCounterRaw(&mut ticks);
    return int(ticks);
}

impl is_cfunction(value: ptr[PyObject]) -> bool {
    return jacpy_type_check(value, addressof(PyCFunction_Type)) != 0;
}

impl method_name(function: ptr[PyObject]) -> ptr[PyObject] {
    method: ptr[PyMethodDef] = jacpy_cfunction_method(function);
    return PyUnicode_FromFormat("%s", method.view(1)[0].ml_name);
}

impl normalize_user_obj(value: ptr[PyObject]) -> ptr[PyObject] {
    if not is_cfunction(value) {
        return Py_NewRef(value);
    }
    name = method_name(value);
    if not name {
        return NULL;
    }
    try {
        return describe_cfunction(value, name);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(name);
    }
}

impl describe_cfunction(function: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    bound = jacpy_cfunction_self(function);
    module = jacpy_cfunction_module(function);
    if not bound {
        modname = NULL;
        if module {
            if jacpy_is_unicode(module) != 0 {
                modname = Py_NewRef(module);
            } elif jacpy_type_check(module, addressof(PyModule_Type)) != 0 {
                modname = PyModule_GetNameObject(module);
                if not modname {
                    PyErr_Clear();
                }
            }
        }
        if modname {
            try {
                if _PyUnicode_EqualToASCIIString(modname, ptr[u8]("builtins")) == 0 {
                    return text_object(f"<{text_value(modname)}.{text_value(name)}>");
                }
            } finally {
                jacpy_release(modname);
            }
        }
        return text_object(f"<{text_value(name)}>");
    }

    found = _PyType_LookupRef(Py_TYPE(bound), name);
    if found {
        shown = PyObject_Repr(found);
        jacpy_release(found);
        if shown {
            return shown;
        }
    }

    PyErr_Clear();
    if module and jacpy_is_unicode(module) != 0 {
        described = PyObject_Str(module);
        if not described {
            return NULL;
        }
        try {
            return text_object(
                f"<built-in method {text_value(described)}.{text_value(name)}>"
            );
        } finally {
            jacpy_release(described);
        }
    }
    return text_object(f"<built-in method {text_value(name)}>");
}

impl get_entry(state: ProfilerState, key: int) -> ProfilerEntry | None {
    item = state.entries.get(key);
    if isinstance(item, ProfilerEntry) {
        return item;
    }
    return None;
}

impl new_entry(
    state: ProfilerState, key: int, user_obj: ptr[PyObject]
) -> ProfilerEntry | None {
    normalized = normalize_user_obj(user_obj);
    if not normalized {
        PyErr_Clear();
        state.flags |= POF_NOMEMORY;
        return None;
    }
    record = ProfilerEntry(key=key, user_obj=normalized, calls=RotatingTree());
    state.entries.add(record);
    return record;
}

impl get_sub_entry(
    caller: ProfilerEntry, record: ProfilerEntry
) -> ProfilerSubEntry | None {
    item = caller.calls.get(record.key);
    if isinstance(item, ProfilerSubEntry) {
        return item;
    }
    return None;
}

impl new_sub_entry(caller: ProfilerEntry, record: ProfilerEntry) -> ProfilerSubEntry {
    sub_entry = ProfilerSubEntry(key=record.key, callee=record);
    caller.calls.add(sub_entry);
    return sub_entry;
}

impl clear_entries(state: ProfilerState) {
    for item in state.entries.nodes() {
        if isinstance(item, ProfilerEntry) {
            for sub_node in item.calls.nodes() {
                if isinstance(sub_node, ProfilerSubEntry) {
                    sub_node.callee = None;
                }
            }
            item.calls.clear();
            user_obj = item.user_obj;
            item.user_obj = NULL;
            jacpy_release(user_obj);
        }
    }
    state.entries.clear();

    state.current = None;
    state.free_contexts = [];
}

impl init_context(
    state: ProfilerState, context: ProfilerContext, record: ProfilerEntry
) {
    context.ctx_entry = record;
    context.subt = 0;
    context.previous = state.current;
    state.current = context;
    record.recursion_level += 1;
    previous = context.previous;
    if state.flags & POF_SUBCALLS and previous is not None {
        caller = previous.ctx_entry;
        if caller is not None {
            sub_entry = get_sub_entry(caller, record);
            if sub_entry is None {
                sub_entry = new_sub_entry(caller, record);
            }
            sub_entry.recursion_level += 1;
        }
    }
    context.t0 = call_timer(state);
}

impl stop(state: ProfilerState, context: ProfilerContext, record: ProfilerEntry) {
    tt = call_timer(state) - context.t0;
    it = tt - context.subt;
    previous = context.previous;
    if previous is not None {
        previous.subt += tt;
    }
    state.current = previous;
    record.recursion_level -= 1;
    if record.recursion_level == 0 {
        record.tt += tt;
    } else {
        record.recursivecallcount += 1;
    }
    record.it += it;
    record.callcount += 1;
    if state.flags & POF_SUBCALLS and previous is not None {
        caller = previous.ctx_entry;
        if caller is not None {
            sub_entry = get_sub_entry(caller, record);
            if sub_entry is not None {
                sub_entry.recursion_level -= 1;
                if sub_entry.recursion_level == 0 {
                    sub_entry.tt += tt;
                } else {
                    sub_entry.recursivecallcount += 1;
                }
                sub_entry.it += it;
                sub_entry.callcount += 1;
            }
        }
    }
}

impl ptrace_enter_call(state: ProfilerState, key: int, user_obj: ptr[PyObject]) {
    exception = PyErr_GetRaisedException();
    record = get_entry(state, key);
    if record is None {
        record = new_entry(state, key, user_obj);
    }
    if record is not None {
        context = state.free_contexts.pop()
            if state.free_contexts
            else ProfilerContext();
        init_context(state, context, record);
    }
    PyErr_SetRaisedException(exception);
}

impl ptrace_leave_call(state: ProfilerState, key: int) {
    context = state.current;
    if context is None {
        return;
    }
    record = get_entry(state, key);
    if record is not None {
        stop(state, context, record);
    } else {
        state.current = context.previous;
    }

    context.previous = None;
    context.ctx_entry = None;
    state.free_contexts.append(context);
}

impl pending_exception(state: ProfilerState) -> bool {
    if state.flags & POF_NOMEMORY {
        state.flags -= POF_NOMEMORY;
        object_error(PyExc_MemoryError, "memory was exhausted while profiling");
        return True;
    }
    return False;
}

impl flush_unmatched(state: ProfilerState) {
    while state.current is not None {
        context = state.current;
        record = context.ctx_entry;
        if record is not None {
            stop(state, context, record);
        } else {
            state.current = context.previous;
        }
    }
}

impl stats_row(type: ptr[PyObject], items: list[ptr[PyObject]]) -> ptr[PyObject] {
    row = PyStructSequence_New(type);
    failed = not row;
    for index in range(len(items)) {
        if not items[index] {
            failed = True;
        }
        if failed {
            jacpy_release(items[index]);
        } else {
            PyStructSequence_SetItem(row, i64(index), items[index]);
        }
    }
    if failed {
        jacpy_release(row);
        return NULL;
    }
    return row;
}

impl stats_for_entry(
    record: ProfilerEntry, module: ptr[PyObject], factor: f64, result: ptr[PyObject]
) -> bool {
    if record.callcount == 0 {
        return True;
    }
    sublist = NULL;
    if record.calls.top is not None {
        sublist = PyList_New(0);
        if not sublist {
            return False;
        }
        for item in record.calls.nodes() {
            if not isinstance(item, ProfilerSubEntry) or item.callee is None {
                continue;
            }
            row = stats_row(
                jacpy_binding_state_get(module, 2),
                [
                    Py_NewRef(item.callee.user_obj),
                    PyLong_FromLong(i64(item.callcount)),
                    PyLong_FromLong(i64(item.recursivecallcount)),
                    PyFloat_FromDouble(factor * f64(item.tt)),
                    PyFloat_FromDouble(factor * f64(item.it))
                ]
            );
            if not row {
                jacpy_release(sublist);
                return False;
            }
            status = PyList_Append(sublist, row);
            jacpy_release(row);
            if status < 0 {
                jacpy_release(sublist);
                return False;
            }
        }
    } else {
        sublist = Py_NewRef(borrowed_none());
    }
    row = stats_row(
        jacpy_binding_state_get(module, 1),
        [
            Py_NewRef(record.user_obj),
            PyLong_FromLong(i64(record.callcount)),
            PyLong_FromLong(i64(record.recursivecallcount)),
            PyFloat_FromDouble(factor * f64(record.tt)),
            PyFloat_FromDouble(factor * f64(record.it)),
            sublist
        ]
    );
    if not row {
        return False;
    }
    status = PyList_Append(result, row);
    jacpy_release(row);
    return status == 0;
}

impl _lsprof_Profiler_getstats_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    module = PyType_GetModule(cls);
    if not module {
        return NULL;
    }
    if pending_exception(state) {
        return NULL;
    }
    factor = state.external_timer_unit;
    if not state.external_timer or state.external_timer_unit == 0.0 {
        factor = 1.0 / f64(_PyTime_FromSeconds(1));
    }
    result = PyList_New(0);
    if not result {
        return NULL;
    }
    for item in state.entries.nodes() {
        if isinstance(item, ProfilerEntry)
            and not stats_for_entry(item, module, factor, result) {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

impl set_subcalls(state: ProfilerState, value: bool) {
    if value {
        state.flags |= POF_SUBCALLS;
    } else {
        state.flags &= ~POF_SUBCALLS;
    }
}

impl set_builtins(state: ProfilerState, value: bool) {
    if value {
        state.flags |= POF_BUILTINS;
    } else {
        state.flags &= ~POF_BUILTINS;
    }
}

impl _lsprof_Profiler__pystart_callback_impl(
    receiver: ptr[PyObject], code: ptr[PyObject], instruction_offset: ptr[PyObject]
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    ptrace_enter_call(state, int(code), code);
    return Py_NewRef(borrowed_none());
}

impl _lsprof_Profiler__pythrow_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    exception: ptr[PyObject]
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    ptrace_enter_call(state, int(code), code);
    return Py_NewRef(borrowed_none());
}

impl _lsprof_Profiler__pyreturn_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    retval: ptr[PyObject]
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    ptrace_leave_call(state, int(code));
    return Py_NewRef(borrowed_none());
}

impl get_cfunc_from_callable(
    callable: ptr[PyObject], self_arg: ptr[PyObject], missing: ptr[PyObject]
) -> ptr[PyObject] {
    if is_cfunction(callable) {
        return Py_NewRef(callable);
    }
    if Py_TYPE(callable) == addressof(PyMethodDescr_Type) {
        if self_arg == missing {
            return NULL;
        }
        method = descriptor_get(callable, self_arg, Py_TYPE(self_arg));
        if not method {
            PyErr_Clear();
            return NULL;
        }
        if is_cfunction(method) {
            return method;
        }
        jacpy_release(method);
    }
    return NULL;
}

impl _lsprof_Profiler__ccall_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    callable_: ptr[PyObject],
    self_arg: ptr[PyObject]
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    if state.flags & POF_BUILTINS {
        cfunc = get_cfunc_from_callable(callable_, self_arg, state.missing);
        if cfunc {
            ptrace_enter_call(state, int(jacpy_cfunction_method(cfunc)), cfunc);
            jacpy_release(cfunc);
        }
    }
    return Py_NewRef(borrowed_none());
}

impl _lsprof_Profiler__creturn_callback_impl(
    receiver: ptr[PyObject],
    code: ptr[PyObject],
    instruction_offset: ptr[PyObject],
    callable_: ptr[PyObject],
    self_arg: ptr[PyObject]
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    if state.flags & POF_BUILTINS {
        cfunc = get_cfunc_from_callable(callable_, self_arg, state.missing);
        if cfunc {
            ptrace_leave_call(state, int(jacpy_cfunction_method(cfunc)));
            jacpy_release(cfunc);
        }
    }
    return Py_NewRef(borrowed_none());
}

impl register_callbacks(
    receiver: ptr[PyObject], state: ProfilerState, monitoring: ptr[PyObject]
) -> bool {
    check = call_method(
        monitoring,
        "use_tool_id",
        [PyLong_FromLong(i64(state.tool_id)), PyUnicode_FromString(ptr[u8]("cProfile"))]
    );
    if not check {
        object_error(PyExc_ValueError, "Another profiling tool is already active");
        return False;
    }
    jacpy_release(check);
    all_events = 0;
    for (event, name) in CALLBACK_TABLE {
        callback = jacpy_object_getattr_text(receiver, name);
        if not callback {
            return False;
        }
        registered = call_method(
            monitoring,
            "register_callback",
            [
                PyLong_FromLong(i64(state.tool_id)),
                PyLong_FromLong(i64(1 << event)),
                callback
            ]
        );
        if not registered {
            return False;
        }
        jacpy_release(registered);
        all_events |= 1 << event;
    }
    events = call_method(
        monitoring,
        "set_events",
        [PyLong_FromLong(i64(state.tool_id)), PyLong_FromLong(i64(all_events))]
    );
    if not events {
        return False;
    }
    jacpy_release(events);
    return True;
}

impl _lsprof_Profiler_enable_impl(
    receiver: ptr[PyObject], subcalls: bool, builtins: bool
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    set_subcalls(state, subcalls);
    set_builtins(state, builtins);
    monitoring = PyImport_ImportModuleAttrString("sys", "monitoring");
    if not monitoring {
        return NULL;
    }
    registered = register_callbacks(receiver, state, monitoring);
    jacpy_release(monitoring);
    if not registered {
        return NULL;
    }
    state.flags |= POF_ENABLED;
    return Py_NewRef(borrowed_none());
}

impl unregister_callbacks(state: ProfilerState, monitoring: ptr[PyObject]) -> bool {
    for (event, name) in CALLBACK_TABLE {
        result = call_method(
            monitoring,
            "register_callback",
            [
                PyLong_FromLong(i64(state.tool_id)),
                PyLong_FromLong(i64(1 << event)),
                Py_NewRef(borrowed_none())
            ]
        );
        if not result {
            return False;
        }
        jacpy_release(result);
    }
    result = call_method(
        monitoring,
        "set_events",
        [PyLong_FromLong(i64(state.tool_id)), PyLong_FromLong(0)]
    );
    if not result {
        return False;
    }
    jacpy_release(result);
    result = call_method(
        monitoring, "free_tool_id", [PyLong_FromLong(i64(state.tool_id))]
    );
    if not result {
        return False;
    }
    jacpy_release(result);
    return True;
}

impl _lsprof_Profiler_disable_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    if state.flags & POF_EXT_TIMER {
        object_error(PyExc_RuntimeError, "cannot disable profiler in external timer");
        return NULL;
    }
    if state.flags & POF_ENABLED {
        monitoring = PyImport_ImportModuleAttrString("sys", "monitoring");
        if not monitoring {
            return NULL;
        }
        unregistered = unregister_callbacks(state, monitoring);
        jacpy_release(monitoring);
        if not unregistered {
            return NULL;
        }
        state.flags &= ~POF_ENABLED;
        flush_unmatched(state);
    }
    if pending_exception(state) {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

impl _lsprof_Profiler_clear_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    if state.flags & POF_EXT_TIMER {
        object_error(PyExc_RuntimeError, "cannot clear profiler in external timer");
        return NULL;
    }
    clear_entries(state);
    return Py_NewRef(borrowed_none());
}

impl profiler_init_impl(
    receiver: ptr[PyObject],
    timer: ptr[PyObject],
    timeunit: f64,
    subcalls: bool,
    builtins: bool
) -> i32 {
    state = profiler_of(receiver);
    if state is None {
        return i32(-1);
    }
    set_subcalls(state, subcalls);
    set_builtins(state, builtins);
    state.external_timer_unit = timeunit;
    previous = state.external_timer;
    state.external_timer = Py_NewRef(timer) if timer else NULL;
    jacpy_release(previous);
    state.tool_id = PY_MONITORING_PROFILER_ID;
    monitoring = PyImport_ImportModuleAttrString("sys", "monitoring");
    if not monitoring {
        return i32(-1);
    }
    missing = PyObject_GetAttrString(monitoring, ptr[u8]("MISSING"));
    jacpy_release(monitoring);
    if not missing {
        return i32(-1);
    }
    previous = state.missing;
    state.missing = missing;
    jacpy_release(previous);
    return i32(0);
}
