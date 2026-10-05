"""Native pickle byte streams, framing and bounds checks.

Retained Python objects provide byte storage and file callbacks. Protocol
framing and cursor progression are Jac policies. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyByteArray_Resize,
    PyErr_GetRaisedException,
    PyErr_SetRaisedException,
    PyLong_FromLongLong,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    Py_NewRef,
    jacpy_bytearray_new,
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_exception_context,
    jacpy_is_bytes,
    jacpy_memory_byte,
    jacpy_memory_copy,
    jacpy_memory_set,
    jacpy_offset,
    jacpy_release,
    jacpy_set_exception
}
import from jaclang.runtime.python.capi {
    required,
    checked,
    boundary_failure,
    object_error,
    object_tuple
}
import from jaclang.runtime.python.modules.binary_scalars { read_bits, write_bits }

def stream_error(kind: ptr[PyObject], message: str) {
    cause = PyErr_GetRaisedException();
    try {
        jacpy_set_exception(
            kind, message, i64(len(message.encode("utf-8", "surrogatepass")))
        );
        error = PyErr_GetRaisedException();
        if error != 0 {
            if cause != 0 {
                jacpy_exception_context(error, cause);
            }
            PyErr_SetRaisedException(error);
        }
    } finally {
        jacpy_release(cause);
    }
    raise boundary_failure();
}

def builtin_stream_error(kind: str, message: str) {
    cause = PyErr_GetRaisedException();
    try {
        object_error(kind, message);
        error = PyErr_GetRaisedException();
        if error != 0 {
            if cause != 0 {
                jacpy_exception_context(error, cause);
            }
            PyErr_SetRaisedException(error);
        }
    } finally {
        jacpy_release(cause);
    }
    raise boundary_failure();
}

obj pickle_writer {
    has buffer: ptr[PyObject] = NULL,
        write: ptr[PyObject] = NULL,
        framed: bool = False;

    def clear {
        buffer = self.buffer;
        write = self.write;
        self.buffer = NULL;
        self.write = NULL;
        jacpy_release(buffer);
        jacpy_release(write);
    }

    def initialize(write: ptr[PyObject], framed: bool) {
        self.clear();
        self.buffer = required(jacpy_bytearray_new(0));
        self.write = Py_NewRef(write);
        self.framed = framed;
    }

    def append(address: ptr, count: i64) {
        current = jacpy_bytes_length(self.buffer);
        if count < 0 or count > 9223372036854775807 - current {
            builtin_stream_error("OverflowError", "pickle byte stream is too large");
        }
        checked(PyByteArray_Resize(self.buffer, current + count));
        if count != 0 {
            jacpy_memory_copy(
                jacpy_offset(jacpy_bytes_address(self.buffer), current), address, count
            );
        }
    }

    def byte(value: int) {
        current = jacpy_bytes_length(self.buffer);
        if current == 9223372036854775807 {
            builtin_stream_error("OverflowError", "pickle byte stream is too large");
        }
        checked(PyByteArray_Resize(self.buffer, current + 1));
        jacpy_memory_set(jacpy_bytes_address(self.buffer), current, i64(value));
    }

    def integer(value: u64, width: int) {
        for i in range(width) {
            self.byte(int((value >> (i * 8)) & 255));
        }
    }

    def data(value: ptr[PyObject]) {
        self.append(jacpy_bytes_address(value), jacpy_bytes_length(value));
    }

    def send(value: ptr[PyObject]) {
        result = required(PyObject_CallOneArg(self.write, value));
        jacpy_release(result);
    }

    def flush(force: bool) {
        count = jacpy_bytes_length(self.buffer);
        if count == 0 or (not force and count < 65536) {
            return;
        }
        # Snapshot before calling write: callbacks cannot invalidate a borrowed
        # storage address or modify the bytes already handed to the stream.
        payload = required(
            jacpy_bytes_from_memory(jacpy_bytes_address(self.buffer), count)
        );
        try {
            checked(PyByteArray_Resize(self.buffer, 0));
            if self.framed and count >= 4 {
                header = required(jacpy_bytearray_new(9));
                try {
                    address = jacpy_bytes_address(header);
                    jacpy_memory_set(address, 0, 149);
                    write_bits(jacpy_offset(address, 1), 8, True, u64(count));
                    immutable = required(jacpy_bytes_from_memory(address, 9));
                    try {
                        self.send(immutable);
                    } finally {
                        jacpy_release(immutable);
                    }
                } finally {
                    jacpy_release(header);
                }
            }
            self.send(payload);
        } finally {
            jacpy_release(payload);
        }
    }
}

obj pickle_reader {
    has read: ptr[PyObject] = NULL,
        readline: ptr[PyObject] = NULL,
        frame: ptr[PyObject] = NULL,
        position: i64 = 0,
        error: ptr[PyObject] = NULL;

    def clear {
        read = self.read;
        readline = self.readline;
        frame = self.frame;
        error = self.error;
        self.read = NULL;
        self.readline = NULL;
        self.frame = NULL;
        self.error = NULL;
        self.position = 0;
        jacpy_release(read);
        jacpy_release(readline);
        jacpy_release(frame);
        jacpy_release(error);
    }

    def initialize(read: ptr[PyObject], readline: ptr[PyObject], error: ptr[PyObject]) {
        self.clear();
        self.read = Py_NewRef(read);
        self.readline = Py_NewRef(readline);
        self.error = Py_NewRef(error);
    }

    def file_read(count: i64) -> ptr[PyObject] {
        argument = required(PyLong_FromLongLong(count));
        result: ptr[PyObject] = NULL;
        try {
            result = required(PyObject_CallOneArg(self.read, argument));
        } finally {
            jacpy_release(argument);
        }
        if jacpy_is_bytes(result) == 0 {
            jacpy_release(result);
            builtin_stream_error("TypeError", "file.read() must return bytes");
        }
        return result;
    }

    def exact(count: i64) -> ptr[PyObject] {
        if count < 0 {
            stream_error(self.error, "pickle byte count is negative");
        }
        if self.frame != 0 {
            remaining = jacpy_bytes_length(self.frame) - self.position;
            if remaining == 0 {
                old = self.frame;
                self.frame = NULL;
                self.position = 0;
                jacpy_release(old);
            } elif remaining < count {
                stream_error(self.error, "pickle exhausted before end of frame");
            } else {
                result = required(
                    jacpy_bytes_from_memory(
                        jacpy_offset(jacpy_bytes_address(self.frame), self.position),
                        count
                    )
                );
                self.position += count;
                return result;
            }
        }
        result = self.file_read(count);
        if jacpy_bytes_length(result) != count {
            jacpy_release(result);
            stream_error(self.error, "pickle data was truncated");
        }
        return result;
    }

    def integer(width: int) -> u64 {
        value = self.exact(i64(width));
        try {
            return read_bits(jacpy_bytes_address(value), width, True);
        } finally {
            jacpy_release(value);
        }
    }

    def opcode -> int {
        if self.frame != 0 and self.position < jacpy_bytes_length(self.frame) {
            result = int(
                jacpy_memory_byte(jacpy_bytes_address(self.frame), self.position)
            );
            self.position += 1;
            return result;
        }
        old = self.frame;
        self.frame = NULL;
        self.position = 0;
        jacpy_release(old);
        value = self.file_read(1);
        try {
            if jacpy_bytes_length(value) == 0 {
                builtin_stream_error("EOFError", "Ran out of input");
            }
            if jacpy_bytes_length(value) != 1 {
                stream_error(self.error, "file.read() returned too many bytes");
            }
            return int(jacpy_memory_byte(jacpy_bytes_address(value), 0));
        } finally {
            jacpy_release(value);
        }
    }

    def line -> ptr[PyObject] {
        if self.frame != 0 {
            start = self.position;
            length = jacpy_bytes_length(self.frame);
            if start < length {
                address = jacpy_bytes_address(self.frame);
                for index in range(int(start), int(length)) {
                    if jacpy_memory_byte(address, i64(index)) == 10 {
                        self.position = i64(index) + 1;
                        return required(
                            jacpy_bytes_from_memory(
                                jacpy_offset(address, start), self.position - start
                            )
                        );
                    }
                }
                stream_error(self.error, "pickle exhausted before end of frame");
            }
            old = self.frame;
            self.frame = NULL;
            self.position = 0;
            jacpy_release(old);
        }
        arguments = object_tuple([]);
        value: ptr[PyObject] = NULL;
        try {
            value = required(PyObject_Call(self.readline, arguments, NULL));
        } finally {
            jacpy_release(arguments);
        }
        if jacpy_is_bytes(value) == 0 {
            jacpy_release(value);
            builtin_stream_error("TypeError", "file.readline() must return bytes");
        }
        length = jacpy_bytes_length(value);
        if length == 0
            or jacpy_memory_byte(jacpy_bytes_address(value), length - 1) != 10 {
            jacpy_release(value);
            stream_error(self.error, "pickle data was truncated");
        }
        return value;
    }

    def begin_frame(count: u64) {
        if count > 9223372036854775807 {
            builtin_stream_error(
                "OverflowError", "FRAME length exceeds system's maximum"
            );
        }
        if self.frame != 0 and self.position != jacpy_bytes_length(self.frame) {
            stream_error(
                self.error, "beginning of a new frame before end of current frame"
            );
        }
        old = self.frame;
        self.frame = NULL;
        self.position = 0;
        jacpy_release(old);
        self.frame = self.file_read(i64(count));
        if jacpy_bytes_length(self.frame) != i64(count) {
            stream_error(self.error, "pickle data was truncated");
        }
    }
}
