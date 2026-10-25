import from c {
    def Py_HashPointer(p: ptr) -> i64;  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format_: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  def _PyErr_SetString(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], message: ptr[u8]
    );  obj ContextWatcherCall {
        has watcher: Callable[[i32, ptr[PyObject]], i32] = 0;
    }  glob:priv PyContext_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("get"),
                 ml_meth=ptr(_contextvars_Context_get),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "get($self, key, default=None, /)\n--\n\n"
                     "Return the value for `key` if `key` has the value in the context object.\n\n"
                     "If `key` does not exist, return `default`.  If `default` is not\n"
                     "given, return None."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("items"),
                 ml_meth=ptr(_contextvars_Context_items),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "items($self, /)\n--\n\n"
                     "Return all variables and their values in the context object.\n\n"
                     "The result is returned as a list of 2-tuples (variable, value)."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("keys"),
                 ml_meth=ptr(_contextvars_Context_keys),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "keys($self, /)\n--\n\n"
                     "Return a list of all variables in the context object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("values"),
                 ml_meth=ptr(_contextvars_Context_values),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "values($self, /)\n--\n\n"
                     "Return a list of all variables' values in the context object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(_contextvars_Context_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "copy($self, /)\n--\n\nReturn a shallow copy of the context object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("run"),
                 ml_meth=ptr(context_run),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         PyContext_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_contains=context_tp_contains
         ),
         PyContext_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=context_tp_len, mp_subscript=context_tp_subscript
         ),
         PyContextVar_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("name"),
                 type_=_Py_T_OBJECT,
                 offset=PyContextVar_VAR_NAME,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         PyContextVar_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("get"),
                 ml_meth=ptr(_contextvars_ContextVar_get),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "get($self, default=<unrepresentable>, /)\n--\n\n"
                     "Return a value for the context variable for the current context.\n\n"
                     "If there is no value for the variable in the current context, the\n"
                     "method will:\n"
                     " * return the value of the default argument of the method, if\n"
                     "   provided; or\n"
                     " * return the default value for the context variable, if it was\n"
                     "   created with one; or\n"
                     " * raise a LookupError."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("set"),
                 ml_meth=ptr(_contextvars_ContextVar_set),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "set($self, value, /)\n--\n\n"
                     "Call to set a new value for the context variable in the current context.\n\n"
                     "The required value argument is the new value for the context\n"
                     "variable.\n\n"
                     "Returns a Token object that can be used to restore the variable to\n"
                     "its previous value via the `ContextVar.reset()` method."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("reset"),
                 ml_meth=ptr(_contextvars_ContextVar_reset),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "reset($self, token, /)\n--\n\n"
                     "Reset the context variable.\n\n"
                     "The variable is reset to the value it had before the\n"
                     "`ContextVar.set()` that created the token was used."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "ContextVars are generic over the type of their contained values"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         PyContextTokenType_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("var"), get=token_get_var),
             PyGetSetDef(name=ptr[u8]("old_value"), get=token_get_old_value),
             PyGetSetDef()
         ],
         PyContextTokenType_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "Tokens are generic over the same type as the ContextVar which created them."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__enter__"),
                 ml_meth=ptr(token_enter),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__enter__($self, /)\n--\n\nEnter into Token context manager."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__exit__"),
                 ml_meth=ptr(token_exit),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "__exit__($self, type, val, tb, /)\n--\n\n"
                     "Exit from Token context manager, restore the linked ContextVar."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         contextvar_kwlist: list[ptr[u8]] = [
             ptr[u8](""),
             ptr[u8]("default"),
             ptr[u8]()
         ]; glob PyContext_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("_contextvars.Context"),
             tp_basicsize=PyContext_SIZE,
             tp_dealloc=context_tp_dealloc,
             tp_as_sequence=addressof(PyContext_as_sequence),
             tp_as_mapping=addressof(PyContext_as_mapping),
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=context_tp_traverse,
             tp_clear=context_tp_clear,
             tp_richcompare=context_tp_richcompare,
             tp_weaklistoffset=PyContext_CTX_WEAKREFLIST,
             tp_iter=context_tp_iter,
             tp_methods=addressof(PyContext_methods),
             tp_new=context_tp_new
         ),
         PyContextVar_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("_contextvars.ContextVar"),
             tp_basicsize=PyContextVar_SIZE,
             tp_dealloc=contextvar_tp_dealloc,
             tp_repr=contextvar_tp_repr,
             tp_hash=contextvar_tp_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=contextvar_tp_traverse,
             tp_clear=contextvar_tp_clear,
             tp_methods=addressof(PyContextVar_methods),
             tp_members=addressof(PyContextVar_members),
             tp_new=contextvar_tp_new,
             tp_free=PyObject_GC_Del
         ),
         PyContextToken_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("_contextvars.Token"),
             tp_basicsize=PyContextToken_SIZE,
             tp_dealloc=token_tp_dealloc,
             tp_repr=token_tp_repr,
             tp_hash=PyObject_HashNotImplemented,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=token_tp_traverse,
             tp_clear=token_tp_clear,
             tp_methods=addressof(PyContextTokenType_methods),
             tp_getset=addressof(PyContextTokenType_getsetlist),
             tp_new=token_tp_new,
             tp_free=PyObject_GC_Del
         ),
         _PyContextTokenMissing_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("Token.MISSING"),
             tp_basicsize=_PyContextTokenMissing_SIZE,
             tp_dealloc=context_token_missing_tp_dealloc,
             tp_repr=context_token_missing_tp_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
         );
}

def context_of(op: ptr[PyObject]) -> ptr[PyContext];

def contextvar_of(op: ptr[PyObject]) -> ptr[PyContextVar];

def token_of(op: ptr[PyObject]) -> ptr[PyContextToken];

def context_check_exact(op: ptr[PyObject]) -> bool;

def contextvar_check_exact(op: ptr[PyObject]) -> bool;

def token_check_exact(op: ptr[PyObject]) -> bool;

def ts_context_slot(ts: ptr[PyThreadState]) -> ptr[ptr[PyObject]];

def ts_context_ver(ts: ptr[PyThreadState]) -> ptr[u64];

def ts_id(ts: ptr[PyThreadState]) -> u64;

def context_event_name(event: i32) -> ptr[u8];

def notify_context_watchers(ts: ptr[PyThreadState], event: i32, ctx: ptr[PyObject]);

def context_switched(ts: ptr[PyThreadState]);

def _PyContext_Enter(ts: ptr[PyThreadState], octx: ptr[PyObject]) -> i32;

def _PyContext_Exit(ts: ptr[PyThreadState], octx: ptr[PyObject]) -> i32;

def contextvar_get(
    ovar: ptr[PyObject], dflt: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def _context_alloc -> ptr[PyContext];

def context_new_empty -> ptr[PyContext];

def context_new_from_vars(vars: ptr[PyHamtObject]) -> ptr[PyContext];

def context_get -> ptr[PyContext];

def context_check_key_type(key: ptr[PyObject]) -> i32;

def context_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def context_tp_clear(op: ptr[PyObject]) -> i32;

def context_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def context_tp_dealloc(self_: ptr[PyObject]);

def context_tp_iter(op: ptr[PyObject]) -> ptr[PyObject];

def context_tp_richcompare(
    v: ptr[PyObject], w: ptr[PyObject], op: i32
) -> ptr[PyObject];

def context_tp_len(op: ptr[PyObject]) -> i64;

def context_tp_subscript(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def context_tp_contains(op: ptr[PyObject], key: ptr[PyObject]) -> i32;

def _contextvars_Context_get_impl(
    self_: ptr[PyContext], key: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_Context_get(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def _contextvars_Context_items_impl(self_: ptr[PyContext]) -> ptr[PyObject];

def _contextvars_Context_items(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_Context_keys_impl(self_: ptr[PyContext]) -> ptr[PyObject];

def _contextvars_Context_keys(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_Context_values_impl(self_: ptr[PyContext]) -> ptr[PyObject];

def _contextvars_Context_values(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_Context_copy_impl(self_: ptr[PyContext]) -> ptr[PyObject];

def _contextvars_Context_copy(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject];

def context_run(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def contextvar_set(var: ptr[PyContextVar], val: ptr[PyObject]) -> i32;

def contextvar_del(var: ptr[PyContextVar]) -> i32;

def contextvar_generate_hash(addr: ptr, name: ptr[PyObject]) -> i64;

def contextvar_new(name: ptr[PyObject], dflt: ptr[PyObject]) -> ptr[PyObject];

def contextvar_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def contextvar_tp_clear(op: ptr[PyObject]) -> i32;

def contextvar_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def contextvar_tp_dealloc(self_: ptr[PyObject]);

def contextvar_tp_hash(op: ptr[PyObject]) -> i64;

def contextvar_tp_repr(op: ptr[PyObject]) -> ptr[PyObject];

def _contextvars_ContextVar_get_impl(
    self_: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_ContextVar_get(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def _contextvars_ContextVar_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_ContextVar_set(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_ContextVar_reset_impl(
    self_: ptr[PyObject], token: ptr[PyObject]
) -> ptr[PyObject];

def _contextvars_ContextVar_reset(
    self_: ptr[PyObject], token: ptr[PyObject]
) -> ptr[PyObject];

def token_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def token_tp_clear(op: ptr[PyObject]) -> i32;

def token_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def token_tp_dealloc(self_: ptr[PyObject]);

def token_tp_repr(op: ptr[PyObject]) -> ptr[PyObject];

def token_get_var(op: ptr[PyObject], _ignored: ptr) -> ptr[PyObject];

def token_get_old_value(op: ptr[PyObject], _ignored: ptr) -> ptr[PyObject];

def token_enter_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def token_enter(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def token_exit_impl(
    self_: ptr[PyObject], type: ptr[PyObject], val: ptr[PyObject], tb: ptr[PyObject]
) -> ptr[PyObject];

def token_exit(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def token_new(
    ctx: ptr[PyContext], var: ptr[PyContextVar], val: ptr[PyObject]
) -> ptr[PyObject];

def context_token_missing_tp_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def context_token_missing_tp_dealloc(self_: ptr[PyObject]);

def get_token_missing -> ptr[PyObject];

import from c {
    def _PyContext_NewHamtForTests -> ptr[PyObject] {
        return ptr[PyObject](_PyHamt_New());
    }  def PyContext_New -> ptr[PyObject] {
        return ptr[PyObject](context_new_empty());
    }  def PyContext_Copy(octx: ptr[PyObject]) -> ptr[PyObject] {
        if not context_check_exact(octx) {
            PyErr_SetString(PyExc_TypeError, "an instance of Context was expected");
            return NULL;
        }
        return ptr[PyObject](
            context_new_from_vars(context_of(octx).view(1)[0].ctx_vars)
        );
    }  def PyContext_CopyCurrent -> ptr[PyObject] {
        ctx = context_get();
        if not ctx {
            return NULL;
        }
        return ptr[PyObject](context_new_from_vars(ctx.view(1)[0].ctx_vars));
    }  def PyContext_AddWatcher(callback: ptr) -> i32 {
        interp = current_interp();
        for i in range(CONTEXT_MAX_WATCHERS) {
            slot = ptr[int](interp + PyInterpreterState_CONTEXT_WATCHERS) + i;
            if slot.view(1)[0] == 0 {
                slot.view(1)[0] = int(callback);
                active = interp + PyInterpreterState_ACTIVE_CONTEXT_WATCHERS;
                active.view(1)[0] = active.view(1)[0] | u8(1 << i);
                return i32(i);
            }
        }
        PyErr_SetString(PyExc_RuntimeError, "no more context watcher IDs available");
        return i32(-1);
    }  def PyContext_ClearWatcher(watcher_id: i32) -> i32 {
        interp = current_interp();
        if watcher_id < 0 or i64(watcher_id) >= CONTEXT_MAX_WATCHERS {
            PyErr_Format(PyExc_ValueError, "Invalid context watcher ID %d", watcher_id);
            return i32(-1);
        }
        slot = ptr[int](interp + PyInterpreterState_CONTEXT_WATCHERS) + i64(watcher_id);
        if slot.view(1)[0] == 0 {
            PyErr_Format(
                PyExc_ValueError, "No context watcher set for ID %d", watcher_id
            );
            return i32(-1);
        }
        slot.view(1)[0] = 0;
        active = interp + PyInterpreterState_ACTIVE_CONTEXT_WATCHERS;
        active.view(1)[0] = active.view(1)[0] & ~u8(1 << i64(watcher_id));
        return i32(0);
    }  def PyContext_Enter(octx: ptr[PyObject]) -> i32 {
        return _PyContext_Enter(thread_state(), octx);
    }  def PyContext_Exit(octx: ptr[PyObject]) -> i32 {
        return _PyContext_Exit(thread_state(), octx);
    }  def PyContextVar_New(name: ptr[u8], dflt: ptr[PyObject]) -> ptr[PyObject] {
        pyname = PyUnicode_FromString(name);
        if not pyname {
            return NULL;
        }
        var = contextvar_new(pyname, dflt);
        object_decref(pyname);
        return var;
    }  def PyContextVar_Get(
        ovar: ptr[PyObject], dflt: ptr[PyObject], val: ptr[ptr[PyObject]]
    ) -> i32 {
        if not contextvar_check_exact(ovar) {
            PyErr_SetString(PyExc_TypeError, "an instance of ContextVar was expected");
            return i32(-1);
        }
        (status, found) = contextvar_get(ovar, dflt);
        if val {
            val.view(1)[0] = found;
        }
        return status;
    }  def PyContextVar_Set(ovar: ptr[PyObject], val: ptr[PyObject]) -> ptr[PyObject] {
        if not contextvar_check_exact(ovar) {
            PyErr_SetString(PyExc_TypeError, "an instance of ContextVar was expected");
            return NULL;
        }
        var = contextvar_of(ovar);
        ctx = context_get();
        if not ctx {
            return NULL;
        }
        (found, old_val) = hamt_find_value(ctx.view(1)[0].ctx_vars, ovar);
        if found < 0 {
            return NULL;
        }
        object_xincref(old_val);
        tok = token_new(ctx, var, old_val);
        object_xdecref(old_val);
        if contextvar_set(var, val) != 0 {
            object_decref(tok);
            return NULL;
        }
        return tok;
    }  def PyContextVar_Reset(ovar: ptr[PyObject], otok: ptr[PyObject]) -> i32 {
        if not contextvar_check_exact(ovar) {
            PyErr_SetString(PyExc_TypeError, "an instance of ContextVar was expected");
            return i32(-1);
        }
        if not token_check_exact(otok) {
            PyErr_SetString(PyExc_TypeError, "an instance of Token was expected");
            return i32(-1);
        }
        var = contextvar_of(ovar);
        tok = token_of(otok);
        if tok.view(1)[0].tok_used != 0 {
            PyErr_Format(PyExc_RuntimeError, "%R has already been used once", otok);
            return i32(-1);
        }
        if var != tok.view(1)[0].tok_var {
            PyErr_Format(
                PyExc_ValueError, "%R was created by a different ContextVar", otok
            );
            return i32(-1);
        }
        ctx = context_get();
        if ctx != tok.view(1)[0].tok_ctx {
            PyErr_Format(
                PyExc_ValueError, "%R was created in a different Context", otok
            );
            return i32(-1);
        }
        tok.view(1)[0].tok_used = 1;
        oldval = tok.view(1)[0].tok_oldval;
        if not oldval {
            return contextvar_del(var);
        }
        return contextvar_set(var, oldval);
    }  def _PyContext_Init(interp: ptr) -> PyStatus {
        missing = get_token_missing();
        if PyDict_SetItemString(
            _PyType_GetDict(ptr[PyObject](addressof(PyContextToken_Type))),
            ptr[u8]("MISSING"),
            missing
        )
            != 0 {
            object_decref(missing);
            return status_err(
                ptr[u8]("_PyContext_Init"), ptr[u8]("can't init context types")
            );
        }
        object_decref(missing);
        return status_ok();
    }
}

impl context_of(op: ptr[PyObject]) -> ptr[PyContext] {
    return ptr[PyContext](op);
}

impl contextvar_of(op: ptr[PyObject]) -> ptr[PyContextVar] {
    return ptr[PyContextVar](op);
}

impl token_of(op: ptr[PyObject]) -> ptr[PyContextToken] {
    return ptr[PyContextToken](op);
}

impl context_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyContext_Type));
}

impl contextvar_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyContextVar_Type));
}

impl token_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyContextToken_Type));
}

impl ts_context_slot(ts: ptr[PyThreadState]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](ts) + PyThreadState_CONTEXT);
}

impl ts_context_ver(ts: ptr[PyThreadState]) -> ptr[u64] {
    return ptr[u64](ptr[u8](ts) + PyThreadState_CONTEXT_VER);
}

impl ts_id(ts: ptr[PyThreadState]) -> u64 {
    return ptr[u64](ptr[u8](ts) + PyThreadState_ID).view(1)[0];
}

impl context_event_name(event: i32) -> ptr[u8] {
    if event == Py_CONTEXT_SWITCHED {
        return ptr[u8]("Py_CONTEXT_SWITCHED");
    }
    return ptr[u8]("?");
}

impl notify_context_watchers(ts: ptr[PyThreadState], event: i32, ctx: ptr[PyObject]) {
    target = ctx;
    if not target {
        target = Py_None;
    }
    interp = ptr[ptr[u8]](ptr[u8](ts) + PyThreadState_INTERP).view(1)[0];
    bits = (interp + PyInterpreterState_ACTIVE_CONTEXT_WATCHERS).view(1)[0];
    i: i64 = 0;
    while bits != u8(0) {
        if (bits & u8(1)) != u8(0) {
            calls = ptr[ContextWatcherCall](
                __thread_local_block("jac_object_model_context_watcher_slot", 8)
            );
            calls.view(1)[0].watcher = (
                ptr[int](interp + PyInterpreterState_CONTEXT_WATCHERS) + i
            ).view(
                1
            )[0];
            if calls.view(1)[0].watcher(event, target) < 0 {
                PyErr_FormatUnraisable(
                    "Exception ignored in %s watcher callback for %R",
                    context_event_name(event),
                    target
                );
            }
        }
        i += 1;
        bits = bits >> u8(1);
    }
}

impl context_switched(ts: ptr[PyThreadState]) {
    ver = ts_context_ver(ts);
    ver.view(1)[0] = wrapping_add(ver.view(1)[0], u64(1));

    notify_context_watchers(ts, Py_CONTEXT_SWITCHED, ts_context_slot(ts).view(1)[0]);
}

impl _PyContext_Enter(ts: ptr[PyThreadState], octx: ptr[PyObject]) -> i32 {
    if not context_check_exact(octx) {
        PyErr_SetString(PyExc_TypeError, "an instance of Context was expected");
        return i32(-1);
    }
    ctx = context_of(octx);
    if ctx.view(1)[0].ctx_entered != 0 {
        _PyErr_Format(
            ts,
            PyExc_RuntimeError,
            ptr[u8]("cannot enter context: %R is already entered"),
            octx
        );
        return i32(-1);
    }
    slot = ts_context_slot(ts);

    ctx.view(1)[0].ctx_prev = ptr[PyContext](slot.view(1)[0]);
    ctx.view(1)[0].ctx_entered = 1;
    slot.view(1)[0] = object_new_ref(octx);
    context_switched(ts);
    return i32(0);
}

impl _PyContext_Exit(ts: ptr[PyThreadState], octx: ptr[PyObject]) -> i32 {
    if not context_check_exact(octx) {
        PyErr_SetString(PyExc_TypeError, "an instance of Context was expected");
        return i32(-1);
    }
    ctx = context_of(octx);
    if ctx.view(1)[0].ctx_entered == 0 {
        PyErr_Format(
            PyExc_RuntimeError, "cannot exit context: %R has not been entered", octx
        );
        return i32(-1);
    }
    slot = ts_context_slot(ts);
    if slot.view(1)[0] != octx {
        PyErr_SetString(
            PyExc_RuntimeError,
            "cannot exit context: thread state references a different context object"
        );
        return i32(-1);
    }
    old = slot.view(1)[0];
    slot.view(1)[0] = ptr[PyObject](ctx.view(1)[0].ctx_prev);
    object_decref(old);
    ctx.view(1)[0].ctx_prev = ptr[PyContext]();
    ctx.view(1)[0].ctx_entered = 0;
    context_switched(ts);
    return i32(0);
}

impl contextvar_get(
    ovar: ptr[PyObject], dflt: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    if not contextvar_check_exact(ovar) {
        PyErr_SetString(PyExc_TypeError, "an instance of ContextVar was expected");
        return (i32(-1), NULL);
    }
    var = contextvar_of(ovar);
    ts = thread_state();
    current = ts_context_slot(ts).view(1)[0];
    if current {
        cached = var.view(1)[0].var_cached;
        version = ts_context_ver(ts).view(1)[0];
        if cached
            and var.view(1)[0].var_cached_tsid == ts_id(ts)
            and var.view(1)[0].var_cached_tsver == version {
            return (i32(0), object_xnew_ref(cached));
        }
        (res, found) = hamt_find_value(context_of(current).view(1)[0].ctx_vars, ovar);
        if res < 0 {
            return (i32(-1), NULL);
        }
        if res == 1 {
            var.view(1)[0].var_cached = found;
            var.view(1)[0].var_cached_tsid = ts_id(ts);
            var.view(1)[0].var_cached_tsver = version;
            return (i32(0), object_xnew_ref(found));
        }
    }
    if not dflt {
        return (i32(0), object_xnew_ref(var.view(1)[0].var_default));
    }
    return (i32(0), object_xnew_ref(dflt));
}

impl _context_alloc -> ptr[PyContext] {
    op = freelist_pop(_Py_freelists_CONTEXTS);
    if not op {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyContext_Type)));
        if not op {
            return ptr[PyContext]();
        }
    }
    ctx = context_of(op);
    ctx.view(1)[0].ctx_vars = ptr[PyHamtObject]();
    ctx.view(1)[0].ctx_prev = ptr[PyContext]();
    ctx.view(1)[0].ctx_entered = 0;
    ctx.view(1)[0].ctx_weakreflist = NULL;
    return ctx;
}

impl context_new_empty -> ptr[PyContext] {
    ctx = _context_alloc();
    if not ctx {
        return ptr[PyContext]();
    }
    vars = _PyHamt_New();
    ctx.view(1)[0].ctx_vars = vars;
    if not vars {
        object_decref(ptr[PyObject](ctx));
        return ptr[PyContext]();
    }
    object_gc_track(ptr[PyObject](ctx));
    return ctx;
}

impl context_new_from_vars(vars: ptr[PyHamtObject]) -> ptr[PyContext] {
    ctx = _context_alloc();
    if not ctx {
        return ptr[PyContext]();
    }
    ctx.view(1)[0].ctx_vars = ptr[PyHamtObject](object_new_ref(ptr[PyObject](vars)));
    object_gc_track(ptr[PyObject](ctx));
    return ctx;
}

impl context_get -> ptr[PyContext] {
    ts = thread_state();
    slot = ts_context_slot(ts);
    current = slot.view(1)[0];
    if not current {
        fresh = context_new_empty();
        if not fresh {
            return ptr[PyContext]();
        }
        slot.view(1)[0] = ptr[PyObject](fresh);
        return fresh;
    }
    return context_of(current);
}

impl context_check_key_type(key: ptr[PyObject]) -> i32 {
    if not contextvar_check_exact(key) {
        PyErr_Format(PyExc_TypeError, "a ContextVar key was expected, got %R", key);
        return i32(-1);
    }
    return i32(0);
}

impl context_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if PyTuple_Size(args) != 0 or (kwds and PyDict_Size(kwds) != 0) {
        PyErr_SetString(PyExc_TypeError, "Context() does not accept any arguments");
        return NULL;
    }
    return PyContext_New();
}

impl context_tp_clear(op: ptr[PyObject]) -> i32 {
    ctx = context_of(op);
    prev = ptr[PyObject](ctx.view(1)[0].ctx_prev);
    if prev {
        ctx.view(1)[0].ctx_prev = ptr[PyContext]();
        object_decref(prev);
    }
    vars = ptr[PyObject](ctx.view(1)[0].ctx_vars);
    if vars {
        ctx.view(1)[0].ctx_vars = ptr[PyHamtObject]();
        object_decref(vars);
    }
    return i32(0);
}

impl context_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    ctx = context_of(op);
    vret = visit_reference(ptr[PyObject](ctx.view(1)[0].ctx_prev), visitor, arg);
    if vret != i32(0) {
        return vret;
    }
    return visit_reference(ptr[PyObject](ctx.view(1)[0].ctx_vars), visitor, arg);
}

impl context_tp_dealloc(self_: ptr[PyObject]) {
    object_gc_untrack(self_);
    if context_of(self_).view(1)[0].ctx_weakreflist {
        PyObject_ClearWeakRefs(self_);
    }
    context_tp_clear(self_);
    if not freelist_push(_Py_freelists_CONTEXTS, self_, Py_contexts_MAXFREELIST) {
        object_type(self_).view(1)[0].tp_free(ptr(self_));
    }
}

impl context_tp_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    return _PyHamt_NewIterKeys(context_of(op).view(1)[0].ctx_vars);
}

impl context_tp_richcompare(
    v: ptr[PyObject], w: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if not context_check_exact(v)
        or not context_check_exact(w)
        or (op != Py_EQ and op != Py_NE) {
        return object_new_ref(Py_NotImplemented);
    }
    res = _PyHamt_Eq(
        context_of(v).view(1)[0].ctx_vars, context_of(w).view(1)[0].ctx_vars
    );
    if res < 0 {
        return NULL;
    }
    if op == Py_NE {
        if res != 0 {
            res = i32(0);
        } else {
            res = i32(1);
        }
    }
    return PyBool_FromLong(i64(res));
}

impl context_tp_len(op: ptr[PyObject]) -> i64 {
    return _PyHamt_Len(context_of(op).view(1)[0].ctx_vars);
}

impl context_tp_subscript(op: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    if context_check_key_type(key) != 0 {
        return NULL;
    }
    (found, val) = hamt_find_value(context_of(op).view(1)[0].ctx_vars, key);
    if found < 0 {
        return NULL;
    }
    if found == 0 {
        PyErr_SetObject(PyExc_KeyError, key);
        return NULL;
    }
    return object_new_ref(val);
}

impl context_tp_contains(op: ptr[PyObject], key: ptr[PyObject]) -> i32 {
    if context_check_key_type(key) != 0 {
        return i32(-1);
    }
    (found, _val) = hamt_find_value(context_of(op).view(1)[0].ctx_vars, key);
    return found;
}

impl _contextvars_Context_get_impl(
    self_: ptr[PyContext], key: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    if context_check_key_type(key) != 0 {
        return NULL;
    }
    (found, val) = hamt_find_value(self_.view(1)[0].ctx_vars, key);
    if found < 0 {
        return NULL;
    }
    if found == 0 {
        return object_new_ref(default_value);
    }
    return object_new_ref(val);
}

impl _contextvars_Context_get(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional("get", nargs, 1, 2) == 0 {
        return NULL;
    }
    key = args.view(1)[0];
    default_value = Py_None;
    if nargs >= 2 {
        default_value = (args + 1).view(1)[0];
    }
    return _contextvars_Context_get_impl(context_of(self_), key, default_value);
}

impl _contextvars_Context_items_impl(self_: ptr[PyContext]) -> ptr[PyObject] {
    return _PyHamt_NewIterItems(self_.view(1)[0].ctx_vars);
}

impl _contextvars_Context_items(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _contextvars_Context_items_impl(context_of(self_));
}

impl _contextvars_Context_keys_impl(self_: ptr[PyContext]) -> ptr[PyObject] {
    return _PyHamt_NewIterKeys(self_.view(1)[0].ctx_vars);
}

impl _contextvars_Context_keys(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _contextvars_Context_keys_impl(context_of(self_));
}

impl _contextvars_Context_values_impl(self_: ptr[PyContext]) -> ptr[PyObject] {
    return _PyHamt_NewIterValues(self_.view(1)[0].ctx_vars);
}

impl _contextvars_Context_values(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _contextvars_Context_values_impl(context_of(self_));
}

impl _contextvars_Context_copy_impl(self_: ptr[PyContext]) -> ptr[PyObject] {
    return ptr[PyObject](context_new_from_vars(self_.view(1)[0].ctx_vars));
}

impl _contextvars_Context_copy(
    self_: ptr[PyObject], _unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _contextvars_Context_copy_impl(context_of(self_));
}

impl context_run(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    ts = thread_state();
    if nargs < 1 {
        _PyErr_SetString(
            ts, PyExc_TypeError, ptr[u8]("run() missing 1 required positional argument")
        );
        return NULL;
    }
    if _PyContext_Enter(ts, self_) != 0 {
        return NULL;
    }
    call_result = vectorcall_tstate(
        ts, args.view(1)[0], args + 1, u64(nargs - 1), kwnames
    );
    if _PyContext_Exit(ts, self_) != 0 {
        object_xdecref(call_result);
        return NULL;
    }
    return call_result;
}

impl contextvar_set(var: ptr[PyContextVar], val: ptr[PyObject]) -> i32 {
    var.view(1)[0].var_cached = NULL;
    ts = thread_state();
    ctx = context_get();
    if not ctx {
        return i32(-1);
    }
    new_vars = _PyHamt_Assoc(ctx.view(1)[0].ctx_vars, ptr[PyObject](var), val);
    if not new_vars {
        return i32(-1);
    }
    old = ptr[PyObject](ctx.view(1)[0].ctx_vars);
    ctx.view(1)[0].ctx_vars = new_vars;
    object_decref(old);

    var.view(1)[0].var_cached = val;
    var.view(1)[0].var_cached_tsid = ts_id(ts);
    var.view(1)[0].var_cached_tsver = ts_context_ver(ts).view(1)[0];
    return i32(0);
}

impl contextvar_del(var: ptr[PyContextVar]) -> i32 {
    var.view(1)[0].var_cached = NULL;
    ctx = context_get();
    if not ctx {
        return i32(-1);
    }
    vars = ctx.view(1)[0].ctx_vars;
    new_vars = _PyHamt_Without(vars, ptr[PyObject](var));
    if not new_vars {
        return i32(-1);
    }
    if vars == new_vars {
        object_decref(ptr[PyObject](new_vars));
        PyErr_SetObject(PyExc_LookupError, ptr[PyObject](var));
        return i32(-1);
    }
    ctx.view(1)[0].ctx_vars = new_vars;
    object_decref(ptr[PyObject](vars));
    return i32(0);
}

impl contextvar_generate_hash(addr: ptr, name: ptr[PyObject]) -> i64 {
    name_hash = PyObject_Hash(name);
    if name_hash == -1 {
        return -1;
    }
    res = Py_HashPointer(addr) ^ name_hash;
    if res == -1 {
        return -2;
    }
    return res;
}

impl contextvar_new(name: ptr[PyObject], dflt: ptr[PyObject]) -> ptr[PyObject] {
    if not unicode_check(name) {
        PyErr_SetString(PyExc_TypeError, "context variable name must be a str");
        return NULL;
    }
    op = _PyObject_GC_New(ptr[PyObject](addressof(PyContextVar_Type)));
    if not op {
        return NULL;
    }
    var = contextvar_of(op);
    var.view(1)[0].var_name = object_new_ref(name);
    var.view(1)[0].var_default = object_xnew_ref(dflt);
    var.view(1)[0].var_cached = NULL;
    var.view(1)[0].var_cached_tsid = u64(0);
    var.view(1)[0].var_cached_tsver = u64(0);
    var.view(1)[0].var_hash = contextvar_generate_hash(ptr(op), name);
    if var.view(1)[0].var_hash == -1 {
        object_decref(op);
        return NULL;
    }
    if gc_may_be_tracked(name) or (dflt and gc_may_be_tracked(dflt)) {
        PyObject_GC_Track(op);
    }
    return op;
}

impl contextvar_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    name = NULL;
    dflt = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        "O|$O:ContextVar",
        ptr(addressof(contextvar_kwlist)),
        &mut name,
        &mut dflt
    )
        == 0 {
        return NULL;
    }
    return contextvar_new(name, dflt);
}

impl contextvar_tp_clear(op: ptr[PyObject]) -> i32 {
    var = contextvar_of(op);
    name = var.view(1)[0].var_name;
    if name {
        var.view(1)[0].var_name = NULL;
        object_decref(name);
    }
    dflt = var.view(1)[0].var_default;
    if dflt {
        var.view(1)[0].var_default = NULL;
        object_decref(dflt);
    }
    var.view(1)[0].var_cached = NULL;
    var.view(1)[0].var_cached_tsid = u64(0);
    var.view(1)[0].var_cached_tsver = u64(0);
    return i32(0);
}

impl contextvar_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    var = contextvar_of(op);
    vret = visit_reference(var.view(1)[0].var_name, visitor, arg);
    if vret != i32(0) {
        return vret;
    }
    return visit_reference(var.view(1)[0].var_default, visitor, arg);
}

impl contextvar_tp_dealloc(self_: ptr[PyObject]) {
    PyObject_GC_UnTrack(self_);
    contextvar_tp_clear(self_);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl contextvar_tp_hash(op: ptr[PyObject]) -> i64 {
    return contextvar_of(op).view(1)[0].var_hash;
}

impl contextvar_tp_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    var = contextvar_of(op);

    estimate: i64 = 43;
    if var.view(1)[0].var_default {
        estimate = 53;
    }
    writer = PyUnicodeWriter_Create(estimate);
    if not writer {
        return NULL;
    }
    if PyUnicodeWriter_WriteASCII(writer, ptr[u8]("<ContextVar name="), 17) < 0
        or PyUnicodeWriter_WriteRepr(writer, var.view(1)[0].var_name) < 0 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    if var.view(1)[0].var_default {
        if PyUnicodeWriter_WriteASCII(writer, ptr[u8](" default="), 9) < 0
            or PyUnicodeWriter_WriteRepr(writer, var.view(1)[0].var_default) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
    }
    if PyUnicodeWriter_Format(writer, " at %p>", op) < 0 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

impl _contextvars_ContextVar_get_impl(
    self_: ptr[PyObject], default_value: ptr[PyObject]
) -> ptr[PyObject] {
    (status, val) = contextvar_get(self_, default_value);
    if status < 0 {
        return NULL;
    }
    if not val {
        PyErr_SetObject(PyExc_LookupError, self_);
        return NULL;
    }
    return val;
}

impl _contextvars_ContextVar_get(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional("get", nargs, 0, 1) == 0 {
        return NULL;
    }
    default_value = NULL;
    if nargs >= 1 {
        default_value = args.view(1)[0];
    }
    return _contextvars_ContextVar_get_impl(self_, default_value);
}

impl _contextvars_ContextVar_set_impl(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    return PyContextVar_Set(self_, value);
}

impl _contextvars_ContextVar_set(
    self_: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    return _contextvars_ContextVar_set_impl(self_, value);
}

impl _contextvars_ContextVar_reset_impl(
    self_: ptr[PyObject], token: ptr[PyObject]
) -> ptr[PyObject] {
    if not token_check_exact(token) {
        PyErr_Format(PyExc_TypeError, "expected an instance of Token, got %R", token);
        return NULL;
    }
    if PyContextVar_Reset(self_, token) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl _contextvars_ContextVar_reset(
    self_: ptr[PyObject], token: ptr[PyObject]
) -> ptr[PyObject] {
    return _contextvars_ContextVar_reset_impl(self_, token);
}

impl token_tp_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(PyExc_RuntimeError, "Tokens can only be created by ContextVars");
    return NULL;
}

impl token_tp_clear(op: ptr[PyObject]) -> i32 {
    tok = token_of(op);
    ctx = ptr[PyObject](tok.view(1)[0].tok_ctx);
    if ctx {
        tok.view(1)[0].tok_ctx = ptr[PyContext]();
        object_decref(ctx);
    }
    var = ptr[PyObject](tok.view(1)[0].tok_var);
    if var {
        tok.view(1)[0].tok_var = ptr[PyContextVar]();
        object_decref(var);
    }
    oldval = tok.view(1)[0].tok_oldval;
    if oldval {
        tok.view(1)[0].tok_oldval = NULL;
        object_decref(oldval);
    }
    return i32(0);
}

impl token_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    tok = token_of(op);
    vret = visit_reference(ptr[PyObject](tok.view(1)[0].tok_ctx), visitor, arg);
    if vret != i32(0) {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](tok.view(1)[0].tok_var), visitor, arg);
    if vret != i32(0) {
        return vret;
    }
    return visit_reference(tok.view(1)[0].tok_oldval, visitor, arg);
}

impl token_tp_dealloc(self_: ptr[PyObject]) {
    PyObject_GC_UnTrack(self_);
    token_tp_clear(self_);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
}

impl token_tp_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    tok = token_of(op);
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        return NULL;
    }
    if PyUnicodeWriter_WriteASCII(writer, ptr[u8]("<Token"), 6) < 0 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    if tok.view(1)[0].tok_used != 0 {
        if PyUnicodeWriter_WriteASCII(writer, ptr[u8](" used"), 5) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
    }
    if PyUnicodeWriter_WriteASCII(writer, ptr[u8](" var="), 5) < 0
        or PyUnicodeWriter_WriteRepr(writer, ptr[PyObject](tok.view(1)[0].tok_var)) < 0
        or PyUnicodeWriter_Format(writer, " at %p>", op) < 0 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

impl token_get_var(op: ptr[PyObject], _ignored: ptr) -> ptr[PyObject] {
    return object_new_ref(ptr[PyObject](token_of(op).view(1)[0].tok_var));
}

impl token_get_old_value(op: ptr[PyObject], _ignored: ptr) -> ptr[PyObject] {
    oldval = token_of(op).view(1)[0].tok_oldval;
    if not oldval {
        return get_token_missing();
    }
    return object_new_ref(oldval);
}

impl token_enter_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(self_);
}

impl token_enter(self_: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return token_enter_impl(self_);
}

impl token_exit_impl(
    self_: ptr[PyObject], type: ptr[PyObject], val: ptr[PyObject], tb: ptr[PyObject]
) -> ptr[PyObject] {
    ret = PyContextVar_Reset(ptr[PyObject](token_of(self_).view(1)[0].tok_var), self_);
    if ret < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl token_exit(
    self_: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional("__exit__", nargs, 3, 3) == 0 {
        return NULL;
    }
    return token_exit_impl(
        self_, args.view(1)[0], (args + 1).view(1)[0], (args + 2).view(1)[0]
    );
}

impl token_new(
    ctx: ptr[PyContext], var: ptr[PyContextVar], val: ptr[PyObject]
) -> ptr[PyObject] {
    op = _PyObject_GC_New(ptr[PyObject](addressof(PyContextToken_Type)));
    if not op {
        return NULL;
    }
    tok = token_of(op);
    tok.view(1)[0].tok_ctx = ptr[PyContext](object_new_ref(ptr[PyObject](ctx)));
    tok.view(1)[0].tok_var = ptr[PyContextVar](object_new_ref(ptr[PyObject](var)));
    tok.view(1)[0].tok_oldval = object_xnew_ref(val);
    tok.view(1)[0].tok_used = 0;
    PyObject_GC_Track(op);
    return op;
}

impl context_token_missing_tp_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("<Token.MISSING>"));
}

impl context_token_missing_tp_dealloc(self_: ptr[PyObject]) {
    return;
}

impl get_token_missing -> ptr[PyObject] {
    return ptr[PyObject](
        int(addressof(_PyRuntime)) + _PyRuntimeState_CONTEXT_TOKEN_MISSING
    );
}
