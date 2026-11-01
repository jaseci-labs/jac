obj BufferArgument {
    has view: ptr[Py_buffer] = ptr[Py_buffer]();

    def acquire(value: ptr[PyObject], ascii: bool = False) -> bool;
    def acquire_text(value: ptr[PyObject]) -> bool;
    def bytes -> ptr[PyObject];
    def acquire_writable(value: ptr[PyObject]) -> bool;
    def acquire_string(value: ptr[PyObject]) -> bool;
    def export(value: ptr[PyObject], flags: i64) -> bool;
    def owner -> ptr[PyObject];
    def close;
    def address -> ptr;
    def size -> i64;
    def dimensions -> i64;
    def drop;
}

import from jaclang.runtime.python.cpython_api {
    jacpy_buffer_acquire,
    jacpy_buffer_bytes,
    jacpy_buffer_release,
    NULL,
    Py_buffer,
    PyArg_Parse,
    PyErr_NoMemory,
    PyMem_Calloc,
    PyMem_Free,
    PyObject,
    PyObject_GetBuffer
}
import from jaclang.runtime.python.layouts { PY_BUFFER_SIZE }

def:priv new_view -> ptr[Py_buffer];

import from c {
    obj BufferLayout {
        has address: ptr,
            count: i64,
            itemsize: i64,
            readonly: i64 = 0;
    }  def jacpy_binding_buffer_fill(
        view: ptr[Py_buffer],
        object: ptr[PyObject],
        layout: BufferLayout,
        format: str,
        flags: i32
    ) -> i32;  def jacpy_binding_buffer_dispose(view: ptr[Py_buffer]);
}

impl BufferArgument.acquire(value: ptr[PyObject], ascii: bool = False) -> bool {
    self.close();
    self.view = jacpy_buffer_acquire(value, i64(ascii));
    return bool(self.view);
}

impl BufferArgument.acquire_text(value: ptr[PyObject]) -> bool {
    self.close();
    self.view = jacpy_buffer_acquire(value, 2);
    return bool(self.view);
}

impl BufferArgument.bytes -> ptr[PyObject] {
    return jacpy_buffer_bytes(self.view);
}

impl BufferArgument.acquire_writable(value: ptr[PyObject]) -> bool {
    self.close();
    view = new_view();
    if view and PyArg_Parse(value, ptr[u8]("w*"), view) == 0 {
        PyMem_Free(view);
        view = ptr[Py_buffer]();
    }
    self.view = view;
    return bool(view);
}

impl BufferArgument.acquire_string(value: ptr[PyObject]) -> bool {
    self.close();
    view = new_view();
    if view and PyArg_Parse(value, ptr[u8]("s*"), view) == 0 {
        PyMem_Free(view);
        view = ptr[Py_buffer]();
    }
    self.view = view;
    return bool(view);
}

impl BufferArgument.export(value: ptr[PyObject], flags: i64) -> bool {
    self.close();
    view = new_view();
    if view and PyObject_GetBuffer(value, view, i32(flags)) < 0 {
        PyMem_Free(view);
        view = ptr[Py_buffer]();
    }
    self.view = view;
    return bool(view);
}

impl BufferArgument.owner -> ptr[PyObject] {
    if not self.view {
        return NULL;
    }
    return self.view.view(1)[0].owner;
}

impl BufferArgument.close {
    previous = self.view;
    self.view = ptr[Py_buffer]();
    jacpy_buffer_release(previous);
}

impl BufferArgument.address -> ptr {
    return self.view.view(1)[0].buf;
}

impl BufferArgument.size -> i64 {
    return self.view.view(1)[0].length;
}

impl BufferArgument.dimensions -> i64 {
    return i64(self.view.view(1)[0].ndim);
}

impl BufferArgument.drop {
    self.close();
}

impl new_view -> ptr[Py_buffer] {
    view = ptr[Py_buffer](PyMem_Calloc(1, PY_BUFFER_SIZE));
    if not view {
        PyErr_NoMemory();
    }
    return view;
}
