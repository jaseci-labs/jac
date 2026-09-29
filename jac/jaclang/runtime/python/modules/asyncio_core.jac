"""The object layouts, module state and Future machinery of the native
_asyncio module.

Derived from CPython 3.14.6 Modules/_asynciomodule.c; see ../LICENSE.cpython.
A Future or Task is the C module's FutureObj or TaskObj in place: the same
fields at the same offsets, the flag bitfields being the byte at
FUT_BITS_OFFSET (object_api.c asserts the layout against the C structs), so
profilers that read a task through Py_AsyncioModuleDebugOffsets see a Jac
task as they see a C one. The running loop and task of a thread and the
task lists live in the thread and interpreter states, reached through
object_api.c helpers. The module state is the binding layer's reference
slots, indexed by the STATE_* constants, with the task name counter as
native state. The free-threaded build's critical sections and
stop-the-world pauses have no counterpart: every JacPython build has a GIL.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyCoro_Type,
    PyErr_Format,
    PyErr_GivenExceptionMatches,
    PyErr_SetObject,
    PyErr_SetString,
    PyException_GetTraceback,
    PyException_SetCause,
    PyException_SetContext,
    PyException_SetTraceback,
    PyExc_BaseException,
    PyExc_RuntimeError,
    PyExc_StopIteration,
    PyExc_TypeError,
    PyList_Append,
    PyList_GetItem,
    PyList_New,
    PyList_SetItem,
    PyList_Size,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_CallMethodObjArgs,
    PyObject_CallNoArgs,
    PyObject_CallOneArg,
    PyObject_GetAttr,
    PyObject_GetOptionalAttr,
    PyObject_IsTrue,
    PyObject_VectorcallMethod,
    PySet_Add,
    PySet_Contains,
    PySet_Discard,
    PySet_New,
    PySet_Size,
    PyTuple_GetItem,
    PyTuple_New,
    PyType_IsSubtype,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    _Py_IsInterpreterFinalizing,
    PyInterpreterState_Get,
    jacpy_asyncio_running_loop,
    jacpy_asyncio_running_task,
    jacpy_asyncio_tasks_head,
    jacpy_is_type,
    jacpy_release,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.layouts { _object }
import from jaclang.runtime.python.object_model.bool { py_false, py_true }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_module_native_get,
    jacpy_binding_module_native_present,
    jacpy_binding_state_get
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.type { jacpy_binding_owner }

import from c {
    # FutureObj: FutureObj_HEAD(fut).
    obj FutureObj {
        has ob_base: _object,
            fut_loop: ptr[PyObject],
            fut_callback0: ptr[PyObject],
            fut_context0: ptr[PyObject],
            fut_callbacks: ptr[PyObject],
            fut_exception: ptr[PyObject],
            fut_exception_tb: ptr[PyObject],
            fut_result: ptr[PyObject],
            fut_source_tb: ptr[PyObject],
            fut_cancel_msg: ptr[PyObject],
            fut_cancelled_exc: ptr[PyObject],
            fut_awaited_by: ptr[PyObject],
            fut_state: i32,
            fut_is_task: i8,
            fut_awaited_by_is_set: i8,
            # The unsigned bitfields fut_log_tb, fut_blocking and TaskObj's
            # task_must_cancel and task_log_destroy_pending share this byte.
            fut_bits: u8,
            fut_bits_pad: u8;
    }
    # TaskObj: FutureObj_HEAD(task) and the task fields; task_node is the
    # struct llist_node {next, prev} of the task lists.
    obj TaskObj {
        has base: FutureObj,
            task_num_cancels_requested: i32,
            task_fut_waiter: ptr[PyObject],
            task_coro: ptr[PyObject],
            task_name: ptr[PyObject],
            task_context: ptr[PyObject],
            task_node_next: ptr,
            task_node_prev: ptr;
    }  obj TaskStepMethWrapper {
        has ob_base: _object,
            sw_task: ptr[PyObject],
            sw_arg: ptr[PyObject];
    }  obj FutureIterObject {
        has ob_base: _object,
            future: ptr[PyObject];
    }  obj LlistNode {
        has next: ptr,
            prev: ptr;
    }
    # A vectorcall argument array with room for PY_VECTORCALL_ARGUMENTS_OFFSET.
    obj CallStack {
        has slot0: ptr[PyObject],
            slot1: ptr[PyObject],
            slot2: ptr[PyObject],
            slot3: ptr[PyObject],
            slot4: ptr[PyObject];
    }
}

# The sizes and offsets object_api.c asserts against the C structs.
glob FUTURE_OBJECT_SIZE: Final[int] = 112,
     TASK_OBJECT_SIZE: Final[int] = 168,
     TASK_STEP_WRAPPER_SIZE: Final[int] = 32,
     FUTURE_ITER_SIZE: Final[int] = 24,
     TASK_NODE_OFFSET: Final[int] = 152;

# fut_state
glob STATE_PENDING: Final[int] = 0,
     STATE_CANCELLED: Final[int] = 1,
     STATE_FINISHED: Final[int] = 2;

# The bits of fut_bits.
glob BIT_LOG_TB: Final[int] = 1,
     BIT_BLOCKING: Final[int] = 2,
     BIT_MUST_CANCEL: Final[int] = 4,
     BIT_LOG_DESTROY_PENDING: Final[int] = 8;

# PY_VECTORCALL_ARGUMENTS_OFFSET
glob ARGUMENTS_OFFSET: Final[u64] = 0x8000000000000000;

# The module state slots.
glob STATE_FUTURE_ITER_TYPE: Final[int] = 0,
     STATE_TASK_STEP_WRAPPER_TYPE: Final[int] = 1,
     STATE_FUTURE_TYPE: Final[int] = 2,
     STATE_TASK_TYPE: Final[int] = 3,
     STATE_ASYNCIO_MOD: Final[int] = 4,
     STATE_CONTEXT_KWNAME: Final[int] = 5,
     STATE_NON_ASYNCIO_TASKS: Final[int] = 6,
     STATE_NON_ASYNCIO_EAGER_TASKS: Final[int] = 7,
     STATE_ISCOROUTINE_TYPECACHE: Final[int] = 8,
     STATE_GET_EVENT_LOOP_POLICY: Final[int] = 9,
     STATE_FUTURE_REPR_FUNC: Final[int] = 10,
     STATE_CANCELLED_ERROR: Final[int] = 11,
     STATE_INVALID_STATE_ERROR: Final[int] = 12,
     STATE_TASK_GET_STACK_FUNC: Final[int] = 13,
     STATE_TASK_PRINT_STACK_FUNC: Final[int] = 14,
     STATE_TASK_REPR_FUNC: Final[int] = 15,
     STATE_ISCOROUTINE_FUNC: Final[int] = 16,
     STATE_TRACEBACK_EXTRACT_STACK: Final[int] = 17,
     STATE_COUNT: Final[int] = 18;

# The ModuleDefinition handle of _asyncio, set when the module executes, for
# PyType_GetModuleByDef().
obj ModuleToken {
    has handle: ptr = ptr();
}

glob asyncio_module_token: ModuleToken = ModuleToken();

"""The module state that is not a reference: the task name counter."""
obj AsyncioState(NativeState) {
    has task_name_counter: int = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

"""The interned identifiers the C module names with _Py_ID(); interned once
per process, like the runtime's static strings."""
obj Identifiers {
    has ready: bool = False,
        call_soon: ptr[PyObject] = NULL,
        get_debug: ptr[PyObject] = NULL,
        get_event_loop: ptr[PyObject] = NULL,
        get_loop: ptr[PyObject] = NULL,
        loop_attr: ptr[PyObject] = NULL,
        cancel: ptr[PyObject] = NULL,
        throw: ptr[PyObject] = NULL,
        asyncio_future_blocking: ptr[PyObject] = NULL,
        add_done_callback: ptr[PyObject] = NULL,
        is_running: ptr[PyObject] = NULL,
        add: ptr[PyObject] = NULL,
        discard: ptr[PyObject] = NULL,
        done: ptr[PyObject] = NULL,
        call_exception_handler: ptr[PyObject] = NULL,
        message: ptr[PyObject] = NULL,
        exception: ptr[PyObject] = NULL,
        future: ptr[PyObject] = NULL,
        source_traceback: ptr[PyObject] = NULL,
        task: ptr[PyObject] = NULL,
        pending: ptr[PyObject] = NULL,
        cancelled: ptr[PyObject] = NULL,
        finished: ptr[PyObject] = NULL,
        result: ptr[PyObject] = NULL;
}

glob ids = Identifiers();

"""Intern the identifiers; False with the error set."""
def intern_identifiers -> bool {
    if ids.ready {
        return True;
    }
    names = [
        "call_soon",
        "get_debug",
        "get_event_loop",
        "get_loop",
        "_loop",
        "cancel",
        "throw",
        "_asyncio_future_blocking",
        "add_done_callback",
        "is_running",
        "add",
        "discard",
        "done",
        "call_exception_handler",
        "message",
        "exception",
        "future",
        "source_traceback",
        "task",
        "PENDING",
        "CANCELLED",
        "FINISHED",
        "result"
    ];
    values: list[ptr[PyObject]] = [];
    for name in names {
        value = PyUnicode_InternFromString(name);
        if not value {
            for made in values {
                jacpy_release(made);
            }
            return False;
        }
        values.append(value);
    }
    ids.call_soon = values[0];
    ids.get_debug = values[1];
    ids.get_event_loop = values[2];
    ids.get_loop = values[3];
    ids.loop_attr = values[4];
    ids.cancel = values[5];
    ids.throw = values[6];
    ids.asyncio_future_blocking = values[7];
    ids.add_done_callback = values[8];
    ids.is_running = values[9];
    ids.add = values[10];
    ids.discard = values[11];
    ids.done = values[12];
    ids.call_exception_handler = values[13];
    ids.message = values[14];
    ids.exception = values[15];
    ids.future = values[16];
    ids.source_traceback = values[17];
    ids.task = values[18];
    ids.pending = values[19];
    ids.cancelled = values[20];
    ids.finished = values[21];
    ids.result = values[22];
    ids.ready = True;
    return True;
}

# ---------------------------------------------------------------------------
# Object and state access.

def fut_of(op: ptr[PyObject]) -> ptr[FutureObj] {
    return ptr[FutureObj](op);
}

def task_of(op: ptr[PyObject]) -> ptr[TaskObj] {
    return ptr[TaskObj](op);
}

def has_bit(op: ptr[PyObject], bit: int) -> bool {
    return (int(ptr[FutureObj](op).view(1)[0].fut_bits) & bit) != 0;
}

def set_bit(op: ptr[PyObject], bit: int, value: bool) {
    record = ptr[FutureObj](op).view(1);
    bits = int(record[0].fut_bits);
    record[0].fut_bits = u8((bits | bit) if value else (bits & ~bit & 0xFF));
}

"""A reference of the module state (borrowed)."""
def state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

"""get_asyncio_state_by_def() and get_asyncio_state_by_cls(): the _asyncio
module of an object's or a class's type (borrowed)."""
def module_of_type(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, asyncio_module_token.handle);
}

def module_of(op: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(Py_TYPE(op), asyncio_module_token.handle);
}

def native_state(module: ptr[PyObject]) -> AsyncioState | None {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, AsyncioState) {
            return state;
        }
    }
    return None;
}

"""PyObject_TypeCheck()."""
def type_check(op: ptr[PyObject], type: ptr[PyObject]) -> bool {
    return Py_TYPE(op) == type or PyType_IsSubtype(Py_TYPE(op), type) != 0;
}

def future_check_exact(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    return Py_TYPE(op) == state_ref(module, STATE_FUTURE_TYPE);
}

def task_check_exact(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    return Py_TYPE(op) == state_ref(module, STATE_TASK_TYPE);
}

def task_check(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    return type_check(op, state_ref(module, STATE_TASK_TYPE));
}

"""TaskOrFuture_Check(): exact types first, then subclasses."""
def task_or_future_check(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    type = Py_TYPE(op);
    future_type = state_ref(module, STATE_FUTURE_TYPE);
    task_type = state_ref(module, STATE_TASK_TYPE);
    return type == task_type
        or type == future_type
        or PyType_IsSubtype(type, future_type) != 0
        or PyType_IsSubtype(type, task_type) != 0;
}

"""PyExceptionClass_Check()."""
def exception_class_check(op: ptr[PyObject]) -> bool {
    return jacpy_is_type(op) != 0 and PyType_IsSubtype(op, PyExc_BaseException) != 0;
}

"""PyExceptionInstance_Check()."""
def exception_instance_check(op: ptr[PyObject]) -> bool {
    return PyType_IsSubtype(Py_TYPE(op), PyExc_BaseException) != 0;
}

"""Py_XSETREF(slot, value) for a field read and written through `get`/`put`
is spelled out at each site; this releases an old reference."""
def release(value: ptr[PyObject]) {
    if value {
        jacpy_release(value);
    }
}

# ---------------------------------------------------------------------------
# The running loop and task of this thread.

def running_loop_slot -> ptr[ptr[PyObject]] {
    return jacpy_asyncio_running_loop();
}

def running_task_slot -> ptr[ptr[PyObject]] {
    return jacpy_asyncio_running_task();
}

def running_loop -> ptr[PyObject] {
    return jacpy_asyncio_running_loop().view(1)[0];
}

# ---------------------------------------------------------------------------
# Helpers of the Future machinery.

"""_is_coroutine(): asyncio.iscoroutine() for a coroutine other than a
native one, caching up to 100 positive types."""
def:priv is_coroutine_slow(module: ptr[PyObject], coro: ptr[PyObject]) -> int {
    res = PyObject_CallOneArg(state_ref(module, STATE_ISCOROUTINE_FUNC), coro);
    if not res {
        return -1;
    }
    is_res_true = int(PyObject_IsTrue(res));
    jacpy_release(res);
    if is_res_true <= 0 {
        return is_res_true;
    }
    typecache = state_ref(module, STATE_ISCOROUTINE_TYPECACHE);
    if PySet_Size(typecache) < 100 {
        # Just in case we don't want to cache more than 100 positive types.
        if PySet_Add(typecache, Py_TYPE(coro)) != 0 {
            return -1;
        }
    }
    return 1;
}

"""is_coroutine(): 1 when `coro` is a coroutine, 0 when not, -1 on error."""
def is_coroutine(module: ptr[PyObject], coro: ptr[PyObject]) -> int {
    if Py_TYPE(coro) == addressof(PyCoro_Type) {
        return 1;
    }
    # Check if type(coro) is in the cache: that makes this almost as fast as
    # the exact check for non-native coroutine-like objects.
    has_it = int(
        PySet_Contains(state_ref(module, STATE_ISCOROUTINE_TYPECACHE), Py_TYPE(coro))
    );
    if has_it == 0 {
        return is_coroutine_slow(module, coro);
    }
    return has_it;
}

"""get_future_loop(): asyncio.futures._get_loop (a new reference)."""
def get_future_loop(module: ptr[PyObject], fut: ptr[PyObject]) -> ptr[PyObject] {
    if future_check_exact(module, fut) or task_check_exact(module, fut) {
        return Py_NewRef(fut_of(fut).view(1)[0].fut_loop);
    }
    getloop = NULL;
    if PyObject_GetOptionalAttr(fut, ids.get_loop, &mut getloop) < 0 {
        return NULL;
    }
    if getloop {
        res = PyObject_CallNoArgs(getloop);
        jacpy_release(getloop);
        return res;
    }
    return PyObject_GetAttr(fut, ids.loop_attr);
}

"""get_event_loop(): the running loop, else the policy's loop."""
def get_event_loop(module: ptr[PyObject]) -> ptr[PyObject] {
    loop = running_loop();
    if loop {
        return Py_NewRef(loop);
    }
    policy = PyObject_CallNoArgs(state_ref(module, STATE_GET_EVENT_LOOP_POLICY));
    if not policy {
        return NULL;
    }
    loop = PyObject_CallMethodObjArgs(policy, ids.get_event_loop, NULL);
    jacpy_release(policy);
    return loop;
}

"""call_soon(): loop.call_soon(func[, arg][, context=ctx]); -1 on error."""
def call_soon(
    module: ptr[PyObject],
    loop: ptr[PyObject],
    func: ptr[PyObject],
    arg: ptr[PyObject],
    ctx: ptr[PyObject]
) -> int {
    stack = CallStack(slot0=NULL, slot1=loop, slot2=func, slot3=arg, slot4=ctx);
    args = ptr[ptr[PyObject]](ptr(&mut stack)) + 1;
    handle = NULL;
    if not ctx {
        handle = PyObject_VectorcallMethod(
            ids.call_soon, args, u64(3) | ARGUMENTS_OFFSET, NULL
        );
    } else {
        # All references on the stack are borrowed.
        nargs = 2;
        if arg {
            nargs = 3;
        } else {
            stack.slot3 = ctx;
        }
        handle = PyObject_VectorcallMethod(
            ids.call_soon,
            args,
            u64(nargs) | ARGUMENTS_OFFSET,
            state_ref(module, STATE_CONTEXT_KWNAME)
        );
    }
    if not handle {
        return -1;
    }
    jacpy_release(handle);
    return 0;
}

def future_is_alive(op: ptr[PyObject]) -> bool {
    return bool(fut_of(op).view(1)[0].fut_loop);
}

"""future_ensure_alive(): -1 with RuntimeError for an uninitialized future."""
def future_ensure_alive(op: ptr[PyObject]) -> int {
    if not future_is_alive(op) {
        PyErr_SetString(PyExc_RuntimeError, "Future object is not initialized.");
        return -1;
    }
    return 0;
}

# ---------------------------------------------------------------------------
# The task lists.

"""register_task(): link the task into this thread's list."""
def register_task(op: ptr[PyObject]) {
    record = task_of(op).view(1);
    if record[0].task_node_next {
        # Already registered.
        return;
    }
    head = ptr[LlistNode](jacpy_asyncio_tasks_head());
    link = ptr(op) + TASK_NODE_OFFSET;
    last = head.view(1)[0].prev;
    record[0].task_node_prev = last;
    record[0].task_node_next = ptr(head);
    ptr[LlistNode](last).view(1)[0].next = link;
    head.view(1)[0].prev = link;
}

"""unregister_task(): unlink a registered task."""
def unregister_task(op: ptr[PyObject]) {
    record = task_of(op).view(1);
    next = record[0].task_node_next;
    if not next {
        # Not registered.
        return;
    }
    prev = record[0].task_node_prev;
    ptr[LlistNode](prev).view(1)[0].next = next;
    ptr[LlistNode](next).view(1)[0].prev = prev;
    record[0].task_node_prev = ptr();
    record[0].task_node_next = ptr();
}

"""enter_task(): -1 with RuntimeError when `loop` is not running here or
another task is."""
def enter_task(loop: ptr[PyObject], task: ptr[PyObject]) -> int {
    if running_loop() != loop {
        PyErr_Format(PyExc_RuntimeError, "loop %R is not the running loop", loop);
        return -1;
    }
    slot = running_task_slot().view(1);
    if slot[0] {
        PyErr_Format(
            PyExc_RuntimeError,
            "Cannot enter into task %R while another task %R is being executed.",
            task,
            slot[0]
        );
        return -1;
    }
    slot[0] = Py_NewRef(task);
    return 0;
}

"""leave_task()."""
def leave_task(loop: ptr[PyObject], task: ptr[PyObject]) -> int {
    if running_loop() != loop {
        PyErr_Format(PyExc_RuntimeError, "loop %R is not the running loop", loop);
        return -1;
    }
    slot = running_task_slot().view(1);
    if slot[0] != task {
        PyErr_Format(
            PyExc_RuntimeError,
            "Invalid attempt to leave task %R while task %R is entered.",
            task,
            slot[0] if slot[0] else Py_None
        );
        return -1;
    }
    current = slot[0];
    slot[0] = NULL;
    jacpy_release(current);
    return 0;
}

"""swap_current_task(): install `task` (None for none) and return the
previous task, or None (a new reference)."""
def swap_current_task(loop: ptr[PyObject], task: ptr[PyObject]) -> ptr[PyObject] {
    if running_loop() != loop {
        PyErr_Format(PyExc_RuntimeError, "loop %R is not the running loop", loop);
        return NULL;
    }
    slot = running_task_slot().view(1);
    # Transfer ownership to avoid redundant reference counting.
    prev_task = slot[0];
    slot[0] = Py_NewRef(task) if task != Py_None else NULL;
    if not prev_task {
        return Py_NewRef(Py_None);
    }
    return prev_task;
}

# ---------------------------------------------------------------------------
# The Future machinery.

"""future_schedule_callbacks(): schedule every callback of a done future."""
def future_schedule_callbacks(module: ptr[PyObject], op: ptr[PyObject]) -> int {
    if task_check(module, op) {
        # Remove the task from the linked list of tasks, as it is finished.
        unregister_task(op);
    }
    record = fut_of(op).view(1);
    if record[0].fut_callback0 {
        # There's a first callback. Transfer its ownership so that an evil
        # call_soon cannot alter fut_callback0 or fut_context0.
        fut_callback0 = record[0].fut_callback0;
        record[0].fut_callback0 = NULL;
        fut_context0 = record[0].fut_context0;
        record[0].fut_context0 = NULL;
        ret = call_soon(module, record[0].fut_loop, fut_callback0, op, fut_context0);
        release(fut_callback0);
        release(fut_context0);
        if ret != 0 {
            # If an error occurs in the pure-Python implementation, all
            # callbacks are cleared.
            callbacks = record[0].fut_callbacks;
            record[0].fut_callbacks = NULL;
            release(callbacks);
            return ret;
        }
    }
    if not record[0].fut_callbacks {
        # No more callbacks.
        return 0;
    }
    # Transfer the ownership of the callbacks list so that external code
    # cannot mutate it during the iteration.
    callbacks = record[0].fut_callbacks;
    record[0].fut_callbacks = NULL;
    n = PyList_Size(callbacks);
    for i in range(int(n)) {
        cb_tup = PyList_GetItem(callbacks, i64(i));
        cb = PyTuple_GetItem(cb_tup, 0);
        ctx = PyTuple_GetItem(cb_tup, 1);
        if call_soon(module, record[0].fut_loop, cb, op, ctx) != 0 {
            jacpy_release(callbacks);
            return -1;
        }
    }
    jacpy_release(callbacks);
    return 0;
}

"""Clear every reference field of a FutureObj (FutureObj_clear()'s fields)."""
def clear_future_fields(op: ptr[PyObject]) {
    record = fut_of(op).view(1);
    for index in range(11) {
        slot = ptr[ptr[PyObject]](ptr(op) + 16 + 8 * index).view(1);
        value = slot[0];
        if value {
            slot[0] = NULL;
            jacpy_release(value);
        }
    }
}

"""future_init()."""
def future_init(op: ptr[PyObject], loop: ptr[PyObject]) -> int {
    clear_future_fields(op);
    record = fut_of(op).view(1);
    record[0].fut_state = i32(STATE_PENDING);
    set_bit(op, BIT_LOG_TB, False);
    set_bit(op, BIT_BLOCKING, False);
    record[0].fut_awaited_by_is_set = i8(0);
    record[0].fut_is_task = i8(0);
    if loop == Py_None {
        loop = get_event_loop(module_of(op));
        if not loop {
            return -1;
        }
    } else {
        loop = Py_NewRef(loop);
    }
    record[0].fut_loop = loop;
    res = PyObject_CallMethodObjArgs(loop, ids.get_debug, NULL);
    if not res {
        return -1;
    }
    is_true = int(PyObject_IsTrue(res));
    jacpy_release(res);
    if is_true < 0 {
        return -1;
    }
    if is_true and _Py_IsInterpreterFinalizing(PyInterpreterState_Get()) == 0 {
        # Only try to capture the traceback if the interpreter is not being
        # finalized: a Future created in a __del__ during shutdown finds the
        # traceback module unloaded.
        source_tb = PyObject_CallNoArgs(
            state_ref(module_of(op), STATE_TRACEBACK_EXTRACT_STACK)
        );
        record[0].fut_source_tb = source_tb;
        if not source_tb {
            return -1;
        }
    }
    return 0;
}

"""future_awaited_by_add(): record that `thing` awaits the future; a single
awaiter is kept alone, more in a set."""
def future_awaited_by_add(op: ptr[PyObject], thing: ptr[PyObject]) -> int {
    record = fut_of(op).view(1);
    if not record[0].fut_awaited_by {
        record[0].fut_awaited_by = Py_NewRef(thing);
        return 0;
    }
    if record[0].fut_awaited_by_is_set {
        return int(PySet_Add(record[0].fut_awaited_by, thing));
    }
    collected = PySet_New(NULL);
    if not collected {
        return -1;
    }
    if PySet_Add(collected, thing) != 0
        or PySet_Add(collected, record[0].fut_awaited_by) != 0 {
        jacpy_release(collected);
        return -1;
    }
    previous = record[0].fut_awaited_by;
    record[0].fut_awaited_by = collected;
    jacpy_release(previous);
    record[0].fut_awaited_by_is_set = i8(1);
    return 0;
}

"""future_awaited_by_discard(): as set.discard(), no error when absent."""
def future_awaited_by_discard(op: ptr[PyObject], thing: ptr[PyObject]) -> int {
    record = fut_of(op).view(1);
    awaited_by = record[0].fut_awaited_by;
    if not awaited_by {
        return 0;
    }
    if awaited_by == thing {
        record[0].fut_awaited_by = NULL;
        jacpy_release(awaited_by);
        return 0;
    }
    if record[0].fut_awaited_by_is_set {
        if PySet_Discard(awaited_by, thing) < 0 {
            return -1;
        }
    }
    return 0;
}

"""future_set_result()."""
def future_set_result(
    module: ptr[PyObject], op: ptr[PyObject], res: ptr[PyObject]
) -> ptr[PyObject] {
    if future_ensure_alive(op) != 0 {
        return NULL;
    }
    record = fut_of(op).view(1);
    if int(record[0].fut_state) != STATE_PENDING {
        PyErr_SetString(state_ref(module, STATE_INVALID_STATE_ERROR), "invalid state");
        return NULL;
    }
    record[0].fut_result = Py_NewRef(res);
    record[0].fut_state = i32(STATE_FINISHED);
    if future_schedule_callbacks(module, op) == -1 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

"""future_set_exception()."""
def future_set_exception(
    module: ptr[PyObject], op: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    record = fut_of(op).view(1);
    invalid_state = state_ref(module, STATE_INVALID_STATE_ERROR);
    if int(record[0].fut_state) != STATE_PENDING {
        PyErr_SetString(invalid_state, "invalid state");
        return NULL;
    }
    exc_val = NULL;
    if exception_class_check(exc) {
        exc_val = PyObject_CallNoArgs(exc);
        if not exc_val {
            return NULL;
        }
        if int(record[0].fut_state) != STATE_PENDING {
            jacpy_release(exc_val);
            PyErr_SetString(invalid_state, "invalid state");
            return NULL;
        }
    } else {
        exc_val = Py_NewRef(exc);
    }
    if not exception_instance_check(exc_val) {
        jacpy_release(exc_val);
        PyErr_SetString(PyExc_TypeError, "invalid exception object");
        return NULL;
    }
    if PyErr_GivenExceptionMatches(exc_val, PyExc_StopIteration) != 0 {
        message = PyUnicode_FromString(
            "StopIteration interacts badly with generators and cannot be raised into a Future"
        );
        if not message {
            jacpy_release(exc_val);
            return NULL;
        }
        err = PyObject_CallOneArg(PyExc_RuntimeError, message);
        jacpy_release(message);
        if not err {
            jacpy_release(exc_val);
            return NULL;
        }
        PyException_SetCause(err, Py_NewRef(exc_val));
        PyException_SetContext(err, Py_NewRef(exc_val));
        jacpy_release(exc_val);
        exc_val = err;
    }
    record[0].fut_exception = exc_val;
    record[0].fut_exception_tb = PyException_GetTraceback(exc_val);
    record[0].fut_state = i32(STATE_FINISHED);
    if future_schedule_callbacks(module, op) == -1 {
        return NULL;
    }
    set_bit(op, BIT_LOG_TB, True);
    return Py_NewRef(Py_None);
}

"""create_cancelled_error(): the stored CancelledError, else a new one with
the cancel message (a new reference)."""
def create_cancelled_error(module: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject] {
    record = fut_of(op).view(1);
    if record[0].fut_cancelled_exc {
        # Transfer ownership.
        exc = record[0].fut_cancelled_exc;
        record[0].fut_cancelled_exc = NULL;
        return exc;
    }
    msg = record[0].fut_cancel_msg;
    cancelled_error = state_ref(module, STATE_CANCELLED_ERROR);
    if not msg or msg == Py_None {
        return PyObject_CallNoArgs(cancelled_error);
    }
    return PyObject_CallOneArg(cancelled_error, msg);
}

"""future_set_cancelled_error()."""
def future_set_cancelled_error(module: ptr[PyObject], op: ptr[PyObject]) {
    exc = create_cancelled_error(module, op);
    if not exc {
        return;
    }
    PyErr_SetObject(state_ref(module, STATE_CANCELLED_ERROR), exc);
    jacpy_release(exc);
}

"""future_get_result(): (0, result) or (1, exception) with a new reference,
(-1, NULL) with the error set."""
def future_get_result(
    module: ptr[PyObject], op: ptr[PyObject]
) -> tuple[int, ptr[PyObject]] {
    record = fut_of(op).view(1);
    state = int(record[0].fut_state);
    if state == STATE_CANCELLED {
        future_set_cancelled_error(module, op);
        return (-1, NULL);
    }
    if state != STATE_FINISHED {
        PyErr_SetString(
            state_ref(module, STATE_INVALID_STATE_ERROR), "Result is not set."
        );
        return (-1, NULL);
    }
    set_bit(op, BIT_LOG_TB, False);
    if record[0].fut_exception {
        tb = record[0].fut_exception_tb;
        if not tb {
            tb = Py_None;
        }
        if PyException_SetTraceback(record[0].fut_exception, tb) < 0 {
            return (-1, NULL);
        }
        result = Py_NewRef(record[0].fut_exception);
        exception_tb = record[0].fut_exception_tb;
        record[0].fut_exception_tb = NULL;
        release(exception_tb);
        return (1, result);
    }
    return (0, Py_NewRef(record[0].fut_result));
}

"""future_add_done_callback(): schedule `arg` now for a done future, else
keep it (the first in fut_callback0, the rest in fut_callbacks)."""
def future_add_done_callback(
    module: ptr[PyObject], op: ptr[PyObject], arg: ptr[PyObject], ctx: ptr[PyObject]
) -> ptr[PyObject] {
    if not future_is_alive(op) {
        PyErr_SetString(PyExc_RuntimeError, "uninitialized Future object");
        return NULL;
    }
    record = fut_of(op).view(1);
    if int(record[0].fut_state) != STATE_PENDING {
        # The future is done or cancelled: schedule the callback right away.
        if call_soon(module, record[0].fut_loop, arg, op, ctx) != 0 {
            return NULL;
        }
    } elif not record[0].fut_callbacks and not record[0].fut_callback0 {
        # The first callback.
        record[0].fut_callback0 = Py_NewRef(arg);
        record[0].fut_context0 = Py_NewRef(ctx);
    } else {
        tup = PyTuple_New(2);
        if not tup {
            return NULL;
        }
        jacpy_tuple_set_owned(tup, 0, Py_NewRef(arg));
        jacpy_tuple_set_owned(tup, 1, Py_NewRef(ctx));
        if record[0].fut_callbacks {
            err = PyList_Append(record[0].fut_callbacks, tup);
            jacpy_release(tup);
            if err != 0 {
                return NULL;
            }
        } else {
            callbacks = PyList_New(1);
            if not callbacks {
                jacpy_release(tup);
                return NULL;
            }
            PyList_SetItem(callbacks, 0, tup);
            record[0].fut_callbacks = callbacks;
        }
    }
    return Py_NewRef(Py_None);
}

"""future_cancel()."""
def future_cancel(
    module: ptr[PyObject], op: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    set_bit(op, BIT_LOG_TB, False);
    record = fut_of(op).view(1);
    if int(record[0].fut_state) != STATE_PENDING {
        return Py_NewRef(py_false());
    }
    record[0].fut_state = i32(STATE_CANCELLED);
    previous = record[0].fut_cancel_msg;
    record[0].fut_cancel_msg = Py_NewRef(msg) if msg else NULL;
    release(previous);
    if future_schedule_callbacks(module, op) == -1 {
        return NULL;
    }
    return Py_NewRef(py_true());
}
