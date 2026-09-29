"""The _asyncio module: the Future, Task, FutureIter and TaskStepMethWrapper
types as C-layout specs over the generated clinic tables, the module state
and the execution slot in Modules/_asynciomodule.c's order."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyImport_ImportModule,
    PyMethodDef,
    PyModule_AddType,
    PyObject,
    PyObject_CallNoArgs,
    PyObject_GenericGetAttr,
    PyObject_GetAttrString,
    PyObject_SelfIter,
    PySet_New,
    PyType_FromModuleAndSpec,
    PyType_GenericNew,
    PyType_Slot,
    PyType_Spec,
    Py_BuildValue,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_FASTCALL,
    METH_NOARGS,
    METH_O,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_IMMUTABLETYPE,
    Py_TPFLAGS_MANAGED_DICT,
    Py_TPFLAGS_MANAGED_WEAKREF,
    PyGetSetDef,
    Py_am_await,
    Py_am_send,
    Py_tp_call,
    Py_tp_clear,
    Py_tp_dealloc,
    Py_tp_doc,
    Py_tp_finalize,
    Py_tp_getattro,
    Py_tp_getset,
    Py_tp_init,
    Py_tp_iter,
    Py_tp_iternext,
    Py_tp_methods,
    Py_tp_new,
    Py_tp_repr,
    Py_tp_token,
    Py_tp_traverse
}
import from jaclang.runtime.python.capi { c_string_copy }
import from jaclang.runtime.python.object_model.genericalias { Py_GenericAlias }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    clear_state,
    jacpy_binding_module_native_set,
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    method_table,
    traverse_state
}
import from jaclang.runtime.python.bindings.type { PropertyDefinition, getset_table }
import from jaclang.runtime.python.bindings.clinic.asyncio {
    FutureType_methods___class_getitem___doc,
    Future_doc,
    Future_getset,
    Future_methods,
    TaskType_methods___class_getitem___doc,
    Task_doc,
    Task_getset,
    Task_methods,
    _asyncio_Future___init___init,
    _asyncio_Task___init___init,
    module_methods
}
import from jaclang.runtime.python.modules.asyncio_core {
    AsyncioState,
    FUTURE_ITER_SIZE,
    FUTURE_OBJECT_SIZE,
    STATE_ASYNCIO_MOD,
    STATE_CANCELLED_ERROR,
    STATE_CONTEXT_KWNAME,
    STATE_COUNT,
    STATE_FUTURE_ITER_TYPE,
    STATE_FUTURE_REPR_FUNC,
    STATE_FUTURE_TYPE,
    STATE_GET_EVENT_LOOP_POLICY,
    STATE_INVALID_STATE_ERROR,
    STATE_ISCOROUTINE_FUNC,
    STATE_ISCOROUTINE_TYPECACHE,
    STATE_NON_ASYNCIO_EAGER_TASKS,
    STATE_NON_ASYNCIO_TASKS,
    STATE_TASK_GET_STACK_FUNC,
    STATE_TASK_PRINT_STACK_FUNC,
    STATE_TASK_REPR_FUNC,
    STATE_TASK_STEP_WRAPPER_TYPE,
    STATE_TASK_TYPE,
    STATE_TRACEBACK_EXTRACT_STACK,
    TASK_OBJECT_SIZE,
    TASK_STEP_WRAPPER_SIZE,
    asyncio_module_token,
    intern_identifiers,
    release,
    running_loop_slot,
    running_task_slot
}
import from jaclang.runtime.python.modules.asyncio {
    Future_token,
    Task_token,
    future_clear,
    future_dealloc,
    future_finalize,
    future_new_iter,
    future_repr,
    future_traverse,
    futureiter_am_send,
    futureiter_clear,
    futureiter_close,
    futureiter_dealloc,
    futureiter_iternext,
    futureiter_send,
    futureiter_throw,
    futureiter_traverse,
    stepwrapper_call,
    stepwrapper_clear,
    stepwrapper_dealloc,
    stepwrapper_self,
    stepwrapper_traverse,
    task_clear,
    task_dealloc,
    task_finalize,
    task_repr,
    task_traverse
}

import from c {
    glob:priv futureiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(futureiter_send),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("throw"),
                 ml_meth=ptr(futureiter_throw),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(futureiter_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         futureiter_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(futureiter_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(futureiter_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(futureiter_clear)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(futureiter_iternext)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(futureiter_methods))),
             PyType_Slot(slot=Py_am_send, pfunc=ptr(futureiter_am_send)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         futureiter_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_asyncio.FutureIter"),
             basicsize=i32(FUTURE_ITER_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(futureiter_slots)
         ),
         stepwrapper_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__self__"), get=stepwrapper_self),
             PyGetSetDef()
         ],
         stepwrapper_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(stepwrapper_getset))),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(stepwrapper_dealloc)),
             PyType_Slot(slot=Py_tp_call, pfunc=ptr(stepwrapper_call)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(stepwrapper_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(stepwrapper_clear)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         stepwrapper_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_asyncio.TaskStepMethWrapper"),
             basicsize=i32(TASK_STEP_WRAPPER_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(stepwrapper_slots)
         ),
         # The doc, methods and getset slots are filled once per process by
         # install_tables(); the token is the spec (Py_TP_USE_SPEC).
         future_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(future_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(future_repr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(future_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(future_clear)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(future_new_iter)),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_asyncio_Future___init___init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(PyType_GenericNew)),
             PyType_Slot(slot=Py_tp_finalize, pfunc=ptr(future_finalize)),
             PyType_Slot(slot=Py_am_await, pfunc=ptr(future_new_iter)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         future_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_asyncio.Future"),
             basicsize=i32(FUTURE_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_DICT
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(future_slots)
         ),
         task_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(task_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(task_repr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(task_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(task_clear)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(future_new_iter)),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_asyncio_Task___init___init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(PyType_GenericNew)),
             PyType_Slot(slot=Py_tp_finalize, pfunc=ptr(task_finalize)),
             PyType_Slot(slot=Py_am_await, pfunc=ptr(future_new_iter)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         task_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_asyncio.Task"),
             basicsize=i32(TASK_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_MANAGED_DICT
                     | Py_TPFLAGS_MANAGED_WEAKREF
             ),
             slots=addressof(task_slots)
         );
}

# The index of the doc, methods and getset slots in future_slots and
# task_slots.
glob:priv SLOT_DOC: int = 1,
     SLOT_METHODS: int = 2,
     SLOT_GETSET: int = 3;

"""The entries of `table` named in `names`, in that order."""
def:priv select_methods(
    table: list[MethodDefinition], names: list[str]
) -> list[MethodDefinition] {
    selected: list[MethodDefinition] = [];
    for name in names {
        for method in table {
            if method.name == name {
                selected.append(method);
                break;
            }
        }
    }
    return selected;
}

def:priv select_properties(
    table: list[PropertyDefinition], names: list[str]
) -> list[PropertyDefinition] {
    selected: list[PropertyDefinition] = [];
    for name in names {
        for property in table {
            if property.name == name {
                selected.append(property);
                break;
            }
        }
    }
    return selected;
}

def:priv class_getitem_method(doc: str) -> MethodDefinition {
    # METH_O | METH_CLASS
    return MethodDefinition(
        "__class_getitem__", MethodCallbacks(positional=Py_GenericAlias), doc, 24
    );
}

"""Fill the doc, methods and getset slots of `slots`; False with the error
set."""
def:priv fill_slots(
    slots: ptr[PyType_Slot],
    doc: str,
    methods: list[MethodDefinition],
    getset: list[PropertyDefinition]
) -> bool {
    doc_text = c_string_copy(doc);
    method_records = method_table(methods);
    getset_records = getset_table(getset);
    if doc_text.is_null() or method_records.is_null() or getset_records.is_null() {
        return False;
    }
    (slots + SLOT_DOC).view(1)[0].pfunc = ptr(doc_text);
    (slots + SLOT_METHODS).view(1)[0].pfunc = ptr(method_records);
    (slots + SLOT_GETSET).view(1)[0].pfunc = ptr(getset_records);
    return True;
}

import from c {
    # Whether the Future and Task tables are installed: they live for the
    # process, as the C module's static tables do.
    glob:priv tables_ready: i32 = 0;
}

"""FutureType_methods, FutureType_getsetlist, TaskType_methods and
TaskType_getsetlist in the C module's order, once per process."""
def:priv install_tables -> bool {
    if tables_ready != 0 {
        return True;
    }
    future_methods = select_methods(
        Future_methods,
        [
            "result",
            "exception",
            "set_result",
            "set_exception",
            "add_done_callback",
            "remove_done_callback",
            "cancel",
            "cancelled",
            "done",
            "get_loop",
            "_make_cancelled_error"
        ]
    );
    future_methods.append(
        class_getitem_method(FutureType_methods___class_getitem___doc)
    );
    future_getset = select_properties(
        Future_getset,
        [
            "_state",
            "_asyncio_future_blocking",
            "_loop",
            "_callbacks",
            "_result",
            "_exception",
            "_log_traceback",
            "_source_traceback",
            "_cancel_message",
            "_asyncio_awaited_by"
        ]
    );
    task_methods = select_methods(
        Future_methods,
        [
            "result",
            "exception",
            "add_done_callback",
            "remove_done_callback",
            "cancelled",
            "done"
        ]
    );
    task_methods.extend(
        select_methods(
            Task_methods,
            [
                "set_result",
                "set_exception",
                "cancel",
                "cancelling",
                "uncancel",
                "get_stack",
                "print_stack",
                "_make_cancelled_error",
                "get_name",
                "set_name",
                "get_coro",
                "get_context"
            ]
        )
    );
    task_methods.append(class_getitem_method(TaskType_methods___class_getitem___doc));
    task_getset = select_properties(
        Task_getset, ["_log_destroy_pending", "_must_cancel", "_coro", "_fut_waiter"]
    );
    if not fill_slots(
        ptr[PyType_Slot](addressof(future_slots)),
        Future_doc,
        future_methods,
        future_getset
    )
        or not fill_slots(
            ptr[PyType_Slot](addressof(task_slots)), Task_doc, task_methods, task_getset
        ) {
        return False;
    }
    tables_ready = 1;
    return True;
}

"""Store a new reference (consumed) in the module state; False when NULL."""
def:priv set_state(module: ptr[PyObject], index: int, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    jacpy_release(value);
    return True;
}

"""An attribute of an imported module into the module state."""
def:priv set_attribute_state(
    module: ptr[PyObject], index: int, source: ptr[PyObject], name: str
) -> bool {
    return set_state(module, index, PyObject_GetAttrString(source, name));
}

"""module_init(): the asyncio functions and classes the C code calls."""
def:priv module_init(module: ptr[PyObject]) -> bool {
    if not set_state(module, STATE_ASYNCIO_MOD, PyImport_ImportModule("asyncio"))
        or not set_state(module, STATE_ISCOROUTINE_TYPECACHE, PySet_New(NULL))
        or not set_state(
            module, STATE_CONTEXT_KWNAME, Py_BuildValue("(s)", ptr[u8]("context"))
        ) {
        return False;
    }
    for (name, attributes) in [
        ("asyncio.events", [(STATE_GET_EVENT_LOOP_POLICY, "_get_event_loop_policy")]),
        ("asyncio.base_futures", [(STATE_FUTURE_REPR_FUNC, "_future_repr")]),
        (
            "asyncio.exceptions",
            [
                (STATE_INVALID_STATE_ERROR, "InvalidStateError"),
                (STATE_CANCELLED_ERROR, "CancelledError")
            ]
        ),
        (
            "asyncio.base_tasks",
            [
                (STATE_TASK_REPR_FUNC, "_task_repr"),
                (STATE_TASK_GET_STACK_FUNC, "_task_get_stack"),
                (STATE_TASK_PRINT_STACK_FUNC, "_task_print_stack")
            ]
        ),
        ("asyncio.coroutines", [(STATE_ISCOROUTINE_FUNC, "iscoroutine")]),
        ("traceback", [(STATE_TRACEBACK_EXTRACT_STACK, "extract_stack")])
    ] {
        source = PyImport_ImportModule(name);
        if not source {
            return False;
        }
        for (index, attribute) in attributes {
            if not set_attribute_state(module, index, source, attribute) {
                jacpy_release(source);
                return False;
            }
        }
        jacpy_release(source);
    }
    weakref = PyImport_ImportModule("weakref");
    if not weakref {
        return False;
    }
    weak_set = PyObject_GetAttrString(weakref, "WeakSet");
    jacpy_release(weakref);
    if not weak_set {
        return False;
    }
    tasks = PyObject_CallNoArgs(weak_set);
    jacpy_release(weak_set);
    return set_state(module, STATE_NON_ASYNCIO_TASKS, tasks)
        and set_state(module, STATE_NON_ASYNCIO_EAGER_TASKS, PySet_New(NULL));
}

"""CREATE_TYPE()."""
def:priv create_type(
    module: ptr[PyObject], index: int, spec: ptr[PyType_Spec], base: ptr[PyObject]
) -> bool {
    return set_state(module, index, PyType_FromModuleAndSpec(module, spec, base));
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    asyncio_module_token.handle = definition.handle;
    Future_token.handle = ptr(addressof(future_spec));
    Task_token.handle = ptr(addressof(task_spec));
    if not intern_identifiers() or not install_tables() {
        return i32(-1);
    }
    jacpy_binding_module_native_set(module, AsyncioState());
    if not create_type(
        module, STATE_TASK_STEP_WRAPPER_TYPE, addressof(stepwrapper_spec), NULL
    )
        or not create_type(
            module, STATE_FUTURE_ITER_TYPE, addressof(futureiter_spec), NULL
        )
        or not create_type(module, STATE_FUTURE_TYPE, addressof(future_spec), NULL)
        or not create_type(
            module,
            STATE_TASK_TYPE,
            addressof(task_spec),
            jacpy_binding_state_get(module, i64(STATE_FUTURE_TYPE))
        ) {
        return i32(-1);
    }
    if PyModule_AddType(module, jacpy_binding_state_get(module, i64(STATE_FUTURE_TYPE)))
        < 0
        or PyModule_AddType(
            module, jacpy_binding_state_get(module, i64(STATE_TASK_TYPE))
        )
            < 0 {
        return i32(-1);
    }
    # Must be done after the types are added, to avoid a circular dependency.
    if not module_init(module) {
        return i32(-1);
    }
    return i32(0);
}

"""module_clear(): the state, and this thread's running loop and task, so
finalizers can run early; other threads' are cleared by
PyThreadState_Clear()."""
def:priv module_clear(module: ptr[PyObject]) -> i32 {
    clear_state(module);
    loop_slot = running_loop_slot().view(1);
    loop = loop_slot[0];
    loop_slot[0] = NULL;
    release(loop);
    task_slot = running_task_slot().view(1);
    task = task_slot[0];
    task_slot[0] = NULL;
    release(task);
    return i32(0);
}

def:priv module_free(module: ptr[PyObject]) {
    module_clear(module);
}

glob:priv definition = ModuleDefinition(
         "_asyncio",
         "Accelerator module for asyncio",
         module_methods,
         ModuleHooks(
             execute=execute,
             traverse=traverse_state,
             clear=module_clear,
             free=module_free
         ),
         STATE_COUNT,
         own_lifecycle=True
     );

def:pub PyInit__asyncio -> ptr[PyObject] {
    return definition.initialize();
}
