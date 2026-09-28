"""Own an exported Python buffer across conversions that can invoke user code."""

obj BufferArgument {
    has view: ptr[Py_buffer] = ptr[Py_buffer]();

    def acquire(value: ptr[PyObject], ascii: bool = False) -> bool {
        self.close();
        self.view = jacpy_buffer_acquire(value, i64(ascii));
        return bool(self.view);
    }

    def bytes -> ptr[PyObject] {
        return jacpy_buffer_bytes(self.view);
    }

    def acquire_writable(value: ptr[PyObject]) -> bool {
        self.close();
        self.view = jacpy_buffer_acquire_writable(value);
        return bool(self.view);
    }

    def owner -> ptr[PyObject] {
        if not self.view {
            return NULL;
        }
        return self.view.view(1)[0].owner;
    }

    def close {
        previous = self.view;
        self.view = ptr[Py_buffer]();
        jacpy_buffer_release(previous);
    }

    def address -> ptr {
        return self.view.view(1)[0].buf;
    }

    def size -> i64 {
        return self.view.view(1)[0].length;
    }

    def dimensions -> i64 {
        return i64(self.view.view(1)[0].ndim);
    }

    def drop {
        self.close();
    }
}

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyObject,
    Py_buffer,
    jacpy_buffer_acquire,
    jacpy_buffer_acquire_writable,
    jacpy_buffer_bytes,
    jacpy_buffer_release
}
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
