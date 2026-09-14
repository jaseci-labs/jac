"""Own an exported Python buffer across conversions that can invoke user code."""
import from c {
    def jacpy_buffer_acquire(value: u64, ascii: i64) -> u64;  def jacpy_buffer_release(
        value: u64
    );  def jacpy_buffer_bytes(view: u64) -> u64;  def jacpy_buffer_address(
        view: u64
    ) -> u64;  def jacpy_buffer_length(view: u64) -> i64;  def jacpy_buffer_dimensions(
        view: u64
    ) -> i64;  def jacpy_buffer_acquire_writable(value: u64) -> u64;  def jacpy_buffer_owner(
        view: u64
    ) -> u64;
}

obj BufferArgument {
    has view: u64 = 0;

    def acquire(value: u64, ascii: bool = False) -> bool {
        self.close();
        self.view = jacpy_buffer_acquire(value, i64(ascii));
        return self.view != 0;
    }

    def bytes -> u64 {
        return jacpy_buffer_bytes(self.view);
    }

    def acquire_writable(value: u64) -> bool {
        self.close();
        self.view = jacpy_buffer_acquire_writable(value);
        return self.view != 0;
    }

    def owner -> u64 {
        return jacpy_buffer_owner(self.view);
    }

    def close {
        previous = self.view;
        self.view = 0;
        jacpy_buffer_release(previous);
    }

    def address -> u64 {
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

import from c {
    obj BufferLayout {
        has address: u64,
            count: i64,
            itemsize: i64,
            readonly: i64 = 0;
    }  def jacpy_binding_buffer_fill(
        view: u64, object: u64, layout: BufferLayout, format: str, flags: i32
    ) -> i32;  def jacpy_binding_buffer_dispose(view: u64);
}
