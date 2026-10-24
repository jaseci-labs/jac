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
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(fast_future_init)),
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
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(fast_task_init)),
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

glob:priv SLOT_DOC: int = 1,
     SLOT_METHODS: int = 2,
     SLOT_GETSET: int = 3;

import from c {
    obj KeywordsCall {
        has call:
            Callable[
                [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                ptr[PyObject]
            ] = 0;
    }  obj FastCall {
        has call: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0;
    }  glob:priv set_result_glue: KeywordsCall = KeywordsCall(),
         add_done_callback_glue: KeywordsCall = KeywordsCall(),
         get_loop_glue: KeywordsCall = KeywordsCall(),
         add_awaited_glue: FastCall = FastCall(),
         discard_awaited_glue: FastCall = FastCall();
}

def:priv keywords_glue(
    glue: ptr[KeywordsCall],
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv positional_glue(
    glue: ptr[FastCall], receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv fast_done(receiver: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def:priv fast_cancelled(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv fast_result(receiver: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def:priv fast_exception(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv fast_get_loop(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv fast_set_result(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv fast_add_done_callback(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv fast_add_to_awaited_by(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv fast_discard_from_awaited_by(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv fast_future_init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def:priv fast_task_init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def:priv with_fast_paths(table: list[MethodDefinition]) -> list[MethodDefinition];

def:priv module_functions -> list[MethodDefinition];

def:priv select_methods(
    table: list[MethodDefinition], names: list[str]
) -> list[MethodDefinition];

def:priv select_properties(
    table: list[PropertyDefinition], names: list[str]
) -> list[PropertyDefinition];

def:priv class_getitem_method(doc: str) -> MethodDefinition;

def:priv fill_slots(
    slots: ptr[PyType_Slot],
    doc: str,
    methods: list[MethodDefinition],
    getset: list[PropertyDefinition]
) -> bool;

import from c { glob:priv tables_ready: i32 = 0; }

def:priv install_tables -> bool;

def:priv set_state(module: ptr[PyObject], index: int, value: ptr[PyObject]) -> bool;

def:priv set_attribute_state(
    module: ptr[PyObject], index: int, source: ptr[PyObject], name: str
) -> bool;

def:priv module_init(module: ptr[PyObject]) -> bool;

def:priv create_type(
    module: ptr[PyObject], index: int, spec: ptr[PyType_Spec], base: ptr[PyObject]
) -> bool;

def:priv execute(module: ptr[PyObject]) -> i32;

def:priv module_clear(module: ptr[PyObject]) -> i32;

def:priv module_free(module: ptr[PyObject]);

glob:priv definition = ModuleDefinition(
         "_asyncio",
         "Accelerator module for asyncio",
         module_functions(),
         ModuleHooks(
             execute=execute,
             traverse=traverse_state,
             clear=module_clear,
             free=module_free
         ),
         STATE_COUNT,
         own_lifecycle=True
     );

def:pub PyInit__asyncio -> ptr[PyObject];

impl keywords_glue(
    glue: ptr[KeywordsCall],
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return glue.view(1)[0].call(receiver, args, nargs, kwnames);
}

impl positional_glue(
    glue: ptr[FastCall], receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return glue.view(1)[0].call(receiver, args, nargs);
}

impl fast_done(receiver: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return _asyncio_Future_done_impl(receiver);
}

impl fast_cancelled(receiver: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return _asyncio_Future_cancelled_impl(receiver);
}

impl fast_result(receiver: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return _asyncio_Future_result_impl(receiver);
}

impl fast_exception(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 0 and not kwnames {
        return _asyncio_Future_exception_impl(receiver, NULL);
    }
    return keywords_glue(
        ptr[KeywordsCall](
            __thread_local_block("jac_bindings_asyncio_exception_glue", 8)
        ),
        receiver,
        args,
        nargs,
        kwnames
    );
}

impl fast_get_loop(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 0 and not kwnames {
        return _asyncio_Future_get_loop_impl(receiver, NULL);
    }
    return keywords_glue(addressof(get_loop_glue), receiver, args, nargs, kwnames);
}

impl fast_set_result(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 1 and not kwnames {
        return _asyncio_Future_set_result_impl(receiver, NULL, args.view(1)[0]);
    }
    return keywords_glue(addressof(set_result_glue), receiver, args, nargs, kwnames);
}

impl fast_add_done_callback(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if nargs == 1 and not kwnames {
        return _asyncio_Future_add_done_callback_impl(
            receiver, NULL, args.view(1)[0], NULL
        );
    }

    if nargs == 1
        and kwnames
        and PyTuple_Size(kwnames) == 1
        and PyTuple_GetItem(kwnames, 0) == ids.kw_context {
        values = args.view(2);
        return _asyncio_Future_add_done_callback_impl(
            receiver, NULL, values[0], values[1]
        );
    }
    return keywords_glue(
        addressof(add_done_callback_glue), receiver, args, nargs, kwnames
    );
}

impl fast_add_to_awaited_by(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs == 2 {
        values = args.view(2);
        return _asyncio_future_add_to_awaited_by_impl(module, values[0], values[1]);
    }
    return positional_glue(addressof(add_awaited_glue), module, args, nargs);
}

impl fast_discard_from_awaited_by(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs == 2 {
        values = args.view(2);
        return _asyncio_future_discard_from_awaited_by_impl(
            module, values[0], values[1]
        );
    }
    return positional_glue(addressof(discard_awaited_glue), module, args, nargs);
}

impl fast_future_init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    if PyTuple_Size(args) == 0 {
        count = jacpy_dict_size(kwargs) if kwargs else i64(0);
        if count == 0 {
            return _asyncio_Future___init___impl(receiver, Py_None);
        }
        if count == 1 {
            position: i64 = 0;
            key: ptr[PyObject] = NULL;
            value: ptr[PyObject] = NULL;
            PyDict_Next(kwargs, &mut position, &mut key, &mut value);
            if key == ids.kw_loop {
                return _asyncio_Future___init___impl(receiver, value);
            }
        }
    }
    return _asyncio_Future___init___init(receiver, args, kwargs);
}

impl fast_task_init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    if PyTuple_Size(args) != 1 {
        return _asyncio_Task___init___init(receiver, args, kwargs);
    }
    loop = Py_None;
    name = Py_None;
    context = Py_None;
    eager: ptr[PyObject] = NULL;
    if kwargs {
        position: i64 = 0;
        key: ptr[PyObject] = NULL;
        value: ptr[PyObject] = NULL;
        while PyDict_Next(kwargs, &mut position, &mut key, &mut value) != 0 {
            if key == ids.kw_loop {
                loop = value;
            } elif key == ids.kw_name {
                name = value;
            } elif key == ids.kw_context {
                context = value;
            } elif key == ids.kw_eager_start {
                eager = value;
            } else {
                return _asyncio_Task___init___init(receiver, args, kwargs);
            }
        }
    }
    eager_start = False;
    if eager {
        truth = int(PyObject_IsTrue(eager));
        if truth < 0 {
            return i32(-1);
        }
        eager_start = truth != 0;
    }
    return _asyncio_Task___init___impl(
        receiver, PyTuple_GetItem(args, 0), loop, name, context, eager_start
    );
}

impl with_fast_paths(table: list[MethodDefinition]) -> list[MethodDefinition] {
    methods: list[MethodDefinition] = [];
    for method in table {
        callbacks = method.callbacks;
        if method.name == "done" {
            callbacks = MethodCallbacks(positional=fast_done);
        } elif method.name == "cancelled" {
            callbacks = MethodCallbacks(positional=fast_cancelled);
        } elif method.name == "result" {
            callbacks = MethodCallbacks(positional=fast_result);
        } elif method.name == "exception" {
            ptr[KeywordsCall](
                __thread_local_block("jac_bindings_asyncio_exception_glue", 8)
            ).view(
                1
            )[0].call = method.callbacks.fast_keywords;
            callbacks = MethodCallbacks(fast_keywords=fast_exception);
        } elif method.name == "get_loop" {
            addressof(get_loop_glue).view(1)[0].call = method.callbacks.fast_keywords;
            callbacks = MethodCallbacks(fast_keywords=fast_get_loop);
        } elif method.name == "set_result" {
            addressof(set_result_glue).view(1)[0].call = method.callbacks.fast_keywords;
            callbacks = MethodCallbacks(fast_keywords=fast_set_result);
        } elif method.name == "add_done_callback" {
            addressof(add_done_callback_glue).view(1)[0].call = method.callbacks.fast_keywords;
            callbacks = MethodCallbacks(fast_keywords=fast_add_done_callback);
        }
        methods.append(
            MethodDefinition(method.name, callbacks, method.doc, method.flags)
        );
    }
    return methods;
}

impl module_functions -> list[MethodDefinition] {
    methods: list[MethodDefinition] = [];
    for method in module_methods {
        callbacks = method.callbacks;
        if method.name == "future_add_to_awaited_by" {
            addressof(add_awaited_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=fast_add_to_awaited_by);
        } elif method.name == "future_discard_from_awaited_by" {
            addressof(discard_awaited_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=fast_discard_from_awaited_by);
        }
        methods.append(
            MethodDefinition(method.name, callbacks, method.doc, method.flags)
        );
    }
    return methods;
}

impl select_methods(
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

impl select_properties(
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

impl class_getitem_method(doc: str) -> MethodDefinition {
    return MethodDefinition(
        "__class_getitem__", MethodCallbacks(positional=Py_GenericAlias), doc, 24
    );
}

impl fill_slots(
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

impl install_tables -> bool {
    if tables_ready != 0 {
        return True;
    }
    future_methods = select_methods(
        with_fast_paths(Future_methods),
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
        with_fast_paths(Future_methods),
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

impl set_state(module: ptr[PyObject], index: int, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    jacpy_release(value);
    return True;
}

impl set_attribute_state(
    module: ptr[PyObject], index: int, source: ptr[PyObject], name: str
) -> bool {
    return set_state(module, index, jacpy_object_getattr_text(source, name));
}

impl module_init(module: ptr[PyObject]) -> bool {
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
    weak_set = PyObject_GetAttrString(weakref, ptr[u8]("WeakSet"));
    jacpy_release(weakref);
    if not weak_set {
        return False;
    }
    tasks = PyObject_CallNoArgs(weak_set);
    jacpy_release(weak_set);
    return set_state(module, STATE_NON_ASYNCIO_TASKS, tasks)
        and set_state(module, STATE_NON_ASYNCIO_EAGER_TASKS, PySet_New(NULL));
}

impl create_type(
    module: ptr[PyObject], index: int, spec: ptr[PyType_Spec], base: ptr[PyObject]
) -> bool {
    return set_state(module, index, PyType_FromModuleAndSpec(module, spec, base));
}

impl execute(module: ptr[PyObject]) -> i32 {
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

    if not module_init(module) {
        return i32(-1);
    }
    return i32(0);
}

impl module_clear(module: ptr[PyObject]) -> i32 {
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

impl module_free(module: ptr[PyObject]) {
    module_clear(module);
}

impl PyInit__asyncio -> ptr[PyObject] {
    return definition.initialize();
}
