"""Native pickle byte streams, framing and bounds checks.

Retained Python objects provide byte storage and file callbacks. Protocol
framing and cursor progression are Jac policies. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_error_take,
    jacpy_error_restore,
    jacpy_exception_context,
    required,
    checked,
    boundary_failure,
    object_error,
    object_tuple,
    jacpy_release,
    jacpy_retain,
    jacpy_set_exception,
    jacpy_int,
    jacpy_call,
    jacpy_call_one,
    jacpy_bytes_from_memory,
    jacpy_bytes_address,
    jacpy_bytes_length,
    jacpy_is_bytes,
    jacpy_bytearray_new,
    jacpy_bytearray_resize,
    jacpy_memory_copy,
    jacpy_memory_byte,
    jacpy_memory_set
}
import from jaclang.runtime.python.modules.binary_scalars { read_bits, write_bits }

def stream_error(kind: u64, message: str) {
    cause = jacpy_error_take();
    try {
        jacpy_set_exception(
            kind, message, i64(len(message.encode("utf-8", "surrogatepass")))
        );
        error = jacpy_error_take();
        if error != 0 {
            if cause != 0 {
                jacpy_exception_context(error, cause);
            }
            jacpy_error_restore(error);
        }
    } finally {
        jacpy_release(cause);
    }
    raise boundary_failure();
}

def builtin_stream_error(kind: str, message: str) {
    cause = jacpy_error_take();
    try {
        object_error(kind, message);
        error = jacpy_error_take();
        if error != 0 {
            if cause != 0 {
                jacpy_exception_context(error, cause);
            }
            jacpy_error_restore(error);
        }
    } finally {
        jacpy_release(cause);
    }
    raise boundary_failure();
}

obj pickle_writer {
    has buffer: u64 = 0,
        write: u64 = 0,
        framed: bool = False;

    def clear {
        buffer = self.buffer;
        write = self.write;
        self.buffer = 0;
        self.write = 0;
        jacpy_release(buffer);
        jacpy_release(write);
    }

    def initialize(write: u64, framed: bool) {
        self.clear();
        self.buffer = required(jacpy_bytearray_new(0));
        self.write = jacpy_retain(write);
        self.framed = framed;
    }

    def append(address: u64, count: i64) {
        current = jacpy_bytes_length(self.buffer);
        if count < 0 or count > 9223372036854775807 - current {
            builtin_stream_error("OverflowError", "pickle byte stream is too large");
        }
        checked(jacpy_bytearray_resize(self.buffer, current + count));
        if count != 0 {
            jacpy_memory_copy(
                jacpy_bytes_address(self.buffer) + u64(current), address, count
            );
        }
    }

    def byte(value: int) {
        current = jacpy_bytes_length(self.buffer);
        if current == 9223372036854775807 {
            builtin_stream_error("OverflowError", "pickle byte stream is too large");
        }
        checked(jacpy_bytearray_resize(self.buffer, current + 1));
        jacpy_memory_set(jacpy_bytes_address(self.buffer), current, i64(value));
    }

    def integer(value: u64, width: int) {
        for i in range(width) {
            self.byte(int((value >> (i * 8)) & 255));
        }
    }

    def data(value: u64) {
        self.append(jacpy_bytes_address(value), jacpy_bytes_length(value));
    }

    def send(value: u64) {
        result = required(jacpy_call_one(self.write, value));
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
            checked(jacpy_bytearray_resize(self.buffer, 0));
            if self.framed and count >= 4 {
                header = required(jacpy_bytearray_new(9));
                try {
                    address = jacpy_bytes_address(header);
                    jacpy_memory_set(address, 0, 149);
                    write_bits(address + 1, 8, True, u64(count));
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
    has read: u64 = 0,
        readline: u64 = 0,
        frame: u64 = 0,
        position: i64 = 0,
        error: u64 = 0;

    def clear {
        read = self.read;
        readline = self.readline;
        frame = self.frame;
        error = self.error;
        self.read = 0;
        self.readline = 0;
        self.frame = 0;
        self.error = 0;
        self.position = 0;
        jacpy_release(read);
        jacpy_release(readline);
        jacpy_release(frame);
        jacpy_release(error);
    }

    def initialize(read: u64, readline: u64, error: u64) {
        self.clear();
        self.read = jacpy_retain(read);
        self.readline = jacpy_retain(readline);
        self.error = jacpy_retain(error);
    }

    def file_read(count: i64) -> u64 {
        argument = required(jacpy_int(count));
        result: u64 = 0;
        try {
            result = required(jacpy_call_one(self.read, argument));
        } finally {
            jacpy_release(argument);
        }
        if jacpy_is_bytes(result) == 0 {
            jacpy_release(result);
            builtin_stream_error("TypeError", "file.read() must return bytes");
        }
        return result;
    }

    def exact(count: i64) -> u64 {
        if count < 0 {
            stream_error(self.error, "pickle byte count is negative");
        }
        if self.frame != 0 {
            remaining = jacpy_bytes_length(self.frame) - self.position;
            if remaining == 0 {
                old = self.frame;
                self.frame = 0;
                self.position = 0;
                jacpy_release(old);
            } elif remaining < count {
                stream_error(self.error, "pickle exhausted before end of frame");
            } else {
                result = required(
                    jacpy_bytes_from_memory(
                        jacpy_bytes_address(self.frame) + u64(self.position), count
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
        self.frame = 0;
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

    def line -> u64 {
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
                                address + u64(start), self.position - start
                            )
                        );
                    }
                }
                stream_error(self.error, "pickle exhausted before end of frame");
            }
            old = self.frame;
            self.frame = 0;
            self.position = 0;
            jacpy_release(old);
        }
        arguments = object_tuple([]);
        value: u64 = 0;
        try {
            value = required(jacpy_call(self.readline, arguments, 0));
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
        self.frame = 0;
        self.position = 0;
        jacpy_release(old);
        self.frame = self.file_read(i64(count));
        if jacpy_bytes_length(self.frame) != i64(count) {
            stream_error(self.error, "pickle data was truncated");
        }
    }
}
