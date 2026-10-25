import from c {
    def _PyImport_GetModules(interp: ptr[u8]) -> ptr[PyObject];  def _PyImport_BlessMyLoader(
        interp: ptr[u8], module_globals: ptr[PyObject]
    ) -> ptr[PyObject];  def PyThreadState_GetFrame(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PySys_GetOptionalAttr(
        name: ptr[PyObject], value: &mut ptr[PyObject]
    ) -> i32;  def PyUnicode_FromFormatV(
        format: ptr[u8], vargs: VaList
    ) -> ptr[PyObject];  def jacpy_stdio_stream(stream: i32) -> ptr;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  obj WarningsStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject](),
            s8: ptr[PyObject] = ptr[PyObject](),
            s9: ptr[PyObject] = ptr[PyObject](),
            s10: ptr[PyObject] = ptr[PyObject](),
            s11: ptr[PyObject] = ptr[PyObject](),
            s12: ptr[PyObject] = ptr[PyObject](),
            s13: ptr[PyObject] = ptr[PyObject](),
            s14: ptr[PyObject] = ptr[PyObject](),
            s15: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut WarningsStack) -> int;
}

glob:priv PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF;

def check_interp(interp: ptr[u8]) -> bool;

def get_current_interp -> ptr[u8];

def get_current_tstate -> ptr[PyThreadState];

def tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def warnings_get_state(interp: ptr[u8]) -> ptr[u8];

def state_slot(st: ptr[u8], offset: i64) -> ptr[ptr[PyObject]];

def state_get(st: ptr[u8], offset: i64) -> ptr[PyObject];

def state_setref(st: ptr[u8], offset: i64, value: ptr[PyObject]);

def state_clear(st: ptr[u8], offset: i64);

def filters_version_slot(st: ptr[u8]) -> ptr[i64];

def warnings_clear_state(st: ptr[u8]);

def create_filter(
    category: ptr[PyObject], action_str: ptr[PyObject], modname: ptr[u8]
) -> ptr[PyObject];

def init_filters(interp: ptr[u8]) -> ptr[PyObject];

def check_matched(interp: ptr[u8], obj_: ptr[PyObject], arg: ptr[PyObject]) -> i32;

def get_warnings_attr(
    interp: ptr[u8], attr: ptr[PyObject], try_import: bool
) -> ptr[PyObject];

def warnings_lock(interp: ptr[u8]);

def warnings_unlock(interp: ptr[u8]) -> i32;

def warnings_lock_held(st: ptr[u8]) -> bool;

def get_warnings_context(interp: ptr[u8]) -> ptr[PyObject];

def get_warnings_context_filters(interp: ptr[u8]) -> ptr[PyObject];

def get_warnings_filters(interp: ptr[u8]) -> ptr[PyObject];

def warnings_acquire_lock_impl(module: ptr[PyObject]) -> ptr[PyObject];

def warnings_release_lock_impl(module: ptr[PyObject]) -> ptr[PyObject];

def get_once_registry(interp: ptr[u8]) -> ptr[PyObject];

def get_default_action(interp: ptr[u8]) -> ptr[PyObject];

def filter_search(
    interp: ptr[u8],
    category: ptr[PyObject],
    text: ptr[PyObject],
    lineno: i64,
    module: ptr[PyObject],
    list_name: ptr[u8],
    filters: ptr[PyObject]
) -> tuple[bool, ptr[PyObject], ptr[PyObject]];

def get_filter(
    interp: ptr[u8],
    category: ptr[PyObject],
    text: ptr[PyObject],
    lineno: i64,
    module: ptr[PyObject]
) -> tuple[ptr[PyObject], ptr[PyObject]];

def already_warned(
    interp: ptr[u8], registry: ptr[PyObject], key: ptr[PyObject], should_set: bool
) -> i32;

def normalize_module(filename: ptr[PyObject]) -> ptr[PyObject];

def update_registry(
    interp: ptr[u8],
    registry: ptr[PyObject],
    text: ptr[PyObject],
    category: ptr[PyObject],
    add_zero: bool
) -> i32;

def show_warning(
    tstate: ptr[PyThreadState],
    filename: ptr[PyObject],
    lineno: i32,
    text: ptr[PyObject],
    category: ptr[PyObject],
    sourceline: ptr[PyObject]
);

def call_show_warning(
    tstate: ptr[PyThreadState],
    category: ptr[PyObject],
    text: ptr[PyObject],
    message: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    lineno_obj: ptr[PyObject],
    sourceline: ptr[PyObject],
    source: ptr[PyObject]
) -> i32;

def warn_explicit(
    tstate: ptr[PyThreadState],
    category_in: ptr[PyObject],
    message_in: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    module_in: ptr[PyObject],
    registry_in: ptr[PyObject],
    sourceline: ptr[PyObject],
    source_in: ptr[PyObject]
) -> ptr[PyObject];

def get_frame_filename(frame: ptr[PyObject]) -> ptr[PyObject];

def is_internal_filename(filename: ptr[PyObject]) -> bool;

def is_filename_to_skip(
    filename: ptr[PyObject], skip_file_prefixes: ptr[PyObject]
) -> bool;

def is_internal_frame(frame: ptr[PyObject]) -> bool;

def next_external_frame(
    frame_in: ptr[PyObject], skip_file_prefixes: ptr[PyObject]
) -> ptr[PyObject];

def setup_context(
    stack_level_in: i64, skip_file_prefixes: ptr[PyObject]
) -> tuple[bool, ptr[PyObject], i32, ptr[PyObject], ptr[PyObject]];

def get_category(message: ptr[PyObject], category_in: ptr[PyObject]) -> ptr[PyObject];

def do_warn(
    message: ptr[PyObject],
    category: ptr[PyObject],
    stack_level: i64,
    source: ptr[PyObject],
    skip_file_prefixes: ptr[PyObject]
) -> ptr[PyObject];

def warnings_warn_impl(
    module: ptr[PyObject],
    message: ptr[PyObject],
    category_in: ptr[PyObject],
    stacklevel_in: i64,
    source: ptr[PyObject],
    skip_file_prefixes_in: ptr[PyObject]
) -> ptr[PyObject];

def get_source_line(
    interp: ptr[u8], module_globals: ptr[PyObject], lineno: i32
) -> ptr[PyObject];

def warnings_warn_explicit_impl(
    module: ptr[PyObject],
    message: ptr[PyObject],
    category: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    mod: ptr[PyObject],
    registry: ptr[PyObject],
    module_globals: ptr[PyObject],
    sourceobj: ptr[PyObject]
) -> ptr[PyObject];

def warnings_filters_mutated_lock_held_impl(module: ptr[PyObject]) -> ptr[PyObject];

def warn_unicode(
    category_in: ptr[PyObject],
    message: ptr[PyObject],
    stack_level: i64,
    source: ptr[PyObject]
) -> i32;

def warn_formatted(
    source: ptr[PyObject],
    category: ptr[PyObject],
    stack_level: i64,
    message: ptr[PyObject]
) -> i32;

def warnings_module_exec(module: ptr[PyObject]) -> i32;

import from c {
    def _PyWarnings_InitState(interp: ptr[u8]) -> i32 {
        st = warnings_get_state(interp);
        if not state_get(st, _warnings_runtime_state_FILTERS) {
            filters = init_filters(interp);
            state_slot(st, _warnings_runtime_state_FILTERS).view(1)[0] = filters;
            if not filters {
                return i32(-1);
            }
        }
        if not state_get(st, _warnings_runtime_state_ONCE_REGISTRY) {
            once_registry = PyDict_New();
            state_slot(st, _warnings_runtime_state_ONCE_REGISTRY).view(1)[0] = once_registry;
            if not once_registry {
                return i32(-1);
            }
        }
        if not state_get(st, _warnings_runtime_state_DEFAULT_ACTION) {
            default_action = PyUnicode_FromString(ptr[u8]("default"));
            state_slot(st, _warnings_runtime_state_DEFAULT_ACTION).view(1)[0] = default_action;
            if not default_action {
                return i32(-1);
            }
        }
        if not state_get(st, _warnings_runtime_state_CONTEXT) {
            context = PyContextVar_New(ptr[u8]("_warnings_context"), NULL);
            state_slot(st, _warnings_runtime_state_CONTEXT).view(1)[0] = context;
            if not context {
                return i32(-1);
            }
        }
        filters_version_slot(st).view(1)[0] = 0;
        return i32(0);
    }  def PyErr_WarnFormat(
        category: ptr[PyObject], stack_level: i64, format: ptr[u8], *vargs: VaList
    ) -> i32 {
        return warn_formatted(
            NULL, category, stack_level, PyUnicode_FromFormatV(format, vargs)
        );
    }  def PyErr_ResourceWarning(
        source: ptr[PyObject], stack_level: i64, format: ptr[u8], *vargs: VaList
    ) -> i32 {
        return warn_formatted(
            source,
            PyExc_ResourceWarning,
            stack_level,
            PyUnicode_FromFormatV(format, vargs)
        );
    }  def PyErr_WarnEx(
        category: ptr[PyObject], text: ptr[u8], stack_level: i64
    ) -> i32 {
        message = PyUnicode_FromString(text);
        if not message {
            return i32(-1);
        }
        ret = warn_unicode(category, message, stack_level, NULL);
        object_decref(message);
        return ret;
    }  def PyErr_Warn(category: ptr[PyObject], text: ptr[u8]) -> i32 {
        return PyErr_WarnEx(category, text, 1);
    }  def PyErr_WarnExplicitObject(
        category_in: ptr[PyObject],
        message: ptr[PyObject],
        filename: ptr[PyObject],
        lineno: i32,
        module: ptr[PyObject],
        registry: ptr[PyObject]
    ) -> i32 {
        category = category_in;
        if not category {
            category = PyExc_RuntimeWarning;
        }
        tstate = get_current_tstate();
        if not tstate {
            return i32(-1);
        }
        interp = tstate_interp(tstate);
        warnings_lock(interp);
        res = warn_explicit(
            tstate, category, message, filename, lineno, module, registry, NULL, NULL
        );
        warnings_unlock(interp);
        if not res {
            return i32(-1);
        }
        object_decref(res);
        return i32(0);
    }  def PyErr_WarnExplicit(
        category: ptr[PyObject],
        text: ptr[u8],
        filename_str: ptr[u8],
        lineno: i32,
        module_str: ptr[u8],
        registry: ptr[PyObject]
    ) -> i32 {
        message = PyUnicode_FromString(text);
        if not message {
            return i32(-1);
        }
        filename = PyUnicode_DecodeFSDefault(filename_str);
        if not filename {
            object_decref(message);
            return i32(-1);
        }
        module = NULL;
        if module_str {
            module = PyUnicode_FromString(module_str);
            if not module {
                object_decref(filename);
                object_decref(message);
                return i32(-1);
            }
        }
        ret = PyErr_WarnExplicitObject(
            category, message, filename, lineno, module, registry
        );
        object_xdecref(module);
        object_decref(filename);
        object_decref(message);
        return ret;
    }  def PyErr_WarnExplicitFormat(
        category: ptr[PyObject],
        filename_str: ptr[u8],
        lineno: i32,
        module_str: ptr[u8],
        registry: ptr[PyObject],
        format: ptr[u8],
        *vargs: VaList
    ) -> i32 {
        module = NULL;
        ret = i32(-1);
        filename = PyUnicode_DecodeFSDefault(filename_str);
        if filename {
            failed = False;
            if module_str {
                module = PyUnicode_FromString(module_str);
                if not module {
                    failed = True;
                }
            }
            if not failed {
                message = PyUnicode_FromFormatV(format, vargs);
                if message {
                    tstate = get_current_tstate();
                    if tstate {
                        interp = tstate_interp(tstate);
                        warnings_lock(interp);
                        res = warn_explicit(
                            tstate,
                            category,
                            message,
                            filename,
                            lineno,
                            module,
                            registry,
                            NULL,
                            NULL
                        );
                        warnings_unlock(interp);
                        object_decref(message);
                        if res {
                            object_decref(res);
                            ret = i32(0);
                        }
                    }
                }
            }
        }
        object_xdecref(module);
        object_xdecref(filename);
        return ret;
    }  def _PyErr_WarnUnawaitedAgenMethod(agen: ptr[PyObject], method: ptr[PyObject]) {
        exc = PyErr_GetRaisedException();
        ag_qualname = ptr[ptr[PyObject]](ptr[u8](agen) + PyGenObject_QUALNAME).view(1)[
            0
        ];
        if warn_formatted(
            agen,
            PyExc_RuntimeWarning,
            1,
            PyUnicode_FromFormat(
                "coroutine method %R of %R was never awaited", method, ag_qualname
            )
        )
            < i32(0) {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while finalizing async generator %R"), agen
            );
        }
        PyErr_SetRaisedException(exc);
    }  def _PyErr_WarnUnawaitedCoroutine(coro: ptr[PyObject]) {
        warned = False;
        interp = current_interp();
        fn = get_warnings_attr(interp, py_id(_Py_ID__warn_unawaited_coroutine), True);
        if fn {
            res = PyObject_CallOneArg(fn, coro);
            object_decref(fn);
            if res or PyErr_ExceptionMatches(PyExc_RuntimeWarning) != i32(0) {
                warned = True;
            }
            object_xdecref(res);
        }
        if PyErr_Occurred() {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while finalizing coroutine %R"), coro
            );
        }
        if not warned {
            cr_qualname = ptr[ptr[PyObject]](ptr[u8](coro) + PyGenObject_QUALNAME).view(
                1
            )[0];
            if warn_formatted(
                coro,
                PyExc_RuntimeWarning,
                1,
                PyUnicode_FromFormat("coroutine '%S' was never awaited", cr_qualname)
            )
                < i32(0) {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while finalizing coroutine %R"), coro
                );
            }
        }
    }  def _PyWarnings_Fini(interp: ptr[u8]) {
        warnings_clear_state(warnings_get_state(interp));
    }
}

impl check_interp(interp: ptr[u8]) -> bool {
    if not interp {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8]("warnings_get_state: could not identify current interpreter")
        );
        return False;
    }
    return True;
}

impl get_current_interp -> ptr[u8] {
    interp = current_interp();
    if check_interp(interp) {
        return interp;
    }
    return ptr[u8]();
}

impl get_current_tstate -> ptr[PyThreadState] {
    tstate = current_tstate();
    if not tstate {
        check_interp(ptr[u8]());
        return ptr[PyThreadState]();
    }
    if check_interp(tstate_interp(tstate)) {
        return tstate;
    }
    return ptr[PyThreadState]();
}

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl warnings_get_state(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_WARNINGS;
}

impl state_slot(st: ptr[u8], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](st + offset);
}

impl state_get(st: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](st + offset).view(1)[0];
}

impl state_setref(st: ptr[u8], offset: i64, value: ptr[PyObject]) {
    slot = state_slot(st, offset);
    old = slot.view(1)[0];
    slot.view(1)[0] = value;
    object_xdecref(old);
}

impl state_clear(st: ptr[u8], offset: i64) {
    slot = state_slot(st, offset);
    old = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(old);
}

impl filters_version_slot(st: ptr[u8]) -> ptr[i64] {
    return ptr[i64](st + _warnings_runtime_state_FILTERS_VERSION);
}

impl warnings_clear_state(st: ptr[u8]) {
    state_clear(st, _warnings_runtime_state_FILTERS);
    state_clear(st, _warnings_runtime_state_ONCE_REGISTRY);
    state_clear(st, _warnings_runtime_state_DEFAULT_ACTION);
    state_clear(st, _warnings_runtime_state_CONTEXT);
}

impl create_filter(
    category: ptr[PyObject], action_str: ptr[PyObject], modname: ptr[u8]
) -> ptr[PyObject] {
    modname_obj = NULL;

    if modname {
        modname_obj = PyUnicode_InternFromString(modname);
        if not modname_obj {
            return NULL;
        }
    } else {
        modname_obj = object_new_ref(Py_None);
    }

    filter = PyTuple_Pack(
        i64(5), action_str, Py_None, category, modname_obj, long_zero()
    );
    object_decref(modname_obj);
    return filter;
}

impl init_filters(interp: ptr[u8]) -> ptr[PyObject] {
    filters = PyList_New(5);
    if not filters {
        return NULL;
    }
    list_set_item(
        filters,
        0,
        create_filter(
            PyExc_DeprecationWarning, py_id(_Py_ID_default), ptr[u8]("__main__")
        )
    );
    list_set_item(
        filters,
        1,
        create_filter(PyExc_DeprecationWarning, py_id(_Py_ID_ignore), ptr[u8]())
    );
    list_set_item(
        filters,
        2,
        create_filter(PyExc_PendingDeprecationWarning, py_id(_Py_ID_ignore), ptr[u8]())
    );
    list_set_item(
        filters, 3, create_filter(PyExc_ImportWarning, py_id(_Py_ID_ignore), ptr[u8]())
    );
    list_set_item(
        filters,
        4,
        create_filter(PyExc_ResourceWarning, py_id(_Py_ID_ignore), ptr[u8]())
    );
    items = ptr[PyListObject](filters).view(1)[0].ob_item;
    x: i64 = 0;
    while x < 5 {
        if not (items + x).view(1)[0] {
            object_decref(filters);
            return NULL;
        }
        x += 1;
    }
    return filters;
}

impl check_matched(interp: ptr[u8], obj_: ptr[PyObject], arg: ptr[PyObject]) -> i32 {
    if obj_ == Py_None {
        return i32(1);
    }

    if unicode_check_exact(obj_) {
        cmp_result = PyUnicode_Compare(obj_, arg);
        if cmp_result == i32(-1) and PyErr_Occurred() {
            return i32(-1);
        }
        return i32(1) if cmp_result == i32(0) else i32(0);
    }

    slots: own WarningsStack = WarningsStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = obj_;
    stack.view(2)[1] = arg;
    result = PyObject_VectorcallMethod(
        py_id(_Py_ID_match), stack, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
    if not result {
        return i32(-1);
    }
    rc = PyObject_IsTrue(result);
    object_decref(result);
    return rc;
}

impl get_warnings_attr(
    interp: ptr[u8], attr: ptr[PyObject], try_import: bool
) -> ptr[PyObject] {
    warnings_module = NULL;

    if try_import
        and _Py_IsInterpreterFinalizing(ptr[PyInterpreterState](interp)) == i32(0) {
        warnings_module = PyImport_Import(py_id(_Py_ID_warnings));
        if not warnings_module {
            if PyErr_ExceptionMatches(PyExc_ImportError) != i32(0) {
                PyErr_Clear();
            }
            return NULL;
        }
    } else {
        if not _PyImport_GetModules(interp) {
            return NULL;
        }
        warnings_module = PyImport_GetModule(py_id(_Py_ID_warnings));
        if not warnings_module {
            return NULL;
        }
    }
    obj_ = NULL;
    PyObject_GetOptionalAttr(warnings_module, attr, &mut obj_);
    object_decref(warnings_module);
    return obj_;
}

impl warnings_lock(interp: ptr[u8]) {
    _PyRecursiveMutex_Lock(warnings_get_state(interp) + _warnings_runtime_state_LOCK);
}

impl warnings_unlock(interp: ptr[u8]) -> i32 {
    return _PyRecursiveMutex_TryUnlock(
        warnings_get_state(interp) + _warnings_runtime_state_LOCK
    );
}

impl warnings_lock_held(st: ptr[u8]) -> bool {
    return (load_u8(int(st + _warnings_runtime_state_LOCK)) & _Py_LOCKED) != u8(0);
}

impl get_warnings_context(interp: ptr[u8]) -> ptr[PyObject] {
    st = warnings_get_state(interp);
    ctx = NULL;
    if PyContextVar_Get(state_get(st, _warnings_runtime_state_CONTEXT), NULL, &mut ctx)
        < i32(0) {
        return NULL;
    }
    if not ctx {
        return object_new_ref(Py_None);
    }
    return ctx;
}

impl get_warnings_context_filters(interp: ptr[u8]) -> ptr[PyObject] {
    ctx = get_warnings_context(interp);
    if not ctx {
        return NULL;
    }
    if ctx == Py_None {
        return object_new_ref(Py_None);
    }
    context_filters = PyObject_GetAttr(ctx, py_id(_Py_ID__filters));
    object_decref(ctx);
    if not context_filters {
        return NULL;
    }
    if not list_check(context_filters) {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("_filters of warnings._warnings_context must be a list")
        );
        object_decref(context_filters);
        return NULL;
    }
    return context_filters;
}

impl get_warnings_filters(interp: ptr[u8]) -> ptr[PyObject] {
    st = warnings_get_state(interp);
    warnings_filters = get_warnings_attr(interp, py_id(_Py_ID_filters), False);
    if not warnings_filters {
        if PyErr_Occurred() {
            return NULL;
        }
    } else {
        state_setref(st, _warnings_runtime_state_FILTERS, warnings_filters);
    }
    filters = state_get(st, _warnings_runtime_state_FILTERS);
    if not filters or not list_check(filters) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("_warnings.filters must be a list"));
        return NULL;
    }
    return filters;
}

impl warnings_acquire_lock_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = get_current_interp();
    if not interp {
        return NULL;
    }
    warnings_lock(interp);
    return object_new_ref(Py_None);
}

impl warnings_release_lock_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = get_current_interp();
    if not interp {
        return NULL;
    }
    if warnings_unlock(interp) < i32(0) {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("cannot release un-acquired lock"));
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl get_once_registry(interp: ptr[u8]) -> ptr[PyObject] {
    st = warnings_get_state(interp);
    registry = get_warnings_attr(interp, py_id(_Py_ID_onceregistry), False);
    if not registry {
        if PyErr_Occurred() {
            return NULL;
        }
        return state_get(st, _warnings_runtime_state_ONCE_REGISTRY);
    }
    if not dict_check(registry) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("_warnings.onceregistry must be a dict, not '%.200s'"),
            object_type(registry).view(1)[0].tp_name
        );
        object_decref(registry);
        return NULL;
    }
    state_setref(st, _warnings_runtime_state_ONCE_REGISTRY, registry);
    return registry;
}

impl get_default_action(interp: ptr[u8]) -> ptr[PyObject] {
    st = warnings_get_state(interp);
    default_action = get_warnings_attr(interp, py_id(_Py_ID_defaultaction), False);
    if not default_action {
        if PyErr_Occurred() {
            return NULL;
        }
        return state_get(st, _warnings_runtime_state_DEFAULT_ACTION);
    }
    if not unicode_check(default_action) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("_warnings.defaultaction must be a string, not '%.200s'"),
            object_type(default_action).view(1)[0].tp_name
        );
        object_decref(default_action);
        return NULL;
    }
    state_setref(st, _warnings_runtime_state_DEFAULT_ACTION, default_action);
    return default_action;
}

impl filter_search(
    interp: ptr[u8],
    category: ptr[PyObject],
    text: ptr[PyObject],
    lineno: i64,
    module: ptr[PyObject],
    list_name: ptr[u8],
    filters: ptr[PyObject]
) -> tuple[bool, ptr[PyObject], ptr[PyObject]] {
    i: i64 = 0;
    while i < object_size(filters) {
        tmp_item = (ptr[PyListObject](filters).view(1)[0].ob_item + i).view(1)[0];
        if not tuple_check(tmp_item) or object_size(tmp_item) != 5 {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("warnings.%s item %zd isn't a 5-tuple"),
                list_name,
                i
            );
            return (False, NULL, NULL);
        }

        object_incref(tmp_item);
        action = tuple_get_item(tmp_item, 0);
        msg = tuple_get_item(tmp_item, 1);
        cat = tuple_get_item(tmp_item, 2);
        mod = tuple_get_item(tmp_item, 3);
        ln_obj = tuple_get_item(tmp_item, 4);
        if not unicode_check(action) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("action must be a string, not '%.200s'"),
                object_type(action).view(1)[0].tp_name
            );
            object_decref(tmp_item);
            return (False, NULL, NULL);
        }
        good_msg = check_matched(interp, msg, text);
        if good_msg == i32(-1) {
            object_decref(tmp_item);
            return (False, NULL, NULL);
        }
        good_mod = check_matched(interp, mod, module);
        if good_mod == i32(-1) {
            object_decref(tmp_item);
            return (False, NULL, NULL);
        }
        is_subclass = PyObject_IsSubclass(category, cat);
        if is_subclass == i32(-1) {
            object_decref(tmp_item);
            return (False, NULL, NULL);
        }
        ln = PyLong_AsSsize_t(ln_obj);
        if ln == -1 and PyErr_Occurred() {
            object_decref(tmp_item);
            return (False, NULL, NULL);
        }
        if good_msg != i32(0)
            and is_subclass != i32(0)
            and good_mod != i32(0)
            and (ln == 0 or lineno == ln) {
            return (True, tmp_item, action);
        }
        object_decref(tmp_item);
        i += 1;
    }
    return (True, NULL, NULL);
}

impl get_filter(
    interp: ptr[u8],
    category: ptr[PyObject],
    text: ptr[PyObject],
    lineno: i64,
    module: ptr[PyObject]
) -> tuple[ptr[PyObject], ptr[PyObject]] {
    context_filters = get_warnings_context_filters(interp);
    if not context_filters {
        return (NULL, NULL);
    }
    use_global_filters = False;
    if context_filters == Py_None {
        use_global_filters = True;
    } else {
        (ok, item, context_action) = filter_search(
            interp,
            category,
            text,
            lineno,
            module,
            ptr[u8]("_warnings_context _filters"),
            context_filters
        );
        if not ok {
            object_decref(context_filters);
            return (NULL, NULL);
        }
        object_decref(context_filters);
        if context_action {
            return (context_action, item);
        }
    }
    if use_global_filters {
        filters = get_warnings_filters(interp);
        if not filters {
            return (NULL, NULL);
        }
        (found, global_item, action) = filter_search(
            interp, category, text, lineno, module, ptr[u8]("filters"), filters
        );
        if not found {
            return (NULL, NULL);
        }
        if action {
            return (action, global_item);
        }
    }
    default_action = get_default_action(interp);
    if default_action {
        return (default_action, object_new_ref(Py_None));
    }
    return (NULL, NULL);
}

impl already_warned(
    interp: ptr[u8], registry: ptr[PyObject], key: ptr[PyObject], should_set: bool
) -> i32 {
    if not key {
        return i32(-1);
    }
    st = warnings_get_state(interp);
    version_obj = NULL;
    if PyDict_GetItemRef(registry, py_id(_Py_ID_version), &mut version_obj) < i32(0) {
        return i32(-1);
    }
    should_update_version = not version_obj
        or not long_check_exact(version_obj)
        or PyLong_AsLong(version_obj) != filters_version_slot(st).view(1)[0];
    object_xdecref(version_obj);
    if should_update_version {
        PyDict_Clear(registry);
        version_obj = PyLong_FromLong(filters_version_slot(st).view(1)[0]);
        if not version_obj {
            return i32(-1);
        }
        if PyDict_SetItem(registry, py_id(_Py_ID_version), version_obj) < i32(0) {
            object_decref(version_obj);
            return i32(-1);
        }
        object_decref(version_obj);
    } else {
        already = NULL;
        if PyDict_GetItemRef(registry, key, &mut already) < i32(0) {
            return i32(-1);
        }
        if already {
            rc = PyObject_IsTrue(already);
            object_decref(already);
            if rc != i32(0) {
                return rc;
            }
        }
    }

    if should_set {
        return PyDict_SetItem(registry, key, ptr[PyObject](addressof(_Py_TrueStruct)));
    }
    return i32(0);
}

impl normalize_module(filename: ptr[PyObject]) -> ptr[PyObject] {
    length = PyUnicode_GetLength(filename);
    if length < 0 {
        return NULL;
    }
    if length == 0 {
        return PyUnicode_FromString(ptr[u8]("<unknown>"));
    }

    if length >= 3
        and uo_read_char(filename, length - 3) == u32(46)
        and uo_read_char(filename, length - 2) == u32(112)
        and uo_read_char(filename, length - 1) == u32(121) {
        return PyUnicode_Substring(filename, 0, length - 3);
    }
    return object_new_ref(filename);
}

impl update_registry(
    interp: ptr[u8],
    registry: ptr[PyObject],
    text: ptr[PyObject],
    category: ptr[PyObject],
    add_zero: bool
) -> i32 {
    altkey = NULL;
    if add_zero {
        altkey = PyTuple_Pack(i64(3), text, category, long_zero());
    } else {
        altkey = PyTuple_Pack(i64(2), text, category);
    }
    rc = already_warned(interp, registry, altkey, True);
    object_xdecref(altkey);
    return rc;
}

impl show_warning(
    tstate: ptr[PyThreadState],
    filename: ptr[PyObject],
    lineno: i32,
    text: ptr[PyObject],
    category: ptr[PyObject],
    sourceline: ptr[PyObject]
) {
    f_stderr = NULL;
    slots: own WarningsStack = WarningsStack();
    lineno_str = ptr[u8](jacpy_stack_address(&mut slots));
    PyOS_snprintf(lineno_str, u64(128), ptr[u8](":%d: "), lineno);
    name = PyObject_GetAttr(category, py_id(_Py_ID___name__));
    while True {
        if not name {
            break;
        }
        if _PySys_GetOptionalAttr(py_id(_Py_ID_stderr), &mut f_stderr) <= i32(0) {
            fputs(ptr[u8]("lost sys.stderr\n"), jacpy_stdio_stream(i32(2)));
            break;
        }

        if PyFile_WriteObject(filename, f_stderr, Py_PRINT_RAW) < i32(0)
            or PyFile_WriteString(lineno_str, f_stderr) < i32(0)
            or PyFile_WriteObject(name, f_stderr, Py_PRINT_RAW) < i32(0)
            or PyFile_WriteString(ptr[u8](": "), f_stderr) < i32(0)
            or PyFile_WriteObject(text, f_stderr, Py_PRINT_RAW) < i32(0)
            or PyFile_WriteString(ptr[u8]("\n"), f_stderr) < i32(0) {
            break;
        }
        old_name = name;
        name = NULL;
        object_decref(old_name);

        if sourceline {
            length = unicode_length(sourceline);
            i: i64 = 0;
            while i < length {
                ch = uo_read_char(sourceline, i);
                if ch != u32(32) and ch != u32(9) and ch != u32(12) {
                    break;
                }
                i += 1;
            }
            truncated = PyUnicode_Substring(sourceline, i, length);
            if not truncated {
                break;
            }
            PyFile_WriteObject(sourceline, f_stderr, Py_PRINT_RAW);
            object_decref(truncated);
            PyFile_WriteString(ptr[u8]("\n"), f_stderr);
        } else {
            _Py_DisplaySourceLine(
                f_stderr, filename, lineno, i32(2), ptr[i32](), ptr[ptr[PyObject]]()
            );
        }
        break;
    }
    object_xdecref(f_stderr);
    object_xdecref(name);
    PyErr_Clear();
}

impl call_show_warning(
    tstate: ptr[PyThreadState],
    category: ptr[PyObject],
    text: ptr[PyObject],
    message: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    lineno_obj: ptr[PyObject],
    sourceline: ptr[PyObject],
    source: ptr[PyObject]
) -> i32 {
    interp = tstate_interp(tstate);

    show_fn = get_warnings_attr(interp, py_id(_Py_ID__showwarnmsg), True);
    if not show_fn {
        if PyErr_Occurred() {
            return i32(-1);
        }
        show_warning(tstate, filename, lineno, text, category, sourceline);
        return i32(0);
    }
    if PyCallable_Check(show_fn) == i32(0) {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8]("warnings._showwarnmsg() must be set to a callable")
        );
        object_xdecref(show_fn);
        return i32(-1);
    }
    warnmsg_cls = get_warnings_attr(interp, py_id(_Py_ID_WarningMessage), False);
    if not warnmsg_cls {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("unable to get warnings.WarningMessage")
            );
        }
        object_xdecref(show_fn);
        return i32(-1);
    }
    msg = PyObject_CallFunctionObjArgs(
        warnmsg_cls,
        message,
        category,
        filename,
        lineno_obj,
        Py_None,
        Py_None,
        source,
        NULL
    );
    object_decref(warnmsg_cls);
    if not msg {
        object_xdecref(show_fn);
        return i32(-1);
    }
    res = PyObject_CallOneArg(show_fn, msg);
    object_decref(show_fn);
    object_decref(msg);
    if not res {
        return i32(-1);
    }
    object_decref(res);
    return i32(0);
}

impl warn_explicit(
    tstate: ptr[PyThreadState],
    category_in: ptr[PyObject],
    message_in: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    module_in: ptr[PyObject],
    registry_in: ptr[PyObject],
    sourceline: ptr[PyObject],
    source_in: ptr[PyObject]
) -> ptr[PyObject] {
    interp = tstate_interp(tstate);
    category = category_in;
    message = message_in;
    module = module_in;
    registry = registry_in;
    source = source_in;

    if module == Py_None {
        return object_new_ref(Py_None);
    }
    if registry and not dict_check(registry) and registry != Py_None {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("'registry' must be a dict or None"));
        return NULL;
    }

    if not module {
        module = normalize_module(filename);
        if not module {
            return NULL;
        }
    } else {
        object_incref(module);
    }
    key = NULL;
    text = NULL;
    result = NULL;
    lineno_obj = NULL;
    item = NULL;

    object_incref(message);
    while True {
        rc = PyObject_IsInstance(message, PyExc_Warning);
        if rc == i32(-1) {
            break;
        }
        if rc == i32(1) {
            text = PyObject_Str(message);
            if not text {
                break;
            }
            category = ptr[PyObject](object_type(message));
        } else {
            text = message;
            message = PyObject_CallOneArg(category, message);
            if not message {
                break;
            }
        }
        lineno_obj = PyLong_FromLong(i64(lineno));
        if not lineno_obj {
            break;
        }
        if source == Py_None {
            source = NULL;
        }

        key = PyTuple_Pack(i64(3), text, category, lineno_obj);
        if not key {
            break;
        }
        if registry and registry != Py_None {
            rc = already_warned(interp, registry, key, False);
            if rc == i32(-1) {
                break;
            } elif rc == i32(1) {
                result = object_new_ref(Py_None);
                break;
            }
        }
        (action, chosen_item) = get_filter(interp, category, text, i64(lineno), module);
        item = chosen_item;
        if not action {
            break;
        }
        if _PyUnicode_EqualToASCIIString(action, ptr[u8]("error")) != i32(0) {
            PyErr_SetObject(category, message);
            break;
        }
        if _PyUnicode_EqualToASCIIString(action, ptr[u8]("ignore")) != i32(0) {
            result = object_new_ref(Py_None);
            break;
        }

        rc = i32(0);
        failed = False;
        if _PyUnicode_EqualToASCIIString(action, ptr[u8]("always")) == i32(0)
            and _PyUnicode_EqualToASCIIString(action, ptr[u8]("all")) == i32(0) {
            if registry
                and registry != Py_None
                and PyDict_SetItem(
                    registry, key, ptr[PyObject](addressof(_Py_TrueStruct))
                )
                    < i32(0) {
                break;
            }
            if _PyUnicode_EqualToASCIIString(action, ptr[u8]("once")) != i32(0) {
                if not registry or registry == Py_None {
                    registry = get_once_registry(interp);
                    if not registry {
                        failed = True;
                    }
                }
                if not failed {
                    rc = update_registry(interp, registry, text, category, False);
                }
            } elif _PyUnicode_EqualToASCIIString(action, ptr[u8]("module")) != i32(0) {
                if registry and registry != Py_None {
                    rc = update_registry(interp, registry, text, category, False);
                }
            } elif _PyUnicode_EqualToASCIIString(action, ptr[u8]("default"))
                == i32(0) {
                PyErr_Format(
                    PyExc_RuntimeError,
                    ptr[u8]("Unrecognized action (%R) in warnings.filters:\n %R"),
                    action,
                    item
                );
                failed = True;
            }
        }
        if failed {
            break;
        }
        if rc == i32(1) {
            result = object_new_ref(Py_None);
            break;
        }
        if rc == i32(0) {
            if call_show_warning(
                tstate,
                category,
                text,
                message,
                filename,
                lineno,
                lineno_obj,
                sourceline,
                source
            )
                < i32(0) {
                break;
            }
        } else {
            break;
        }
        result = object_new_ref(Py_None);
        break;
    }
    object_xdecref(item);
    object_xdecref(key);
    object_xdecref(text);
    object_xdecref(lineno_obj);
    object_decref(module);
    object_xdecref(message);

    return result;
}

impl get_frame_filename(frame: ptr[PyObject]) -> ptr[PyObject] {
    code = PyFrame_GetCode(frame);
    filename = ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_FILENAME).view(1)[0];
    object_decref(code);
    return filename;
}

impl is_internal_filename(filename: ptr[PyObject]) -> bool {
    if not unicode_check(filename) {
        return False;
    }
    contains = PyUnicode_Contains(filename, py_id(_Py_ID_importlib));
    if contains < i32(0) {
        return False;
    } elif contains > i32(0) {
        contains = PyUnicode_Contains(filename, py_id(_Py_ID__bootstrap));
        if contains < i32(0) {
            return False;
        } elif contains > i32(0) {
            return True;
        }
    }
    return False;
}

impl is_filename_to_skip(
    filename: ptr[PyObject], skip_file_prefixes: ptr[PyObject]
) -> bool {
    if skip_file_prefixes {
        if not unicode_check(filename) {
            return False;
        }
        prefixes = object_size(skip_file_prefixes);
        idx: i64 = 0;
        while idx < prefixes {
            prefix = tuple_get_item(skip_file_prefixes, idx);
            found = PyUnicode_Tailmatch(filename, prefix, 0, PY_SSIZE_T_MAX, i32(-1));
            if found == 1 {
                return True;
            }
            if found < 0 {
                return False;
            }
            idx += 1;
        }
    }
    return False;
}

impl is_internal_frame(frame: ptr[PyObject]) -> bool {
    if not frame {
        return False;
    }
    filename = get_frame_filename(frame);
    if not filename {
        return False;
    }
    return is_internal_filename(filename);
}

impl next_external_frame(
    frame_in: ptr[PyObject], skip_file_prefixes: ptr[PyObject]
) -> ptr[PyObject] {
    frame = frame_in;
    while True {
        back = PyFrame_GetBack(frame);
        old = frame;
        frame = back;
        object_decref(old);
        if not frame {
            break;
        }
        frame_filename = get_frame_filename(frame);
        if not frame_filename {
            break;
        }
        if not (
            is_internal_filename(frame_filename)
            or is_filename_to_skip(frame_filename, skip_file_prefixes)
        ) {
            break;
        }
    }
    return frame;
}

impl setup_context(
    stack_level_in: i64, skip_file_prefixes: ptr[PyObject]
) -> tuple[bool, ptr[PyObject], i32, ptr[PyObject], ptr[PyObject]] {
    stack_level = stack_level_in;

    tstate = get_current_tstate();
    if not tstate {
        return (False, NULL, i32(0), NULL, NULL);
    }
    if skip_file_prefixes {
        prefixes = object_size(skip_file_prefixes);
        idx: i64 = 0;
        while idx < prefixes {
            prefix = tuple_get_item(skip_file_prefixes, idx);
            if not unicode_check(prefix) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("Found non-str '%s' in skip_file_prefixes."),
                    object_type(prefix).view(1)[0].tp_name
                );
                return (False, NULL, i32(0), NULL, NULL);
            }
            idx += 1;
        }
    }
    interp = tstate_interp(tstate);
    f = PyThreadState_GetFrame(tstate);

    if stack_level <= 0 or is_internal_frame(f) {
        while True {
            stack_level -= 1;
            if not (stack_level > 0 and f) {
                break;
            }
            back = PyFrame_GetBack(f);
            old = f;
            f = back;
            object_decref(old);
        }
    } else {
        while True {
            stack_level -= 1;
            if not (stack_level > 0 and f) {
                break;
            }
            f = next_external_frame(f, skip_file_prefixes);
        }
    }
    globals = NULL;
    filename = NULL;
    lineno = i32(0);
    if not f {
        globals = ptr[ptr[PyObject]](interp + PyInterpreterState_SYSDICT).view(1)[0];
        filename = PyUnicode_FromString(ptr[u8]("<sys>"));
        lineno = i32(0);
    } else {
        iframe = ptr[ptr[u8]](ptr[u8](f) + PyFrameObject_F_FRAME).view(1)[0];
        globals = ptr[ptr[PyObject]](iframe + _PyInterpreterFrame_F_GLOBALS).view(1)[0];
        code = iframe_code(iframe);
        filename = object_new_ref(
            ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_FILENAME).view(1)[0]
        );
        lineno = PyFrame_GetLineNumber(f);
        object_decref(f);
    }
    module = NULL;
    registry = NULL;

    rc = PyDict_GetItemRef(globals, py_id(_Py_ID___warningregistry__), &mut registry);
    failed = rc < i32(0);
    if not failed and not registry {
        registry = PyDict_New();
        if not registry {
            failed = True;
        } elif PyDict_SetItem(globals, py_id(_Py_ID___warningregistry__), registry)
            < i32(0) {
            failed = True;
        }
    }
    if not failed {
        rc = PyDict_GetItemRef(globals, py_id(_Py_ID___name__), &mut module);
        if rc < i32(0) {
            failed = True;
        } else {
            if rc > i32(0) {
                if module == Py_None or unicode_check(module) {
                    return (True, filename, lineno, module, registry);
                }
                object_decref(module);
            }
            module = PyUnicode_FromString(ptr[u8]("<string>"));
            if not module {
                failed = True;
            } else {
                return (True, filename, lineno, module, registry);
            }
        }
    }
    object_xdecref(registry);
    object_xdecref(module);
    object_xdecref(filename);
    return (False, NULL, i32(0), NULL, NULL);
}

impl get_category(message: ptr[PyObject], category_in: ptr[PyObject]) -> ptr[PyObject] {
    category = category_in;

    rc = PyObject_IsInstance(message, PyExc_Warning);
    if rc == i32(-1) {
        return NULL;
    }
    if rc == i32(1) {
        category = ptr[PyObject](object_type(message));
    } elif not category or category == Py_None {
        category = PyExc_UserWarning;
    }

    rc = PyObject_IsSubclass(category, PyExc_Warning);

    if rc == i32(-1) or rc == i32(0) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("category must be a Warning subclass, not '%s'"),
            object_type(category).view(1)[0].tp_name
        );
        return NULL;
    }
    return category;
}

impl do_warn(
    message: ptr[PyObject],
    category: ptr[PyObject],
    stack_level: i64,
    source: ptr[PyObject],
    skip_file_prefixes: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = get_current_tstate();
    if not tstate {
        return NULL;
    }
    (ok, filename, lineno, module, registry) = setup_context(
        stack_level, skip_file_prefixes
    );
    if not ok {
        return NULL;
    }
    interp = tstate_interp(tstate);
    warnings_lock(interp);
    res = warn_explicit(
        tstate, category, message, filename, lineno, module, registry, NULL, source
    );
    warnings_unlock(interp);
    object_decref(filename);
    object_decref(registry);
    object_decref(module);
    return res;
}

impl warnings_warn_impl(
    module: ptr[PyObject],
    message: ptr[PyObject],
    category_in: ptr[PyObject],
    stacklevel_in: i64,
    source: ptr[PyObject],
    skip_file_prefixes_in: ptr[PyObject]
) -> ptr[PyObject] {
    stacklevel = stacklevel_in;
    skip_file_prefixes = skip_file_prefixes_in;
    category = get_category(message, category_in);
    if not category {
        return NULL;
    }
    if skip_file_prefixes {
        if object_size(skip_file_prefixes) > 0 {
            if stacklevel < 2 {
                stacklevel = 2;
            }
        } else {
            object_decref(skip_file_prefixes);
            skip_file_prefixes = NULL;
        }
    }
    return do_warn(message, category, stacklevel, source, skip_file_prefixes);
}

impl get_source_line(
    interp: ptr[u8], module_globals: ptr[PyObject], lineno: i32
) -> ptr[PyObject] {
    loader = _PyImport_BlessMyLoader(interp, module_globals);
    if not loader {
        return NULL;
    }
    module_name = NULL;
    rc = PyDict_GetItemRef(module_globals, py_id(_Py_ID___name__), &mut module_name);
    if rc < i32(0) or rc == i32(0) {
        object_decref(loader);
        return NULL;
    }

    get_source = NULL;
    PyObject_GetOptionalAttr(loader, py_id(_Py_ID_get_source), &mut get_source);
    object_decref(loader);
    if not get_source {
        object_decref(module_name);
        return NULL;
    }

    source = PyObject_CallOneArg(get_source, module_name);
    object_decref(get_source);
    object_decref(module_name);
    if not source {
        return NULL;
    }
    if source == Py_None {
        object_decref(source);
        return NULL;
    }

    source_list = PyUnicode_Splitlines(source, i32(0));
    object_decref(source);
    if not source_list {
        return NULL;
    }

    source_line = PyList_GetItem(source_list, i64(lineno) - 1);
    object_xincref(source_line);
    object_decref(source_list);
    return source_line;
}

impl warnings_warn_explicit_impl(
    module: ptr[PyObject],
    message: ptr[PyObject],
    category: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    mod: ptr[PyObject],
    registry: ptr[PyObject],
    module_globals: ptr[PyObject],
    sourceobj: ptr[PyObject]
) -> ptr[PyObject] {
    source_line = NULL;
    tstate = get_current_tstate();
    if not tstate {
        return NULL;
    }
    if module_globals and module_globals != Py_None {
        if not dict_check(module_globals) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("module_globals must be a dict, not '%.200s'"),
                object_type(module_globals).view(1)[0].tp_name
            );
            return NULL;
        }
        source_line = get_source_line(tstate_interp(tstate), module_globals, lineno);
        if not source_line and PyErr_Occurred() {
            return NULL;
        }
    }
    interp = tstate_interp(tstate);
    warnings_lock(interp);
    returned = warn_explicit(
        tstate,
        category,
        message,
        filename,
        lineno,
        mod,
        registry,
        source_line,
        sourceobj
    );
    warnings_unlock(interp);
    object_xdecref(source_line);
    return returned;
}

impl warnings_filters_mutated_lock_held_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    interp = get_current_interp();
    if not interp {
        return NULL;
    }
    st = warnings_get_state(interp);

    if not warnings_lock_held(st) {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("warnings lock is not held"));
        return NULL;
    }
    version = filters_version_slot(st);
    version.view(1)[0] = version.view(1)[0] + 1;
    return object_new_ref(Py_None);
}

impl warn_unicode(
    category_in: ptr[PyObject],
    message: ptr[PyObject],
    stack_level: i64,
    source: ptr[PyObject]
) -> i32 {
    category = category_in;
    if not category {
        category = PyExc_RuntimeWarning;
    }
    res = do_warn(message, category, stack_level, source, NULL);
    if not res {
        return i32(-1);
    }
    object_decref(res);
    return i32(0);
}

impl warn_formatted(
    source: ptr[PyObject],
    category: ptr[PyObject],
    stack_level: i64,
    message: ptr[PyObject]
) -> i32 {
    if not message {
        return i32(-1);
    }
    res = warn_unicode(category, message, stack_level, source);
    object_decref(message);
    return res;
}

impl warnings_module_exec(module: ptr[PyObject]) -> i32 {
    interp = get_current_interp();
    if not interp {
        return i32(-1);
    }
    st = warnings_get_state(interp);
    if PyModule_AddObjectRef(
        module, ptr[u8]("filters"), state_get(st, _warnings_runtime_state_FILTERS)
    )
        < i32(0) {
        return i32(-1);
    }
    if PyModule_AddObjectRef(
        module, ptr[u8]("_onceregistry"), state_get(st, _warnings_runtime_state_ONCE_REGISTRY)
    )
        < i32(0) {
        return i32(-1);
    }
    if PyModule_AddObjectRef(
        module, ptr[u8]("_defaultaction"), state_get(st, _warnings_runtime_state_DEFAULT_ACTION)
    )
        < i32(0) {
        return i32(-1);
    }
    if PyModule_AddObjectRef(
        module, ptr[u8]("_warnings_context"), state_get(st, _warnings_runtime_state_CONTEXT)
    )
        < i32(0) {
        return i32(-1);
    }
    return i32(0);
}
