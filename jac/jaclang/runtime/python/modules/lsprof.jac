"""The deterministic profiler behind cProfile, driven by sys.monitoring.

Derived from CPython 3.14.6 Modules/_lsprof.c and Modules/rotatingtree.c; see
../LICENSE.cpython. enable() registers the profiler's bound callback methods
for the call and return events of the PROFILER tool id. Entries are keyed by
the address of the code object, or of the PyMethodDef of a built-in, and live
in a rotating tree owned by the profiler state, as does each entry's tree of
per-caller subentries. Timings are PyTime_t ticks of the default performance
counter or of the user's timer, scaled when the stats are read.

A rotating tree (Armin Rigo) is a dict-like splay variant. It works best when
the same small set of keys is looked up over and over and that set evolves
slowly: a lookup occasionally rotates the found path to move the node towards
the root. Each tree owns its random bit stream. rotatingtree.c shares one
stream between every tree of the process behind a mutex; the stream only
decides when a lookup rebalances, so per-tree streams need no lock and change
no result.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_c_text,
    jacpy_cfunction_method,
    jacpy_cfunction_module,
    jacpy_cfunction_self,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_type_check,
    jacpy_unraisable,
    NULL,
    Py_NewRef,
    Py_TYPE,
    PyCFunction_Type,
    PyErr_Clear,
    PyErr_GetRaisedException,
    PyErr_SetRaisedException,
    _PyEval_SetProfile,
    PyExc_MemoryError,
    PyExc_RuntimeError,
    PyExc_SystemError,
    PyExc_ValueError,
    PyFloat_FromDouble,
    PyImport_ImportModuleAttrString,
    PyList_Append,
    PyList_New,
    PyLong_FromLong,
    PyMethodDef,
    PyMethodDescr_Type,
    PyModule_GetNameObject,
    PyModule_Type,
    PyObject,
    PyObject_CallNoArgs,
    PyObject_GetAttrString,
    PyObject_Repr,
    PyObject_Str,
    PyStructSequence_New,
    PyStructSequence_SetItem,
    PyThreadState_Get,
    _PyTime_FromLong,
    _PyTime_FromSeconds,
    _PyTime_FromSecondsObject,
    PyTime_PerfCounterRaw,
    PyType_GetModule,
    _PyType_LookupRef,
    _PyUnicode_EqualToASCIIString,
    PyUnicode_FromString
}
import from jaclang.runtime.python.capi {
    boundary_failure,
    object_error,
    text_object,
    text_value
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    descriptor_get,
    jacpy_binding_allocate
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.references { call_method }
import from jaclang.runtime.python.bindings.converters { ClassToken, borrowed_none }

obj RotatingNode {
    has key: int = 0,
        left: RotatingNode | None = None,
        right: RotatingNode | None = None;
}

obj RotatingTree {
    has top: RotatingNode | None = None,
        random_value: int = 1,
        random_stream: int = 0;

    # randombits(): a fast-and-dirty generator, slightly biased towards ones.
    def randombits(bits: int) -> int {
        if self.random_stream < (1 << bits) {
            self.random_value = (self.random_value * 1082527) & 0xFFFFFFFF;
            self.random_stream = self.random_value;
        }
        result = self.random_stream & ((1 << bits) - 1);
        self.random_stream = self.random_stream >> bits;
        return result;
    }

    # RotatingTree_Add(): insert node as a new leaf.
    def add(item: RotatingNode) {
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

    # Store child in the link a lookup came through: the root when parent is
    # None, otherwise parent's left or right link.
    def relink(parent: RotatingNode | None, on_left: bool, child: RotatingNode) {
        if parent is None {
            self.top = child;
        } elif on_left {
            parent.left = child;
        } else {
            parent.right = child;
        }
    }

    # RotatingTree_Get(): the node with key, or None. One lookup in eight
    # rotates each step of its path with probability one half.
    def get(key: int) -> RotatingNode | None {
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

    # RotatingTree_Enum(): every node in key order.
    def nodes -> list[RotatingNode] {
        result: list[RotatingNode] = [];
        collect(self.top, result);
        return result;
    }

    # Unlink every node without recursion, so dropping a long chain of nodes
    # cannot exhaust the stack.
    def clear {
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
}

# In-order walk: recurse into left subtrees, loop down right ones.
def:priv collect(top: RotatingNode | None, result: list[RotatingNode]) {
    item = top;
    while item is not None {
        collect(item.left, result);
        result.append(item);
        item = item.right;
    }
}

glob Profiler_token = ClassToken();

glob:priv POF_ENABLED: int = 0x001,
     POF_SUBCALLS: int = 0x002,
     POF_BUILTINS: int = 0x004,
     POF_EXT_TIMER: int = 0x008,
     POF_NOMEMORY: int = 0x100,
     PY_MONITORING_PROFILER_ID: int = 2,
     PY_TIME_ROUND_FLOOR: i32 = 0,
     # sys.monitoring events and the callback method each one calls.
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

# A function or user-defined block. user_obj is the code object or, for a
# built-in, a descriptive str; the entry owns it until clear_entries().
obj ProfilerEntry(RotatingNode) {
    has user_obj: ptr[PyObject] = NULL,
        tt: int = 0,
        it: int = 0,
        callcount: int = 0,
        recursivecallcount: int = 0,
        recursion_level: int = 0,
        calls: RotatingTree = RotatingTree();
}

# A function called from another function: keyed by the callee's key.
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

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return visit_reference(self.external_timer, visitor, context);
    }

    def clear {
        clear_entries(self);
        timer = self.external_timer;
        self.external_timer = NULL;
        jacpy_release(timer);
        missing = self.missing;
        self.missing = NULL;
        jacpy_release(missing);
    }

    def drop {
        self.clear();
    }
}

def profiler_of(instance: ptr[PyObject]) -> ProfilerState | None {
    if jacpy_binding_native_present(instance, Profiler_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Profiler_token.handle);
        if isinstance(state, ProfilerState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "Profiler state is unavailable");
    return None;
}

# tp_new: the zeroed ProfilerObject that __init__ then configures.
def profiler_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = ProfilerState(entries=RotatingTree(), free_contexts=[]);
    if jacpy_binding_native_set(instance, Profiler_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

# profiler_dealloc(), before the payload is disposed.
def profiler_finalize(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, Profiler_token.handle) == 0 {
        return;
    }
    state = jacpy_binding_native_get(instance, Profiler_token.handle);
    if not isinstance(state, ProfilerState) {
        return;
    }
    if state.flags & POF_ENABLED {
        if _PyEval_SetProfile(PyThreadState_Get(), ptr(), NULL) < 0 {
            jacpy_unraisable(
                "Exception ignored while destroying _lsprof profiler", NULL
            );
        }
    }
    flush_unmatched(state);
    clear_entries(state);
}

# CallExternalTimer(): the user's timer as PyTime_t. A failure is reported as
# unraisable and reads as 0.
def:priv call_external_timer(state: ProfilerState) -> int {
    # The timer can run arbitrary code: disable() and clear() refuse to run
    # while this flag is set.
    state.flags |= POF_EXT_TIMER;
    value = PyObject_CallNoArgs(state.external_timer);
    state.flags &= ~POF_EXT_TIMER;
    if not value {
        jacpy_unraisable(
            "Exception ignored while calling _lsprof timer", state.external_timer
        );
        return 0;
    }
    result: i64 = 0;
    status: i32 = 0;
    if state.external_timer_unit > 0.0 {
        # An integer count, scaled by the time unit in getstats().
        status = _PyTime_FromLong(&mut result, value);
    } else {
        # Seconds as a float, held as nanoseconds.
        status = _PyTime_FromSecondsObject(&mut result, value, PY_TIME_ROUND_FLOOR);
    }
    jacpy_release(value);
    if status < 0 {
        jacpy_unraisable(
            "Exception ignored while calling _lsprof timer", state.external_timer
        );
        return 0;
    }
    return int(result);
}

def:priv call_timer(state: ProfilerState) -> int {
    if state.external_timer {
        return call_external_timer(state);
    }
    ticks: i64 = 0;
    PyTime_PerfCounterRaw(&mut ticks);
    return int(ticks);
}

def:priv is_cfunction(value: ptr[PyObject]) -> bool {
    return jacpy_type_check(value, addressof(PyCFunction_Type)) != 0;
}

# The UTF-8 name of a built-in's PyMethodDef, as %s formats it.
def:priv method_name(function: ptr[PyObject]) -> ptr[PyObject] {
    method: ptr[PyMethodDef] = jacpy_cfunction_method(function);
    return jacpy_c_text(method.view(1)[0].ml_name);
}

# normalizeUserObj(): code objects are kept; a built-in function is replaced
# by a descriptive string, since keeping __self__ of a built-in method alive
# is not wanted.
def:priv normalize_user_obj(value: ptr[PyObject]) -> ptr[PyObject] {
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

def:priv describe_cfunction(
    function: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    bound = jacpy_cfunction_self(function);
    module = jacpy_cfunction_module(function);
    if not bound {
        # A built-in function: <module.name>, or <name> for builtins.
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
                if _PyUnicode_EqualToASCIIString(modname, "builtins") == 0 {
                    return text_object(f"<{text_value(modname)}.{text_value(name)}>");
                }
            } finally {
                jacpy_release(modname);
            }
        }
        return text_object(f"<{text_value(name)}>");
    }
    # A built-in method: repr(getattr(type(__self__), __name__)).
    found = _PyType_LookupRef(Py_TYPE(bound), name);
    if found {
        shown = PyObject_Repr(found);
        jacpy_release(found);
        if shown {
            return shown;
        }
    }
    # Otherwise, use __module__.
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

def:priv get_entry(state: ProfilerState, key: int) -> ProfilerEntry | None {
    item = state.entries.get(key);
    if isinstance(item, ProfilerEntry) {
        return item;
    }
    return None;
}

def:priv new_entry(
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

def:priv get_sub_entry(
    caller: ProfilerEntry, record: ProfilerEntry
) -> ProfilerSubEntry | None {
    item = caller.calls.get(record.key);
    if isinstance(item, ProfilerSubEntry) {
        return item;
    }
    return None;
}

def:priv new_sub_entry(
    caller: ProfilerEntry, record: ProfilerEntry
) -> ProfilerSubEntry {
    sub_entry = ProfilerSubEntry(key=record.key, callee=record);
    caller.calls.add(sub_entry);
    return sub_entry;
}

# clearEntries(): release each entry's user object and drop the trees. A
# subentry holds its callee, so each entry's subentries go first; that breaks
# every entry -> subentry -> entry cycle.
def:priv clear_entries(state: ProfilerState) {
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
    # The contexts of calls still in progress and the free list go too.
    state.current = None;
    state.free_contexts = [];
}

def:priv init_context(
    state: ProfilerState, context: ProfilerContext, record: ProfilerEntry
) {
    context.ctx_entry = record;
    context.subt = 0;
    context.previous = state.current;
    state.current = context;
    record.recursion_level += 1;
    previous = context.previous;
    if state.flags & POF_SUBCALLS and previous is not None {
        # Find or create an entry for me in my caller's entry.
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

def:priv stop(state: ProfilerState, context: ProfilerContext, record: ProfilerEntry) {
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

# Entering a call to the function identified by key (a code object or a
# PyMethodDef address). Entering a generator through throw() can arrive with
# an exception set, which must survive the bookkeeping.
def:priv ptrace_enter_call(state: ProfilerState, key: int, user_obj: ptr[PyObject]) {
    exception = PyErr_GetRaisedException();
    record = get_entry(state, key);
    if record is None {
        record = new_entry(state, key, user_obj);
    }
    if record is not None {
        # Take a context from the free list.
        context = state.free_contexts.pop()
            if state.free_contexts
            else ProfilerContext();
        init_context(state, context, record);
    }
    PyErr_SetRaisedException(exception);
}

def:priv ptrace_leave_call(state: ProfilerState, key: int) {
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
    # Return the context to the free list.
    context.previous = None;
    context.ctx_entry = None;
    state.free_contexts.append(context);
}

def:priv pending_exception(state: ProfilerState) -> bool {
    if state.flags & POF_NOMEMORY {
        state.flags -= POF_NOMEMORY;
        object_error(PyExc_MemoryError, "memory was exhausted while profiling");
        return True;
    }
    return False;
}

def:priv flush_unmatched(state: ProfilerState) {
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

# A profiler_entry or profiler_subentry row; the items are new references,
# consumed even when the row cannot be built.
def:priv stats_row(type: ptr[PyObject], items: list[ptr[PyObject]]) -> ptr[PyObject] {
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

def:priv stats_for_entry(
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

def _lsprof_Profiler_getstats_impl(
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

def:priv set_subcalls(state: ProfilerState, value: bool) {
    if value {
        state.flags |= POF_SUBCALLS;
    } else {
        state.flags &= ~POF_SUBCALLS;
    }
}

def:priv set_builtins(state: ProfilerState, value: bool) {
    if value {
        state.flags |= POF_BUILTINS;
    } else {
        state.flags &= ~POF_BUILTINS;
    }
}

def _lsprof_Profiler__pystart_callback_impl(
    receiver: ptr[PyObject], code: ptr[PyObject], instruction_offset: ptr[PyObject]
) -> ptr[PyObject] {
    state = profiler_of(receiver);
    if state is None {
        return NULL;
    }
    ptrace_enter_call(state, int(code), code);
    return Py_NewRef(borrowed_none());
}

def _lsprof_Profiler__pythrow_callback_impl(
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

def _lsprof_Profiler__pyreturn_callback_impl(
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

# get_cfunc_from_callable(): the built-in function a C call event reports, as
# a new reference, or NULL (no exception) when it is not one.
def:priv get_cfunc_from_callable(
    callable: ptr[PyObject], self_arg: ptr[PyObject], missing: ptr[PyObject]
) -> ptr[PyObject] {
    if is_cfunction(callable) {
        return Py_NewRef(callable);
    }
    if Py_TYPE(callable) == addressof(PyMethodDescr_Type) {
        # For backwards compatibility a method descriptor is reported as the
        # built-in method it binds; skip it when there is no argument.
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

def _lsprof_Profiler__ccall_callback_impl(
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

def _lsprof_Profiler__creturn_callback_impl(
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

# Register every callback of CALLBACK_TABLE with sys.monitoring and set the
# events; False with the exception set on failure.
def:priv register_callbacks(
    receiver: ptr[PyObject], state: ProfilerState, monitoring: ptr[PyObject]
) -> bool {
    check = call_method(
        monitoring,
        "use_tool_id",
        [PyLong_FromLong(i64(state.tool_id)), PyUnicode_FromString("cProfile")]
    );
    if not check {
        object_error(PyExc_ValueError, "Another profiling tool is already active");
        return False;
    }
    jacpy_release(check);
    all_events = 0;
    for (event, name) in CALLBACK_TABLE {
        callback = PyObject_GetAttrString(receiver, name);
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

def _lsprof_Profiler_enable_impl(
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

# Unregister the callbacks, clear the events and free the tool id.
def:priv unregister_callbacks(state: ProfilerState, monitoring: ptr[PyObject]) -> bool {
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

def _lsprof_Profiler_disable_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
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

def _lsprof_Profiler_clear_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
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

def profiler_init_impl(
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
    missing = PyObject_GetAttrString(monitoring, "MISSING");
    jacpy_release(monitoring);
    if not missing {
        return i32(-1);
    }
    previous = state.missing;
    state.missing = missing;
    jacpy_release(previous);
    return i32(0);
}
