"""Memory-allocation tracing; derived from CPython 3.14.6 Modules/_tracemalloc.c.

The tracer itself hooks the allocators in Python/tracemalloc.c.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyLong_FromLong,
    PyLong_FromSize_t,
    PyObject,
    Py_NewRef,
    _PyTraceMalloc_ClearTraces,
    _PyTraceMalloc_GetMemory,
    _PyTraceMalloc_GetObjectTraceback,
    _PyTraceMalloc_GetTracebackLimit,
    _PyTraceMalloc_GetTracedMemory,
    _PyTraceMalloc_GetTraces,
    _PyTraceMalloc_IsTracing,
    _PyTraceMalloc_ResetPeak,
    _PyTraceMalloc_Start,
    _PyTraceMalloc_Stop
}
import from jaclang.runtime.python.bindings.converters { borrowed_none }

def:priv none -> ptr[PyObject] {
    return Py_NewRef(borrowed_none());
}

def _tracemalloc_is_tracing_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(_PyTraceMalloc_IsTracing()));
}

def _tracemalloc_clear_traces_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    _PyTraceMalloc_ClearTraces();
    return none();
}

def _tracemalloc__get_traces_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyTraceMalloc_GetTraces();
}

def _tracemalloc__get_object_traceback_impl(
    module: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    return _PyTraceMalloc_GetObjectTraceback(obj_);
}

def _tracemalloc_start_impl(module: ptr[PyObject], nframe: i32) -> ptr[PyObject] {
    if _PyTraceMalloc_Start(nframe) < 0 {
        return NULL;
    }
    return none();
}

def _tracemalloc_stop_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    _PyTraceMalloc_Stop();
    return none();
}

def _tracemalloc_get_traceback_limit_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(_PyTraceMalloc_GetTracebackLimit()));
}

def _tracemalloc_get_tracemalloc_memory_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromSize_t(_PyTraceMalloc_GetMemory());
}

def _tracemalloc_get_traced_memory_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _PyTraceMalloc_GetTracedMemory();
}

def _tracemalloc_reset_peak_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    _PyTraceMalloc_ResetPeak();
    return none();
}
