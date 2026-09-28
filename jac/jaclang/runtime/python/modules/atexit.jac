"""Exit callbacks; derived from CPython 3.14.6 Modules/atexitmodule.c.

The interpreter keeps both callback lists in PyInterpreterState: the Python
callbacks as a list of (func, args, kwargs) tuples, newest first, and the C
callbacks of PyUnstable_AtExit as a linked list of atexit_callback records.
The two list heads are interpreter-state fields (the C one guarded by a lock
macro), so the jacpy_atexit_* helpers of compiler_runtime.c reach them, and
_PyAtExit_Init stays C because it returns PyStatus by value. The records
themselves are C-layout structs walked and called here. The interpreter calls
the other hooks by their C names.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyCallable_Check,
    PyExc_TypeError,
    PyInterpreterState,
    PyInterpreterState_Get,
    PyList_Clear,
    PyList_GetItem,
    PyList_GetSlice,
    PyList_Insert,
    PyList_SetSlice,
    PyList_Size,
    PyLong_FromSsize_t,
    PyMem_Free,
    PyObject,
    PyObject_Call,
    PyObject_RichCompareBool,
    PyTuple_GetItem,
    PyTuple_GetSlice,
    PyTuple_New,
    PyTuple_Size,
    Py_NewRef,
    Py_None,
    jacpy_atexit_callbacks,
    jacpy_atexit_detach,
    jacpy_atexit_push,
    jacpy_atexit_release_callbacks,
    jacpy_release,
    jacpy_tuple_set_owned,
    jacpy_unraisable
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.converters { borrowed_none }

glob:priv PY_EQ: i32 = 2;

"""The current interpreter's list of Python callbacks (borrowed)."""
def:priv current_callbacks -> ptr[PyObject] {
    return jacpy_atexit_callbacks(PyInterpreterState_Get());
}

"""atexit_cleanup(): drop every Python callback without calling it."""
def:priv atexit_cleanup(callbacks: ptr[PyObject]) {
    PyList_Clear(callbacks);
}

"""atexit_callfuncs(): call the Python callbacks, newest first, then drop them."""
def:priv atexit_callfuncs(callbacks: ptr[PyObject]) {
    copy = PyList_GetSlice(callbacks, 0, PyList_Size(callbacks));
    if not copy {
        jacpy_unraisable("Exception ignored while copying atexit callbacks", NULL);
        return;
    }
    for index in range(int(PyList_Size(copy))) {
        item = PyList_GetItem(copy, i64(index));
        func = PyTuple_GetItem(item, 0);
        args = PyTuple_GetItem(item, 1);
        kwargs = PyTuple_GetItem(item, 2);
        result = PyObject_Call(func, args, NULL if kwargs == Py_None else kwargs);
        if not result {
            jacpy_unraisable("Exception ignored in atexit callback", func);
        } else {
            jacpy_release(result);
        }
    }
    jacpy_release(copy);
    atexit_cleanup(callbacks);
}

def:pub PyUnstable_AtExit(
    interp: ptr[PyInterpreterState], func: ptr, data: ptr
) -> i32 {
    return jacpy_atexit_push(interp, func, data);
}

"""Called once the interpreter no longer runs Python code: drop the Python
callbacks, then run the C ones newest first."""
def:pub _PyAtExit_Fini(interp: ptr[PyInterpreterState]) {
    callbacks = jacpy_atexit_callbacks(interp);
    if callbacks {
        atexit_cleanup(callbacks);
    }
    jacpy_atexit_release_callbacks(interp);
    callback = jacpy_atexit_detach(interp);
    while callback {
        record = callback.view(1)[0];
        # Freed before the call, as CPython does: the record is not needed after.
        PyMem_Free(callback);
        record.func(record.data);
        callback = record.next;
    }
}

def:pub _PyAtExit_Call(interp: ptr[PyInterpreterState]) {
    atexit_callfuncs(jacpy_atexit_callbacks(interp));
}

"""register(func, /, *args, **kwargs): func is returned, so it decorates."""
def atexit_register(
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

def atexit_run_exitfuncs(
    module: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    atexit_callfuncs(current_callbacks());
    return Py_NewRef(borrowed_none());
}

def atexit_clear(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    atexit_cleanup(current_callbacks());
    return Py_NewRef(borrowed_none());
}

def atexit_ncallbacks(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromSsize_t(PyList_Size(current_callbacks()));
}

"""Remove every registration of func, newest first. A comparison can run code
that unregisters callbacks, so a match is found again by identity."""
def:priv atexit_unregister_locked(
    callbacks: ptr[PyObject], func: ptr[PyObject]
) -> i32 {
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

def atexit_unregister(module: ptr[PyObject], func: ptr[PyObject]) -> ptr[PyObject] {
    if atexit_unregister_locked(current_callbacks(), func) < 0 {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}
