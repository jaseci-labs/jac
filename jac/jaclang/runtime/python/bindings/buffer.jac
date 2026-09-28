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
        return jacpy_buffer_owner(self.view);
    }

    def close {
        previous = self.view;
        self.view = ptr[Py_buffer]();
        jacpy_buffer_release(previous);
    }

    def address -> ptr {
        return jacpy_buffer_address(self.view);
    }

    def size -> i64 {
        return jacpy_buffer_length(self.view);
    }

    def dimensions -> i64 {
        return jacpy_buffer_dimensions(self.view);
    }

    def drop {
        self.close();
    }
}

import from jaclang.runtime.python.cpython_api {
    PyObject,
    Py_buffer,
    jacpy_buffer_acquire,
    jacpy_buffer_acquire_writable,
    jacpy_buffer_address,
    jacpy_buffer_bytes,
    jacpy_buffer_dimensions,
    jacpy_buffer_length,
    jacpy_buffer_owner,
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
