glob:priv PY_EQ: i32 = 2;

def:priv current_callbacks -> ptr[PyObject];

def:priv atexit_cleanup(callbacks: ptr[PyObject]);

def:priv atexit_callfuncs(callbacks: ptr[PyObject]);

import from c {
    def _PyAtExit_Init(interp: ptr[PyInterpreterState]) -> PyStatus {
        callbacks = PyList_New(0);
        jacpy_atexit_callbacks(interp).view(1)[0] = callbacks;
        if not callbacks {
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyAtExit_Init"),
                err_msg=ptr[u8]("memory allocation failed"),
                exitcode=0
            );
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def PyUnstable_AtExit(
        interp: ptr[PyInterpreterState], func: ptr, data: ptr
    ) -> i32 {
        return jacpy_atexit_push(interp, func, data);
    }  def _PyAtExit_Fini(interp: ptr[PyInterpreterState]) {
        slot = jacpy_atexit_callbacks(interp);
        callbacks = slot.view(1)[0];
        if callbacks {
            atexit_cleanup(callbacks);
        }

        slot.view(1)[0] = NULL;
        jacpy_release(callbacks);
        callback = jacpy_atexit_detach(interp);
        while callback {
            record = callback.view(1)[0];

            PyMem_Free(callback);
            record.func(record.data);
            callback = record.next;
        }
    }  def _PyAtExit_Call(interp: ptr[PyInterpreterState]) {
        atexit_callfuncs(jacpy_atexit_callbacks(interp).view(1)[0]);
    }
}

def atexit_register(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def atexit_run_exitfuncs(
    module: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def atexit_clear(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def atexit_ncallbacks(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def:priv atexit_unregister_locked(
    callbacks: ptr[PyObject], func: ptr[PyObject]
) -> i32;

def atexit_unregister(module: ptr[PyObject], func: ptr[PyObject]) -> ptr[PyObject];

impl current_callbacks -> ptr[PyObject] {
    return jacpy_atexit_callbacks(PyInterpreterState_Get()).view(1)[0];
}

impl atexit_cleanup(callbacks: ptr[PyObject]) {
    PyList_Clear(callbacks);
}

impl atexit_callfuncs(callbacks: ptr[PyObject]) {
    copy = PyList_GetSlice(callbacks, 0, PyList_Size(callbacks));
    if not copy {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while copying atexit callbacks")
        );
        return;
    }
    for index in range(int(PyList_Size(copy))) {
        item = PyList_GetItem(copy, i64(index));
        func = PyTuple_GetItem(item, 0);
        args = PyTuple_GetItem(item, 1);
        kwargs = PyTuple_GetItem(item, 2);
        result = PyObject_Call(func, args, NULL if kwargs == Py_None else kwargs);
        if not result {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored in atexit callback %R"), func
            );
        } else {
            jacpy_release(result);
        }
    }
    jacpy_release(copy);
    atexit_cleanup(callbacks);
}

impl atexit_register(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    count = PyTuple_Size(args);
    if count == 0 {
        object_error(PyExc_TypeError, "register() takes at least 1 argument (0 given)");
        return NULL;
    }
    func = PyTuple_GetItem(args, 0);
    if PyCallable_Check(func) == 0 {
        object_error(PyExc_TypeError, "the first argument must be callable");
        return NULL;
    }
    func_args = PyTuple_GetSlice(args, 1, count);
    if not func_args {
        return NULL;
    }
    func_kwargs = kwargs or borrowed_none();
    callback = PyTuple_New(3);
    if not callback {
        jacpy_release(func_args);
        return NULL;
    }
    jacpy_tuple_set_owned(callback, 0, Py_NewRef(func));
    jacpy_tuple_set_owned(callback, 1, func_args);
    jacpy_tuple_set_owned(callback, 2, Py_NewRef(func_kwargs));
    if PyList_Insert(current_callbacks(), 0, callback) < 0 {
        jacpy_release(callback);
        return NULL;
    }
    jacpy_release(callback);
    return Py_NewRef(func);
}

impl atexit_run_exitfuncs(
    module: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    atexit_callfuncs(current_callbacks());
    return Py_NewRef(borrowed_none());
}

impl atexit_clear(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    atexit_cleanup(current_callbacks());
    return Py_NewRef(borrowed_none());
}

impl atexit_ncallbacks(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromSsize_t(PyList_Size(current_callbacks()));
}

impl atexit_unregister_locked(callbacks: ptr[PyObject], func: ptr[PyObject]) -> i32 {
    index = PyList_Size(callbacks) - 1;
    while index >= 0 {
        item = Py_NewRef(PyList_GetItem(callbacks, index));
        cmp = PyObject_RichCompareBool(func, PyTuple_GetItem(item, 0), PY_EQ);
        if cmp < 0 {
            jacpy_release(item);
            return i32(-1);
        }
        if cmp == 1 {
            position = PyList_Size(callbacks) - 1;
            if index < position {
                position = index;
            }
            while position >= 0 {
                if PyList_GetItem(callbacks, position) == item {
                    if PyList_SetSlice(callbacks, position, position + 1, NULL) < 0 {
                        jacpy_release(item);
                        return i32(-1);
                    }
                    index = position;
                    break;
                }
                position -= 1;
            }
        }
        jacpy_release(item);
        if index >= PyList_Size(callbacks) {
            index = PyList_Size(callbacks);
        }
        index -= 1;
    }
    return i32(0);
}

impl atexit_unregister(module: ptr[PyObject], func: ptr[PyObject]) -> ptr[PyObject] {
    if atexit_unregister_locked(current_callbacks(), func) < 0 {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}
