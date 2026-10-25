import from c {
    def PyModule_GetState(m: ptr[PyObject]) -> ptr;  def PyInterpreterState_GetID(
        interp: ptr[u8]
    ) -> i64;  def PyUnstable_AtExit(interp: ptr[u8], func: ptr, data: ptr) -> i32;  def _Py_FatalErrorFunc(
        func: ptr[u8], message: ptr[u8]
    );  def _PyXIData_New -> ptr[_PyXIData_t];  def _PyXIData_Init(
        xidata: ptr[_PyXIData_t],
        interp: ptr[u8],
        shared: ptr,
        obj_: ptr[PyObject],
        new_object: ptr
    );  def _PyObject_GetXIData(
        tstate: ptr[PyThreadState],
        obj_: ptr[PyObject],
        fallback: i32,
        xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyXIData_NewObject(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];  def _PyXIData_Release(
        xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyXIData_ReleaseAndRawFree(xidata: ptr[_PyXIData_t]) -> i32;  def jacpy_stack_address(
        slots: &mut qidarg_converter_data
    ) -> int;  obj qidarg_converter_data {
        has label: ptr[u8] = ptr[u8](),
            id: i64 = 0;
    }  obj QueuesModuleState {
        has queue_type: ptr[PyTypeObject],
            QueueError: ptr[PyObject],
            QueueNotFoundError: ptr[PyObject],
            QueueEmpty: ptr[PyObject],
            QueueFull: ptr[PyObject];
    }  obj _queueitem {
        has interpid: i64,
            data: ptr[_PyXIData_t],
            unboundop: i32,
            next: ptr[_queueitem];
    }  obj _queue {
        has num_waiters: i64,
            mutex: ptr,
            alive: i32,
            items_maxsize: i64,
            items_count: i64,
            items_first: ptr[_queueitem],
            items_last: ptr[_queueitem],
            defaults_fallback: i32,
            defaults_unboundop: i32;
    }  obj _queueref {
        has next: ptr[_queueref],
            qid: i64,
            refcount: i64,
            queue: ptr[_queue];
    }  obj _queues {
        has mutex: ptr,
            head: ptr[_queueref],
            count: i64,
            next_id: i64;
    }  obj queue_id_and_info {
        has id: i64,
            defaults_fallback: i32,
            defaults_unboundop: i32;
    }  obj _queueid_xid {
        has qid: i64;
    }  obj QueuesGlobals {
        has mutex: u8,
            module_count: i32,
            queues: _queues;
    }  obj QueuesModuleDef {
        has m_base: PyModuleDef_Base,
            m_name: ptr[u8],
            m_doc: ptr[u8],
            m_size: i64,
            m_methods: ptr[PyMethodDef],
            m_slots: ptr[PyModuleDef_Slot],
            m_traverse: ptr,
            m_clear: ptr,
            m_free: ptr;
    }  glob:priv _globals: QueuesGlobals = QueuesGlobals();
}

glob:priv XID_IGNORE_EXC: Final[i32] = 1,
     XID_FREE: Final[i32] = 2,
     ERR_EXCEPTION_RAISED: Final[i32] = -1,
     ERR_QUEUES_ALLOC: Final[i32] = -11,
     ERR_QUEUE_ALLOC: Final[i32] = -12,
     ERR_NO_NEXT_QUEUE_ID: Final[i32] = -13,
     ERR_QUEUE_NOT_FOUND: Final[i32] = -14,
     ERR_QUEUE_EMPTY: Final[i32] = -21,
     ERR_QUEUE_FULL: Final[i32] = -22,
     ERR_QUEUE_NEVER_BOUND: Final[i32] = -23,
     WAIT_LOCK: Final[i32] = 1,
     PY_SSIZE_T_MAX_VALUE: Final[i64] = 9223372036854775807,
     INT64_MAX_VALUE: Final[i64] = 9223372036854775807,
     QUEUEITEM_SIZE: Final[u64] = 32,
     QUEUE_SIZE: Final[u64] = 64,
     QUEUEREF_SIZE: Final[u64] = 32,
     QUEUE_ID_AND_INFO_SIZE: Final[i64] = 16,
     QUEUEID_XID_SIZE: Final[u64] = 8,
     GLOBALS_QUEUES: Final[i64] = 8;

def _release_xid_data(data: ptr[_PyXIData_t], flags: i32) -> i32;

def _get_current_interp -> ptr[u8];

def _get_current_module -> ptr[PyObject];

def idarg_int64_converter(arg: ptr[PyObject], p: ptr) -> i32;

def ensure_highlevel_module_loaded -> i32;

def get_module_state(mod: ptr[PyObject]) -> ptr[QueuesModuleState];

def traverse_module_state(
    state: ptr[QueuesModuleState], visitor: ptr, arg: ptr
) -> i32;

def clear_module_state(state: ptr[QueuesModuleState]) -> i32;

def resolve_module_errcode(
    state: ptr[QueuesModuleState], errcode: i32, qid: i64
) -> tuple[i32, ptr[PyObject], ptr[PyObject]];

def add_exctype(
    mod: ptr[PyObject], qualname: ptr[u8], doc: ptr[u8], base: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def add_QueueError(mod: ptr[PyObject]) -> i32;

def set_external_exc_types(
    state: ptr[QueuesModuleState], emptyerror: ptr[PyObject], fullerror: ptr[PyObject]
) -> i32;

def ensure_external_exc_types(state: ptr[QueuesModuleState]) -> i32;

def handle_queue_error(err: i32, mod: ptr[PyObject], qid: i64) -> i32;

def _queueitem_init(
    item: ptr[_queueitem], interpid: i64, data: ptr[_PyXIData_t], unboundop: i32
);

def _queueitem_clear_data(item: ptr[_queueitem]);

def _queueitem_clear(item: ptr[_queueitem]);

def _queueitem_new(
    interpid: i64, data: ptr[_PyXIData_t], unboundop: i32
) -> ptr[_queueitem];

def _queueitem_free(item: ptr[_queueitem]);

def _queueitem_free_all(item: ptr[_queueitem]);

def _queueitem_popped(item: ptr[_queueitem]) -> tuple[ptr[_PyXIData_t], i32];

def _queueitem_clear_interpreter(item: ptr[_queueitem]) -> i32;

def _queue_init(
    queue: ptr[_queue], maxsize: i64, defaults_fallback: i32, defaults_unboundop: i32
) -> i32;

def _queue_clear(queue: ptr[_queue]);

def _queue_free(queue: ptr[_queue]);

def _queue_kill_and_wait(queue: ptr[_queue]);

def _queue_mark_waiter(queue: ptr[_queue], parent_mutex: ptr);

def _queue_unmark_waiter(queue: ptr[_queue], parent_mutex: ptr);

def _queue_lock(queue: ptr[_queue]) -> i32;

def _queue_unlock(queue: ptr[_queue]);

def _queue_add(
    queue: ptr[_queue], interpid: i64, data: ptr[_PyXIData_t], unboundop: i32
) -> i32;

def _queue_next(queue: ptr[_queue]) -> tuple[i32, ptr[_PyXIData_t], i32];

def _queue_get_maxsize(queue: ptr[_queue]) -> tuple[i32, i64];

def _queue_is_full(queue: ptr[_queue]) -> tuple[i32, i32];

def _queue_get_count(queue: ptr[_queue]) -> tuple[i32, i64];

def _queue_clear_interpreter(queue: ptr[_queue], interpid: i64);

def _queuerefs_find(
    first: ptr[_queueref], qid: i64
) -> tuple[ptr[_queueref], ptr[_queueref]];

def _queuerefs_clear(head: ptr[_queueref]);

def _queues_init(queues: ptr[_queues], mutex: ptr);

def _queues_fini(queues: ptr[_queues]) -> ptr;

def _queues_next_id(queues: ptr[_queues]) -> i64;

def _queues_lookup(queues: ptr[_queues], qid: i64) -> tuple[i32, ptr[_queue]];

def _queues_add(queues: ptr[_queues], queue: ptr[_queue]) -> i64;

def _queues_remove_ref(
    queues: ptr[_queues], ref: ptr[_queueref], prev: ptr[_queueref]
) -> ptr[_queue];

def _queues_remove(queues: ptr[_queues], qid: i64) -> tuple[i32, ptr[_queue]];

def _queues_incref(queues: ptr[_queues], qid: i64) -> i32;

def _queues_decref(queues: ptr[_queues], qid: i64) -> i32;

def _queues_list_all(queues: ptr[_queues]) -> tuple[ptr[queue_id_and_info], i64];

def _queues_clear_interpreter(queues: ptr[_queues], interpid: i64);

def queue_create(
    queues: ptr[_queues], maxsize: i64, defaults_fallback: i32, defaults_unboundop: i32
) -> i64;

def queue_destroy(queues: ptr[_queues], qid: i64) -> i32;

def queue_put(
    queues: ptr[_queues], qid: i64, obj_: ptr[PyObject], unboundop: i32, fallback: i32
) -> i32;

def queue_get(queues: ptr[_queues], qid: i64) -> tuple[i32, ptr[PyObject], i32];

def queue_get_defaults(queues: ptr[_queues], qid: i64) -> tuple[i32, i32, i32];

def queue_get_maxsize(queues: ptr[_queues], qid: i64) -> tuple[i32, i64];

def queue_is_full(queues: ptr[_queues], qid: i64) -> tuple[i32, i32];

def queue_get_count(queues: ptr[_queues], qid: i64) -> tuple[i32, i64];

def set_external_queue_type(
    state: ptr[QueuesModuleState], queue_type: ptr[PyTypeObject]
) -> i32;

def get_external_queue_type(module: ptr[PyObject]) -> ptr[PyTypeObject];

def _get_global_queues -> ptr[_queues];

def _queueid_xid_new(qid: i64) -> ptr;

def _queueid_xid_free(data: ptr);

def _queueobj_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject];

def _queueobj_shared(
    tstate: ptr[PyThreadState], queueobj: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32;

def _globals_init -> i32;

def _globals_fini;

def clear_interpreter(data: ptr);

def qidarg_converter(arg: ptr[PyObject], p: ptr) -> i32;

def queuesmod_create(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_destroy(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_list_all(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def queuesmod_put(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_get(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_bind(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_release(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_get_maxsize(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_get_queue_defaults(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_is_full(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod_get_count(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def queuesmod__register_heap_types(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def exception_class_check(x: ptr[PyObject]) -> bool;

def module_exec(mod: ptr[PyObject]) -> i32;

def module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def module_clear(mod: ptr[PyObject]) -> i32;

def module_free(mod: ptr);

import from c {
    glob:priv create_kwlist: list[ptr[u8]] = [
             ptr[u8]("maxsize"),
             ptr[u8]("unboundop"),
             ptr[u8]("fallback"),
             ptr[u8]()
         ],
         qid_kwlist: list[ptr[u8]] = [ptr[u8]("qid"), ptr[u8]()],
         put_kwlist: list[ptr[u8]] = [
             ptr[u8]("qid"),
             ptr[u8]("obj"),
             ptr[u8]("unboundop"),
             ptr[u8]("fallback"),
             ptr[u8]()
         ],
         register_heap_types_kwlist: list[ptr[u8]] = [
             ptr[u8]("queuetype"),
             ptr[u8]("emptyerror"),
             ptr[u8]("fullerror"),
             ptr[u8]()
         ],
         module_functions: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("create"),
                 ml_meth=ptr(queuesmod_create),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "create(maxsize, unboundop, fallback) -> qid\n\nCreate a new cross-interpreter queue and return its unique generated ID.\nIt is a new reference as though bind() had been called on the queue.\n\nThe caller is responsible for calling destroy() for the new queue\nbefore the runtime is finalized."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("destroy"),
                 ml_meth=ptr(queuesmod_destroy),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "destroy(qid)\n\nClear and destroy the queue.  Afterward attempts to use the queue\nwill behave as though it never existed."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("list_all"),
                 ml_meth=ptr(queuesmod_list_all),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "list_all() -> [(qid, unboundop, fallback)]\n\nReturn the list of IDs for all queues.\nEach corresponding default unbound op and fallback is also included."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("put"),
                 ml_meth=ptr(queuesmod_put),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]("put(qid, obj)\n\nAdd the object's data to the queue.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get"),
                 ml_meth=ptr(queuesmod_get),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get(qid) -> (obj, unboundop)\n\nReturn a new object from the data at the front of the queue.\nThe unbound op is also returned.\n\nIf there is nothing to receive then raise QueueEmpty."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("bind"),
                 ml_meth=ptr(queuesmod_bind),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "bind(qid)\n\nTake a reference to the identified queue.\nThe queue is not destroyed until there are no references left."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("release"),
                 ml_meth=ptr(queuesmod_release),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "release(qid)\n\nRelease a reference to the queue.\nThe queue is destroyed once there are no references left."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_maxsize"),
                 ml_meth=ptr(queuesmod_get_maxsize),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get_maxsize(qid)\n\nReturn the maximum number of items in the queue."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_queue_defaults"),
                 ml_meth=ptr(queuesmod_get_queue_defaults),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get_queue_defaults(qid)\n\nReturn the queue's default values, set when it was created."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_full"),
                 ml_meth=ptr(queuesmod_is_full),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "is_full(qid)\n\nReturn true if the queue has a maxsize and has reached it."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_count"),
                 ml_meth=ptr(queuesmod_get_count),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get_count(qid)\n\nReturn the number of items in the queue."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_register_heap_types"),
                 ml_meth=ptr(queuesmod__register_heap_types),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         module_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(module_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob moduledef: QueuesModuleDef = QueuesModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_interpqueues"),
             m_doc=ptr[u8](
                 "This module provides primitive operations to manage Python interpreters.\nThe 'interpreters' module provides a more convenient interface."
             ),
             m_size=40,
             m_methods=addressof(module_functions),
             m_slots=addressof(module_slots),
             m_traverse=ptr(module_traverse),
             m_clear=ptr(module_clear),
             m_free=ptr(module_free)
         );
}

impl _release_xid_data(data: ptr[_PyXIData_t], flags: i32) -> i32 {
    ignoreexc = flags & XID_IGNORE_EXC;
    exc = NULL;
    if ignoreexc != 0 {
        exc = PyErr_GetRaisedException();
    }
    res: i32 = 0;
    if (flags & XID_FREE) != 0 {
        res = _PyXIData_ReleaseAndRawFree(data);
    } else {
        res = _PyXIData_Release(data);
    }
    if res < 0 {
        if ignoreexc != 0 {
            PyErr_Clear();
        }
    }
    if ignoreexc != 0 {
        PyErr_SetRaisedException(exc);
    }
    return res;
}

impl _get_current_interp -> ptr[u8] {
    return ptr[u8](PyInterpreterState_Get());
}

impl _get_current_module -> ptr[PyObject] {
    name = PyUnicode_FromString(ptr[u8]("_interpqueues"));
    if not name {
        return NULL;
    }
    mod = PyImport_GetModule(name);
    object_decref(name);
    if not mod {
        return NULL;
    }
    return mod;
}

impl idarg_int64_converter(arg: ptr[PyObject], p: ptr) -> i32 {
    id: i64 = 0;
    data = ptr[qidarg_converter_data](p);
    label = data.view(1)[0].label;
    if not label {
        label = ptr[u8]("ID");
    }
    if PyIndex_Check(arg) != 0 {
        overflow: i32 = 0;
        id = PyLong_AsLongLongAndOverflow(arg, &mut overflow);
        if id == -1 and PyErr_Occurred() {
            return 0;
        } elif id == -1 and overflow == 1 {
            PyErr_Format(
                PyExc_OverflowError,
                ptr[u8]("max %s is %lld, got %R"),
                label,
                INT64_MAX_VALUE,
                arg
            );
            return 0;
        } elif id < 0 {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("%s must be a non-negative int, got %R"),
                label,
                arg
            );
            return 0;
        }
    } else {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%s must be an int, got %.100s"),
            label,
            object_type(arg).view(1)[0].tp_name
        );
        return 0;
    }
    data.view(1)[0].id = id;
    return 1;
}

impl ensure_highlevel_module_loaded -> i32 {
    highlevel = PyImport_ImportModule(ptr[u8]("concurrent.interpreters._queues"));
    if not highlevel {
        return -1;
    }
    object_decref(highlevel);
    return 0;
}

impl get_module_state(mod: ptr[PyObject]) -> ptr[QueuesModuleState] {
    return ptr[QueuesModuleState](PyModule_GetState(mod));
}

impl traverse_module_state(
    state: ptr[QueuesModuleState], visitor: ptr, arg: ptr
) -> i32 {
    vret = visit_reference(ptr[PyObject](state.view(1)[0].queue_type), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(state.view(1)[0].QueueError, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(state.view(1)[0].QueueNotFoundError, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(state.view(1)[0].QueueEmpty, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(state.view(1)[0].QueueFull, visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl clear_module_state(state: ptr[QueuesModuleState]) -> i32 {
    if state.view(1)[0].queue_type {
        clear_xid_class(state.view(1)[0].queue_type);
    }
    old_type = state.view(1)[0].queue_type;
    state.view(1)[0].queue_type = ptr[PyTypeObject]();
    object_xdecref(ptr[PyObject](old_type));

    old = state.view(1)[0].QueueError;
    state.view(1)[0].QueueError = NULL;
    object_xdecref(old);
    old = state.view(1)[0].QueueNotFoundError;
    state.view(1)[0].QueueNotFoundError = NULL;
    object_xdecref(old);
    old = state.view(1)[0].QueueEmpty;
    state.view(1)[0].QueueEmpty = NULL;
    object_xdecref(old);
    old = state.view(1)[0].QueueFull;
    state.view(1)[0].QueueFull = NULL;
    object_xdecref(old);
    return 0;
}

impl resolve_module_errcode(
    state: ptr[QueuesModuleState], errcode: i32, qid: i64
) -> tuple[i32, ptr[PyObject], ptr[PyObject]] {
    exctype = NULL;
    msg = NULL;
    if errcode == ERR_NO_NEXT_QUEUE_ID {
        exctype = state.view(1)[0].QueueError;
        msg = PyUnicode_FromString(ptr[u8]("ran out of queue IDs"));
    } elif errcode == ERR_QUEUE_NOT_FOUND {
        exctype = state.view(1)[0].QueueNotFoundError;
        msg = PyUnicode_FromFormat("queue %lld not found", qid);
    } elif errcode == ERR_QUEUE_EMPTY {
        if ensure_external_exc_types(state) < 0 {
            return (i32(-1), NULL, NULL);
        }
        exctype = state.view(1)[0].QueueEmpty;
        msg = PyUnicode_FromFormat("queue %lld is empty", qid);
    } elif errcode == ERR_QUEUE_FULL {
        if ensure_external_exc_types(state) < 0 {
            return (i32(-1), NULL, NULL);
        }
        exctype = state.view(1)[0].QueueFull;
        msg = PyUnicode_FromFormat("queue %lld is full", qid);
    } elif errcode == ERR_QUEUE_NEVER_BOUND {
        exctype = state.view(1)[0].QueueError;
        msg = PyUnicode_FromFormat("queue %lld never bound", qid);
    } else {
        PyErr_Format(PyExc_ValueError, ptr[u8]("unsupported error code %d"), errcode);
        return (i32(-1), NULL, NULL);
    }
    if not msg {
        return (i32(-1), NULL, NULL);
    }
    return (i32(0), exctype, msg);
}

impl add_exctype(
    mod: ptr[PyObject], qualname: ptr[u8], doc: ptr[u8], base: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    exctype = PyErr_NewExceptionWithDoc(qualname, doc, base, NULL);
    if not exctype {
        return (i32(-1), NULL);
    }
    if PyModule_AddType(mod, exctype) < 0 {
        object_decref(exctype);
        return (i32(-1), NULL);
    }
    return (i32(0), exctype);
}

impl add_QueueError(mod: ptr[PyObject]) -> i32 {
    state = get_module_state(mod);
    (status, exctype) = add_exctype(
        mod,
        ptr[u8]("concurrent.interpreters.QueueError"),
        ptr[u8]("Indicates that a queue-related error happened."),
        PyExc_RuntimeError
    );
    if status < 0 {
        return -1;
    }
    state.view(1)[0].QueueError = exctype;
    (status, exctype) = add_exctype(
        mod,
        ptr[u8]("concurrent.interpreters.QueueNotFoundError"),
        ptr[u8](),
        state.view(1)[0].QueueError
    );
    if status < 0 {
        return -1;
    }
    state.view(1)[0].QueueNotFoundError = exctype;
    state.view(1)[0].QueueEmpty = NULL;
    state.view(1)[0].QueueFull = NULL;
    return 0;
}

impl set_external_exc_types(
    state: ptr[QueuesModuleState], emptyerror: ptr[PyObject], fullerror: ptr[PyObject]
) -> i32 {
    if state.view(1)[0].QueueEmpty {
        old = state.view(1)[0].QueueEmpty;
        state.view(1)[0].QueueEmpty = NULL;
        object_xdecref(old);
        old = state.view(1)[0].QueueFull;
        state.view(1)[0].QueueFull = NULL;
        object_xdecref(old);
    }
    state.view(1)[0].QueueEmpty = object_new_ref(emptyerror);
    state.view(1)[0].QueueFull = object_new_ref(fullerror);
    return 0;
}

impl ensure_external_exc_types(state: ptr[QueuesModuleState]) -> i32 {
    if state.view(1)[0].QueueEmpty {
        return 0;
    }
    if ensure_highlevel_module_loaded() < 0 {
        return -1;
    }
    return 0;
}

impl handle_queue_error(err: i32, mod: ptr[PyObject], qid: i64) -> i32 {
    if err == 0 {
        return 0;
    }
    if err == ERR_QUEUE_ALLOC or err == ERR_QUEUES_ALLOC {
        PyErr_NoMemory();
    } elif err == -1 {
        return -1;
    } else {
        state = get_module_state(mod);
        (status, exctype, msg) = resolve_module_errcode(state, err, qid);
        if status < 0 {
            return -1;
        }
        exc = PyObject_CallOneArg(exctype, msg);
        object_decref(msg);
        if not exc {
            return -1;
        }
        PyErr_SetObject(exctype, exc);
        object_decref(exc);
    }
    return 1;
}

impl _queueitem_init(
    item: ptr[_queueitem], interpid: i64, data: ptr[_PyXIData_t], unboundop: i32
) {
    if interpid < 0 {
        interpid = get_interpid(data);
    }
    item.view(1)[0].interpid = interpid;
    item.view(1)[0].data = data;
    item.view(1)[0].unboundop = unboundop;
    item.view(1)[0].next = ptr[_queueitem]();
}

impl _queueitem_clear_data(item: ptr[_queueitem]) {
    if not item.view(1)[0].data {
        return;
    }
    _release_xid_data(item.view(1)[0].data, XID_IGNORE_EXC | XID_FREE);
    item.view(1)[0].data = ptr[_PyXIData_t]();
}

impl _queueitem_clear(item: ptr[_queueitem]) {
    item.view(1)[0].next = ptr[_queueitem]();
    _queueitem_clear_data(item);
}

impl _queueitem_new(
    interpid: i64, data: ptr[_PyXIData_t], unboundop: i32
) -> ptr[_queueitem] {
    item = ptr[_queueitem](PyMem_RawMalloc(QUEUEITEM_SIZE));
    if not item {
        PyErr_NoMemory();
        return ptr[_queueitem]();
    }
    _queueitem_init(item, interpid, data, unboundop);
    return item;
}

impl _queueitem_free(item: ptr[_queueitem]) {
    _queueitem_clear(item);
    PyMem_RawFree(ptr(item));
}

impl _queueitem_free_all(item: ptr[_queueitem]) {
    while item {
        last = item;
        item = item.view(1)[0].next;
        _queueitem_free(last);
    }
}

impl _queueitem_popped(item: ptr[_queueitem]) -> tuple[ptr[_PyXIData_t], i32] {
    data = item.view(1)[0].data;
    unboundop = item.view(1)[0].unboundop;
    item.view(1)[0].data = ptr[_PyXIData_t]();
    _queueitem_free(item);
    return (data, unboundop);
}

impl _queueitem_clear_interpreter(item: ptr[_queueitem]) -> i32 {
    if not item.view(1)[0].data {
        return 0;
    }
    unboundop = item.view(1)[0].unboundop;
    if unboundop == UNBOUND_REMOVE {
        return 1;
    } elif unboundop == UNBOUND_ERROR or unboundop == UNBOUND_REPLACE {
        _queueitem_clear_data(item);
        return 0;
    }
    _Py_FatalErrorFunc(
        ptr[u8]("_queueitem_clear_interpreter"), ptr[u8]("not reachable")
    );
    return -1;
}

impl _queue_init(
    queue: ptr[_queue], maxsize: i64, defaults_fallback: i32, defaults_unboundop: i32
) -> i32 {
    mutex = PyThread_allocate_lock();
    if not mutex {
        return ERR_QUEUE_ALLOC;
    }
    q = queue.view(1);
    q[0].num_waiters = 0;
    q[0].mutex = mutex;
    q[0].alive = 1;
    q[0].items_maxsize = maxsize;
    q[0].items_count = 0;
    q[0].items_first = ptr[_queueitem]();
    q[0].items_last = ptr[_queueitem]();
    q[0].defaults_fallback = defaults_fallback;
    q[0].defaults_unboundop = defaults_unboundop;
    return 0;
}

impl _queue_clear(queue: ptr[_queue]) {
    _queueitem_free_all(queue.view(1)[0].items_first);
    PyThread_free_lock(queue.view(1)[0].mutex);
    q = queue.view(1);
    q[0].num_waiters = 0;
    q[0].mutex = ptr();
    q[0].alive = 0;
    q[0].items_maxsize = 0;
    q[0].items_count = 0;
    q[0].items_first = ptr[_queueitem]();
    q[0].items_last = ptr[_queueitem]();
    q[0].defaults_fallback = 0;
    q[0].defaults_unboundop = 0;
}

impl _queue_free(queue: ptr[_queue]) {
    _queue_clear(queue);
    PyMem_RawFree(ptr(queue));
}

impl _queue_kill_and_wait(queue: ptr[_queue]) {
    PyThread_acquire_lock(queue.view(1)[0].mutex, WAIT_LOCK);
    queue.view(1)[0].alive = 0;
    PyThread_release_lock(queue.view(1)[0].mutex);

    while queue.view(1)[0].num_waiters > 0 {
        PyThread_acquire_lock(queue.view(1)[0].mutex, WAIT_LOCK);
        PyThread_release_lock(queue.view(1)[0].mutex);
    }
}

impl _queue_mark_waiter(queue: ptr[_queue], parent_mutex: ptr) {
    if parent_mutex {
        PyThread_acquire_lock(parent_mutex, WAIT_LOCK);
        queue.view(1)[0].num_waiters += 1;
        PyThread_release_lock(parent_mutex);
    } else {
        queue.view(1)[0].num_waiters += 1;
    }
}

impl _queue_unmark_waiter(queue: ptr[_queue], parent_mutex: ptr) {
    if parent_mutex {
        PyThread_acquire_lock(parent_mutex, WAIT_LOCK);
        queue.view(1)[0].num_waiters -= 1;
        PyThread_release_lock(parent_mutex);
    } else {
        queue.view(1)[0].num_waiters -= 1;
    }
}

impl _queue_lock(queue: ptr[_queue]) -> i32 {
    PyThread_acquire_lock(queue.view(1)[0].mutex, WAIT_LOCK);
    if queue.view(1)[0].alive == 0 {
        PyThread_release_lock(queue.view(1)[0].mutex);
        return ERR_QUEUE_NOT_FOUND;
    }
    return 0;
}

impl _queue_unlock(queue: ptr[_queue]) {
    PyThread_release_lock(queue.view(1)[0].mutex);
}

impl _queue_add(
    queue: ptr[_queue], interpid: i64, data: ptr[_PyXIData_t], unboundop: i32
) -> i32 {
    err = _queue_lock(queue);
    if err < 0 {
        return err;
    }

    maxsize = queue.view(1)[0].items_maxsize;
    if maxsize <= 0 {
        maxsize = PY_SSIZE_T_MAX_VALUE;
    }
    if queue.view(1)[0].items_count >= maxsize {
        _queue_unlock(queue);
        return ERR_QUEUE_FULL;
    }

    item = _queueitem_new(interpid, data, unboundop);
    if not item {
        _queue_unlock(queue);
        return -1;
    }

    queue.view(1)[0].items_count += 1;
    if not queue.view(1)[0].items_first {
        queue.view(1)[0].items_first = item;
    } else {
        queue.view(1)[0].items_last.view(1)[0].next = item;
    }
    queue.view(1)[0].items_last = item;

    _queue_unlock(queue);
    return 0;
}

impl _queue_next(queue: ptr[_queue]) -> tuple[i32, ptr[_PyXIData_t], i32] {
    err = _queue_lock(queue);
    if err < 0 {
        return (err, ptr[_PyXIData_t](), i32(0));
    }

    item = queue.view(1)[0].items_first;
    if not item {
        _queue_unlock(queue);
        return (ERR_QUEUE_EMPTY, ptr[_PyXIData_t](), i32(0));
    }
    queue.view(1)[0].items_first = item.view(1)[0].next;
    if queue.view(1)[0].items_last == item {
        queue.view(1)[0].items_last = ptr[_queueitem]();
    }
    queue.view(1)[0].items_count -= 1;

    (data, unboundop) = _queueitem_popped(item);

    _queue_unlock(queue);
    return (i32(0), data, unboundop);
}

impl _queue_get_maxsize(queue: ptr[_queue]) -> tuple[i32, i64] {
    err = _queue_lock(queue);
    if err < 0 {
        return (err, i64(0));
    }

    maxsize = queue.view(1)[0].items_maxsize;

    _queue_unlock(queue);
    return (i32(0), maxsize);
}

impl _queue_is_full(queue: ptr[_queue]) -> tuple[i32, i32] {
    err = _queue_lock(queue);
    if err < 0 {
        return (err, i32(0));
    }

    is_full: i32 = 0;
    if queue.view(1)[0].items_maxsize > 0 {
        if queue.view(1)[0].items_count == queue.view(1)[0].items_maxsize {
            is_full = 1;
        }
    }

    _queue_unlock(queue);
    return (i32(0), is_full);
}

impl _queue_get_count(queue: ptr[_queue]) -> tuple[i32, i64] {
    err = _queue_lock(queue);
    if err < 0 {
        return (err, i64(0));
    }

    count = queue.view(1)[0].items_count;

    _queue_unlock(queue);
    return (i32(0), count);
}

impl _queue_clear_interpreter(queue: ptr[_queue], interpid: i64) {
    err = _queue_lock(queue);
    if err == ERR_QUEUE_NOT_FOUND {
        return;
    }

    prev = ptr[_queueitem]();
    next = queue.view(1)[0].items_first;
    while next {
        item = next;
        next = item.view(1)[0].next;
        remove: i32 = 0;
        if item.view(1)[0].interpid == interpid {
            remove = _queueitem_clear_interpreter(item);
        }
        if remove != 0 {
            _queueitem_free(item);
            if not prev {
                queue.view(1)[0].items_first = next;
            } else {
                prev.view(1)[0].next = next;
            }
            queue.view(1)[0].items_count -= 1;
        } else {
            prev = item;
        }
    }

    _queue_unlock(queue);
}

impl _queuerefs_find(
    first: ptr[_queueref], qid: i64
) -> tuple[ptr[_queueref], ptr[_queueref]] {
    prev = ptr[_queueref]();
    ref = first;
    while ref {
        if ref.view(1)[0].qid == qid {
            break;
        }
        prev = ref;
        ref = ref.view(1)[0].next;
    }
    return (ref, prev);
}

impl _queuerefs_clear(head: ptr[_queueref]) {
    next = head;
    while next {
        ref = next;
        next = ref.view(1)[0].next;

        queue = ref.view(1)[0].queue;
        PyMem_RawFree(ptr(ref));

        _queue_kill_and_wait(queue);
        _queue_free(queue);
    }
}

impl _queues_init(queues: ptr[_queues], mutex: ptr) {
    queues.view(1)[0].mutex = mutex;
    queues.view(1)[0].head = ptr[_queueref]();
    queues.view(1)[0].count = 0;
    queues.view(1)[0].next_id = 1;
}

impl _queues_fini(queues: ptr[_queues]) -> ptr {
    mutex = queues.view(1)[0].mutex;

    PyThread_acquire_lock(mutex, WAIT_LOCK);
    if queues.view(1)[0].count > 0 {
        _queuerefs_clear(queues.view(1)[0].head);
    }
    queues.view(1)[0].mutex = ptr();
    queues.view(1)[0].head = ptr[_queueref]();
    queues.view(1)[0].count = 0;
    queues.view(1)[0].next_id = 0;
    PyThread_release_lock(mutex);

    return mutex;
}

impl _queues_next_id(queues: ptr[_queues]) -> i64 {
    qid = queues.view(1)[0].next_id;
    if qid < 0 {
        return i64(ERR_NO_NEXT_QUEUE_ID);
    }
    queues.view(1)[0].next_id += 1;
    return qid;
}

impl _queues_lookup(queues: ptr[_queues], qid: i64) -> tuple[i32, ptr[_queue]] {
    PyThread_acquire_lock(queues.view(1)[0].mutex, WAIT_LOCK);

    (ref, prev) = _queuerefs_find(queues.view(1)[0].head, qid);
    if not ref {
        PyThread_release_lock(queues.view(1)[0].mutex);
        return (ERR_QUEUE_NOT_FOUND, ptr[_queue]());
    }
    queue = ref.view(1)[0].queue;
    _queue_mark_waiter(queue, ptr());

    PyThread_release_lock(queues.view(1)[0].mutex);

    return (i32(0), queue);
}

impl _queues_add(queues: ptr[_queues], queue: ptr[_queue]) -> i64 {
    qid: i64 = -1;
    PyThread_acquire_lock(queues.view(1)[0].mutex, WAIT_LOCK);

    _qid = _queues_next_id(queues);
    if _qid < 0 {
        PyThread_release_lock(queues.view(1)[0].mutex);
        return qid;
    }
    ref = ptr[_queueref](PyMem_RawMalloc(QUEUEREF_SIZE));
    if not ref {
        qid = i64(ERR_QUEUE_ALLOC);
        PyThread_release_lock(queues.view(1)[0].mutex);
        return qid;
    }
    ref.view(1)[0].next = ptr[_queueref]();
    ref.view(1)[0].qid = _qid;
    ref.view(1)[0].refcount = 0;
    ref.view(1)[0].queue = queue;

    ref.view(1)[0].next = queues.view(1)[0].head;
    queues.view(1)[0].head = ref;
    queues.view(1)[0].count += 1;

    qid = _qid;
    PyThread_release_lock(queues.view(1)[0].mutex);
    return qid;
}

impl _queues_remove_ref(
    queues: ptr[_queues], ref: ptr[_queueref], prev: ptr[_queueref]
) -> ptr[_queue] {
    if ref == queues.view(1)[0].head {
        queues.view(1)[0].head = ref.view(1)[0].next;
    } else {
        prev.view(1)[0].next = ref.view(1)[0].next;
    }
    ref.view(1)[0].next = ptr[_queueref]();
    queues.view(1)[0].count -= 1;

    queue = ref.view(1)[0].queue;
    ref.view(1)[0].queue = ptr[_queue]();
    PyMem_RawFree(ptr(ref));
    return queue;
}

impl _queues_remove(queues: ptr[_queues], qid: i64) -> tuple[i32, ptr[_queue]] {
    PyThread_acquire_lock(queues.view(1)[0].mutex, WAIT_LOCK);

    (ref, prev) = _queuerefs_find(queues.view(1)[0].head, qid);
    if not ref {
        PyThread_release_lock(queues.view(1)[0].mutex);
        return (ERR_QUEUE_NOT_FOUND, ptr[_queue]());
    }

    queue = _queues_remove_ref(queues, ref, prev);
    PyThread_release_lock(queues.view(1)[0].mutex);

    return (i32(0), queue);
}

impl _queues_incref(queues: ptr[_queues], qid: i64) -> i32 {
    res: i32 = -1;
    PyThread_acquire_lock(queues.view(1)[0].mutex, WAIT_LOCK);

    (ref, prev) = _queuerefs_find(queues.view(1)[0].head, qid);
    if not ref {
        res = ERR_QUEUE_NOT_FOUND;
    } else {
        ref.view(1)[0].refcount += 1;
        res = 0;
    }

    PyThread_release_lock(queues.view(1)[0].mutex);
    return res;
}

impl _queues_decref(queues: ptr[_queues], qid: i64) -> i32 {
    res: i32 = -1;
    PyThread_acquire_lock(queues.view(1)[0].mutex, WAIT_LOCK);

    (ref, prev) = _queuerefs_find(queues.view(1)[0].head, qid);
    if not ref {
        res = ERR_QUEUE_NOT_FOUND;
        PyThread_release_lock(queues.view(1)[0].mutex);
        return res;
    }
    if ref.view(1)[0].refcount == 0 {
        res = ERR_QUEUE_NEVER_BOUND;
        PyThread_release_lock(queues.view(1)[0].mutex);
        return res;
    }
    ref.view(1)[0].refcount -= 1;

    if ref.view(1)[0].refcount == 0 {
        queue = _queues_remove_ref(queues, ref, prev);
        PyThread_release_lock(queues.view(1)[0].mutex);

        _queue_kill_and_wait(queue);
        _queue_free(queue);
        return 0;
    }

    res = 0;
    PyThread_release_lock(queues.view(1)[0].mutex);
    return res;
}

impl _queues_list_all(queues: ptr[_queues]) -> tuple[ptr[queue_id_and_info], i64] {
    qids = ptr[queue_id_and_info]();
    count: i64 = 0;
    PyThread_acquire_lock(queues.view(1)[0].mutex, WAIT_LOCK);
    n = queues.view(1)[0].count;
    ids = ptr[queue_id_and_info]();
    if n <= PY_SSIZE_T_MAX_VALUE // QUEUE_ID_AND_INFO_SIZE {
        ids = ptr[queue_id_and_info](PyMem_Malloc(u64(n * QUEUE_ID_AND_INFO_SIZE)));
    }
    if not ids {
        PyThread_release_lock(queues.view(1)[0].mutex);
        return (qids, count);
    }
    ref = queues.view(1)[0].head;
    i: i64 = 0;
    while ref {
        cur = (ids + i).view(1);
        cur[0].id = ref.view(1)[0].qid;
        cur[0].defaults_fallback = ref.view(1)[0].queue.view(1)[0].defaults_fallback;
        cur[0].defaults_unboundop = ref.view(1)[0].queue.view(1)[0].defaults_unboundop;
        ref = ref.view(1)[0].next;
        i += 1;
    }
    count = queues.view(1)[0].count;

    qids = ids;
    PyThread_release_lock(queues.view(1)[0].mutex);
    return (qids, count);
}

impl _queues_clear_interpreter(queues: ptr[_queues], interpid: i64) {
    PyThread_acquire_lock(queues.view(1)[0].mutex, WAIT_LOCK);

    ref = queues.view(1)[0].head;
    while ref {
        _queue_clear_interpreter(ref.view(1)[0].queue, interpid);
        ref = ref.view(1)[0].next;
    }

    PyThread_release_lock(queues.view(1)[0].mutex);
}

impl queue_create(
    queues: ptr[_queues], maxsize: i64, defaults_fallback: i32, defaults_unboundop: i32
) -> i64 {
    queue = ptr[_queue](PyMem_RawMalloc(QUEUE_SIZE));
    if not queue {
        return i64(ERR_QUEUE_ALLOC);
    }
    err = _queue_init(queue, maxsize, defaults_fallback, defaults_unboundop);
    if err < 0 {
        PyMem_RawFree(ptr(queue));
        return i64(err);
    }
    qid = _queues_add(queues, queue);
    if qid < 0 {
        _queue_clear(queue);
        PyMem_RawFree(ptr(queue));
    }
    return qid;
}

impl queue_destroy(queues: ptr[_queues], qid: i64) -> i32 {
    (err, queue) = _queues_remove(queues, qid);
    if err < 0 {
        return err;
    }
    _queue_kill_and_wait(queue);
    _queue_free(queue);
    return 0;
}

impl queue_put(
    queues: ptr[_queues], qid: i64, obj_: ptr[PyObject], unboundop: i32, fallback: i32
) -> i32 {
    tstate = PyThreadState_Get();

    (err, queue) = _queues_lookup(queues, qid);
    if err != 0 {
        return err;
    }

    xidata = _PyXIData_New();
    if not xidata {
        _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
        return -1;
    }
    if _PyObject_GetXIData(tstate, obj_, fallback, xidata) != 0 {
        _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
        PyMem_RawFree(ptr(xidata));
        return -1;
    }

    interpid: i64 = -1;
    res = _queue_add(queue, interpid, xidata, unboundop);
    _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
    if res != 0 {
        _release_xid_data(xidata, 0);
        PyMem_RawFree(ptr(xidata));
        return res;
    }

    return 0;
}

impl queue_get(queues: ptr[_queues], qid: i64) -> tuple[i32, ptr[PyObject], i32] {
    (err, queue) = _queues_lookup(queues, qid);
    if err != 0 {
        return (err, NULL, i32(0));
    }

    (err, data, unboundop) = _queue_next(queue);
    _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
    if err != 0 {
        return (err, NULL, i32(0));
    } elif not data {
        return (i32(0), NULL, unboundop);
    }

    obj_ = _PyXIData_NewObject(data);
    if not obj_ {
        _release_xid_data(data, XID_IGNORE_EXC | XID_FREE);
        return (i32(-1), NULL, unboundop);
    }
    release_res = _release_xid_data(data, XID_FREE);
    if release_res < 0 {
        object_decref(obj_);
        return (i32(-1), NULL, unboundop);
    }

    return (i32(0), obj_, unboundop);
}

impl queue_get_defaults(queues: ptr[_queues], qid: i64) -> tuple[i32, i32, i32] {
    (err, queue) = _queues_lookup(queues, qid);
    if err != 0 {
        return (err, i32(0), i32(0));
    }
    fallback = queue.view(1)[0].defaults_fallback;
    unboundop = queue.view(1)[0].defaults_unboundop;
    _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
    return (i32(0), fallback, unboundop);
}

impl queue_get_maxsize(queues: ptr[_queues], qid: i64) -> tuple[i32, i64] {
    (err, queue) = _queues_lookup(queues, qid);
    if err < 0 {
        return (err, i64(0));
    }
    (err, maxsize) = _queue_get_maxsize(queue);
    _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
    return (err, maxsize);
}

impl queue_is_full(queues: ptr[_queues], qid: i64) -> tuple[i32, i32] {
    (err, queue) = _queues_lookup(queues, qid);
    if err < 0 {
        return (err, i32(0));
    }
    (err, is_full) = _queue_is_full(queue);
    _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
    return (err, is_full);
}

impl queue_get_count(queues: ptr[_queues], qid: i64) -> tuple[i32, i64] {
    (err, queue) = _queues_lookup(queues, qid);
    if err < 0 {
        return (err, i64(0));
    }
    (err, count) = _queue_get_count(queue);
    _queue_unmark_waiter(queue, queues.view(1)[0].mutex);
    return (err, count);
}

impl set_external_queue_type(
    state: ptr[QueuesModuleState], queue_type: ptr[PyTypeObject]
) -> i32 {
    if state.view(1)[0].queue_type {
        clear_xid_class(state.view(1)[0].queue_type);
        old = state.view(1)[0].queue_type;
        state.view(1)[0].queue_type = ptr[PyTypeObject]();
        object_xdecref(ptr[PyObject](old));
    }

    if ensure_xid_class(queue_type, ptr(_queueobj_shared)) < 0 {
        return -1;
    }
    state.view(1)[0].queue_type = ptr[PyTypeObject](
        object_new_ref(ptr[PyObject](queue_type))
    );

    return 0;
}

impl get_external_queue_type(module: ptr[PyObject]) -> ptr[PyTypeObject] {
    state = get_module_state(module);

    cls = state.view(1)[0].queue_type;
    if not cls {
        if ensure_highlevel_module_loaded() < 0 {
            return ptr[PyTypeObject]();
        }
        cls = state.view(1)[0].queue_type;
    }
    return cls;
}

impl _get_global_queues -> ptr[_queues] {
    return ptr[_queues](ptr[u8](addressof(_globals)) + GLOBALS_QUEUES);
}

impl _queueid_xid_new(qid: i64) -> ptr {
    queues = _get_global_queues();
    if _queues_incref(queues, qid) < 0 {
        return ptr();
    }

    data = ptr[_queueid_xid](PyMem_RawMalloc(QUEUEID_XID_SIZE));
    if not data {
        _queues_decref(queues, qid);
        return ptr();
    }
    data.view(1)[0].qid = qid;
    return ptr(data);
}

impl _queueid_xid_free(data: ptr) {
    qid = ptr[_queueid_xid](data).view(1)[0].qid;
    PyMem_RawFree(data);
    queues = _get_global_queues();
    _queues_decref(queues, qid);
}

impl _queueobj_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject] {
    qid = ptr[i64](data.view(1)[0].data).view(1)[0];
    qidobj = PyLong_FromLongLong(qid);
    if not qidobj {
        return NULL;
    }

    mod = _get_current_module();
    if not mod {
        mod = PyImport_ImportModule(ptr[u8]("_interpqueues"));
        if not mod {
            object_decref(qidobj);
            return NULL;
        }
    }

    cls = get_external_queue_type(mod);
    object_decref(mod);
    if not cls {
        object_decref(qidobj);
        return NULL;
    }
    obj_ = PyObject_CallOneArg(ptr[PyObject](cls), qidobj);
    object_decref(qidobj);
    return obj_;
}

impl _queueobj_shared(
    tstate: ptr[PyThreadState], queueobj: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32 {
    qidobj = PyObject_GetAttrString(queueobj, ptr[u8]("_id"));
    if not qidobj {
        return -1;
    }
    converted: own qidarg_converter_data = qidarg_converter_data();
    conv = ptr[qidarg_converter_data](jacpy_stack_address(&mut converted));
    conv.view(1)[0].label = ptr[u8]("queue ID");
    conv.view(1)[0].id = 0;
    res = idarg_int64_converter(qidobj, ptr(conv));
    object_decref(qidobj);
    if res == 0 {
        return -1;
    }

    raw = _queueid_xid_new(conv.view(1)[0].id);
    if not raw {
        return -1;
    }
    interp = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
    _PyXIData_Init(data, interp, raw, NULL, ptr(_queueobj_from_xid));
    data.view(1)[0].free = int(ptr(_queueid_xid_free));
    return 0;
}

impl _globals_init -> i32 {
    PyMutex_Lock(ptr[PyMutex](addressof(_globals)));
    g = addressof(_globals).view(1);
    g[0].module_count += 1;
    if g[0].module_count == 1 {
        mutex = PyThread_allocate_lock();
        if not mutex {
            g[0].module_count -= 1;
            PyMutex_Unlock(ptr[PyMutex](addressof(_globals)));
            return ERR_QUEUES_ALLOC;
        }
        _queues_init(_get_global_queues(), mutex);
    }
    PyMutex_Unlock(ptr[PyMutex](addressof(_globals)));
    return 0;
}

impl _globals_fini {
    PyMutex_Lock(ptr[PyMutex](addressof(_globals)));
    g = addressof(_globals).view(1);
    g[0].module_count -= 1;
    if g[0].module_count == 0 {
        mutex = _queues_fini(_get_global_queues());
        PyThread_free_lock(mutex);
    }
    PyMutex_Unlock(ptr[PyMutex](addressof(_globals)));
}

impl clear_interpreter(data: ptr) {
    if addressof(_globals).view(1)[0].module_count == 0 {
        return;
    }
    interp = ptr[u8](data);
    interpid = PyInterpreterState_GetID(interp);
    _queues_clear_interpreter(_get_global_queues(), interpid);
}

impl qidarg_converter(arg: ptr[PyObject], p: ptr) -> i32 {
    data = ptr[qidarg_converter_data](p);
    if not data.view(1)[0].label {
        data.view(1)[0].label = ptr[u8]("queue ID");
    }
    return idarg_int64_converter(arg, p);
}

impl queuesmod_create(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    maxsize: i64 = 0;
    unboundarg: i32 = -1;
    fallbackarg: i32 = -1;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("n|ii:create"),
        ptr(addressof(create_kwlist)),
        &mut maxsize,
        &mut unboundarg,
        &mut fallbackarg
    )
        == 0 {
        return NULL;
    }
    (status, defaults_unboundop) = resolve_unboundop(unboundarg, UNBOUND_REPLACE);
    if status < 0 {
        return NULL;
    }
    (status, defaults_fallback) = resolve_fallback(fallbackarg, XIDATA_FULL_FALLBACK);
    if status < 0 {
        return NULL;
    }

    qid = queue_create(
        _get_global_queues(), maxsize, defaults_fallback, defaults_unboundop
    );
    if qid < 0 {
        handle_queue_error(i32(qid), self_, qid);
        return NULL;
    }

    qidobj = PyLong_FromLongLong(qid);
    if not qidobj {
        exc = PyErr_GetRaisedException();
        err = queue_destroy(_get_global_queues(), qid);
        if handle_queue_error(err, self_, qid) != 0 {
            PyErr_Clear();
        }
        PyErr_SetRaisedException(exc);
        return NULL;
    }

    return qidobj;
}

impl queuesmod_destroy(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:destroy"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    err = queue_destroy(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl queuesmod_list_all(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    (qids, count) = _queues_list_all(_get_global_queues());
    if not qids {
        if not PyErr_Occurred() and count == 0 {
            return PyList_New(0);
        }
        return NULL;
    }
    ids = PyList_New(count);
    if ids {
        items = ptr[PyListObject](ids).view(1)[0].ob_item;
        i: i64 = 0;
        while i < count {
            cur = (qids + i).view(1);
            cur_id = cur[0].id;
            cur_unboundop = cur[0].defaults_unboundop;
            cur_fallback = cur[0].defaults_fallback;
            item = Py_BuildValue(ptr[u8]("Lii"), cur_id, cur_unboundop, cur_fallback);
            if not item {
                old = ids;
                ids = NULL;
                object_decref(old);
                break;
            }
            (items + i).view(1)[0] = item;
            i += 1;
        }
    }

    PyMem_Free(ptr(qids));
    return ids;
}

impl queuesmod_put(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    obj_ = NULL;
    unboundarg: i32 = -1;
    fallbackarg: i32 = -1;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&O|ii:put"),
        ptr(addressof(put_kwlist)),
        ptr(qidarg_converter),
        qidp,
        &mut obj_,
        &mut unboundarg,
        &mut fallbackarg
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;
    defaults_fallback: i32 = -1;
    defaults_unboundop: i32 = -1;
    if unboundarg < 0 or fallbackarg < 0 {
        (err, got_fallback, got_unboundop) = queue_get_defaults(
            _get_global_queues(), qid
        );
        if handle_queue_error(err, self_, qid) != 0 {
            return NULL;
        }
        defaults_fallback = got_fallback;
        defaults_unboundop = got_unboundop;
    }
    (status, unboundop) = resolve_unboundop(unboundarg, defaults_unboundop);
    if status < 0 {
        return NULL;
    }
    (status, fallback) = resolve_fallback(fallbackarg, defaults_fallback);
    if status < 0 {
        return NULL;
    }

    put_err = queue_put(_get_global_queues(), qid, obj_, unboundop, fallback);
    if handle_queue_error(put_err, self_, qid) != 0 {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl queuesmod_get(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:get"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    (err, obj_, unboundop) = queue_get(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }

    if not obj_ {
        return Py_BuildValue(ptr[u8]("Oi"), Py_None, unboundop);
    }
    res = Py_BuildValue(ptr[u8]("OO"), obj_, Py_None);
    object_decref(obj_);
    return res;
}

impl queuesmod_bind(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:bind"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    err = _queues_incref(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl queuesmod_release(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:release"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    err = _queues_decref(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl queuesmod_get_maxsize(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:get_maxsize"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    (err, maxsize) = queue_get_maxsize(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }
    return PyLong_FromLongLong(maxsize);
}

impl queuesmod_get_queue_defaults(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:get_queue_defaults"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    (err, fallback, unboundop) = queue_get_defaults(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }

    res = Py_BuildValue(ptr[u8]("ii"), unboundop, fallback);
    return res;
}

impl queuesmod_is_full(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:is_full"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    (err, is_full) = queue_is_full(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }
    if is_full != 0 {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl queuesmod_get_count(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    qidarg: own qidarg_converter_data = qidarg_converter_data();
    qidp = ptr[qidarg_converter_data](jacpy_stack_address(&mut qidarg));
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:get_count"),
        ptr(addressof(qid_kwlist)),
        ptr(qidarg_converter),
        qidp
    )
        == 0 {
        return NULL;
    }
    qid = qidp.view(1)[0].id;

    (err, count) = queue_get_count(_get_global_queues(), qid);
    if handle_queue_error(err, self_, qid) != 0 {
        return NULL;
    }
    return PyLong_FromSsize_t(count);
}

impl queuesmod__register_heap_types(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    queuetype = NULL;
    emptyerror = NULL;
    fullerror = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("OOO:_register_heap_types"),
        ptr(addressof(register_heap_types_kwlist)),
        &mut queuetype,
        &mut emptyerror,
        &mut fullerror
    )
        == 0 {
        return NULL;
    }
    if not type_has_feature(object_type(queuetype), Py_TPFLAGS_TYPE_SUBCLASS) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("expected a type for 'queuetype'"));
        return NULL;
    }
    if not exception_class_check(emptyerror) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("expected an exception type for 'emptyerror'")
        );
        return NULL;
    }
    if not exception_class_check(fullerror) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("expected an exception type for 'fullerror'")
        );
        return NULL;
    }

    state = get_module_state(self_);

    if set_external_queue_type(state, ptr[PyTypeObject](queuetype)) < 0 {
        return NULL;
    }
    if set_external_exc_types(state, emptyerror, fullerror) < 0 {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl exception_class_check(x: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(x), Py_TPFLAGS_TYPE_SUBCLASS)
        and type_has_feature(ptr[PyTypeObject](x), Py_TPFLAGS_BASE_EXC_SUBCLASS);
}

impl module_exec(mod: ptr[PyObject]) -> i32 {
    err = _globals_init();
    if handle_queue_error(err, mod, -1) != 0 {
        return -1;
    }

    if add_QueueError(mod) < 0 {
        _globals_fini();
        return -1;
    }

    interp = _get_current_interp();
    PyUnstable_AtExit(interp, ptr(clear_interpreter), ptr(interp));

    return 0;
}

impl module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    state = get_module_state(mod);
    return traverse_module_state(state, visitor, arg);
}

impl module_clear(mod: ptr[PyObject]) -> i32 {
    state = get_module_state(mod);
    return clear_module_state(state);
}

impl module_free(mod: ptr) {
    state = get_module_state(ptr[PyObject](mod));
    clear_module_state(state);
    _globals_fini();
}
